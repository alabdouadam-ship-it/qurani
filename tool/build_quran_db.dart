import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

// Run with: dart run tool/build_quran_db.dart
// Reads assets/data/quran.json and writes assets/data/quran.db

String normalizeArabic(String input) {
  String s = input;
  s = s.replaceAll(RegExp(r"[\u064B-\u0652\u0670\u0640]"), ''); // diacritics + tatweel
  s = s.replaceAll(RegExp(r"[\u0622\u0623\u0625]"), '\u0627'); // آ/أ/إ -> ا
  s = s.replaceAll('\u0629', '\u0647'); // ة -> ه
  s = s.replaceAll('\u0649', '\u064A'); // ى -> ي
  s = s.replaceAll('\u0624', '\u0648'); // ؤ -> و
  s = s.replaceAll('\u0626', '\u064A'); // ئ -> ي
  return s.toLowerCase().trim();
}

void main() {
  final jsonFile = File('assets/data/quran.json');
  if (!jsonFile.existsSync()) {
    stderr.writeln('ERROR: assets/data/quran.json not found');
    exit(1);
  }

  final outPath = 'assets/data/quran.db';
  if (File(outPath).existsSync()) {
    File(outPath).deleteSync();
  }

  final db = sqlite3.open(outPath);
  try {
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
    db.execute('PRAGMA temp_store = MEMORY;');

    db.execute('''
      CREATE TABLE surah (
        order_no INTEGER PRIMARY KEY,
        name_ar TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE ayah (
        id INTEGER PRIMARY KEY,            -- global ayah number
        surah_order INTEGER NOT NULL,
        number_in_surah INTEGER NOT NULL,
        juz INTEGER NOT NULL,
        text_ar TEXT NOT NULL,
        normalized TEXT NOT NULL,
        FOREIGN KEY(surah_order) REFERENCES surah(order_no)
      );
    ''');

    // Try to create FTS table if available
    bool hasFts = true;
    try {
      db.execute("CREATE VIRTUAL TABLE ayah_fts USING fts5(normalized, content='ayah', content_rowid='id');");
    } catch (_) {
      hasFts = false;
    }

    final raw = json.decode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
    final data = raw['data'] as Map<String, dynamic>;
    final surahs = data['surahs'] as List<dynamic>;

    final insertSurah = db.prepare('INSERT INTO surah(order_no, name_ar) VALUES(?, ?)');
    final insertAyah = db.prepare('INSERT INTO ayah(id, surah_order, number_in_surah, juz, text_ar, normalized) VALUES(?, ?, ?, ?, ?, ?)');
    final insertFts = hasFts ? db.prepare('INSERT INTO ayah_fts(rowid, normalized) VALUES(?, ?)') : null;

    db.execute('BEGIN');
    for (final sEntry in surahs) {
      final s = sEntry as Map<String, dynamic>;
      final surahOrder = (s['number'] as num?)?.toInt() ?? 0;
      final surahName = (s['name'] as String?) ?? '';
      insertSurah.execute([surahOrder, surahName]);

      final ayahs = s['ayahs'] as List<dynamic>? ?? const [];
      for (final aEntry in ayahs) {
        final a = aEntry as Map<String, dynamic>;
        final global = (a['number'] as num?)?.toInt() ?? 0;
        final numberInSurah = (a['numberInSurah'] as num?)?.toInt() ?? 0;
        final juz = (a['juz'] as num?)?.toInt() ?? 1;
        final text = (a['text'] as String?) ?? '';
        final norm = normalizeArabic(text);
        insertAyah.execute([global, surahOrder, numberInSurah, juz, text, norm]);
        if (hasFts) {
          insertFts!.execute([global, norm]);
        }
      }
    }
    db.execute('COMMIT');

    insertSurah.dispose();
    insertAyah.dispose();
    insertFts?.dispose();

    if (!hasFts) {
      db.execute('CREATE INDEX IF NOT EXISTS idx_ayah_norm ON ayah(normalized)');
    }

    stdout.writeln('Successfully built $outPath');
  } finally {
    db.dispose();
  }
}


