import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqf;

class QuranSearchService {
  QuranSearchService._();
  static final QuranSearchService instance = QuranSearchService._();

  static String normalize(String input, {String language = 'ar'}) {
    if (language != 'ar') {
      return input.toLowerCase();
    }
    String s = input;
    s = s.replaceAll(RegExp(r"[\u064B-\u0652\u0670\u0640]"), '');
    s = s.replaceAll(RegExp(r"[\u0622\u0623\u0625]"), '\u0627');
    s = s.replaceAll('\u0629', '\u0647');
    s = s.replaceAll('\u0649', '\u064A');
    s = s.replaceAll('\u0624', '\u0648');
    s = s.replaceAll('\u0626', '\u064A');
    // Collapse multiple spaces to one but preserve single leading/trailing spaces
    s = s.replaceAll(RegExp(r' {2,}'), ' ');
    return s.toLowerCase();
  }

  sqf.Database? _db;
  Map<int, String>? _surahNames; // Arabic names cache
  Map<int, String>? _surahNamesEn; // English names cache
  // bool _hasFts = false; // FTS capability not used at runtime

  Future<void> _ensureDb() async {
    if (_db != null) return;
    // Use sqflite's standard database directory
    final databasesPath = await sqf.getDatabasesPath();
    final dbPath = p.join(databasesPath, 'quran.db');
    
    // Use sqflite's databaseExists for proper check
    bool needsCopy = !await sqf.databaseExists(dbPath);
    
    if (!needsCopy) {
      // Check if database has text_simple column
      try {
        final tempDb = await sqf.openDatabase(dbPath, readOnly: false);
        // Check for required text columns
        await tempDb.rawQuery('SELECT text_simple, text_english FROM ayah LIMIT 1');
        await tempDb.close();
      } catch (e) {
        // Column doesn't exist, need to update database
        needsCopy = true;
        try {
          await sqf.deleteDatabase(dbPath);
        } catch (_) {}
      }
    }
    
    if (needsCopy) {
      try {
        // Ensure parent directory exists
        final dbFile = File(dbPath);
        final parentDir = dbFile.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }
        
        final bytes = await rootBundle.load('assets/data/quran.db');
        await dbFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        
        // Verify file was written
        if (!await sqf.databaseExists(dbPath)) {
          throw Exception('Failed to write database file');
        }
      } catch (e) {
        // Clean up on error
        try {
          await sqf.deleteDatabase(dbPath);
        } catch (_) {}
        throw Exception('Failed to copy database: $e');
      }
    }
    
    _db = await sqf.openDatabase(dbPath, readOnly: false);
    // Detect FTS table (not used but kept for potential future optimizations)
    // final rows = await _db!.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ayah_fts'");
    // _hasFts = rows.isNotEmpty;
    
    // Load surah names if not already loaded
    if (_surahNames == null || _surahNamesEn == null) {
      await _loadSurahNames();
    }
  }
  
  Future<void> _loadSurahNames() async {
    if (_db == null) return;
    
    try {
      final rows = await _db!.query('surah', orderBy: 'order_no');
      _surahNames = {};
      _surahNamesEn = {};
      
      for (final row in rows) {
        final order = row['order_no'] as int;
        _surahNames![order] = row['name_ar'] as String;
        _surahNamesEn![order] = row['name_en'] as String;
      }
    } catch (e) {
      debugPrint('[QuranSearchService] Error loading surah names: $e');
    }
  }
  
  // Getters for surah names
  Map<int, String> get surahNames => _surahNames ?? {};
  Map<int, String> get surahNamesEn => _surahNamesEn ?? {};

  Future<SearchResult> search(String query, {int? surahOrder, String language = 'ar'}) async {
    try {
      await _ensureDb();
      final q = normalize(query, language: language);
      if (q.isEmpty) return SearchResult(ayahs: const <SearchAyah>[], totalOccurrences: 0);
      if (_db == null) {
        throw Exception('Database not initialized');
      }
      
      String textColumn = 'text_simple';
      String searchColumn = 'normalized';
      bool isTranslation = false;

      if (language == 'en') {
        textColumn = 'text_english';
        searchColumn = 'text_english';
        isTranslation = true;
      } else if (language == 'fr') {
        textColumn = 'text_french';
        searchColumn = 'text_french';
        isTranslation = true;
      }

      // Build query with optional surah filter
      String sql;
      if (isTranslation) {
        // use LIKE for translations (case insensitive typically, or we handle it via lower())
        // Assuming database collation is standard, LIKE is case insensitive for ASCII. 
        // For accurate results we might need LOWER(col) depending on SQLite build.
        // Let's rely on LIKE for now as it's standard for search. 
        // NOTE: 'normalized' column for Arabic is specially prepared. 
        // For EN/FR we search the text column directly.
        sql = 'SELECT id, surah_order, number_in_surah, juz, $textColumn as text FROM ayah WHERE LOWER($searchColumn) LIKE ?';
      } else {
         sql = 'SELECT id, surah_order, number_in_surah, juz, text_simple as text, normalized FROM ayah WHERE instr(normalized, ?) > 0';
      }
      
      List<dynamic> params = isTranslation ? ['%$q%'] : [q];
      
      if (surahOrder != null) {
        sql += ' AND surah_order = ?';
        params.add(surahOrder);
      }
      
      sql += ' LIMIT 5000';
      
      final rows = await _db!.rawQuery(sql, params);
      
      // Temporary Debug Logging
      debugPrint('Search Query: $sql');
      debugPrint('Params: $params');
      if (isTranslation) {
        final check = await _db!.rawQuery('SELECT count(*) as c FROM ayah WHERE LOWER($textColumn) LIKE ?', ['%$q%']);
        debugPrint('Direct Count Check ($textColumn): ${check.first['c']}');
        
        // Check sample data
        final sample = await _db!.rawQuery('SELECT $textColumn FROM ayah LIMIT 1');
        debugPrint('Sample Data ($textColumn): ${sample.first[textColumn]}');
      }
      
      int totalOccurrences = 0;
      final results = rows.map((r) {
        try {
          // For Arabic we use 'normalized' column to count, for others we use the text column itself
          final textToSearch = isTranslation ? (r['text'] as String? ?? '').toLowerCase() : (r['normalized'] as String? ?? '');
          final textToDisplay = r['text'] as String? ?? '';
          
          final occurrences = _countOccurrences(textToSearch, q);
          totalOccurrences += occurrences;
          
          return SearchAyah(
            globalNumber: (r['id'] as int? ?? 0),
            surahOrder: (r['surah_order'] as int? ?? 0),
            numberInSurah: (r['number_in_surah'] as int? ?? 0),
            juz: (r['juz'] as int? ?? 1),
            text: textToDisplay,
            occurrenceCount: occurrences,
          );
        } catch (e) {
          throw Exception('Failed to parse search result: $e');
        }
      }).toList();
      
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


