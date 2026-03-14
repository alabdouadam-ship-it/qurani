import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_item.dart';

class NewsService {
  // CONFIGURATION: Simple to change the URL here
  static const String newsUrl = 'https://qurani.info/data/news-v1.json';
  
  static const String _cacheKey = 'news_cache';
  static const String _lastFetchKey = 'news_last_fetch';
  static const String _savedKey = 'news_saved_ids';
  static const String _seenKey = 'news_seen_ids';
  static const String _hasEverSeenKey = 'news_has_ever_seen';
  
  static final ValueNotifier<int> unseenCountNotifier = ValueNotifier<int>(0);
  
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static String? _initialAssetCache;

  /// Fetches news with caching logic
  static Future<List<NewsItem>> getNews({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Try to fetch from remote if cache is old (> 24h) or forced
    final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (forceRefresh || now - lastFetch > const Duration(hours: 24).inMilliseconds) {
      await _fetchRemote(prefs);
    }
    
    // 2. Load and Merge Data
    Map<String, NewsItem> newsMap = {};

    // First load from assets (as the base) - ONLY IN DEBUG MODE to prevent test data leaks
    if (kDebugMode) {
      try {
        _initialAssetCache ??= await rootBundle.loadString('assets/data/news_initial.json');
        final initialNews = _parseNews(_initialAssetCache!);
        for (var item in initialNews) {
          newsMap[item.id] = item;
        }
      } catch (e) {
        debugPrint('[NewsService] Error loading initial asset: $e');
      }
    }

    // Then load from cache (overwriting or adding)
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      final cachedNews = _parseNews(cachedJson);
      for (var item in cachedNews) {
        newsMap[item.id] = item;
      }
    }

    List<NewsItem> news = newsMap.values.toList();
    
    // 3. Filter expired items (unless they are saved)
    final savedIds = getSavedNewsIds(prefs);
    news = news.where((item) => !item.isExpired || savedIds.contains(item.id)).toList();
    
    // Sort by date (newest first)
    news.sort((a, b) => b.publishDate.compareTo(a.publishDate));

    // 4. Calculate Unseen Count
    final hasEverSeen = prefs.getBool(_hasEverSeenKey) ?? false;
    if (!hasEverSeen) {
      unseenCountNotifier.value = 0;
    } else {
      final seenIds = prefs.getStringList(_seenKey) ?? [];
      final unseenItems = news.where((item) => !seenIds.contains(item.id)).toList();
      unseenCountNotifier.value = unseenItems.length;
    }
    
    return news;
  }

  static List<NewsItem> _parseNews(String jsonStr) {
    try {
      final Map<String, dynamic> decoded = json.decode(jsonStr);
      final List<dynamic> list = decoded['news'] ?? [];
      return list.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[NewsService] Error parsing JSON: $e');
      return [];
    }
  }

  static Future<void> _fetchRemote(SharedPreferences prefs) async {
    try {
      final response = await _dio.get(newsUrl);
      if (response.statusCode == 200) {
        // Dio usually decodes JSON automatically to a Map or List.
        // We ensure it's a string for storage.
        final data = response.data;
        final jsonStr = data is String ? data : json.encode(data);
        
        await prefs.setString(_cacheKey, jsonStr);
        await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('[NewsService] Remote fetch successful');
      }
    } catch (e) {
      debugPrint('[NewsService] Silent network error (expected if offline): $e');
    }
  }

  /// Get list of saved news IDs
  static Set<String> getSavedNewsIds(SharedPreferences prefs) {
    final list = prefs.getStringList(_savedKey) ?? [];
    return list.toSet();
  }

  /// Toggle save status of a news item
  static Future<bool> toggleSaveNews(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = getSavedNewsIds(prefs);
    bool isSaved;
    
    if (savedIds.contains(id)) {
      savedIds.remove(id);
      isSaved = false;
    } else {
      savedIds.add(id);
      isSaved = true;
    }
    
    await prefs.setStringList(_savedKey, savedIds.toList());
    return isSaved;
  }

  static Future<bool> isNewsSaved(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return getSavedNewsIds(prefs).contains(id);
  }

  /// Mark all current news as seen
  static Future<void> markAllAsSeen(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final seenIds = prefs.getStringList(_seenKey) ?? [];
    
    // Add new unique IDs to the list
    final updatedSeenIds = {...seenIds, ...ids}.toList();
    
    await prefs.setStringList(_seenKey, updatedSeenIds);
    await prefs.setBool(_hasEverSeenKey, true); // User has now interacted with the news screen
    
    unseenCountNotifier.value = 0;
  }
}
