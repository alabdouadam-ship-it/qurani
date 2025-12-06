import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/surah.dart';

class SurahService {
  static List<Surah>? _cachedArabic;
  static List<Surah>? _cachedEnglish;

  static void _clearCache() {
    _cachedArabic = null;
    _cachedEnglish = null;
  }

  static Future<List<Surah>> _loadFromJson({bool useEnglishName = false}) async {
    final jsonString = await rootBundle.loadString('assets/data/quran-simple.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final surahs = (data['data']['surahs'] as List<dynamic>);
    
    return surahs.map((surahJson) {
      final String name;
      if (useEnglishName) {
        name = (surahJson['englishName'] as String? ?? surahJson['name'] as String? ?? '');
      } else {
        name = (surahJson['name'] as String? ?? '');
      }
      
      final ayahs = (surahJson['ayahs'] as List<dynamic>? ?? []);
      
      return Surah(
        name: name,
        order: (surahJson['number'] as int? ?? 0),
        totalVerses: ayahs.length,
      );
    }).toList();
  }

  static Future<List<Surah>> getArabicSurahs() async {
    if (_cachedArabic != null) return _cachedArabic!;
    _cachedArabic = await _loadFromJson(useEnglishName: false);
    return _cachedArabic!;
  }

  static Future<List<Surah>> getLatinSurahs() async {
    if (_cachedEnglish != null) return _cachedEnglish!;
    _cachedEnglish = await _loadFromJson(useEnglishName: true);
    return _cachedEnglish!;
  }

  static Future<List<Surah>> getLocalizedSurahs(String langCode) async {
    if (langCode == 'ar') {
      return getArabicSurahs();
    }
    return getLatinSurahs();
  }
}
