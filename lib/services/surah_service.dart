import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/surah.dart';

class SurahService {
  static List<Surah>? _cachedArabic;
  static List<Surah>? _cachedLatin;

  static Future<List<Surah>> _loadFromAssetJson(String path) async {
    final raw = await rootBundle.loadString(path);
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => Surah(
      name: e['surah_name'] as String,
      order: (e['surah_order'] as num).toInt(),
      totalVerses: (e['total_verses'] as num).toInt(),
    )).toList();
  }

  static Future<List<Surah>> getArabicSurahs() async {
    if (_cachedArabic != null) return _cachedArabic!;
    _cachedArabic = await _loadFromAssetJson('assets/data/surah_ar.json');
    return _cachedArabic!;
  }

  static Future<List<Surah>> getLatinSurahs() async {
    if (_cachedLatin != null) return _cachedLatin!;
    _cachedLatin = await _loadFromAssetJson('assets/data/surah_latin.json');
    return _cachedLatin!;
  }

  static Future<List<Surah>> getLocalizedSurahs(String langCode) async {
    final ar = await getArabicSurahs();
    if (langCode == 'ar') return ar;
    final la = await getLatinSurahs();
    // Merge by order: prefer latin names, keep verses from arabic (or latin)
    final orderToLatin = { for (final s in la) s.order : s };
    return ar.map((s) {
      final lat = orderToLatin[s.order];
      return Surah(
        name: lat?.name ?? s.name,
        order: s.order,
        totalVerses: s.totalVerses,
      );
    }).toList();
  }
}


