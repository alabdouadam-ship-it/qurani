import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  String get jsonFile {
    switch (this) {
      case QuranEdition.simple:
        return 'assets/data/quran-simple.json';
      case QuranEdition.uthmani:
        return 'assets/data/quran-uthmani.json';
      case QuranEdition.tajweed:
        return 'assets/data/quran-tajweed.json';
      case QuranEdition.english:
        return 'assets/data/quran-english.json';
      case QuranEdition.french:
        return 'assets/data/quran-french.json';
      case QuranEdition.tafsir:
        return 'assets/data/quran-simple.json'; // Fallback for tafsir
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
  QuranRepository._();

  static final QuranRepository instance = QuranRepository._();

  final Map<QuranEdition, Future<Map<String, dynamic>>> _jsonCache = {};
  final Map<String, Future<PageData>> _pageCache = {};
  Future<List<SurahMeta>>? _surahListFuture;
  final Map<QuranEdition, Future<Map<int, String>>> _translationCache = {};
  final Map<QuranEdition, Future<Map<int, AyahData>>> _ayahIndexCache = {};
  Future<Map<String, dynamic>>? _muyassarCache;

  Future<Map<String, dynamic>> _loadJson(QuranEdition edition) async {
    return await _jsonCache.putIfAbsent(edition, () async {
      debugPrint('[QuranRepository] Loading ${edition.jsonFile}...');
      final jsonString = await rootBundle.loadString(edition.jsonFile);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      debugPrint('[QuranRepository] ✓ Loaded ${edition.name}');
      return data;
    });
  }

  Future<PageData> loadPage(int pageNumber, QuranEdition edition) async {
    final key = '${edition.name}::$pageNumber';
    
    return await _pageCache.putIfAbsent(key, () async {
      final jsonData = await _loadJson(edition);
      final surahs = (jsonData['data']['surahs'] as List<dynamic>);
      
      final ayahs = <AyahData>[];
      final surahOccurrences = <SurahOccurrence>[];
      
      for (final surahJson in surahs) {
        final surahMeta = SurahMeta(
          number: surahJson['number'] as int,
          name: surahJson['name'] as String? ?? '',
          englishName: surahJson['englishName'] as String? ?? '',
          englishNameTranslation: surahJson['englishNameTranslation'] as String? ?? '',
          revelationType: surahJson['revelationType'] as String? ?? '',
        );
        
        final ayahsList = (surahJson['ayahs'] as List<dynamic>);
        final startIndex = ayahs.length;
        int ayahCount = 0;
        
        for (final ayahJson in ayahsList) {
          final page = ayahJson['page'] as int? ?? 1;
          if (page == pageNumber) {
            ayahs.add(AyahData(
              number: ayahJson['number'] as int,
              text: ayahJson['text'] as String? ?? '',
              surah: surahMeta,
              numberInSurah: ayahJson['numberInSurah'] as int,
              juz: ayahJson['juz'] as int? ?? 1,
              page: page,
            ));
            ayahCount++;
          }
        }
        
        if (ayahCount > 0) {
          surahOccurrences.add(SurahOccurrence(
            surah: surahMeta,
            startIndex: startIndex,
            ayahCount: ayahCount,
          ));
        }
      }
      
      return PageData(
        number: pageNumber,
        ayahs: ayahs,
        surahOccurrences: surahOccurrences,
      );
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
    final jsonData = await _loadJson(edition);
    final surahs = (jsonData['data']['surahs'] as List<dynamic>);
    
    final surahJson = surahs.firstWhere(
      (s) => s['number'] == surahNumber,
      orElse: () => null,
    );
    
    if (surahJson == null) return [];
    
    final surahMeta = SurahMeta(
      number: surahJson['number'] as int,
      name: surahJson['name'] as String? ?? '',
      englishName: surahJson['englishName'] as String? ?? '',
      englishNameTranslation: surahJson['englishNameTranslation'] as String? ?? '',
      revelationType: surahJson['revelationType'] as String? ?? '',
    );
    
    final ayahsList = (surahJson['ayahs'] as List<dynamic>);
    return ayahsList.map((ayahJson) {
      return AyahBrief(
        number: ayahJson['number'] as int,
        numberInSurah: ayahJson['numberInSurah'] as int,
        text: ayahJson['text'] as String? ?? '',
        surah: surahMeta,
      );
    }).toList();
  }

  Future<List<SurahMeta>> _loadSurahList() async {
    final jsonData = await _loadJson(QuranEdition.simple);
    final surahs = (jsonData['data']['surahs'] as List<dynamic>);
    
    return surahs.map((surahJson) {
      return SurahMeta(
        number: surahJson['number'] as int,
        name: surahJson['name'] as String? ?? '',
        englishName: surahJson['englishName'] as String? ?? '',
        englishNameTranslation: surahJson['englishNameTranslation'] as String? ?? '',
        revelationType: surahJson['revelationType'] as String? ?? '',
      );
    }).toList();
  }

  Future<Map<int, String>> _loadTranslationMap(QuranEdition edition) async {
    final jsonData = await _loadJson(edition);
    final surahs = (jsonData['data']['surahs'] as List<dynamic>);
    
    final Map<int, String> map = {};
    for (final surahJson in surahs) {
      final ayahsList = (surahJson['ayahs'] as List<dynamic>);
      for (final ayahJson in ayahsList) {
        final number = ayahJson['number'] as int;
        final text = ayahJson['text'] as String? ?? '';
        map[number] = text;
      }
    }
    return map;
  }

  Future<String?> loadAyahTafsir(int ayahNumber) async {
    try {
      final muyassarData = await _loadMuyassarJson();
      final surahs = (muyassarData['data']['surahs'] as List<dynamic>);
      
      // Find the ayah by global ayah number
      for (final surahData in surahs) {
        final ayahs = (surahData['ayahs'] as List<dynamic>);
        for (final ayahData in ayahs) {
          if (ayahData['number'] == ayahNumber) {
            return ayahData['text'] as String?;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[QuranRepository] Error loading tafsir: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>> _loadMuyassarJson() async {
    return await (_muyassarCache ??= _loadMuyassarJsonImpl());
  }
  
  Future<Map<String, dynamic>> _loadMuyassarJsonImpl() async {
    debugPrint('[QuranRepository] Loading quran-muyassar.json...');
    final jsonString = await rootBundle.loadString('assets/data/quran-muyassar.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    debugPrint('[QuranRepository] ✓ Loaded muyassar');
    return data;
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
    final jsonData = await _loadJson(edition);
    final surahs = (jsonData['data']['surahs'] as List<dynamic>);
    
    final Map<int, AyahData> map = {};
    for (final surahJson in surahs) {
      final surahMeta = SurahMeta(
        number: surahJson['number'] as int,
        name: surahJson['name'] as String? ?? '',
        englishName: surahJson['englishName'] as String? ?? '',
        englishNameTranslation: surahJson['englishNameTranslation'] as String? ?? '',
        revelationType: surahJson['revelationType'] as String? ?? '',
      );
      
      final ayahsList = (surahJson['ayahs'] as List<dynamic>);
      for (final ayahJson in ayahsList) {
        final number = ayahJson['number'] as int;
        map[number] = AyahData(
          number: number,
          text: ayahJson['text'] as String? ?? '',
          surah: surahMeta,
          numberInSurah: ayahJson['numberInSurah'] as int,
          juz: ayahJson['juz'] as int? ?? 1,
          page: ayahJson['page'] as int? ?? 1,
        );
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
