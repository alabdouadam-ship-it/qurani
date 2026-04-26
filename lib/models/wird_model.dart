import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// A single daily-Wird entry: a recurring dhikr the user wants to recite a
/// fixed number of times on chosen weekdays, optionally with a reminder
/// notification.
///
/// ### Design notes
///
/// * **`daysOfWeek` uses `DateTime.weekday` values** (1 = Monday … 7 = Sunday)
///   so we can compare directly with `DateTime.now().weekday` without any
///   off-by-one translation. The spec mentioned "0=Sat…6=Fri" as a locale
///   example, but encoding days in Dart's native space keeps all scheduling
///   arithmetic honest; the UI is free to re-order the chips so Saturday
///   appears first for Arabic locales.
///
/// * **`lastUpdatedDate` is a calendar date**, not an instant. Storing it as
///   the local `YYYY-MM-DD` string avoids timezone drift — the daily-reset
///   check is "is today a different calendar date from the last update?",
///   which is meaningless at millisecond precision.
///
/// * **`isDeleted` = soft delete.** We keep the row around so any in-flight
///   notification that fires between "user deletes" and "service reschedules"
///   can still look up the title; `WirdService` filters deleted wirds out of
///   every query. A future cleanup pass can hard-delete rows older than N
///   days if the blob ever gets large.
///
/// * **`notificationTime` is persisted as `"HH:mm"`** because `TimeOfDay`
///   has no JSON form of its own and we only ever compare it at minute
///   resolution.
class Wird {
  Wird({
    required this.id,
    required this.title,
    required this.dhikrText,
    required this.targetCount,
    this.currentCount = 0,
    required this.daysOfWeek,
    this.notificationsEnabled = false,
    this.notificationTime = const TimeOfDay(hour: 14, minute: 0),
    this.lastUpdatedDate,
    this.isDeleted = false,
    required this.createdAt,
  });

  /// Stable UUID; used as the logical identity for notifications, progress,
  /// and equality. Never reassigned after creation.
  final String id;
  final String title;
  final String dhikrText;
  final int targetCount;
  final int currentCount;

  /// Days the wird is active on, using `DateTime.weekday` (1=Mon..7=Sun).
  final List<int> daysOfWeek;

  final bool notificationsEnabled;
  final TimeOfDay notificationTime;

  /// Last calendar day (local time) on which `currentCount` was touched.
  /// `null` for a freshly-created wird with no taps yet.
  final DateTime? lastUpdatedDate;

  /// Soft-delete flag. See class-level docstring for the rationale.
  final bool isDeleted;

  /// Creation instant — purely informational, used for stable ordering when
  /// two wirds have identical names.
  final DateTime createdAt;

  /// Convenience: `true` when the user has recited this wird enough times
  /// today. Callers should also check [isActiveOn] for the current weekday
  /// before trusting this value — a completed wird from a non-active day
  /// is still "completed" but won't show up in the today-view.
  bool get isCompleted => currentCount >= targetCount;

  /// `true` if [date]'s weekday is in this wird's [daysOfWeek] schedule.
  bool isActiveOn(DateTime date) => daysOfWeek.contains(date.weekday);

  /// Fractional progress clamped to `[0, 1]`. Safe for `LinearProgressIndicator`.
  double get progressRatio {
    if (targetCount <= 0) return 0.0;
    final r = currentCount / targetCount;
    if (r.isNaN || r < 0) return 0.0;
    if (r > 1) return 1.0;
    return r;
  }

  factory Wird.create({
    required String title,
    required String dhikrText,
    required int targetCount,
    required List<int> daysOfWeek,
    bool notificationsEnabled = false,
    TimeOfDay notificationTime = const TimeOfDay(hour: 14, minute: 0),
  }) {
    return Wird(
      id: const Uuid().v4(),
      title: title,
      dhikrText: dhikrText,
      targetCount: targetCount,
      daysOfWeek: List<int>.from(daysOfWeek),
      notificationsEnabled: notificationsEnabled,
      notificationTime: notificationTime,
      createdAt: DateTime.now(),
    );
  }

  Wird copyWith({
    String? title,
    String? dhikrText,
    int? targetCount,
    int? currentCount,
    List<int>? daysOfWeek,
    bool? notificationsEnabled,
    TimeOfDay? notificationTime,
    DateTime? lastUpdatedDate,
    bool? isDeleted,
  }) {
    return Wird(
      id: id,
      title: title ?? this.title,
      dhikrText: dhikrText ?? this.dhikrText,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      daysOfWeek: daysOfWeek ?? List<int>.from(this.daysOfWeek),
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
      lastUpdatedDate: lastUpdatedDate ?? this.lastUpdatedDate,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // JSON (retained for the one-shot SharedPreferences → SQLite migration)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dhikrText': dhikrText,
        'targetCount': targetCount,
        'currentCount': currentCount,
        'daysOfWeek': daysOfWeek,
        'notificationsEnabled': notificationsEnabled,
        // "HH:mm" — minute-resolution is all the UI and the scheduler need.
        'notificationTime':
            '${notificationTime.hour.toString().padLeft(2, '0')}:'
                '${notificationTime.minute.toString().padLeft(2, '0')}',
        // Store just the calendar date so a timezone offset change cannot
        // flip the reset check by a millisecond.
        'lastUpdatedDate': lastUpdatedDate == null
            ? null
            : '${lastUpdatedDate!.year.toString().padLeft(4, '0')}-'
                '${lastUpdatedDate!.month.toString().padLeft(2, '0')}-'
                '${lastUpdatedDate!.day.toString().padLeft(2, '0')}',
        'isDeleted': isDeleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Wird.fromJson(Map<String, dynamic> json) {
    return Wird(
      id: json['id'] as String,
      title: json['title'] as String,
      dhikrText: json['dhikrText'] as String? ?? '',
      targetCount: (json['targetCount'] as num?)?.toInt() ?? 33,
      currentCount: (json['currentCount'] as num?)?.toInt() ?? 0,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .where((d) => d >= 1 && d <= 7)
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      notificationTime: _parseTimeOfDay(json['notificationTime'] as String?),
      lastUpdatedDate: _parseCalendarDate(json['lastUpdatedDate'] as String?),
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // SQLite row serialization
  // ---------------------------------------------------------------------------

  /// Serialises this wird into a column-map suitable for `db.insert()` or
  /// `db.update()`. Column names match the `wirds` table schema.
  Map<String, dynamic> toRow() => {
        'id': id,
        'title': title,
        'dhikr_text': dhikrText,
        'target_count': targetCount,
        'current_count': currentCount,
        'days_of_week': (daysOfWeek.toList()..sort()).join(','),
        'notifications_enabled': notificationsEnabled ? 1 : 0,
        'notification_time':
            '${notificationTime.hour.toString().padLeft(2, '0')}:'
                '${notificationTime.minute.toString().padLeft(2, '0')}',
        'last_updated_date': lastUpdatedDate == null
            ? null
            : '${lastUpdatedDate!.year.toString().padLeft(4, '0')}-'
                '${lastUpdatedDate!.month.toString().padLeft(2, '0')}-'
                '${lastUpdatedDate!.day.toString().padLeft(2, '0')}',
        'is_deleted': isDeleted ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  /// Re-hydrates a [Wird] from a SQLite row map.
  factory Wird.fromRow(Map<String, dynamic> row) {
    return Wird(
      id: row['id'] as String,
      title: row['title'] as String,
      dhikrText: row['dhikr_text'] as String? ?? '',
      targetCount: (row['target_count'] as int?) ?? 33,
      currentCount: (row['current_count'] as int?) ?? 0,
      daysOfWeek: parseDaysColumn(row['days_of_week'] as String?),
      notificationsEnabled: ((row['notifications_enabled'] as int?) ?? 0) == 1,
      notificationTime:
          _parseTimeOfDay(row['notification_time'] as String?),
      lastUpdatedDate:
          _parseCalendarDate(row['last_updated_date'] as String?),
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Parse helpers
  // ---------------------------------------------------------------------------

  /// Parses comma-separated weekday ints (e.g. `"1,3,5"`) back into a list.
  /// Public because [WirdService] needs it for the daily-reset SQL filtering.
  static List<int> parseDaysColumn(String? raw) {
    if (raw == null || raw.isEmpty) return const [1, 2, 3, 4, 5, 6, 7];
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .where((d) => d != null && d >= 1 && d <= 7)
        .cast<int>()
        .toList();
  }

  static TimeOfDay _parseTimeOfDay(String? raw) {
    if (raw == null || raw.isEmpty) return const TimeOfDay(hour: 14, minute: 0);
    final parts = raw.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 14, minute: 0);
    final h = int.tryParse(parts[0]) ?? 14;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(
      hour: h.clamp(0, 23),
      minute: m.clamp(0, 59),
    );
  }

  static DateTime? _parseCalendarDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || mo == null || d == null) return null;
    return DateTime(y, mo, d);
  }
}
