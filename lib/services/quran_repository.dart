import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Supported Quran text editions.
enum QuranEdition {
  simple,
  uthmani,
  english,
  french,
  tafsir,
}

extension QuranEditionExt on QuranEdition {
  String get assetFolder {
    switch (this) {
      case QuranEdition.simple:
        return 'assets/data/quran-simple';
      case QuranEdition.uthmani:
        return 'assets/data/quran-uthmani';
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
      this == QuranEdition.tafsir;

  bool get isTranslation =>
      this == QuranEdition.english || this == QuranEdition.french;

  bool get isTafsir => this == QuranEdition.tafsir;
}

class QuranRepository {
  QuranRepository._();

  static final QuranRepository instance = QuranRepository._();

  final Map<String, Future<PageData>> _pageCache = {};
  Future<List<SurahMeta>>? _surahListFuture;
  final Map<QuranEdition, Future<Map<int, String>>> _translationCache = {};
  Future<Map<int, String>>? _tafsirCache;
  final Map<QuranEdition, Future<Map<int, AyahData>>> _ayahIndexCache = {};

  Future<PageData> loadPage(int pageNumber, QuranEdition edition) {
    final key = '${edition.identifier}::$pageNumber';
    return _pageCache.putIfAbsent(key, () async {
      final assetPath = '${edition.assetFolder}/pages/$pageNumber.json';
      late final String jsonStr;
      try {
        jsonStr = await rootBundle.loadString(assetPath);
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          FlutterError(
            'Failed to load Quran page asset "$assetPath": $error',
          ),
          stackTrace,
        );
      }
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      final dataMap = decoded['data'] as Map<String, dynamic>;
      return PageData.fromJson(dataMap, edition);
    });
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
    final jsonStr = await rootBundle.loadString('${edition.assetFolder}/quran.json');
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final surahs = data['surahs'] as List<dynamic>;
    final surahEntry = surahs.firstWhere(
      (e) => (e as Map<String, dynamic>)['number'] == surahNumber,
      orElse: () => <String, dynamic>{},
    ) as Map<String, dynamic>;
    final name = surahEntry['name'] as String? ?? '';
    final englishName = surahEntry['englishName'] as String? ?? '';
    final englishNameTranslation = surahEntry['englishNameTranslation'] as String? ?? '';
    final surahMeta = SurahMeta(
      number: surahNumber,
      name: name,
      englishName: englishName,
      englishNameTranslation: englishNameTranslation,
    );
    final ayahs = (surahEntry['ayahs'] as List<dynamic>? ?? const [])
        .map((a) {
          final m = a as Map<String, dynamic>;
          return AyahBrief(
            number: (m['number'] as num?)?.toInt() ?? 0,
            numberInSurah: (m['numberInSurah'] as num?)?.toInt() ?? 0,
            text: m['text'] as String? ?? '',
            surah: surahMeta,
          );
        })
        .toList();
    return ayahs;
  }

  Future<List<SurahMeta>> _loadSurahList() async {
    final jsonStr =
        await rootBundle.loadString('assets/data/quran-simple/quran.json');
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final surahList = data['surahs'] as List<dynamic>;
    return surahList
        .map((entry) =>
            SurahMeta.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<Map<int, String>> _loadTranslationMap(QuranEdition edition) async {
    final Map<int, String> map = {};
    final jsonStr = await rootBundle
        .loadString('${edition.assetFolder}/quran.json');
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final surahs = data['surahs'] as List<dynamic>;
    for (final surahEntry in surahs) {
      final surah = surahEntry as Map<String, dynamic>;
      final ayahs = surah['ayahs'] as List<dynamic>? ?? const [];
      for (final ayahEntry in ayahs) {
        final ayah = ayahEntry as Map<String, dynamic>;
        final number = ayah['number'] as int? ?? 0;
        final text = ayah['text'] as String? ?? '';
        if (number != 0) {
          map[number] = text;
        }
      }
    }
    return map;
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
    final Map<int, AyahData> map = {};
    final jsonStr =
        await rootBundle.loadString('${edition.assetFolder}/quran.json');
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final surahs = data['surahs'] as List<dynamic>;

    for (final surahEntry in surahs) {
      final surahMap = surahEntry as Map<String, dynamic>;
      final surahMeta = SurahMeta(
        number: (surahMap['number'] as num?)?.toInt() ?? 0,
        name: surahMap['name'] as String? ?? '',
        englishName: surahMap['englishName'] as String? ?? '',
        englishNameTranslation:
            surahMap['englishNameTranslation'] as String? ?? '',
      );
      final ayahs = surahMap['ayahs'] as List<dynamic>? ?? const [];
      for (final ayahEntry in ayahs) {
        final ayahMap = ayahEntry as Map<String, dynamic>;
        final number = (ayahMap['number'] as num?)?.toInt();
        if (number == null) continue;
        map[number] = AyahData(
          number: number,
          text: ayahMap['text'] as String? ?? '',
          surah: surahMeta,
          numberInSurah: (ayahMap['numberInSurah'] as num?)?.toInt() ?? 0,
          juz: (ayahMap['juz'] as num?)?.toInt() ?? 1,
          page: (ayahMap['page'] as num?)?.toInt() ?? 1,
        );
      }
    }
    return map;
  }

  Future<Map<int, String>> _loadTafsirMap() async {
    final Map<int, String> map = {};
    final jsonStr =
        await rootBundle.loadString('assets/data/quran_muyassar/quran.json');
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final surahs = data['surahs'] as List<dynamic>;
    for (final surahEntry in surahs) {
      final surah = surahEntry as Map<String, dynamic>;
      final ayahs = surah['ayahs'] as List<dynamic>? ?? const [];
      for (final ayahEntry in ayahs) {
        final ayah = ayahEntry as Map<String, dynamic>;
        final number = ayah['number'] as int? ?? 0;
        final text = ayah['text'] as String? ?? '';
        if (number != 0) {
          map[number] = text;
        }
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
  });

  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;

  factory SurahMeta.fromJson(Map<String, dynamic> json) {
    return SurahMeta(
      number: json['number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
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
