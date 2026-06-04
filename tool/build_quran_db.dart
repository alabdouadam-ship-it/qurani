// Additive Quran DB generator.
//
// Reads the EXISTING bundled `assets/data/quran.db` and augments it in place:
//   1. Renames the legacy `text_tafsir` column to `text_tafsir_muyassar`
//      (one-time; skipped if already done).
//   2. Adds one TEXT column per new tafsir / translation edition.
//   3. Fills each new column from its source JSON in `tool/editions_src/`,
//      matching the JSON global ayah `number` to the DB `id` (both 1..6236).
//
// The existing per-edition data (simple/uthmani/tajweed/english/french and the
// muyassar tafsir already in `text_tafsir`) is preserved untouched — we never
// rebuild from scratch, because the old per-edition source JSONs are not in the
// repo.
//
// Usage (from the project root):
//   dart run tool/build_quran_db.dart
//
// Re-runnable and idempotent: a column that already exists is left in place and
// just re-filled. A timestamped backup of the DB is written next to it before
// any change.
//
// NOTE: This is a DEV tool. It depends on the `sqlite3` dev-dependency and is
// never shipped in the app.

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Describes one edition column to add and the JSON it is sourced from.
class _EditionSource {
  const _EditionSource({
    required this.column,
    required this.jsonFile,
  });

  /// Target column on the `ayah` table.
  final String column;

  /// Source file under `tool/editions_src/`.
  final String jsonFile;
}

/// New columns to add + fill. (Muyassar is handled by the rename below, so it
/// is intentionally NOT listed here.)
const List<_EditionSource> _newEditions = [
  // Translations
  _EditionSource(column: 'text_tr_vakfi', jsonFile: 'tr.vakfi.json'),
  _EditionSource(column: 'text_de_bubenheim', jsonFile: 'de.bubenheim.json'),
  // Tafsir books
  _EditionSource(column: 'text_tafsir_jalalayn', jsonFile: 'ar.jalalayn.json'),
  _EditionSource(column: 'text_tafsir_qurtubi', jsonFile: 'ar.qurtubi.json'),
  _EditionSource(column: 'text_tafsir_miqbas', jsonFile: 'ar.miqbas.json'),
  _EditionSource(column: 'text_tafsir_waseet', jsonFile: 'ar.waseet.json'),
  _EditionSource(column: 'text_tafsir_baghawi', jsonFile: 'ar.baghawi.json'),
];

const String _dbPath = 'assets/data/quran.db';
const String _srcDir = 'tool/editions_src';
const int _expectedAyahCount = 6236;

void main(List<String> args) {
  final dbFile = File(_dbPath);
  if (!dbFile.existsSync()) {
    stderr.writeln('ERROR: $_dbPath not found. Run from the project root.');
    exitCode = 1;
    return;
  }

  // 1) Safety backup.
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '')
      .replaceAll('-', '');
  final backupPath = '$_dbPath.bak_$stamp';
  dbFile.copySync(backupPath);
  stdout.writeln('Backup written: $backupPath');

  final db = sqlite3.open(_dbPath);
  try {
    final existingCols = _ayahColumns(db);

    // 2) Rename legacy text_tafsir -> text_tafsir_muyassar (one-time).
    if (existingCols.contains('text_tafsir') &&
        !existingCols.contains('text_tafsir_muyassar')) {
      db.execute(
          'ALTER TABLE ayah RENAME COLUMN text_tafsir TO text_tafsir_muyassar');
      stdout.writeln('Renamed text_tafsir -> text_tafsir_muyassar');
    } else if (existingCols.contains('text_tafsir_muyassar')) {
      stdout.writeln('text_tafsir_muyassar already present; skipping rename');
    } else {
      stdout.writeln(
          'WARNING: neither text_tafsir nor text_tafsir_muyassar found');
    }

    // 3) Add + fill each new edition column.
    for (final ed in _newEditions) {
      _addColumnIfMissing(db, ed.column);
      _fillColumn(db, ed);
    }

    // 4) Report final state.
    final finalCols = _ayahColumns(db);
    stdout.writeln('\nFinal ayah columns:');
    for (final c in finalCols.where((c) => c.startsWith('text_'))) {
      final filled = db.select(
        'SELECT COUNT(*) AS n FROM ayah WHERE $c IS NOT NULL AND $c != ""',
      ).first['n'] as int;
      stdout.writeln('  $c: $filled / $_expectedAyahCount rows filled');
    }
    stdout.writeln('\nDone. $_dbPath updated.');
  } finally {
    db.dispose();
  }
}

List<String> _ayahColumns(Database db) {
  final rows = db.select('PRAGMA table_info(ayah)');
  return rows.map((r) => r['name'] as String).toList();
}

void _addColumnIfMissing(Database db, String column) {
  if (_ayahColumns(db).contains(column)) {
    stdout.writeln('Column $column already exists; will refill');
    return;
  }
  db.execute('ALTER TABLE ayah ADD COLUMN $column TEXT');
  stdout.writeln('Added column $column');
}

void _fillColumn(Database db, _EditionSource ed) {
  final srcFile = File('$_srcDir/${ed.jsonFile}');
  if (!srcFile.existsSync()) {
    stderr.writeln('  SKIP ${ed.column}: source ${srcFile.path} not found');
    return;
  }
  final decoded = json.decode(srcFile.readAsStringSync());
  final surahs = (decoded['data']?['surahs'] as List<dynamic>?);
  if (surahs == null) {
    stderr.writeln('  SKIP ${ed.column}: ${ed.jsonFile} has no data.surahs');
    return;
  }

  final stmt = db.prepare('UPDATE ayah SET ${ed.column} = ? WHERE id = ?');
  int updated = 0;
  int missingText = 0;
  db.execute('BEGIN TRANSACTION');
  try {
    for (final surah in surahs) {
      final ayahs = (surah['ayahs'] as List<dynamic>);
      for (final a in ayahs) {
        final id = a['number'] as int; // global ayah number == DB id
        final text = a['text'] as String?;
        if (text == null || text.isEmpty) {
          missingText++;
          continue;
        }
        stmt.execute([text, id]);
        updated++;
      }
    }
    db.execute('COMMIT');
  } catch (e) {
    db.execute('ROLLBACK');
    stderr.writeln('  ERROR filling ${ed.column}: $e (rolled back)');
    stmt.dispose();
    return;
  }
  stmt.dispose();
  stdout.writeln(
      '  Filled ${ed.column}: $updated rows'
      '${missingText > 0 ? " ($missingText empty texts skipped)" : ""}');
}
