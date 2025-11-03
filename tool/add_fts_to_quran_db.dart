import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

// Run with: dart run tool/add_fts_to_quran_db.dart
// Adds FTS5 virtual table to existing assets/data/quran.db using data from ayah table.

void main() {
  final db = sqlite3.open('assets/data/quran.db');
  try {
    bool hasFts = false;
    final check = db.select("SELECT name FROM sqlite_master WHERE type='table' AND name='ayah_fts'");
    if (check.isNotEmpty) {
      hasFts = true;
    }
    if (!hasFts) {
      try {
        db.execute("CREATE VIRTUAL TABLE ayah_fts USING fts5(normalized, content='ayah', content_rowid='id');");
        hasFts = true;
      } catch (e) {
        stderr.writeln('FTS5 not available: $e');
        return;
      }
    }
    // Populate FTS table from ayah
    db.execute('BEGIN');
    db.execute('DELETE FROM ayah_fts');
    final rows = db.select('SELECT id, normalized FROM ayah');
    final ins = db.prepare('INSERT INTO ayah_fts(rowid, normalized) VALUES(?, ?)');
    for (final r in rows) {
      ins.execute([r['id'], r['normalized']]);
    }
    ins.dispose();
    db.execute('COMMIT');
    stdout.writeln('FTS index created and populated successfully.');
  } finally {
    db.dispose();
  }
}


