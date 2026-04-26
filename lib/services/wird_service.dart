import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:qurani/models/wird_model.dart';
import 'package:qurani/services/notification_service.dart';
import 'package:qurani/services/user_database_service.dart';

import 'logger.dart';

/// Persistence + orchestration for Daily Wirds.
///
/// ### Storage (v2 — SQLite)
///
/// All wirds (including soft-deleted ones) live in the `wirds` table of
/// `qurani_user.db`. Every write (increment, reset, add, update, delete) is
/// a single atomic SQL statement — no more read-modify-write on a JSON blob.
///
/// On first access after upgrading from the old SharedPreferences storage,
/// `_migrateFromPrefsIfNeeded()` copies the JSON blob into SQLite inside a
/// transaction, then deletes the prefs key so the migration runs exactly once.
///
/// ### Notifications
///
/// We explicitly reject `DateTimeComponents.dayOfWeekAndTime` (weekly
/// recurring) because the spec forbids notifying after today's completion.
/// Cancelling a weekly-recurring entry also kills the following week, so
/// we'd have to re-schedule anyway — which defeats the "set-and-forget"
/// selling point of recurring entries.
///
/// Instead we schedule **one-shot notifications for the next 7 days** per
/// active wird. On each app start (and after every mutation) the window is
/// re-armed, giving us per-occurrence control — we can skip today's
/// notification if the wird is already complete, without affecting tomorrow.
///
/// Note: The lookahead is strictly 7 days to avoid hitting iOS's 64-pending-notification
/// cap. A 14-day lookahead for a user with 5 daily Wirds creates 70 pending items,
/// causing silent drops. 7 days keeps heavy users under 35 pending items.
///
/// ### Daily reset
///
/// On every load, for each active wird whose `lastUpdatedDate` is strictly
/// before today AND today is one of the wird's selected days, we reset
/// `currentCount = 0` and set `lastUpdatedDate = today`. Wirds inactive
/// today are left alone so Friday's progress survives Thursday's rollover.
class WirdService {
  WirdService._();

  // Legacy SharedPreferences keys — only read during the one-shot migration.
  static const String _legacyKey = 'wirds_v1';
  static const String _seededKey = 'wirds_seeded_v1';

  /// Marker so we only attempt the SharedPreferences → SQLite migration
  /// once per install, even if the user later deletes all their wirds.
  static const String _keyMigrated = 'wirds_migrated_to_sqlite_v1';

  /// Prefs key pattern for the once-per-day reset guard.
  /// Value: `wird_daily_reset_YYYY-MM-DD`.
  static const String _resetPrefix = 'wird_daily_reset_';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns all non-deleted wirds after applying the daily reset.
  /// This is the primary query the Wird tab uses.
  static Future<List<Wird>> getActive() async {
    await _ensureMigrated();
    await _applyDailyResetIfNeeded();
    final db = await UserDatabaseService.database();
    final rows = await db.query(
      'wirds',
      where: 'is_deleted = 0',
      orderBy: 'position ASC, rowid ASC',
    );
    return rows.map((r) => Wird.fromRow(r)).toList();
  }

  /// Wirds that are non-deleted AND scheduled for today's weekday.
  static Future<List<Wird>> getTodays() async {
    final today = DateTime.now();
    final active = await getActive();
    return active.where((w) => w.isActiveOn(today)).toList();
  }

  /// Looks up a wird by id. Returns `null` if missing or soft-deleted.
  static Future<Wird?> findById(String id) async {
    await _ensureMigrated();
    final db = await UserDatabaseService.database();
    final rows = await db.query(
      'wirds',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Wird.fromRow(rows.first);
  }

  /// Adds a new wird. Returns the stored [Wird].
  static Future<Wird> add(Wird wird) async {
    await _ensureMigrated();
    final db = await UserDatabaseService.database();
    final position = await _nextPosition(db);
    final row = wird.toRow();
    row['position'] = position;
    await db.insert('wirds', row);
    await _rescheduleOne(wird);
    Log.i('WirdService', 'Added wird "${wird.title}" (${wird.id})');
    return wird;
  }

  /// Saves edits to an existing wird. Reschedules its notifications.
  static Future<void> update(Wird wird) async {
    final db = await UserDatabaseService.database();
    final row = wird.toRow();
    // Don't update position — it's managed separately.
    row.remove('position');
    await db.update('wirds', row, where: 'id = ?', whereArgs: [wird.id]);
    await _rescheduleOne(wird);
  }

  /// Soft-deletes a wird and cancels all its pending notifications.
  static Future<void> delete(String id) async {
    final db = await UserDatabaseService.database();
    await db.update(
      'wirds',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await NotificationService.cancelWirdNotifications(id);
  }

  /// Hard-reset a wird's progress to zero.
  static Future<void> resetProgress(String id) async {
    final db = await UserDatabaseService.database();
    final todayStr = _calendarDateStr(DateTime.now());
    await db.update(
      'wirds',
      {'current_count': 0, 'last_updated_date': todayStr},
      where: 'id = ?',
      whereArgs: [id],
    );
    // A manual reset may need to re-arm today's notification if the wird
    // was previously completed.
    final wird = await findById(id);
    if (wird != null) await _rescheduleOne(wird);
  }

  /// Atomic +1 on the wird's `currentCount`. Returns `true` if this push
  /// tips the wird into the "completed" state.
  static Future<bool> increment(String id) async {
    final db = await UserDatabaseService.database();
    final todayStr = _calendarDateStr(DateTime.now());

    // Atomic increment — no read-modify-write race.
    final affected = await db.rawUpdate(
      'UPDATE wirds SET current_count = current_count + 1, '
      'last_updated_date = ? '
      'WHERE id = ? AND is_deleted = 0',
      [todayStr, id],
    );
    if (affected == 0) return false;

    // Read back to check completion.
    final rows = await db.query(
      'wirds',
      columns: ['current_count', 'target_count'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final current = (rows.first['current_count'] as int?) ?? 0;
    final target = (rows.first['target_count'] as int?) ?? 33;
    final justCompleted = current == target; // exactly on the boundary
    if (justCompleted) {
      // Reschedule so today's notification is cancelled (done) but
      // tomorrow+'s are still armed.
      final wird = await findById(id);
      if (wird != null) await _rescheduleOne(wird);
    }
    return justCompleted;
  }

  /// Called from `main.dart` shortly after `runApp`. Does three things:
  /// 1. Seeds the 5 default wirds on a brand-new install.
  /// 2. Applies today's daily reset.
  /// 3. Re-arms the rolling 14-day notification window for every active wird.
  static Future<void> ensureReadyAndReschedule() async {
    await _ensureMigrated();
    await _seedDefaultsIfFirstLaunch();
    final active = await getActive();
    for (final w in active) {
      await _rescheduleOne(w);
    }
  }

  // ---------------------------------------------------------------------------
  // Migration: SharedPreferences JSON → SQLite
  // ---------------------------------------------------------------------------

  /// One-shot migration from the legacy `wirds_v1` SharedPreferences blob
  /// into the `wirds` SQLite table. Safe to call repeatedly — does real
  /// work only once.
  static Future<void> _ensureMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyMigrated) == true) return;

    final db = await UserDatabaseService.database();

    // If we already have data (e.g. test install, previous successful
    // migration that crashed before setting the flag), don't clobber.
    final existing = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM wirds'),
        ) ??
        0;
    if (existing > 0) {
      await prefs.setBool(_keyMigrated, true);
      return;
    }

    // Read the legacy JSON blob.
    final raw = prefs.getString(_legacyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        await db.transaction((txn) async {
          int position = 0;
          for (final entry in list) {
            final wird = Wird.fromJson(entry as Map<String, dynamic>);
            final row = wird.toRow();
            row['position'] = position++;
            await txn.insert('wirds', row);
          }
        });
        Log.i('WirdService',
            'Migrated ${list.length} wirds from SharedPreferences to SQLite');
      } catch (e, st) {
        Log.e('WirdService',
            'Failed to migrate wirds from prefs; starting fresh', e, st);
      }
    }

    // Clean up legacy keys. Migration marker is set last to be safe
    // against a crash during cleanup.
    try {
      await prefs.remove(_legacyKey);
    } catch (_) {}
    await prefs.setBool(_keyMigrated, true);
  }

  // ---------------------------------------------------------------------------
  // Daily reset
  // ---------------------------------------------------------------------------

  /// For every active wird whose `lastUpdatedDate` predates today AND
  /// today is in its weekday schedule, clear `currentCount`. Wirds not
  /// scheduled for today are left alone so their progress survives idle
  /// days. Guarded by a prefs flag so it runs at most once per calendar day.
  static Future<void> _applyDailyResetIfNeeded() async {
    final now = DateTime.now();
    final todayStr = _calendarDateStr(now);
    final flagKey = '$_resetPrefix$todayStr';

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(flagKey) == true) return; // already reset today

    final db = await UserDatabaseService.database();

    // Read all wirds that need resetting — we must check the weekday in
    // Dart because SQLite doesn't natively understand our comma-separated
    // days_of_week encoding.
    final candidates = await db.query(
      'wirds',
      where: 'is_deleted = 0 AND '
          '(last_updated_date IS NULL OR last_updated_date < ?)',
      whereArgs: [todayStr],
    );

    if (candidates.isNotEmpty) {
      final todayWeekday = now.weekday;
      await db.transaction((txn) async {
        for (final row in candidates) {
          final days = Wird.parseDaysColumn(row['days_of_week'] as String?);
          if (!days.contains(todayWeekday)) continue;
          await txn.update(
            'wirds',
            {'current_count': 0, 'last_updated_date': todayStr},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      });
    }

    await prefs.setBool(flagKey, true);
  }

  // ---------------------------------------------------------------------------
  // Seeding
  // ---------------------------------------------------------------------------

  /// Seeds the 5 default wirds on first launch. Gated by a prefs flag so
  /// a user who deletes all defaults doesn't see them reappear.
  static Future<void> _seedDefaultsIfFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededKey) == true) return;

    final db = await UserDatabaseService.database();

    // If a previous migration already populated wirds, just mark seeded.
    final existing = Sqflite.firstIntValue(
          await db.rawQuery(
              'SELECT COUNT(*) FROM wirds WHERE is_deleted = 0'),
        ) ??
        0;
    if (existing > 0) {
      await prefs.setBool(_seededKey, true);
      return;
    }

    const allDays = <int>[1, 2, 3, 4, 5, 6, 7];
    final defaults = [
      Wird.create(
        title: 'استغفار',
        dhikrText: 'أستغفر الله',
        targetCount: 100,
        daysOfWeek: allDays,
      ),
      Wird.create(
        title: 'الصلاة على النبي ﷺ',
        dhikrText: 'اللهم صلِّ وسلم على نبينا محمد',
        targetCount: 100,
        daysOfWeek: allDays,
      ),
      Wird.create(
        title: 'التسبيح',
        dhikrText: 'سبحان الله',
        targetCount: 100,
        daysOfWeek: allDays,
      ),
      Wird.create(
        title: 'التهليل',
        dhikrText: 'لا إله إلا الله',
        targetCount: 100,
        daysOfWeek: allDays,
      ),
      Wird.create(
        title: 'تسبيح بعد الفريضة',
        dhikrText: 'سبحان الله، الحمد لله، الله أكبر',
        targetCount: 99,
        daysOfWeek: allDays,
      ),
    ];

    await db.transaction((txn) async {
      int position = 0;
      for (final w in defaults) {
        final row = w.toRow();
        row['position'] = position++;
        await txn.insert('wirds', row);
      }
    });

    await prefs.setBool(_seededKey, true);
    Log.i('WirdService', 'Seeded ${defaults.length} default wirds');
  }

  // ---------------------------------------------------------------------------
  // Notification scheduling
  // ---------------------------------------------------------------------------

  /// Cancels any pending notifications for this wird and, if it's still
  /// active and has reminders on, re-schedules one-shots for the next 7
  /// days. Today's notification is skipped if the wird is already
  /// completed OR the chosen time has already passed.
  static Future<void> _rescheduleOne(Wird w) async {
    await NotificationService.cancelWirdNotifications(w.id);
    if (w.isDeleted) return;
    if (!w.notificationsEnabled) {
      Log.d('WirdService',
          'Skipping reschedule for "${w.title}": reminders disabled');
      return;
    }
    if (w.daysOfWeek.isEmpty) {
      Log.w('WirdService',
          'Skipping reschedule for "${w.title}": no days selected');
      return;
    }

    final now = DateTime.now();
    final today = _dateOnly(now);
    final alreadyDoneToday = w.isCompleted &&
        w.lastUpdatedDate != null &&
        !w.lastUpdatedDate!.isBefore(today);

    // 7-day rolling window. Notification IDs are derived from
    // `(wirdId, weekday)` — there are only 7 distinct slots per wird, so
    // scheduling "this Friday" and "next Friday" would collide (the second
    // `zonedSchedule` silently replaces the first). We therefore keep a
    // `scheduledWeekdays` set and accept only the NEAREST future occurrence
    // of each weekday. For multi-day wirds that means up to 7 pending notifications
    // in the next week. We limit lookahead to 7 days to avoid hitting
    // the 64-notification cap on iOS.
    final scheduledWeekdays = <int>{};
    DateTime? firstTrigger;
    for (int offset = 0; offset < 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (!w.daysOfWeek.contains(day.weekday)) continue;
      if (scheduledWeekdays.contains(day.weekday)) continue;

      final triggerAt = DateTime(day.year, day.month, day.day,
          w.notificationTime.hour, w.notificationTime.minute);

      if (triggerAt.isBefore(now)) continue; // time already passed today
      if (offset == 0 && alreadyDoneToday) continue; // nothing to remind

      await NotificationService.scheduleWirdOneShot(
        wirdId: w.id,
        occurrenceDate: day,
        triggerTimeLocal: triggerAt,
        title: w.title,
        body: w.dhikrText,
      );
      scheduledWeekdays.add(day.weekday);
      firstTrigger ??= triggerAt;
    }
    if (scheduledWeekdays.isEmpty) {
      Log.w('WirdService',
          'Rescheduled "${w.title}" but nothing was queued — all candidate '
              'times in the next 7 days are in the past or today is done.');
    } else {
      Log.i('WirdService',
          'Rescheduled "${w.title}": ${scheduledWeekdays.length} '
              'occurrence(s); next at ${firstTrigger?.toIso8601String()}');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Truncate a `DateTime` to its calendar day at midnight local-time.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Formats a DateTime as `YYYY-MM-DD` for SQLite storage.
  static String _calendarDateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<int> _nextPosition(Database db) async {
    final v = Sqflite.firstIntValue(
      await db.rawQuery(
          'SELECT COALESCE(MAX(position), -1) + 1 FROM wirds'),
    );
    return v ?? 0;
  }
}
