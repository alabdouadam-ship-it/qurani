import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqf;

import 'logger.dart';

/// Single shared opener for the bundled `quran.db` SQLite asset.
///
/// Previously, three services (`QuranRepository`, `SurahService`,
/// `QuranSearchService`) each duplicated the "copy asset from bundle if
/// missing or stale, validate schema, open" dance. Worse, two of them
/// declared different `_dbSchemaVersion` constants while writing to the
/// *same* shared-prefs key, which caused a re-copy loop on fresh installs
/// depending on whichever service ran first.
///
/// Consolidating here gives us:
/// * **One source of truth** for the expected schema version.
/// * **One shared [sqf.Database] handle**, so sqflite can serialise reads
///   at the connection level instead of juggling three separate
///   connections to the same file (which on Android can race on
///   `SQLITE_BUSY` even when both sides are read-only).
/// * **One validation path** that lists the union of every column any
///   consumer needs.
/// * **One copy path** so the ~5MB asset write happens exactly once.
class QuranDatabaseService {
  QuranDatabaseService._();

  /// Bundled schema version. Bump this whenever the bundled `quran.db`
  /// changes its schema so existing installs force a re-copy.
  static const int _schemaVersion = 3;
  static const String _versionKey = 'quran_db_schema_version';

  static sqf.Database? _db;
  static Future<sqf.Database>? _opening;

  /// Returns the shared database, opening and copying from assets lazily
  /// on the first call. Callers should not `close()` the returned handle —
  /// use [reset] if a fresh connection is needed.
  static Future<sqf.Database> database() async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    // Drop a closed handle so we reopen below.
    if (existing != null) _db = null;

    final inflight = _opening;
    if (inflight != null) return inflight;

    final future = _openAndEnsure();
    _opening = future;
    try {
      final db = await future;
      _db = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  /// Drop the shared handle (closing if open). The next [database] call
  /// will reopen. Primarily used by repository recovery paths when SQLite
  /// surfaces a "database_closed" error, and by tests.
  static Future<void> reset() async {
    final db = _db;
    _db = null;
    _opening = null;
    if (db != null && db.isOpen) {
      try {
        await db.close();
      } catch (_) {}
    }
  }

  static Future<sqf.Database> _openAndEnsure() async {
    final dbDir = await sqf.getDatabasesPath();
    final dbPath = p.join(dbDir, 'quran.db');

    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_versionKey) ?? 0;
    final dbExists = await sqf.databaseExists(dbPath);
    bool needsCopy = !dbExists || storedVersion < _schemaVersion;

    // Validate the *existing* DB's schema when we're not already planning
    // a re-copy. Probe all the columns every consumer needs so a stale
    // install gets caught regardless of which service loads first.
    if (!needsCopy && dbExists) {
      sqf.Database? probe;
      try {
        probe = await sqf.openDatabase(dbPath, readOnly: true);
        final tables = await probe.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name IN ('ayah', 'surah')",
        );
        if (tables.length != 2) {
          throw Exception('Required tables missing');
        }
        // Union of columns needed by QuranRepository + QuranSearchService.
        await probe.rawQuery(
            'SELECT text_simple, text_english FROM ayah LIMIT 1');
        // Union of columns needed by SurahService + QuranRepository.
        await probe.rawQuery(
            'SELECT name_ar, name_en, name_en_translation, revelation_type, '
            'total_verses, order_no FROM surah LIMIT 1');
        await probe.close();
        probe = null;
      } catch (e, st) {
        Log.w('QuranDatabase', 'Validation failed, forcing re-copy', e, st);
        needsCopy = true;
        try {
          await probe?.close();
        } catch (_) {}
        // Brief wait for OS-level file handles to release — Android can
        // otherwise reject `deleteDatabase` with `EBUSY`.
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          if (await sqf.databaseExists(dbPath)) {
            await sqf.deleteDatabase(dbPath);
          }
        } catch (e2) {
          Log.w('QuranDatabase', 'Could not delete stale DB', e2);
        }
      }
    }

    if (needsCopy) {
      Log.i('QuranDatabase',
          'Copying quran.db from assets (schema v$_schemaVersion)');
      if (await sqf.databaseExists(dbPath)) {
        try {
          await sqf.deleteDatabase(dbPath);
        } catch (_) {}
      }
      try {
        await Directory(p.dirname(dbPath)).create(recursive: true);
      } catch (_) {}
      final bytes = await rootBundle.load('assets/data/quran.db');
      final dbFile = File(dbPath);
      await dbFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await prefs.setInt(_versionKey, _schemaVersion);
      Log.i('QuranDatabase',
          'Copied ${dbFile.lengthSync()} bytes to $dbPath');
    }

    final db = await sqf.openDatabase(dbPath, readOnly: false);
    Log.d('QuranDatabase', 'Opened quran.db');
    return db;
  }
}
