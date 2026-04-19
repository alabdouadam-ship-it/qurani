import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqf;

import 'quran_database_service.dart';

/// Supported Quran text editions.
enum QuranEdition {
  simple,
  uthmani,
  tajweed,
  english,
  french,
  tafsir,
  irab,
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
      case QuranEdition.irab:
        return 'text_simple'; // Audio uses simple edition
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
      case QuranEdition.irab:
        return 'assets/data'; // MASAQ.csv location
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
      case QuranEdition.irab:
        return 'quran-irab';
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
      case QuranEdition.irab:
        return 'إعراب القرآن';
    }
  }

  bool get isRtl =>
      this == QuranEdition.simple ||
      this == QuranEdition.uthmani ||
      this == QuranEdition.tajweed ||
      this == QuranEdition.tafsir ||
      this == QuranEdition.irab;

  bool get isTranslation =>
      this == QuranEdition.english || this == QuranEdition.french;

  bool get isTafsir => this == QuranEdition.tafsir;

  bool get isIrab => this == QuranEdition.irab;
}

class QuranRepository {
  QuranRepository._();

  static final QuranRepository instance = QuranRepository._();

  // LRU bound for page-level caches. A bound of 32 comfortably covers the
  // typical forward/backward swipe window (tens of pages) while keeping worst-
  // case memory to roughly 32 × ~15 ayahs × ~120 bytes ≈ 60 KB per edition.
  static const int _pageCacheMaxEntries = 32;

  sqf.Database? _db;
  // Insertion-ordered LRU of parsed `PageData`, keyed by `edition::page`. We
  // cache Future objects (rather than resolved PageData) so that concurrent
  // requests for the same page coalesce to a single DB query.
  final LinkedHashMap<String, Future<PageData>> _pageCache = LinkedHashMap();
  Future<List<SurahMeta>>? _surahListFuture;
  // NOTE: the previous implementation kept full per-edition maps of every
  // single ayah (`_translationCache`, `_tafsirCache`, `_ayahIndexCache`) in
  // memory — ~6236 entries × N editions, easily several MB, and all just to
  // serve single-ayah lookups that SQLite can do in <1ms via the primary
  // key. We dropped those bulk caches and now issue direct indexed SELECTs
  // per lookup; that eliminates the long-tail OOM risk on constrained
  // devices while being imperceptibly slower in practice.

  /// Reads [key] from [_pageCache], bumping it to the MRU slot so the oldest
  /// entry is the one evicted on overflow. Returns `null` if the key is
  /// missing.
  Future<PageData>? _getCachedPage(String key) {
    final cached = _pageCache.remove(key);
    if (cached == null) return null;
    _pageCache[key] = cached; // re-insert as most-recent
    return cached;
  }

  /// Inserts [future] at the MRU slot and evicts the LRU entries once the
  /// cache exceeds [_pageCacheMaxEntries].
  void _putCachedPage(String key, Future<PageData> future) {
    _pageCache[key] = future;
    while (_pageCache.length > _pageCacheMaxEntries) {
      _pageCache.remove(_pageCache.keys.first);
    }
  }

  /// Ensures the repository has a live handle to the shared `quran.db`.
  ///
  /// All asset-copy / schema-validation / lock-management logic now lives
  /// in [QuranDatabaseService] so `QuranRepository`, `SurahService`, and
  /// `QuranSearchService` share a single connection. If a previously
  /// cached handle was closed (e.g. by an error-recovery path elsewhere),
  /// we transparently re-request a fresh one here.
  Future<void> _ensureDb() async {
    if (_db != null && _db!.isOpen) return;
    _db = await QuranDatabaseService.database();
  }

  Future<PageData> loadPage(int pageNumber, QuranEdition edition) async {
    final key = '${edition.identifier}::$pageNumber';

    try {
      final existing = _getCachedPage(key);
      if (existing != null) return await existing;

      // Launch the DB query and store the Future in the LRU cache *before*
      // awaiting. Concurrent callers for the same key will coalesce on the
      // same Future rather than each firing a separate query.
      final future = _loadPageFromDb(pageNumber, edition);
      _putCachedPage(key, future);
      return await future;
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        debugPrint('Database closed error, clearing cache and retrying');
        _pageCache.remove(key);
        _db = null;
        await _ensureDb();
        return loadPage(pageNumber, edition);
      }
      // On any other failure, drop the (failed) cached Future so subsequent
      // callers get a fresh attempt rather than replaying the exception.
      _pageCache.remove(key);
      rethrow;
    }
  }

  Future<PageData> _loadPageFromDb(int pageNumber, QuranEdition edition) async {
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
    try {
      await _ensureDb();
      if (_db == null) return null;
      final textColumn = edition.dbColumn;
      // Direct PK lookup on the `ayah.id` primary key — SQLite responds in
      // sub-millisecond. This replaces the old 6k-entry in-memory map that
      // was loaded per edition just to serve one lookup.
      final rows = await _db!.rawQuery(
        'SELECT $textColumn AS text FROM ayah WHERE id = ? LIMIT 1',
        [ayahNumber],
      );
      if (rows.isNotEmpty) {
        final text = rows.first['text'] as String?;
        if (text != null && text.isNotEmpty) return text;
      }
      if (pageNumber != null) {
        return loadAyahText(
          ayahNumber: ayahNumber,
          pageNumber: pageNumber,
          edition: edition,
        );
      }
      return null;
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        _db = null;
        await _ensureDb();
        return loadAyahTranslation(
            ayahNumber: ayahNumber,
            edition: edition,
            pageNumber: pageNumber);
      }
      rethrow;
    }
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

  Future<String?> loadAyahTafsir(int ayahNumber) async {
    try {
      await _ensureDb();
      if (_db == null) return null;
      final rows = await _db!.rawQuery(
        'SELECT text_tafsir FROM ayah WHERE id = ? LIMIT 1',
        [ayahNumber],
      );
      if (rows.isEmpty) return null;
      final text = rows.first['text_tafsir'] as String?;
      return (text != null && text.isNotEmpty) ? text : null;
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        _db = null;
        await _ensureDb();
        return loadAyahTafsir(ayahNumber);
      }
      rethrow;
    }
  }

  Future<AyahData?> lookupAyahByNumber(
    int ayahNumber, {
    QuranEdition edition = QuranEdition.simple,
  }) async {
    try {
      await _ensureDb();
      if (_db == null) return null;
      final textColumn = edition.dbColumn;
      // Single indexed-PK query with a JOIN for surah metadata — sub-ms on
      // SQLite. Replaces the previous ~6k-entry in-memory index per edition.
      final rows = await _db!.rawQuery('''
        SELECT
          a.id, a.surah_order, a.number_in_surah, a.juz, a.page, a.$textColumn AS text,
          s.order_no, s.name_ar, s.name_en, s.name_en_translation, s.revelation_type
        FROM ayah a
        LEFT JOIN surah s ON a.surah_order = s.order_no
        WHERE a.id = ?
        LIMIT 1
      ''', [ayahNumber]);
      if (rows.isEmpty) return null;
      final r = rows.first;
      final surahMeta = SurahMeta(
        number: (r['order_no'] as int? ?? 0),
        name: (r['name_ar'] as String? ?? ''),
        englishName: (r['name_en'] as String? ?? ''),
        englishNameTranslation: (r['name_en_translation'] as String? ?? ''),
        revelationType: (r['revelation_type'] as String? ?? ''),
      );
      return AyahData(
        number: ayahNumber,
        text: (r['text'] as String? ?? ''),
        surah: surahMeta,
        numberInSurah: (r['number_in_surah'] as int? ?? 0),
        juz: (r['juz'] as int? ?? 1),
        page: (r['page'] as int? ?? 1),
      );
    } catch (e) {
      if (e.toString().contains('database_closed')) {
        _db = null;
        await _ensureDb();
        return lookupAyahByNumber(ayahNumber, edition: edition);
      }
      rethrow;
    }
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
