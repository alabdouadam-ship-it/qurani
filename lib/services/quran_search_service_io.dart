import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqf;

class QuranSearchService {
  QuranSearchService._();
  static final QuranSearchService instance = QuranSearchService._();

  static String normalize(String input) {
    String s = input;
    s = s.replaceAll(RegExp(r"[\u064B-\u0652\u0670\u0640]"), '');
    s = s.replaceAll(RegExp(r"[\u0622\u0623\u0625]"), '\u0627');
    s = s.replaceAll('\u0629', '\u0647');
    s = s.replaceAll('\u0649', '\u064A');
    s = s.replaceAll('\u0624', '\u0648');
    s = s.replaceAll('\u0626', '\u064A');
    return s.toLowerCase().trim();
  }

  sqf.Database? _db;
  Map<int, String>? _surahNames; // cache
  // bool _hasFts = false; // FTS capability not used at runtime

  Future<void> _ensureDb() async {
    if (_db != null) return;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'quran.db');
    
    bool needsCopy = !File(dbPath).existsSync();
    
    if (!needsCopy) {
      // Check if database has text_simple column
      try {
        final tempDb = await sqf.openDatabase(dbPath, readOnly: true);
        await tempDb.rawQuery('SELECT text_simple FROM ayah LIMIT 1');
        await tempDb.close();
      } catch (e) {
        // Column doesn't exist, need to update database
        print('Database outdated, updating from assets...');
        needsCopy = true;
        await File(dbPath).delete();
      }
    }
    
    if (needsCopy) {
      final bytes = await rootBundle.load('assets/data/quran.db');
      await File(dbPath).create(recursive: true);
      await File(dbPath).writeAsBytes(bytes.buffer.asUint8List());
    }
    
    _db = await sqf.openDatabase(dbPath, readOnly: true);
    // Detect FTS table (not used but kept for potential future optimizations)
    // final rows = await _db!.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ayah_fts'");
    // _hasFts = rows.isNotEmpty;
    final surahRows = await _db!.query('surah');
    _surahNames = { for (final r in surahRows) (r['order_no'] as int): (r['name_ar'] as String) };
  }

  Future<SearchResult> search(String query) async {
    try {
      await _ensureDb();
      final q = normalize(query);
      if (q.isEmpty) return SearchResult(ayahs: const <SearchAyah>[], totalOccurrences: 0);
      if (_db == null) {
        throw Exception('Database not initialized');
      }
      final rows = await _db!.rawQuery(
        'SELECT id, surah_order, number_in_surah, juz, text_simple, normalized FROM ayah WHERE instr(normalized, ?) > 0 LIMIT 5000',
        [q],
      );
      
      int totalOccurrences = 0;
      final results = rows.map((r) {
        try {
          final normalizedText = (r['normalized'] as String? ?? '');
          final occurrences = _countOccurrences(normalizedText, q);
          totalOccurrences += occurrences;
          
          return SearchAyah(
            globalNumber: (r['id'] as int? ?? 0),
            surahOrder: (r['surah_order'] as int? ?? 0),
            numberInSurah: (r['number_in_surah'] as int? ?? 0),
            juz: (r['juz'] as int? ?? 1),
            text: (r['text_simple'] as String? ?? ''),
            occurrenceCount: occurrences,
          );
        } catch (e) {
          throw Exception('Failed to parse search result: $e');
        }
      }).toList();
      
      print('Quran search for "$query" returned ${rows.length} ayahs with $totalOccurrences total occurrences.');
      return SearchResult(ayahs: results, totalOccurrences: totalOccurrences);
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }

  int _countOccurrences(String text, String query) {
    if (query.isEmpty || text.isEmpty) return 0;
    int count = 0;
    int index = 0;
    while ((index = text.indexOf(query, index)) != -1) {
      count++;
      index += query.length;
    }
    return count;
  }

  String surahName(int surahOrder) => _surahNames?[surahOrder] ?? '';
}

class SearchResult {
  SearchResult({
    required this.ayahs,
    required this.totalOccurrences,
  });

  final List<SearchAyah> ayahs;
  final int totalOccurrences;
}

class SearchAyah {
  SearchAyah({
    required this.globalNumber,
    required this.surahOrder,
    required this.numberInSurah,
    required this.juz,
    required this.text,
    required this.occurrenceCount,
  });

  final int globalNumber;
  final int surahOrder;
  final int numberInSurah;
  final int juz;
  final String text;
  final int occurrenceCount;
}


