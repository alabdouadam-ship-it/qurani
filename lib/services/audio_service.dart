import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioService {
  // Map Arabic reciter key to base folder (from script.js FULL_AUDIO_OPTIONS)
  static const Map<String, String> _fullAudioBases = {
    'basit': '/data/full/basit',
    'afs': '/data/full/afs',
    'sds': '/data/full/sds',
    'frs_a': '/data/full/frs_a',
    'husr': '/data/full/husr',
    'minsh': '/data/full/minsh',
    'suwaid': '/data/full/suwaid',
    'muyassar': '/data/muyassar_audio/full',
  };

  static const Map<String, Map<String, String>> _reciterDisplayNames = {
    'basit': {
      'ar': 'عبدالباسط عبدالصمد',
      'en': 'Abdulbasit Abdulsamad',
      'fr': 'Abdulbasit Abdulsamad',
    },
    'afs': {
      'ar': 'العفاسي',
      'en': 'Mishary Alafasy',
      'fr': 'Mishary Alafasy',
    },
    'sds': {
      'ar': 'عبدالرحمن السديس',
      'en': 'Abdulrahman Al Sudais',
      'fr': 'Abdulrahman Al Sudais',
    },
    'frs_a': {
      'ar': 'فارس عباد',
      'en': 'Fares Abbad',
      'fr': 'Fares Abbad',
    },
    'husr': {
      'ar': 'الحصري',
      'en': 'Mahmoud Al Husary',
      'fr': 'Mahmoud Al Husary',
    },
    'minsh': {
      'ar': 'المنشاوي',
      'en': 'Mohamed Al Manshawi',
      'fr': 'Mohamed Al Manshawi',
    },
    'suwaid': {
      'ar': 'أيمن سويد',
      'en': 'Ayman Suwaid',
      'fr': 'Ayman Suwaid',
    },
    'muyassar': {
      'ar': 'تفسير الميسر',
      'en': 'Tafsir Al Muyassar',
      'fr': 'Tafsir Al Muyassar',
    },
    'english_arabic': {
      'ar': 'إنجليزي - عربي',
      'en': 'English - Arabic',
      'fr': 'Anglais - Arabe',
    },
    'english-arabic': {
      'ar': 'إنجليزي - عربي',
      'en': 'English - Arabic',
      'fr': 'Anglais - Arabe',
    },
    'arabic_english': {
      'ar': 'عربي - إنجليزي',
      'en': 'Arabic - English',
      'fr': 'Arabe - Anglais',
    },
    'arabic-english': {
      'ar': 'عربي - إنجليزي',
      'en': 'Arabic - English',
      'fr': 'Arabe - Anglais',
    },
    'french_arabic': {
      'ar': 'فرنسي - عربي',
      'en': 'French - Arabic',
      'fr': 'Français - Arabe',
    },
    'french-arabic': {
      'ar': 'فرنسي - عربي',
      'en': 'French - Arabic',
      'fr': 'Français - Arabe',
    },
    'arabic_french': {
      'ar': 'عربي - فرنسي',
      'en': 'Arabic - French',
      'fr': 'Arabe - Français',
    },
    'arabic-french': {
      'ar': 'عربي - فرنسي',
      'en': 'Arabic - French',
      'fr': 'Arabe - Français',
    },
  };

  static String reciterDisplayName(String code, String langCode) {
    final names = _reciterDisplayNames[code];
    if (names == null) return code;
    return names[langCode] ?? names['en'] ?? code;
  }

  static String _normalizeArabic(String input) {
    const diacritics = r"[\u064B-\u0652\u0670\u0640]";
    return input.replaceAll(RegExp(diacritics), '').trim();
  }

  static String _resolveBaseForReciter(String reciterKeyAr) {
    // Exact match first
    final exact = _fullAudioBases[reciterKeyAr];
    if (exact != null) return exact;
    // Normalized match (remove tashkeel and tatweel)
    final norm = _normalizeArabic(reciterKeyAr);
    for (final entry in _fullAudioBases.entries) {
      if (_normalizeArabic(entry.key) == norm) {
        return entry.value;
      }
    }
    // Fallback to a safe default (Abdulbasit)
    return '/data/full/basit';
  }

  static String? _pad3(int order) {
    if (order < 1 || order > 999) return null;
    final s = order.toString();
    return s.padLeft(3, '0');
  }

  // Returns full URL like https://www.qurani.info/data/full/basit/001.mp3
  static String? buildFullRecitationUrl({required String reciterKeyAr, required int surahOrder}) {
    final base = _resolveBaseForReciter(reciterKeyAr);
    final padded = _pad3(surahOrder);
    if (padded == null) return null;
    return 'https://www.qurani.info$base/$padded.mp3';
  }

  // Returns verse URL like https://www.qurani.info/data/ayahs/afs/001001.mp3
  static String? buildVerseUrl({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
  }) {
    final surahPadded = _pad3(surahOrder);
    final versePadded = _pad3(verseNumber);
    if (surahPadded == null || versePadded == null) return null;
    
    // Map reciter key to ayahs folder name
    final reciterFolder = _getAyahsReciterFolder(reciterKeyAr);
    final basePath = reciterFolder == 'muyassar_audio'
        ? 'https://www.qurani.info/data/muyassar_audio'
        : 'https://www.qurani.info/data/ayahs/$reciterFolder';
    return '$basePath/$surahPadded$versePadded.mp3';
  }
  
  // Maps reciter key to the ayahs folder name
  static const Map<String, String> _ayahReciterFolders = {
    'afs': 'afs',
    'basit': 'basit',
    'frs_a': 'frs_a',
    'husr': 'husr',
    'minsh': 'minsh',
    'suwaid': 'suwaid',
    'sds': 'sds',
    'muyassar': 'muyassar_audio',
    'english_arabic': 'english-arabic',
    'english-arabic': 'english-arabic',
    'arabic_english': 'arabic-english',
    'arabic-english': 'arabic-english',
    'french_arabic': 'french-arabic',
    'french-arabic': 'french-arabic',
    'arabic_french': 'arabic-french',
    'arabic-french': 'arabic-french',
  };

  static String _getAyahsReciterFolder(String reciterKeyAr) {
    return _ayahReciterFolders[reciterKeyAr] ?? _ayahReciterFolders['afs']!;
  }

  // Public wrapper for other files
  static String ayahsReciterFolder(String reciterKeyAr) {
    return _getAyahsReciterFolder(reciterKeyAr);
  }

  // Get list of verse URLs for a surah
  static List<String> buildVerseUrls({
    required String reciterKeyAr,
    required int surahOrder,
    required int totalVerses,
  }) {
    return List.generate(
      totalVerses,
      (index) => buildVerseUrl(
        reciterKeyAr: reciterKeyAr,
        surahOrder: surahOrder,
        verseNumber: index + 1,
      ) ?? '',
    ).where((url) => url.isNotEmpty).toList();
  }

  // Local ayah file path under app documents: ayahs/<reciterFolder>/<SSSVVV>.mp3
  static Future<String> _localAyahFilePath({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final reciterFolder = _getAyahsReciterFolder(reciterKeyAr);
    final s = _pad3(surahOrder) ?? '001';
    final v = _pad3(verseNumber) ?? '001';
    final base = Directory('${dir.path}/ayahs/$reciterFolder');
    return '${base.path}/$s$v.mp3';
  }

  // Public wrapper for other files
  static Future<String> localAyahFilePath({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
  }) {
    return _localAyahFilePath(
      reciterKeyAr: reciterKeyAr,
      surahOrder: surahOrder,
      verseNumber: verseNumber,
    );
  }

  static Future<Uri?> getVerseUriPreferLocal({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
  }) async {
    try {
      final localPath = await _localAyahFilePath(
        reciterKeyAr: reciterKeyAr,
        surahOrder: surahOrder,
        verseNumber: verseNumber,
      );
      if (await File(localPath).exists()) {
        return Uri.file(localPath);
      }
    } catch (_) {}
    final url = buildVerseUrl(
      reciterKeyAr: reciterKeyAr,
      surahOrder: surahOrder,
      verseNumber: verseNumber,
    );
    return url != null ? Uri.parse(url) : null;
  }

  static Future<AudioSource?> buildVerseAudioSource({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
    required MediaItem mediaItem,
  }) async {
    final uri = await getVerseUriPreferLocal(
      reciterKeyAr: reciterKeyAr,
      surahOrder: surahOrder,
      verseNumber: verseNumber,
    );
    if (uri == null) return null;
    return AudioSource.uri(uri, tag: mediaItem);
  }
}


