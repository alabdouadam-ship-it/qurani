import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

class QuranSearchService {
  QuranSearchService._();
  static final QuranSearchService instance = QuranSearchService._();

  static String normalize(String input, {String language = 'ar'}) {
    if (language != 'ar') return input.toLowerCase();
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

  // Indices for different languages
  List<_IndexedAyah>? _indexAr;
  List<_IndexedAyah>? _indexEn;
  List<_IndexedAyah>? _indexFr;
  
  // Metadata (loaded with Arabic index currently)
  Map<int, String>? _surahNames; // Arabic names
  Map<int, String>? _surahNamesEn; // English names
  Map<int, String>? _displayTextsAr; // For displaying Arabic results

  Future<void> _ensureIndex(String language) async {
    if (language == 'ar') {
      if (_indexAr != null) return;
      await _loadArabicIndex();
    } else if (language == 'en') {
      if (_indexEn != null) return;
      await _loadTranslationIndex('en', 'assets/data/quran-english.json');
    } else if (language == 'fr') {
      if (_indexFr != null) return;
      await _loadTranslationIndex('fr', 'assets/data/quran-french.json');
    }
  }

  Future<void> _loadArabicIndex() async {
    // Load quran-clean for searching (normalized text)
    final cleanJsonStr = await rootBundle.loadString('assets/data/quran-clean.json');
    final cleanDecoded = json.decode(cleanJsonStr) as Map<String, dynamic>;
    final cleanData = cleanDecoded['data'] as Map<String, dynamic>;
    final cleanSurahs = cleanData['surahs'] as List<dynamic>;
    
    // Load quran-simple for displaying results
    final simpleJsonStr = await rootBundle.loadString('assets/data/quran-simple.json');
    final simpleDecoded = json.decode(simpleJsonStr) as Map<String, dynamic>;
    final simpleData = simpleDecoded['data'] as Map<String, dynamic>;
    final simpleSurahs = simpleData['surahs'] as List<dynamic>;

    final list = <_IndexedAyah>[];
    final names = <int, String>{};
    final namesEn = <int, String>{};
    final displayMap = <int, String>{};

    // Build index from quran-clean
    for (final entry in cleanSurahs) {
      final m = entry as Map<String, dynamic>;
      final surahOrder = (m['number'] as num?)?.toInt() ?? 0;
      names[surahOrder] = m['name'] as String? ?? '';
      namesEn[surahOrder] = m['englishName'] as String? ?? '';
      
      final ayahs = m['ayahs'] as List<dynamic>? ?? const [];
      for (final a in ayahs) {
        final am = a as Map<String, dynamic>;
        final global = (am['number'] as num?)?.toInt() ?? 0;
        final inSurah = (am['numberInSurah'] as num?)?.toInt() ?? 0;
        final juz = (am['juz'] as num?)?.toInt() ?? 1;
        final text = am['text'] as String? ?? '';
        list.add(
          _IndexedAyah(
            globalNumber: global,
            surahOrder: surahOrder,
            numberInSurah: inSurah,
            juz: juz,
            text: text, // Clean text for searching
            normalized: normalize(text, language: 'ar'),
          ),
        );
      }
    }
    
    // Build display text map from quran-simple
    for (final entry in simpleSurahs) {
      final m = entry as Map<String, dynamic>;
      final ayahs = m['ayahs'] as List<dynamic>? ?? const [];
      for (final a in ayahs) {
        final am = a as Map<String, dynamic>;
        final global = (am['number'] as num?)?.toInt() ?? 0;
        final text = am['text'] as String? ?? '';
        displayMap[global] = text;
      }
    }

    _indexAr = list;
    _surahNames = names;
    _surahNamesEn = namesEn;
    _displayTextsAr = displayMap;
  }

  Future<void> _loadTranslationIndex(String lang, String assetPath) async {
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      final data = decoded['data'];
      final surahs = data['surahs'] as List<dynamic>;

      final list = <_IndexedAyah>[];

      for (final entry in surahs) {
        final m = entry as Map<String, dynamic>;
        final surahOrder = (m['number'] as num?)?.toInt() ?? 0;
        
        final ayahs = m['ayahs'] as List<dynamic>? ?? const [];
        for (final a in ayahs) {
          final am = a as Map<String, dynamic>;
          final global = (am['number'] as num?)?.toInt() ?? 0;
          final inSurah = (am['numberInSurah'] as num?)?.toInt() ?? 0;
          final juz = (am['juz'] as num?)?.toInt() ?? 1;
          final text = am['text'] as String? ?? '';
          list.add(
            _IndexedAyah(
              globalNumber: global,
              surahOrder: surahOrder,
              numberInSurah: inSurah,
              juz: juz,
              text: text, // Original text for display
              normalized: normalize(text, language: lang), // Lowercased for search
            ),
          );
        }
      }
      
      if (lang == 'en') {
        _indexEn = list;
      } else if (lang == 'fr') {
        _indexFr = list;
      }
    } catch (e) {
      debugPrint('Error loading $lang index: $e');
      if (lang == 'en') _indexEn = [];
      if (lang == 'fr') _indexFr = [];
    }
  }

  Future<SearchResult> search(String query, {int? surahOrder, String language = 'ar'}) async {
    await _ensureIndex(language);
    
    // If arabic metadata isn't loaded yet, ensure it is (for surah names)
    if (_surahNames == null) {
      await _ensureIndex('ar');
    }

    final q = normalize(query, language: language);
    if (q.isEmpty) return SearchResult(ayahs: const <SearchAyah>[], totalOccurrences: 0);
    
    List<_IndexedAyah> src;
    if (language == 'en') {
      src = _indexEn ?? [];
    } else if (language == 'fr') {
      src = _indexFr ?? [];
    } else {
      src = _indexAr ?? [];
    }

    final results = <SearchAyah>[];
    int totalOccurrences = 0;
    
    for (final ayah in src) {
      // Filter by surah if specified
      if (surahOrder != null && ayah.surahOrder != surahOrder) {
        continue;
      }
      
      if (ayah.normalized.contains(q)) {
        final occurrences = _countOccurrences(ayah.normalized, q);
        totalOccurrences += occurrences;
        
        // Determine text to display
        // For Arabic, we prefer the "simple" text (from _displayTextsAr)
        // For others, we use the text directly from the index (which is from the translation JSON)
        String displayText = ayah.text;
        if (language == 'ar' && _displayTextsAr != null) {
          displayText = _displayTextsAr![ayah.globalNumber] ?? ayah.text;
        }

        results.add(SearchAyah(
          globalNumber: ayah.globalNumber,
          surahOrder: ayah.surahOrder,
          numberInSurah: ayah.numberInSurah,
          juz: ayah.juz,
          text: displayText,
          occurrenceCount: occurrences,
        ));
        if (results.length >= 500) break;
      }
    }
    return SearchResult(ayahs: results, totalOccurrences: totalOccurrences);
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

  /// Get all surah names in Arabic (order -> name)
  Map<int, String> get surahNames => _surahNames ?? {};

  /// Get all surah names in English (order -> name)
  Map<int, String> get surahNamesEn => _surahNamesEn ?? {};
}

class SearchResult {
  SearchResult({
    required this.ayahs,
    required this.totalOccurrences,
  });

  final List<SearchAyah> ayahs;
  final int totalOccurrences;
}

class _IndexedAyah {
  final int globalNumber;
  final int surahOrder;
  final int numberInSurah;
  final int juz;
  final String text;
  final String normalized;

  const _IndexedAyah({
    required this.globalNumber,
    required this.surahOrder,
    required this.numberInSurah,
    required this.juz,
    required this.text,
    required this.normalized,
  });
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


