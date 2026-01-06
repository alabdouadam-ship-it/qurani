import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Model class for reciter configuration
class ReciterConfig {
  final String code;
  final String nameAr;
  final String nameLatin;
  final String ayahsPath;
  final String? surahsPath;

  ReciterConfig({
    required this.code,
    required this.nameAr,
    required this.nameLatin,
    required this.ayahsPath,
    this.surahsPath,
  });

  factory ReciterConfig.fromJson(Map<String, dynamic> json) {
    return ReciterConfig(
      code: json['code'] as String,
      nameAr: json['nameAr'] as String,
      nameLatin: json['nameLatin'] as String,
      ayahsPath: json['ayahsPath'] as String,
      surahsPath: json['surahsPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'nameAr': nameAr,
      'nameLatin': nameLatin,
      'ayahsPath': ayahsPath,
      'surahsPath': surahsPath,
    };
  }

  /// Get display name based on language code
  String getDisplayName(String langCode) {
    if (langCode == 'ar') return nameAr;
    return nameLatin;
  }

  /// Check if this reciter has full surah audio files
  bool hasFullSurahs() => surahsPath != null && surahsPath!.isNotEmpty;

  /// Check if this reciter has verse-by-verse audio files
  bool hasVerseByVerse() => ayahsPath.isNotEmpty;
}

/// Service to load and manage reciter configurations
class ReciterConfigService {
  static const String _remoteUrl = 'https://qurani.info/data/about-qurani/reciters.json';
  static const String _cacheKey = 'reciters_cache';
  static const String _cacheTimestampKey = 'reciters_timestamp';
  static const String _cacheVersionKey = 'reciters_version';
  static const int _cacheDurationDays = 7;
  static const int _currentVersion = 3; // Increment to force reload
  
  static List<ReciterConfig>? _reciters;
  // Public for synchronous access from AudioService
  static Map<String, ReciterConfig>? reciterMap;

  /// Load reciters with merge strategy:
  /// 1. Always load bundled asset (base truth)
  /// 2. Attempt to load from remote/cache
  /// 3. Merge results (Remote/Cache overrides Asset for same keys, but Asset-only keys are preserved)
  static Future<void> loadReciters() async {
    if (_reciters != null) return; // Already loaded

    debugPrint('[ReciterConfig] Starting to load reciters...');
    
    // Check version and clear cache if outdated
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedVersion = prefs.getInt(_cacheVersionKey) ?? 0;
      if (storedVersion < _currentVersion) {
        debugPrint('[ReciterConfig] Version mismatch ($storedVersion < $_currentVersion), clearing cache');
        await prefs.remove(_cacheKey);
        await prefs.remove(_cacheTimestampKey);
        await prefs.setInt(_cacheVersionKey, _currentVersion);
      }
    } catch (e) {
      debugPrint('[ReciterConfig] Error checking version: $e');
    }
    
    List<ReciterConfig> assetReciters = [];
    List<ReciterConfig> dynamicReciters = [];

    // 1. Load Asset
    try {
      debugPrint('[ReciterConfig] Loading from assets...');
      final assetData = await _loadFallback();
      assetReciters = _parseList(assetData);
      debugPrint('[ReciterConfig] Loaded ${assetReciters.length} reciters from assets');
    } catch (e, stack) {
      debugPrint('[ReciterConfig] ERROR loading asset reciters: $e');
      debugPrint('[ReciterConfig] Stack: $stack');
    }

    // 2. Load Remote/Cache
    try {
      Map<String, dynamic>? dynamicData;
      
      // Check if cache is expired
      if (await _isCacheExpired()) {
         debugPrint('[ReciterConfig] Cache expired, fetching remote...');
         dynamicData = await _fetchRemote();
         if (dynamicData != null) {
           debugPrint('[ReciterConfig] Remote fetch successful');
           await _saveCache(dynamicData);
         } else {
           debugPrint('[ReciterConfig] Remote fetch returned null');
         }
      } else {
        debugPrint('[ReciterConfig] Cache is valid, skipping remote');
      }
      
      // Fallback to cache if remote failed or valid
      if (dynamicData == null) {
        debugPrint('[ReciterConfig] Loading from cache...');
        dynamicData = await _loadCached();
        if (dynamicData != null) {
          debugPrint('[ReciterConfig] Loaded from cache successfully');
        } else {
          debugPrint('[ReciterConfig] No cached data available');
        }
      }
      
      if (dynamicData != null) {
        dynamicReciters = _parseList(dynamicData);
        debugPrint('[ReciterConfig] Parsed ${dynamicReciters.length} dynamic reciters');
      }
    } catch (e, stack) {
      debugPrint('[ReciterConfig] ERROR loading dynamic reciters: $e');
      debugPrint('[ReciterConfig] Stack: $stack');
    }

    // 3. Merge
    _mergeAndSet(assetReciters, dynamicReciters);
    debugPrint('[ReciterConfig] Final count: ${_reciters?.length ?? 0} reciters');
    debugPrint('[ReciterConfig] Reciters: ${_reciters?.map((r) => r.code).join(", ")}');
    
    // Log reciters with full surahs
    final withFullSurahs = _reciters?.where((r) => r.hasFullSurahs()).toList() ?? [];
    debugPrint('[ReciterConfig] Reciters with full surahs: ${withFullSurahs.length}');
    debugPrint('[ReciterConfig] Full surahs list: ${withFullSurahs.map((r) => r.code).join(", ")}');
  }

  static void _mergeAndSet(List<ReciterConfig> assetList, List<ReciterConfig> dynamicList) {
    // Create map from Asset first
    final Map<String, ReciterConfig> merged = {};
    for (var r in assetList) merged[r.code] = r;
    
    // Override/Add from Dynamic (Remote/Cache)
    for (var r in dynamicList) merged[r.code] = r;

    _reciters = merged.values.toList();
    reciterMap = merged;
  }

  static List<ReciterConfig> _parseList(Map<String, dynamic> jsonData) {
    final list = jsonData['reciters'] as List;
    final results = <ReciterConfig>[];
    
    for (int i = 0; i < list.length; i++) {
      try {
        final reciter = ReciterConfig.fromJson(list[i] as Map<String, dynamic>);
        results.add(reciter);
        debugPrint('[ReciterConfig] Loaded reciter: ${reciter.code}');
      } catch (e, stack) {
        debugPrint('[ReciterConfig] ERROR parsing reciter at index $i: $e');
        debugPrint('[ReciterConfig] Stack: $stack');
        debugPrint('[ReciterConfig] Data: ${list[i]}');
        // Continue to next reciter instead of failing completely
      }
    }
    
    return results;
  }

  static void _parseReciters(Map<String, dynamic> jsonData) {
     // Legacy method kept for simple calls, but now redirects to set
     _reciters = _parseList(jsonData);
     reciterMap = { for (var r in _reciters!) r.code: r };
  }

  /// Get a specific reciter by code
  static Future<ReciterConfig?> getReciterByCode(String code) async {
    await loadReciters();
    return reciterMap?[code];
  }

  /// Force refresh reciters from remote server (silent - no error messages)
  static Future<void> forceRefresh() async {
    try {
      debugPrint('[ReciterConfig] Force refresh requested');
      final remoteData = await _fetchRemote();
      if (remoteData != null) {
        debugPrint('[ReciterConfig] Remote data fetched, saving to cache');
        await _saveCache(remoteData);
        // Reload all to merge properly
        _reciters = null; 
        reciterMap = null;
        await loadReciters();
        debugPrint('[ReciterConfig] Refresh complete');
      } else {
        debugPrint('[ReciterConfig] Remote fetch failed, keeping current data');
      }
    } catch (e) {
      debugPrint('[ReciterConfig] Error in forceRefresh: $e');
      // Silent
    }
  }
  
  /// Clear cache and force reload from assets (useful for iOS fresh start)
  static Future<void> clearAndReload() async {
    debugPrint('[ReciterConfig] Clearing cache and reloading from assets');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      _reciters = null;
      reciterMap = null;
      await loadReciters();
      debugPrint('[ReciterConfig] Cache cleared and reloaded');
    } catch (e) {
      debugPrint('[ReciterConfig] Error in clearAndReload: $e');
    }
  }

  static Future<bool> _isCacheExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return true;
      
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(cacheDate);
      
      return difference.inDays >= _cacheDurationDays;
    } catch (_) {
      return true;
    }
  }

  static Future<Map<String, dynamic>?> _fetchRemote() async {
    try {
      final response = await http.get(
        Uri.parse(_remoteUrl),
      ).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      }
      return null;
    } catch (_) {
      // Silent failure - will use cache or fallback
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;
      
      return json.decode(cached) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_cacheKey, json.encode(data));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Silent failure - caching is optional
    }
  }

  static Future<Map<String, dynamic>> _loadFallback() async {
    final jsonString = await rootBundle.loadString('assets/data/reciters.json');
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  /// Get all reciters
  static Future<List<ReciterConfig>> getReciters() async {
    await loadReciters();
    return _reciters ?? [];
  }

  /// Get reciter by code
  static Future<ReciterConfig?> getReciter(String code) async {
    await loadReciters();
    return reciterMap?[code];
  }

  /// Get reciter display name
  static Future<String> getReciterDisplayName(String code, String langCode) async {
    final reciter = await getReciter(code);
    return reciter?.getDisplayName(langCode) ?? code;
  }

  /// Get ayahs path for reciter
  static Future<String?> getAyahsPath(String code) async {
    final reciter = await getReciter(code);
    return reciter?.ayahsPath;
  }

  /// Get surahs path for reciter
  static Future<String?> getSurahsPath(String code) async {
    final reciter = await getReciter(code);
    return reciter?.surahsPath;
  }

  /// Check if reciter has full surahs available
  static Future<bool> hasFullSurahs(String code) async {
    final reciter = await getReciter(code);
    return reciter?.surahsPath != null;
  }

  /// Get list of reciter codes
  static Future<List<String>> getReciterCodes() async {
    final reciters = await getReciters();
    return reciters.map((r) => r.code).toList();
  }

  /// Get reciters with full surahs only
  static Future<List<ReciterConfig>> getRecitersWithFullSurahs() async {
    final reciters = await getReciters();
    return reciters.where((r) => r.surahsPath != null).toList();
  }

  /// Get reciters with verse-by-verse only
  static Future<List<ReciterConfig>> getRecitersWithVerses() async {
    final reciters = await getReciters();
    return reciters.where((r) => r.ayahsPath.isNotEmpty).toList();
  }

  /// Clear cache (useful for testing or reloading)
  static void clearCache() {
    _reciters = null;
    reciterMap = null;
  }
}
