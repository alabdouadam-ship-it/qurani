import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:qurani/util/arabic_font_utils.dart';

class PreferencesService {
  static SharedPreferences? _prefs;

  static const String keyQuranVersion = 'quran_version';
  static const String keyReciter = 'reciter';
  static const String keyRepetitionReciter = 'repetition_reciter';
  static const String keyTheme = 'theme';
  static const String keyLanguage = 'language'; // 'ar' | 'en' | 'fr'
  static const String keyTafsir = 'tafsir';
  static const String keyFontSize = 'font_size';
  static const String keyListenFeaturedSurahs = 'listen_featured_surahs';
  static const String keyArabicFontFamily = 'arabic_font_family';
  static const String keyVerseRepeatCount = 'verse_repeat_count';
  static const String keyDeviceInfoCollected = 'device_info_collected_v1';
  static const String keyDeviceInfoJson = 'device_info_json';
  static const String keyInstallationId = 'installation_id_v1';

  static final ValueNotifier<String> languageNotifier = ValueNotifier<String>('ar');
  static final ValueNotifier<String> themeNotifier = ValueNotifier<String>('green'); // Default to green
  static final ValueNotifier<String> arabicFontNotifier =
      ValueNotifier<String>(ArabicFontUtils.fontAmiri);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedLang = _prefs!.getString(keyLanguage);
    if (savedLang != null && savedLang.isNotEmpty) {
      languageNotifier.value = savedLang;
    }
    final savedTheme = _prefs!.getString(keyTheme);
    if (savedTheme != null && savedTheme.isNotEmpty) {
      themeNotifier.value = savedTheme;
    }
    final savedArabicFont = _prefs!.getString(keyArabicFontFamily);
    if (savedArabicFont != null && savedArabicFont.isNotEmpty) {
      arabicFontNotifier.value = _normalizeArabicFontKey(savedArabicFont);
    } else {
      arabicFontNotifier.value = ArabicFontUtils.fontAmiri;
      await _prefs!.setString(keyArabicFontFamily, arabicFontNotifier.value);
    }

    final savedReciter = _prefs!.getString(keyReciter);
    if (savedReciter == null || savedReciter.isEmpty) {
      await _prefs!.setString(keyReciter, 'afs');
    }
    final savedRepetition = _prefs!.getString(keyRepetitionReciter);
    if (savedRepetition == null || savedRepetition.isEmpty) {
      await _prefs!.setString(keyRepetitionReciter, 'afs');
    }
    final savedRepeatCount = _prefs!.getInt(keyVerseRepeatCount);
    if (savedRepeatCount == null || savedRepeatCount < 1) {
      await _prefs!.setInt(keyVerseRepeatCount, 10);
    }
    final savedFont = _prefs!.getString(keyArabicFontFamily);
    if (savedFont == null || savedFont.isEmpty) {
      await _prefs!.setString(keyArabicFontFamily, ArabicFontUtils.fontAmiri);
    } else {
      final normalized = _normalizeArabicFontKey(savedFont);
      arabicFontNotifier.value = normalized;
      if (normalized != savedFont) {
        await _prefs!.setString(keyArabicFontFamily, normalized);
      }
    }
  }

  static Future<void> saveQuranVersion(String value) async {
    await _prefs?.setString(keyQuranVersion, value);
  }

  static String? getQuranVersion() {
    return _prefs?.getString(keyQuranVersion);
  }

  static Future<void> saveReciter(String value) async {
    await _prefs?.setString(keyReciter, value);
  }

  static String getReciter() {
    final saved = _prefs?.getString(keyReciter);
    if (saved == null || saved.isEmpty) {
      return 'afs';
    }
    return saved;
  }

  static Future<void> saveRepetitionReciter(String value) async {
    await _prefs?.setString(keyRepetitionReciter, value);
  }

  static String getRepetitionReciter() {
    final saved = _prefs?.getString(keyRepetitionReciter);
    if (saved == null || saved.isEmpty) {
      return 'afs';
    }
    return saved;
  }

  static Future<void> saveTheme(String value) async {
    await _prefs?.setString(keyTheme, value);
    themeNotifier.value = value; // Notify listeners
  }

  static String getTheme() {
    final saved = _prefs?.getString(keyTheme);
    return saved ?? 'green'; // Default to green if not set
  }

  static Future<void> saveLanguage(String langCode) async {
    await _prefs?.setString(keyLanguage, langCode);
    languageNotifier.value = langCode;
  }

  static String getLanguage() {
    return languageNotifier.value; // default 'ar'
  }

  // Device info collection flags / storage
  static Future<void> setDeviceInfoCollected(bool value) async {
    await _prefs?.setBool(keyDeviceInfoCollected, value);
  }

  static bool isDeviceInfoCollected() {
    return _prefs?.getBool(keyDeviceInfoCollected) ?? false;
  }

  static Future<void> saveDeviceInfoJson(String json) async {
    await _prefs?.setString(keyDeviceInfoJson, json);
  }

  static String? getDeviceInfoJson() {
    return _prefs?.getString(keyDeviceInfoJson);
  }

  // Installation ID (stable per install, not a hardware/device ID)
  static Future<String> ensureInstallationId() async {
    final existing = _prefs?.getString(keyInstallationId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final id = const Uuid().v4();
    await _prefs?.setString(keyInstallationId, id);
    return id;
  }

  static String getInstallationId() {
    final existing = _prefs?.getString(keyInstallationId);
    return existing ?? '';
  }

  // Generic helpers for simple int flags/epochs used by services (e.g., update checks)
  static Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  // Prayer calculation method
  static const String keyPrayerCalcMethod = 'prayer_calc_method';
  static Future<void> savePrayerCalcMethod(String methodKey) async {
    await _prefs?.setString(keyPrayerCalcMethod, methodKey);
  }

  static String getPrayerCalcMethod() {
    return _prefs?.getString(keyPrayerCalcMethod) ?? 'mwl';
  }

  // Adhan sound selection
  static const String keyAdhanSound = 'adhan_sound';
  static const String keyAdhanVolume = 'adhan_volume';
  static Future<void> saveAdhanSound(String soundKey) async {
    await _prefs?.setString(keyAdhanSound, soundKey);
  }

  static String getAdhanSound() {
    return _prefs?.getString(keyAdhanSound) ?? 'afs';
  }

  static double getAdhanVolume() {
    return _prefs?.getDouble(keyAdhanVolume) ?? 1.0;
  }

  static Future<void> saveAdhanVolume(double value) async {
    await _prefs?.setDouble(keyAdhanVolume, value.clamp(0.0, 1.0));
  }

  // Time format: true => 12h, false => 24h
  static const String keyTimeFormat12h = 'time_format_12h';
  static Future<void> saveTimeFormat12h(bool value) async {
    await _prefs?.setBool(keyTimeFormat12h, value);
  }

  static bool getTimeFormat12h() {
    return _prefs?.getBool(keyTimeFormat12h) ?? false; // default 24h
  }

  // Digit style: true => Western (0-9), false => Eastern (Arabic)
  static const String keyWesternDigits = 'western_digits';
  static Future<void> saveWesternDigits(bool value) async {
    await _prefs?.setBool(keyWesternDigits, value);
  }

  static bool getWesternDigits() {
    return _prefs?.getBool(keyWesternDigits) ?? true; // default Western
  }

  // User name
  static const String keyUserName = 'user_name';
  static Future<void> saveUserName(String name) async {
    await _prefs?.setString(keyUserName, name);
  }

  static String getUserName() {
    return _prefs?.getString(keyUserName) ?? '';
  }

  static Future<void> saveTafsir(String value) async {
    await _prefs?.setString(keyTafsir, value);
  }

  static String? getTafsir() {
    return _prefs?.getString(keyTafsir);
  }

  // Medium Priority: Bookmarking
  static Future<void> saveBookmark(int surahOrder, int positionSeconds) async {
    await _prefs?.setInt('bookmark_$surahOrder', positionSeconds);
  }

  static Future<int?> getBookmark(int surahOrder) async {
    return _prefs?.getInt('bookmark_$surahOrder');
  }

  static Future<void> removeBookmark(int surahOrder) async {
    await _prefs?.remove('bookmark_$surahOrder');
  }

  // Nice to have: Last position resume
  static Future<void> saveLastPosition(int surahOrder, int positionSeconds) async {
    await _prefs?.setInt('last_pos_$surahOrder', positionSeconds);
  }

  static int? getLastPosition(int surahOrder) {
    return _prefs?.getInt('last_pos_$surahOrder');
  }

  // Medium Priority: History
  static Future<void> addToHistory(int surahOrder, String reciterCode) async {
    final key = 'history_list';
    final history = _prefs?.getStringList(key) ?? [];
    final entry = '$surahOrder:$reciterCode:${DateTime.now().millisecondsSinceEpoch}';
    history.insert(0, entry);
    // Keep only last 50
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    await _prefs?.setStringList(key, history);
  }

  static List<Map<String, dynamic>> getHistory() {
    final history = _prefs?.getStringList('history_list') ?? [];
    return history.map((entry) {
      final parts = entry.split(':');
      if (parts.length >= 3) {
        return {
          'surahOrder': int.tryParse(parts[0]) ?? 1,
          'reciterCode': parts[1],
          'timestamp': int.tryParse(parts[2]) ?? 0,
        };
      }
      return null;
    }).whereType<Map<String, dynamic>>().toList();
  }

  // Downloads
  static Future<void> setDownloadedFull(bool value) async {
    await _prefs?.setBool('download_full', value);
  }

  static bool isDownloadedFull() {
    return _prefs?.getBool('download_full') ?? false;
  }

  static Future<void> setDownloadedReciter(String reciter) async {
    await _prefs?.setString('download_reciter', reciter);
  }

  static String? getDownloadedReciter() {
    return _prefs?.getString('download_reciter');
  }

  static Future<void> toggleAyahHighlight(int ayahNumber) async {
    final key = 'highlighted_ayahs';
    final list = _prefs?.getStringList(key) ?? [];
    final ayahKey = ayahNumber.toString();
    if (list.contains(ayahKey)) {
      list.remove(ayahKey);
    } else {
      list.add(ayahKey);
    }
    await _prefs?.setStringList(key, list);
  }

  static Set<int> getHighlightedAyahs() {
    final list = _prefs?.getStringList('highlighted_ayahs') ?? [];
    return list
        .map((entry) => int.tryParse(entry))
        .whereType<int>()
        .toSet();
  }

  /// Featured (bookmarked) surahs management for Listen to Quran feature
  static Future<bool> toggleListenFeaturedSurah(int surahOrder) async {
    final list = _prefs?.getStringList(keyListenFeaturedSurahs) ?? [];
    final key = surahOrder.toString();
    bool isNowFeatured;
    if (list.contains(key)) {
      list.remove(key);
      isNowFeatured = false;
    } else {
      list.add(key);
      isNowFeatured = true;
    }
    await _prefs?.setStringList(keyListenFeaturedSurahs, list);
    return isNowFeatured;
  }

  static bool isListenSurahFeatured(int surahOrder) {
    final list = _prefs?.getStringList(keyListenFeaturedSurahs) ?? [];
    return list.contains(surahOrder.toString());
  }

  static Set<int> getListenFeaturedSurahs() {
    final list = _prefs?.getStringList(keyListenFeaturedSurahs) ?? [];
    return list
        .map((entry) => int.tryParse(entry))
        .whereType<int>()
        .toSet();
  }

  // Prayer time adjustments (offset in minutes per prayer)
  static const String keyPrayerTimeAdjustments = 'prayer_time_adjustments_debug';
  
  /// Get prayer time adjustment (offset in minutes) for a specific prayer
  /// Returns 0 if no adjustment is set
  static int getPrayerTimeAdjustment(String prayerId) {
    final jsonStr = _prefs?.getString(keyPrayerTimeAdjustments);
    if (jsonStr == null || jsonStr.isEmpty) return 0;
    try {
      final Map<String, dynamic> adjustments = json.decode(jsonStr);
      return (adjustments[prayerId] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Set prayer time adjustment (offset in minutes) for a specific prayer
  static Future<void> setPrayerTimeAdjustment(String prayerId, int offsetMinutes) async {
    final jsonStr = _prefs?.getString(keyPrayerTimeAdjustments);
    Map<String, dynamic> adjustments = {};
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        adjustments = json.decode(jsonStr);
      } catch (_) {
        adjustments = {};
      }
    }
    adjustments[prayerId] = offsetMinutes;
    await _prefs?.setString(keyPrayerTimeAdjustments, json.encode(adjustments));
  }

  /// Adjust prayer time adjustment by adding offset (can be negative)
  static Future<void> adjustPrayerTime(String prayerId, int offsetMinutes) async {
    final current = getPrayerTimeAdjustment(prayerId);
    await setPrayerTimeAdjustment(prayerId, current + offsetMinutes);
  }

  /// Get all prayer time adjustments as a map
  static Map<String, int> getAllPrayerTimeAdjustments() {
    final jsonStr = _prefs?.getString(keyPrayerTimeAdjustments);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final Map<String, dynamic> adjustments = json.decode(jsonStr);
      return adjustments.map((key, value) => MapEntry(key, (value as int? ?? 0)));
    } catch (_) {
      return {};
    }
  }

  /// Clear all prayer time adjustments
  static Future<void> clearPrayerTimeAdjustments() async {
    await _prefs?.remove(keyPrayerTimeAdjustments);
  }

  // Font size for Quran reading
  static Future<void> saveFontSize(double fontSize) async {
    await _prefs?.setDouble(keyFontSize, fontSize);
  }

  static double getFontSize() {
    final saved = _prefs?.getDouble(keyFontSize);
    // New steps: 16 (small), 20 (medium), 24 (large), 28 (xlarge)
    final value = saved ?? 24.0; // Default to large (24)
    // If old values exist (18/22), snap to nearest new step
    final steps = <double>[16, 20, 24, 28];
    double nearest = steps.first;
    double bestDiff = (value - nearest).abs();
    for (final s in steps) {
      final d = (value - s).abs();
      if (d < bestDiff) {
        bestDiff = d;
        nearest = s;
      }
    }
    return nearest;
  }

  static Future<void> saveVerseRepeatCount(int count) async {
    if (count < 1) {
      count = 1;
    }
    await _prefs?.setInt(keyVerseRepeatCount, count);
  }

  static int getVerseRepeatCount() {
    final saved = _prefs?.getInt(keyVerseRepeatCount);
    if (saved == null || saved < 1) {
      return 10;
    }
    return saved;
  }

  static Future<void> saveArabicFontFamily(String fontKey) async {
    final normalized = _normalizeArabicFontKey(fontKey);
    await _prefs?.setString(keyArabicFontFamily, normalized);
    arabicFontNotifier.value = normalized;
  }

  static String getArabicFontFamily() {
    final saved = _prefs?.getString(keyArabicFontFamily);
    if (saved == null || saved.isEmpty) {
      return arabicFontNotifier.value;
    }
    final normalized = _normalizeArabicFontKey(saved);
    if (normalized != saved) {
      unawaited(_prefs?.setString(keyArabicFontFamily, normalized));
    }
    return normalized;
  }

  static String _normalizeArabicFontKey(String? value) {
    if (value == null || value.isEmpty) {
      return ArabicFontUtils.fontAmiri;
    }
    switch (value.toLowerCase()) {
      case 'amiriquran-regular':
      case 'amiriquran':
      case 'amiri quran':
      case 'amiri_quran':
        return ArabicFontUtils.fontAmiri;
      case 'scheherazade':
      case 'scheherazade new':
      case 'scheherazade_new':
      case 'lateef':
        return ArabicFontUtils.fontAmiri;
      case 'kfgqpc_hafs_small':
      case 'kfgqpchafssmall':
      case 'kfgqpc hafs (small)':
      case 'kfgqpc hafs small':
      case 'kfgqpchafsunthmanicscriptregular-narz1':
      case 'kfgqpc hafs uthmanic script regular narz1':
        return ArabicFontUtils.fontKfgqpcSmall;
      case 'kfgqpc_hafs_large':
      case 'kfgqpchafslarge':
      case 'kfgqpc hafs (large)':
      case 'kfgqpc hafs large':
      case 'kfgqpchafsunthmanicscriptregular-1jgee':
      case 'kfgqpc hafs uthmanic script regular 1jgee':
        return ArabicFontUtils.fontKfgqpcLarge;
      default:
        return value;
    }
  }
}
