import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

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

  List<_IndexedAyah>? _index;
  Map<int, String>? _surahNames;
  Map<int, String>? _displayTexts; // For displaying results from quran-simple

  Future<void> _ensureIndex() async {
    if (_index != null && _surahNames != null && _displayTexts != null) return;
    
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
    final displayMap = <int, String>{};

    // Build index from quran-clean
    for (final entry in cleanSurahs) {
      final m = entry as Map<String, dynamic>;
      final surahOrder = (m['number'] as num?)?.toInt() ?? 0;
      final surahName = m['name'] as String? ?? '';
      names[surahOrder] = surahName;
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
            normalized: normalize(text),
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

    _index = list;
    _surahNames = names;
    _displayTexts = displayMap;
  }

  Future<SearchResult> search(String query) async {
    await _ensureIndex();
    final q = normalize(query);
    if (q.isEmpty) return SearchResult(ayahs: const <SearchAyah>[], totalOccurrences: 0);
    final src = _index!;
    final results = <SearchAyah>[];
    int totalOccurrences = 0;
    for (final ayah in src) {
      if (ayah.normalized.contains(q)) {
        final occurrences = _countOccurrences(ayah.normalized, q);
        totalOccurrences += occurrences;
        // Use display text from quran-simple instead of search text from quran-clean
        final displayText = _displayTexts?[ayah.globalNumber] ?? ayah.text;
        results.add(SearchAyah(
          globalNumber: ayah.globalNumber,
          surahOrder: ayah.surahOrder,
          numberInSurah: ayah.numberInSurah,
          juz: ayah.juz,
          text: displayText, // Display text from quran-simple
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


