import 'dart:async';
import 'dart:convert';

import 'package:qurani/models/tasbeeh_model.dart';
import 'package:qurani/services/user_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'logger.dart';

/// Tasbeeh / Dhikr counter service backed by SQLite.
///
/// Why SQLite (was: a single JSON blob in SharedPreferences):
/// * **Atomic increments.** A tap handler can do
///   `UPDATE tasbeeh_items SET count = count + 1 WHERE id = ?` — one SQL
///   statement, no read-modify-write race. The old design used an
///   in-memory cache plus a Dart-level write-chain to avoid lost
///   increments on fast tapping; SQLite gives us the same guarantee at
///   the storage layer itself, with none of the JSON-rewrite cost.
/// * **Proportional write cost.** Incrementing one counter used to
///   re-serialise the entire groups-and-items tree and rewrite the full
///   prefs blob. Now it's a single ~100-byte UPDATE. On a long dhikr
///   session (hundreds of taps), the difference shows up in battery /
///   storage churn.
/// * **Per-row reads.** UI can later query a single item's count without
///   pulling the whole tree.
///
/// Migration: on first call after upgrading, we detect any of the three
/// legacy layouts and copy their contents into the new SQL tables, then
/// remove the old prefs keys so the migration runs exactly once.
class TasbeehService {
  TasbeehService._();

  // Legacy prefs keys — only read during the one-shot migration.
  static const String _legacyKeyPhrases = 'tasbeeh_phrases';
  static const String _legacyKeyTotalCounts = 'tasbeeh_total_counts';
  static const String _legacyKeyTasbeehData = 'tasbeeh_data_v2';

  /// Marker so we only attempt the legacy→SQLite migration once per
  /// install, even if the user deletes all their data afterwards.
  static const String _keyMigrated = 'tasbeeh_migrated_to_sqlite_v1';

  // Fallback default phrases for a brand-new install (also used when
  // migrating a legacy `tasbeeh_phrases` list with no saved content).
  static const List<String> legacyDefaultPhrases = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'أستغفر الله',
  ];

  /// Loads all groups with their items, ordered by insertion (`position`).
  static Future<List<TasbeehGroup>> getGroups() async {
    await _ensureSeededAndMigrated();
    final db = await UserDatabaseService.database();
    final groupRows = await db.query(
      'tasbeeh_groups',
      orderBy: 'position ASC, rowid ASC',
    );
    if (groupRows.isEmpty) return const [];

    // Fetch all items in a single query and bucket them by group_id
    // rather than issuing N+1 queries per group.
    final itemRows = await db.query(
      'tasbeeh_items',
      orderBy: 'position ASC, rowid ASC',
    );
    final byGroup = <String, List<TasbeehItem>>{};
    for (final row in itemRows) {
      final groupId = row['group_id'] as String;
      byGroup.putIfAbsent(groupId, () => []).add(TasbeehItem(
            id: row['id'] as String,
            text: row['text'] as String,
            count: (row['count'] as int?) ?? 0,
          ));
    }

    return [
      for (final g in groupRows)
        TasbeehGroup(
          id: g['id'] as String,
          name: g['name'] as String,
          isCustom: ((g['is_custom'] as int?) ?? 0) == 1,
          items: byGroup[g['id'] as String] ?? [],
        ),
    ];
  }

  /// Adds a new custom group and returns immediately — the group will
  /// appear at the end of the list on the next [getGroups] call.
  static Future<void> addGroup(String name) async {
    await _ensureSeededAndMigrated();
    final db = await UserDatabaseService.database();
    final position = await _nextGroupPosition(db);
    await db.insert('tasbeeh_groups', {
      'id': const Uuid().v4(),
      'name': name,
      'is_custom': 1,
      'position': position,
    });
  }

  /// Removes a group and all its items. `ON DELETE CASCADE` on
  /// `tasbeeh_items.group_id` handles the item rows.
  static Future<void> removeGroup(String groupId) async {
    final db = await UserDatabaseService.database();
    await db.delete('tasbeeh_groups', where: 'id = ?', whereArgs: [groupId]);
  }

  static Future<void> addItem(String groupId, String text) async {
    await _ensureSeededAndMigrated();
    final db = await UserDatabaseService.database();
    final position = await _nextItemPosition(db, groupId);
    await db.insert('tasbeeh_items', {
      'id': const Uuid().v4(),
      'group_id': groupId,
      'text': text,
      'count': 0,
      'position': position,
    });
  }

  static Future<void> removeItem(String groupId, String itemId) async {
    final db = await UserDatabaseService.database();
    await db.delete(
      'tasbeeh_items',
      where: 'id = ? AND group_id = ?',
      whereArgs: [itemId, groupId],
    );
  }

  /// Atomically increments the counter for the given item.
  ///
  /// A single-statement `UPDATE ... SET count = count + 1` is atomic at
  /// SQLite's journal level — even with rapid taps queued in parallel,
  /// SQLite serialises them internally so no increment is lost.
  static Future<void> incrementCount(String groupId, String itemId) async {
    final db = await UserDatabaseService.database();
    await db.rawUpdate(
      'UPDATE tasbeeh_items SET count = count + 1 '
      'WHERE id = ? AND group_id = ?',
      [itemId, groupId],
    );
  }

  static Future<void> resetAllCounts() async {
    final db = await UserDatabaseService.database();
    await db.rawUpdate('UPDATE tasbeeh_items SET count = 0');
  }

  static Future<void> resetGroupCounts(String groupId) async {
    final db = await UserDatabaseService.database();
    await db.rawUpdate(
      'UPDATE tasbeeh_items SET count = 0 WHERE group_id = ?',
      [groupId],
    );
  }

  // ----- internals ------------------------------------------------------

  /// Ensures the DB has been seeded with defaults and any legacy data
  /// migrated in. Safe to call repeatedly — does real work only once.
  static Future<void> _ensureSeededAndMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyMigrated) == true) return;

    final db = await UserDatabaseService.database();

    // If we already have data (e.g. test install, manual seeding), don't
    // clobber it — just mark the migration done.
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tasbeeh_groups'),
    ) ?? 0;
    if (existing > 0) {
      await prefs.setBool(_keyMigrated, true);
      return;
    }

    final legacyJson = prefs.getString(_legacyKeyTasbeehData);
    final legacyPhrases = prefs.getStringList(_legacyKeyPhrases);

    try {
      if (legacyJson != null && legacyJson.isNotEmpty) {
        await _migrateFromJsonBlob(db, legacyJson);
      } else if (legacyPhrases != null && legacyPhrases.isNotEmpty) {
        await _migrateFromLegacyPhrases(db, prefs, legacyPhrases);
      } else {
        await _seedDefaults(db);
      }
    } catch (e, st) {
      Log.e('TasbeehService', 'Migration/seed failed, seeding defaults',
          e, st);
      await _seedDefaults(db);
    }

    // Clean up prefs keys regardless of path taken so we never migrate
    // twice. The migration marker is set last to be safe against a crash
    // in the cleanup.
    try {
      await prefs.remove(_legacyKeyPhrases);
      await prefs.remove(_legacyKeyTotalCounts);
      await prefs.remove(_legacyKeyTasbeehData);
    } catch (_) {}
    await prefs.setBool(_keyMigrated, true);
  }

  /// Imports the v2 JSON blob (`tasbeeh_data_v2` — the previous storage
  /// format) into SQLite, preserving group/item IDs and per-item counts.
  static Future<void> _migrateFromJsonBlob(
      Database db, String legacyJson) async {
    final List<dynamic> jsonList = jsonDecode(legacyJson) as List<dynamic>;
    await db.transaction((txn) async {
      int groupPos = 0;
      for (final raw in jsonList) {
        final group = TasbeehGroup.fromJson(raw as Map<String, dynamic>);
        await txn.insert('tasbeeh_groups', {
          'id': group.id,
          'name': group.name,
          'is_custom': group.isCustom ? 1 : 0,
          'position': groupPos++,
        });
        int itemPos = 0;
        for (final item in group.items) {
          await txn.insert('tasbeeh_items', {
            'id': item.id,
            'group_id': group.id,
            'text': item.text,
            'count': item.count,
            'position': itemPos++,
          });
        }
      }
    });
    Log.i('TasbeehService',
        'Migrated ${jsonList.length} groups from JSON blob to SQLite');
  }

  /// Imports the very first storage layout: two prefs keys,
  /// `tasbeeh_phrases` (the phrase list) and `tasbeeh_total_counts`
  /// (a `k:v,k:v` string of index→count). We fold them into the stock
  /// "My Azkar" group and also seed the default groups.
  static Future<void> _migrateFromLegacyPhrases(
    Database db,
    SharedPreferences prefs,
    List<String> phrases,
  ) async {
    final counts = _parseLegacyCountsBlob(prefs.getString(_legacyKeyTotalCounts));
    await db.transaction((txn) async {
      await _seedDefaultsInTxn(txn, customMyAzkar: (myAzkarId) async {
        int pos = 0;
        for (int i = 0; i < phrases.length; i++) {
          await txn.insert('tasbeeh_items', {
            'id': const Uuid().v4(),
            'group_id': myAzkarId,
            'text': phrases[i],
            'count': counts[i] ?? 0,
            'position': pos++,
          });
        }
      });
    });
    Log.i('TasbeehService',
        'Migrated ${phrases.length} legacy phrases into SQLite');
  }

  /// Parses the old `tasbeeh_total_counts` format (`"0:12,1:7,..."`) into
  /// an index→count map. Corrupt entries are silently skipped.
  static Map<int, int> _parseLegacyCountsBlob(String? raw) {
    final result = <int, int>{};
    if (raw == null || raw.isEmpty) return result;
    for (final pair in raw.split(',')) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      final k = int.tryParse(parts[0]);
      final v = int.tryParse(parts[1]);
      if (k != null && v != null) result[k] = v;
    }
    return result;
  }

  /// Seeds the default group set on a fresh install.
  static Future<void> _seedDefaults(Database db) async {
    await db.transaction((txn) async {
      await _seedDefaultsInTxn(txn, customMyAzkar: (myAzkarId) async {
        int pos = 0;
        for (final phrase in legacyDefaultPhrases) {
          await txn.insert('tasbeeh_items', {
            'id': const Uuid().v4(),
            'group_id': myAzkarId,
            'text': phrase,
            'count': 0,
            'position': pos++,
          });
        }
      });
    });
  }

  /// Creates the standard localisation-key-named groups (`groupMyAzkar`,
  /// `groupPostPrayerGeneral`, etc.) inside [txn]. Calls
  /// [customMyAzkar] with the inserted My Azkar group's ID so the caller
  /// can decide what items to put in it (legacy migration vs. defaults).
  static Future<void> _seedDefaultsInTxn(
    DatabaseExecutor txn, {
    required Future<void> Function(String myAzkarId) customMyAzkar,
  }) async {
    const uuid = Uuid();
    Future<String> insertGroup(String nameKey,
        {required int position, bool isCustom = false}) async {
      final id = uuid.v4();
      await txn.insert('tasbeeh_groups', {
        'id': id,
        'name': nameKey,
        'is_custom': isCustom ? 1 : 0,
        'position': position,
      });
      return id;
    }

    Future<void> insertItems(String groupId, List<String> items) async {
      int pos = 0;
      for (final text in items) {
        await txn.insert('tasbeeh_items', {
          'id': uuid.v4(),
          'group_id': groupId,
          'text': text,
          'count': 0,
          'position': pos++,
        });
      }
    }

    int position = 0;
    final myAzkarId =
        await insertGroup('groupMyAzkar', position: position++);
    await customMyAzkar(myAzkarId);

    // 1. General Post-Prayer (Dhuhr, Asr, Isha)
    final postPrayerGeneralItems = [
      'أستغفر الله (3 مرات)',
      'اللهم أنت السلام ومنك السلام، تباركت يا ذا الجلال والإكرام',
      'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير، اللهم لا مانع لما أعطيت، ولا معطي لما منعت، ولا ينفع ذا الجد منك الجد',
      'سبحان الله (33 مرة)',
      'الحمد لله (33 مرة)',
      'الله أكبر (33 مرة)',
      'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير (تمام المائة)',
      'آية الكرسي',
      'سورة الإخلاص، الفلق، الناس',
    ];
    // 2. Fajr & Maghrib Post-Prayer (General + Extras)
    final postPrayerFajrMaghribItems = [
      ...postPrayerGeneralItems,
      'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، يحيي ويميت، وهو على كل شيء قدير (10 مرات)',
      'تكرار المعوذات (الإخلاص، الفلق، الناس) (3 مرات)',
      'اللهم إني أسألك علماً نافعاً، ورزقاً طيباً، وعملاً متقبلاً (بعد الفجر)',
    ];
    final morningEveningItems = [
      'آية الكرسي',
      'المعوذات (الإخلاص، الفلق، الناس) (3 مرات)',
      'اللهم أنت ربي لا إله إلا أنت، خلقتني وأنا عبدك، وأنا على عهدك ووعدك ما استطعت، أعوذ بك من شر ما صنعت، أبوء لك بنعمتك علي، وأبوء بذنبي فاغفر لي فإنه لا يغفر الذنوب إلا أنت',
      'بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم (3 مرات)',
      'رضيت بالله رباً، وبالإسلام ديناً، وبمحمد ﷺ نبياً (3 مرات)',
      'حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم (7 مرات)',
      'سبحان الله وبحمده (100 مرة)',
      'اللهم عافني في بدني، اللهم عافني في سمعي، اللهم عافني في بصري، لا إله إلا أنت (3 مرات)',
    ];
    final sleepItems = [
      'الإخلاص، الفلق، الناس (3 مرات)',
      'آية الكرسي',
      'آخر آيتين من سورة البقرة',
      'باسمك ربي وضعت جنبي وبك أرفعه، إن أمسكت نفسي فارحمها، وإن أرسلتها فاحفظها بما تحفظ به عبادك الصالحين',
      'سبحان الله (33)، الحمد لله (33)، الله أكبر (34)',
      'باسمك اللهم أموت وأحيا',
    ];
    final fridayItems = [
      'الإكثار من الصلاة على النبي ﷺ: اللهم صلِّ وسلم على نبينا محمد',
      'قراءة سورة الكهف',
      'تحري ساعة الاستجابة (آخر ساعة بعد العصر)',
    ];

    final postGeneralId =
        await insertGroup('groupPostPrayerGeneral', position: position++);
    await insertItems(postGeneralId, postPrayerGeneralItems);

    final postFajrMaghribId = await insertGroup(
        'groupPostPrayerFajrMaghrib',
        position: position++);
    await insertItems(postFajrMaghribId, postPrayerFajrMaghribItems);

    final morningId =
        await insertGroup('groupMorning', position: position++);
    await insertItems(morningId, morningEveningItems);

    final eveningId =
        await insertGroup('groupEvening', position: position++);
    await insertItems(eveningId, morningEveningItems);

    final sleepId = await insertGroup('groupSleep', position: position++);
    await insertItems(sleepId, sleepItems);

    final fridayId = await insertGroup('groupFriday', position: position++);
    await insertItems(fridayId, fridayItems);
  }

  static Future<int> _nextGroupPosition(Database db) async {
    final v = Sqflite.firstIntValue(
      await db.rawQuery(
          'SELECT COALESCE(MAX(position), -1) + 1 FROM tasbeeh_groups'),
    );
    return v ?? 0;
  }

  static Future<int> _nextItemPosition(Database db, String groupId) async {
    final v = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COALESCE(MAX(position), -1) + 1 '
        'FROM tasbeeh_items WHERE group_id = ?',
        [groupId],
      ),
    );
    return v ?? 0;
  }
}
