import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqf;

/// Supported Quran text editions.
enum QuranEdition {
  simple,
  uthmani,
  tajweed,
  english,
  french,
  tafsir,
}

extension QuranEditionExt on QuranEdition {
  String get dbColumn {
    switch (this) {
      case QuranEdition.simple:
        return 'text_simple';
      case QuranEdition.uthmani:
        return 'text_uthmani';
      case QuranEdition.tajweed:
        return 'text_tajweed';
      case QuranEdition.english:
        return 'text_english';
      case QuranEdition.french:
        return 'text_french';
      case QuranEdition.tafsir:
        return 'text_tafsir';
    }
  }

  String get assetFolder {
    switch (this) {
      case QuranEdition.simple:
        return 'assets/data/quran-simple';
      case QuranEdition.uthmani:
        return 'assets/data/quran-uthmani';
      case QuranEdition.tajweed:
        return 'assets/data/quran-tajweed';
      case QuranEdition.english:
        return 'assets/data/quran-english';
      case QuranEdition.french:
        return 'assets/data/quran-french';
      case QuranEdition.tafsir:
        return 'assets/data/quran_muyassar';
    }
  }

  String get identifier {
    switch (this) {
      case QuranEdition.simple:
        return 'quran-simple';
      case QuranEdition.uthmani:
        return 'quran-uthmani';
      case QuranEdition.tajweed:
        return 'quran-tajweed';
      case QuranEdition.english:
        return 'quran-english';
      case QuranEdition.french:
        return 'quran-french';
      case QuranEdition.tafsir:
        return 'quran_muyassar';
    }
  }

  String get displayName {
    switch (this) {
      case QuranEdition.simple:
        return 'Arabic (Simple)';
      case QuranEdition.uthmani:
        return 'Arabic (Uthmani)';
      case QuranEdition.tajweed:
        return 'Quran Tajweed';
      case QuranEdition.english:
        return 'English';
      case QuranEdition.french:
        return 'Français';
      case QuranEdition.tafsir:
        return 'Tafsir (Muyassar)';
    }
  }

  bool get isRtl =>
      this == QuranEdition.simple ||
      this == QuranEdition.uthmani ||
      this == QuranEdition.tajweed ||
      this == QuranEdition.tafsir;

  bool get isTranslation =>
      this == QuranEdition.english || this == QuranEdition.french;

  bool get isTafsir => this == QuranEdition.tafsir;
}

class QuranRepository {
  static const int _dbSchemaVersion = 2;
  static const String _dbVersionKey = 'quran_db_schema_version';
  
  QuranRepository._();

  static final QuranRepository instance = QuranRepository._();

  sqf.Database? _db;
  final Map<String, Future<PageData>> _pageCache = {};
  Future<List<SurahMeta>>? _surahListFuture;
  final Map<QuranEdition, Future<Map<int, String>>> _translationCache = {};
  Future<Map<int, String>>? _tafsirCache;
  final Map<QuranEdition, Future<Map<int, AyahData>>> _ayahIndexCache = {};

  void _clearCache() {
    _pageCache.clear();
    _surahListFuture = null;
    _translationCache.clear();
    _tafsirCache = null;
    _ayahIndexCache.clear();
  }

  Future<void> _ensureDb() async {
    if (_db != null && _db!.isOpen) return;
    
    // If database exists but is closed, reset it
    if (_db != null && !_db!.isOpen) {
      debugPrint('Database was closed, resetting connection');
      _db = null;
    }
    
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'quran.db');
    
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_dbVersionKey) ?? 0;
    
    final dbFile = File(dbPath);
    bool needsCopy = !dbFile.existsSync() || storedVersion < _dbSchemaVersion;
    
    if (!needsCopy) {
      // Check if database has valid schema
      sqf.Database? tempDb;
      try {
        tempDb = await sqf.openDatabase(dbPath, readOnly: true);
        
        // First check if required tables exist
        final tables = await tempDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('ayah', 'surah')"
        );
        
        if (tables.length != 2) {
          throw Exception('Missing required tables');
        }
        
        // Then check if required columns exist
        await tempDb.rawQuery('SELECT text_simple FROM ayah LIMIT 1');
        await tempDb.rawQuery('SELECT name_en, name_en_translation, revelation_type, total_verses FROM surah LIMIT 1');
        
        await tempDb.close();
        tempDb = null;
      } catch (e) {
        // Database is invalid or outdated
        debugPrint('Database validation failed, will replace: $e');
        needsCopy = true;
        
        // Close any open connection
        if (tempDb != null) {
          try {
            await tempDb.close();
          } catch (_) {}
          tempDb = null;
        }
        
        // Clear any cached data from old database
        _clearCache();
        _db = null;
        
        // Wait for file handles to release
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Force delete the old database
        try {
          if (dbFile.existsSync()) {
            await dbFile.delete();
            debugPrint('Old database deleted');
          }
        } catch (deleteError) {
          debugPrint('Could not delete old database: $deleteError');
          // Try to delete related files
          try {
            final shmFile = File('$dbPath-shm');
            final walFile = File('$dbPath-wal');
            if (shmFile.existsSync()) await shmFile.delete();
            if (walFile.existsSync()) await walFile.delete();
          } catch (_) {}
        }
      }
    }
    
    if (needsCopy) {
      debugPrint('Copying database from assets (schema version $_dbSchemaVersion)...');
      try {
        // Delete old database if it exists
        if (dbFile.existsSync()) {
          await dbFile.delete();
          debugPrint('Old database deleted');
        }
        final shmFile = File('$dbPath-shm');
        final walFile = File('$dbPath-wal');
        if (shmFile.existsSync()) await shmFile.delete();
        if (walFile.existsSync()) await walFile.delete();
        
        final bytes = await rootBundle.load('assets/data/quran.db');
        
        // Ensure parent directory exists
        await dbFile.parent.create(recursive: true);
        
        // Write the new database
        await dbFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        debugPrint('Database copied successfully: ${dbFile.lengthSync()} bytes');
        
        // Update stored version
        await prefs.setInt(_dbVersionKey, _dbSchemaVersion);
        debugPrint('Database schema version updated to $_dbSchemaVersion');
      } catch (copyError) {
        debugPrint('Error copying database: $copyError');
        throw Exception('Failed to copy database from assets');
      }
    }
    
    // Open the database in single instance mode to prevent locking issues
    _db = await sqf.openDatabase(dbPath, readOnly: true, singleInstance: false);
    debugPrint('Database opened successfully');
  }

  Future<PageData> loadPage(int pageNumber, QuranEdition edition) async {
    final key = '${edition.identifier}::$pageNumber';
    
    try {
      return await _pageCache.putIfAbsent(key, () async {
        await _ensureDb();
        if (_db == null) {
          throw Exception('Database not initialized');
        }

        final textColumn = edition.dbColumn;
        final rows = await _db!.rawQuery('''
          SELECT 
            a.id, a.surah_order, a.number_in_surah, a.juz, a.page, a.$textColumn as text,
            s.order_no, s.name_ar, s.name_en, s.name_en_translation, s.revelation_type
          FROM ayah a
          LEFT JOIN surah s ON a.surah_order = s.order_no
          WHERE a.page = ?
          ORDER BY a.id
        ''', [pageNumber]);

      final ayahs = <AyahData>[];
      for (final r in rows) {
        final surahMeta = SurahMeta(
          number: (r['order_no'] as int? ?? 0),
          name: (r['name_ar'] as String? ?? ''),
          englishName: (r['name_en'] as String? ?? ''),
          englishNameTranslation: (r['name_en_translation'] as String? ?? ''),
          revelationType: (r['revelation_type'] as String? ?? ''),
        );
        ayahs.add(AyahData(
          number: (r['id'] as int? ?? 0),
          text: (r['text'] as String? ?? ''),
          surah: surahMeta,
          numberInSurah: (r['number_in_surah'] as int? ?? 0),
          juz: (r['juz'] as int? ?? 1),
          page: (r['page'] as int? ?? 1),
        ));
      }

      // Build surah occurrences
      final surahOccurrences = <SurahOccurrence>[];
      SurahMeta? current;
      int? startIndex;
      for (var i = 0; i < ayahs.length; i++) {
        final ayah = ayahs[i];
        if (current == null || ayah.surah.number != current.number) {
          if (current != null && startIndex != null) {
            surahOccurrences.add(
              SurahOccurrence(
                surah: current,
                startIndex: startIndex,
                ayahCount: i - startIndex,
              ),
            );
          }
          current = ayah.surah;
          startIndex = i;
        }
      }
      if (current != null && startIndex != null) {
        surahOccurrences.add(
          SurahOccurrence(
            surah: current,
            startIndex: startIndex,
            ayahCount: ayahs.length - startIndex,
          ),
        );
      }

        return PageData(
          number: pageNumber,
          ayahs: ayahs,
          surahOccurrences: surahOccurrences,
        );
      });
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        debugPrint('Database closed error, clearing cache and retrying');
        _pageCache.remove(key);
        _db = null;
        await _ensureDb();
        return loadPage(pageNumber, edition);
      }
      rethrow;
    }
  }

  Future<String?> loadAyahText({
    required int ayahNumber,
    required int pageNumber,
    required QuranEdition edition,
  }) async {
    final page = await loadPage(pageNumber, edition);
    for (final ayah in page.ayahs) {
      if (ayah.number == ayahNumber) {
        return ayah.text;
      }
    }
    return null;
  }

  Future<String?> loadAyahTranslation({
    required int ayahNumber,
    required QuranEdition edition,
    int? pageNumber,
  }) async {
    final cache = await _translationCache.putIfAbsent(
      edition,
      () => _loadTranslationMap(edition),
    );
    final text = cache[ayahNumber];
    if (text != null) {
      return text;
    }
    if (pageNumber != null) {
      return loadAyahText(
        ayahNumber: ayahNumber,
        pageNumber: pageNumber,
        edition: edition,
      );
    }
    return null;
  }

  Future<List<SurahMeta>> loadAllSurahs() {
    _surahListFuture ??= _loadSurahList();
    return _surahListFuture!;
  }

  Future<List<AyahBrief>> loadSurahAyahs(int surahNumber, QuranEdition edition) async {
    try {
      await _ensureDb();
      if (_db == null) {
        throw Exception('Database not initialized');
      }

      // Get surah metadata
      final surahRows = await _db!.query(
        'surah',
        where: 'order_no = ?',
        whereArgs: [surahNumber],
      );
      
      if (surahRows.isEmpty) {
        return [];
      }

      final surahRow = surahRows.first;
      final surahMeta = SurahMeta(
        number: (surahRow['order_no'] as int? ?? 0),
        name: (surahRow['name_ar'] as String? ?? ''),
        englishName: (surahRow['name_en'] as String? ?? ''),
        englishNameTranslation: (surahRow['name_en_translation'] as String? ?? ''),
        revelationType: (surahRow['revelation_type'] as String? ?? ''),
      );

      // Get ayahs
      final textColumn = edition.dbColumn;
      final ayahRows = await _db!.rawQuery('''
        SELECT id, number_in_surah, $textColumn as text
        FROM ayah
        WHERE surah_order = ?
        ORDER BY number_in_surah
      ''', [surahNumber]);

      return ayahRows.map((r) {
        return AyahBrief(
          number: (r['id'] as int? ?? 0),
          numberInSurah: (r['number_in_surah'] as int? ?? 0),
          text: (r['text'] as String? ?? ''),
          surah: surahMeta,
        );
      }).toList();
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        debugPrint('Database closed error in loadSurahAyahs, retrying');
        _db = null;
        await _ensureDb();
        return loadSurahAyahs(surahNumber, edition);
      }
      rethrow;
    }
  }

  Future<List<SurahMeta>> _loadSurahList() async {
    try {
      await _ensureDb();
      if (_db == null) {
        throw Exception('Database not initialized');
      }

      final rows = await _db!.query('surah', orderBy: 'order_no');
      return rows.map((r) {
        return SurahMeta(
          number: (r['order_no'] as int? ?? 0),
          name: (r['name_ar'] as String? ?? ''),
          englishName: (r['name_en'] as String? ?? ''),
          englishNameTranslation: (r['name_en_translation'] as String? ?? ''),
          revelationType: (r['revelation_type'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        debugPrint('Database closed error in _loadSurahList, retrying');
        _surahListFuture = null;
        _db = null;
        await _ensureDb();
        return _loadSurahList();
      }
      rethrow;
    }
  }

  Future<Map<int, String>> _loadTranslationMap(QuranEdition edition) async {
    try {
      await _ensureDb();
      if (_db == null) {
        throw Exception('Database not initialized');
      }

      final Map<int, String> map = {};
      final textColumn = edition.dbColumn;
      final rows = await _db!.rawQuery('''
        SELECT id, $textColumn as text
        FROM ayah
        ORDER BY id
      ''');

      for (final r in rows) {
        final id = r['id'] as int? ?? 0;
        final text = r['text'] as String? ?? '';
        if (id != 0) {
          map[id] = text;
        }
      }
      return map;
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        debugPrint('Database closed error in _loadTranslationMap, retrying');
        _translationCache.remove(edition);
        _db = null;
        await _ensureDb();
        return _loadTranslationMap(edition);
      }
      rethrow;
    }
  }

  Future<String?> loadAyahTafsir(int ayahNumber) async {
    final cache = await (_tafsirCache ??= _loadTafsirMap());
    return cache[ayahNumber];
  }

  Future<AyahData?> lookupAyahByNumber(
    int ayahNumber, {
    QuranEdition edition = QuranEdition.simple,
  }) async {
    final cache = await _ayahIndexCache.putIfAbsent(
      edition,
      () => _loadAyahIndex(edition),
    );
    return cache[ayahNumber];
  }

  Future<Map<int, AyahData>> _loadAyahIndex(QuranEdition edition) async {
    await _ensureDb();
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    final Map<int, AyahData> map = {};
    final textColumn = edition.dbColumn;
    
    final rows = await _db!.rawQuery('''
      SELECT 
        a.id, a.surah_order, a.number_in_surah, a.juz, a.page, a.$textColumn as text,
        s.order_no, s.name_ar, s.name_en, s.name_en_translation, s.revelation_type
      FROM ayah a
      LEFT JOIN surah s ON a.surah_order = s.order_no
      ORDER BY a.id
    ''');

    for (final r in rows) {
      final surahMeta = SurahMeta(
        number: (r['order_no'] as int? ?? 0),
        name: (r['name_ar'] as String? ?? ''),
        englishName: (r['name_en'] as String? ?? ''),
        englishNameTranslation: (r['name_en_translation'] as String? ?? ''),
        revelationType: (r['revelation_type'] as String? ?? ''),
      );
      
      final ayahNumber = (r['id'] as int? ?? 0);
      if (ayahNumber == 0) continue;
      
      map[ayahNumber] = AyahData(
        number: ayahNumber,
        text: (r['text'] as String? ?? ''),
        surah: surahMeta,
        numberInSurah: (r['number_in_surah'] as int? ?? 0),
        juz: (r['juz'] as int? ?? 1),
        page: (r['page'] as int? ?? 1),
      );
    }
    
    return map;
  }

  Future<Map<int, String>> _loadTafsirMap() async {
    await _ensureDb();
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    final Map<int, String> map = {};
    final rows = await _db!.rawQuery('''
      SELECT id, text_tafsir
      FROM ayah
      WHERE text_tafsir IS NOT NULL AND text_tafsir != ''
      ORDER BY id
    ''');

    for (final r in rows) {
      final id = r['id'] as int? ?? 0;
      final text = r['text_tafsir'] as String? ?? '';
      if (id != 0 && text.isNotEmpty) {
        map[id] = text;
      }
    }
    return map;
  }
}

class PageData {
  PageData({
    required this.number,
    required this.ayahs,
    required this.surahOccurrences,
  });

  final int number;
  final List<AyahData> ayahs;
  final List<SurahOccurrence> surahOccurrences;

  int get juz => ayahs.isNotEmpty ? ayahs.first.juz : 1;

  List<SurahMeta> get surahsOnPage =>
      surahOccurrences.map((o) => o.surah).toList();

  factory PageData.fromJson(Map<String, dynamic> json, QuranEdition edition) {
    final number = json['number'] as int;
    final ayahList = (json['ayahs'] as List<dynamic>)
        .map((entry) =>
            AyahData.fromJson(entry as Map<String, dynamic>, edition))
        .toList();
    final surahOccurrences = <SurahOccurrence>[];
    SurahMeta? current;
    int? startIndex;
    for (var i = 0; i < ayahList.length; i++) {
      final ayah = ayahList[i];
      if (current == null || ayah.surah.number != current.number) {
        if (current != null && startIndex != null) {
          surahOccurrences.add(
            SurahOccurrence(
              surah: current,
              startIndex: startIndex,
              ayahCount: i - startIndex,
            ),
          );
        }
        current = ayah.surah;
        startIndex = i;
      }
    }
    if (current != null && startIndex != null) {
      surahOccurrences.add(
        SurahOccurrence(
          surah: current,
          startIndex: startIndex,
          ayahCount: ayahList.length - startIndex,
        ),
      );
    }
    return PageData(
      number: number,
      ayahs: ayahList,
      surahOccurrences: surahOccurrences,
    );
  }
}

class AyahData {
  AyahData({
    required this.number,
    required this.text,
    required this.surah,
    required this.numberInSurah,
    required this.juz,
    required this.page,
  });

  final int number;
  final String text;
  final SurahMeta surah;
  final int numberInSurah;
  final int juz;
  final int page;

  bool get isSurahBeginning => numberInSurah == 1;

  factory AyahData.fromJson(Map<String, dynamic> json, QuranEdition edition) {
    final surahMap = json['surah'] as Map<String, dynamic>? ?? {};
    return AyahData(
      number: json['number'] as int,
      text: json['text'] as String? ?? '',
      surah: SurahMeta.fromJson(surahMap),
      numberInSurah: json['numberInSurah'] as int? ?? 0,
      juz: json['juz'] as int? ?? 1,
      page: json['page'] as int? ?? 1,
    );
  }

}

class SurahMeta {
  const SurahMeta({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.revelationType,
  });

  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final String revelationType; // 'Meccan' | 'Medinan' | ''

  factory SurahMeta.fromJson(Map<String, dynamic> json) {
    return SurahMeta(
      number: json['number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
      revelationType: json['revelationType'] as String? ?? '',
    );
  }
}

class SurahOccurrence {
  const SurahOccurrence({
    required this.surah,
    required this.startIndex,
    required this.ayahCount,
  });

  final SurahMeta surah;
  final int startIndex;
  final int ayahCount;
}

class AyahBrief {
  AyahBrief({
    required this.number,
    required this.numberInSurah,
    required this.text,
    required this.surah,
  });

  final int number;
  final int numberInSurah;
  final String text;
  final SurahMeta surah;
}
