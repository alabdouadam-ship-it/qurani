import 'dart:async';
import 'dart:convert';
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
/// * **One copy path** so the 104 MB asset write happens exactly once. (That
///   figure said "~5MB" for a long time; the database has grown 20x since.)
class QuranDatabaseService {
  QuranDatabaseService._();

  /// Bundled schema version. Bump this whenever the bundled `quran.db`
  /// changes its schema so existing installs force a re-copy.
  ///
  /// v4: renamed `text_tafsir` -> `text_tafsir_muyassar` and added the
  /// turkish/german translation columns plus the jalalayn/qurtubi/miqbas/
  /// waseet/baghawi tafsir columns (see tool/build_quran_db.dart).
  static const int _schemaVersion = 4;
  static const String _versionKey = 'quran_db_schema_version';

  /// Directory of the gzipped, split database produced by
  /// `tool/pack_quran_db.dart`. The unsplit `assets/data/quran.db` is kept in
  /// the repo as the source for that tool but is deliberately NOT declared in
  /// `pubspec.yaml`, so it never ships — shipping both would double the
  /// download.
  static const String _dbAssetDir = 'assets/data/quran_db';
  static const String _manifestName = 'manifest.json';

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
        // v4 columns: the renamed muyassar tafsir + a representative new
        // translation and tafsir. A pre-v4 DB lacks these and throws here,
        // forcing the re-copy even if the stored version key somehow matched.
        await probe.rawQuery(
            'SELECT text_tafsir_muyassar, text_tr_vakfi, text_tafsir_jalalayn '
            'FROM ayah LIMIT 1');
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
      final written = await _copyDatabaseFromAssets(dbPath);
      await prefs.setInt(_versionKey, _schemaVersion);
      Log.i('QuranDatabase', 'Copied $written bytes to $dbPath');
    }

    final db = await sqf.openDatabase(dbPath, readOnly: false);
    Log.d('QuranDatabase', 'Opened quran.db');
    return db;
  }

  /// Writes the bundled database to [dbPath], streaming it out of the bundle
  /// one gzipped part at a time. Returns the number of bytes written.
  ///
  /// This replaced a single `rootBundle.load('assets/data/quran.db')`, which was
  /// a ~104 MB allocation on first launch — and again for the entire installed
  /// base after any [_schemaVersion] bump. Dart offers no streaming asset API,
  /// so the data is shipped pre-split by `tool/pack_quran_db.dart` into ~8 MB
  /// gzipped parts; peak heap is now one part plus the decoder's buffers.
  ///
  /// The download is unaffected: gzip takes the file from 104.37 MB to 28.93 MB,
  /// which is what the App Bundle was already compressing the raw `.db` to. The
  /// decompression simply moves from the packaging layer into here, where it can
  /// be streamed.
  ///
  /// The parts are byte ranges of ONE gzip stream rather than independent
  /// members, so they must be fed to the decoder in order.
  static Future<int> _copyDatabaseFromAssets(String dbPath) async {
    final manifest = json.decode(
      await rootBundle.loadString('$_dbAssetDir/$_manifestName'),
    ) as Map<String, dynamic>;

    final partCount = (manifest['parts'] as num).toInt();
    final expectedBytes = (manifest['rawBytes'] as num).toInt();
    if (partCount <= 0) {
      throw StateError('quran.db manifest declares $partCount parts');
    }

    final dbFile = File(dbPath);
    final sink = dbFile.openWrite();
    try {
      await _gzippedParts(partCount).transform(gzip.decoder).pipe(sink);
    } catch (e) {
      // pipe() closes the sink itself; on failure remove the partial file so a
      // truncated database is never handed to sqlite, and so the next launch
      // retries the copy instead of "succeeding" with a short file.
      try {
        if (dbFile.existsSync()) await dbFile.delete();
      } catch (_) {}
      rethrow;
    }

    final written = dbFile.lengthSync();
    if (written != expectedBytes) {
      try {
        await dbFile.delete();
      } catch (_) {}
      throw StateError('quran.db copy is $written bytes, expected '
          '$expectedBytes — bundle parts may be stale or incomplete.');
    }
    return written;
  }

  /// Yields each gzipped part in order, loading only one at a time.
  static Stream<List<int>> _gzippedParts(int partCount) async* {
    for (var i = 0; i < partCount; i++) {
      final name = 'part-${i.toString().padLeft(3, '0')}.gz';
      final data = await rootBundle.load('$_dbAssetDir/$name');
      // Respect the view's offset/length: ByteData from the asset bundle is not
      // guaranteed to start at byte 0 of its backing buffer, and
      // `asUint8List()` with no arguments would include the surrounding bytes.
      yield data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
  }
}
