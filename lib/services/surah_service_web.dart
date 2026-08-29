import '../models/surah.dart';
import 'web_edition_json.dart';

/// Web surah list.
///
/// Built from the shared `index.json` (~24 KB), which carries full surah
/// metadata including verse counts. Previously this fetched and decoded the
/// entire 2.93 MB `quran-simple.json` and counted its ayah arrays just to
/// produce 114 names and totals.
///
/// It reads the index directly rather than going through
/// `QuranRepository.loadAllSurahs()` because [Surah] needs `totalVerses`, and
/// `SurahMeta` deliberately does not carry it (that model is shared with the io
/// implementation, whose shape must not drift).
class SurahService {
  static List<Surah>? _cachedArabic;
  static List<Surah>? _cachedEnglish;

  static Future<List<Surah>> _loadFromIndex({bool useEnglishName = false}) async {
    final index = await loadEditionIndex();
    final surahs = (index['surahs'] as List<dynamic>?) ?? const [];

    return surahs.map((entry) {
      final m = entry as Map<String, dynamic>;
      final arabicName = m['name'] as String? ?? '';
      final englishName = m['englishName'] as String? ?? '';
      final String name;
      if (useEnglishName) {
        name = englishName.isNotEmpty ? englishName : arabicName;
      } else {
        name = arabicName;
      }
      return Surah(
        name: name,
        order: (m['number'] as num?)?.toInt() ?? 0,
        totalVerses: (m['totalVerses'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  static Future<List<Surah>> getArabicSurahs() async {
    if (_cachedArabic != null) return _cachedArabic!;
    _cachedArabic = await _loadFromIndex(useEnglishName: false);
    return _cachedArabic!;
  }

  static Future<List<Surah>> getLatinSurahs() async {
    if (_cachedEnglish != null) return _cachedEnglish!;
    _cachedEnglish = await _loadFromIndex(useEnglishName: true);
    return _cachedEnglish!;
  }

  static Future<List<Surah>> getLocalizedSurahs(String langCode) async {
    if (langCode == 'ar') {
      return getArabicSurahs();
    }
    return getLatinSurahs();
  }
}
