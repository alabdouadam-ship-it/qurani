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
    final List<NewsItem> assetItems = [];
    if (kDebugMode) {
      try {
        _initialAssetCache ??= await rootBundle.loadString('assets/data/news_initial.json');
        assetItems.addAll(parseNews(_initialAssetCache!));
      } catch (e) {
        debugPrint('[NewsService] Error loading initial asset: $e');
      }
    }

    final String? cachedJson = prefs.getString(_cacheKey);
    final List<NewsItem> cachedItems = cachedJson != null ? parseNews(cachedJson) : [];

    final savedIds = getSavedNewsIds(prefs);
    final news = mergeAndFilterNews(
      assetItems: assetItems,
      remoteItems: cachedItems,
      savedIds: savedIds,
    );

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

  static List<NewsItem> parseNews(String jsonStr) {
    try {
      final Map<String, dynamic> decoded = json.decode(jsonStr);
      final List<dynamic> list = decoded['news'] ?? [];
      return list.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[NewsService] Error parsing JSON: $e');
      return [];
    }
  }

  /// Merges asset news with remote news and filters expired items.
  /// Remote items with the same ID overwrite asset items.
  static List<NewsItem> mergeAndFilterNews({
    required List<NewsItem> assetItems,
    required List<NewsItem> remoteItems,
    required Set<String> savedIds,
  }) {
    Map<String, NewsItem> newsMap = {};

    // 1. Load from assets
    for (var item in assetItems) {
      newsMap[item.id] = item;
    }

    // 2. Overwrite with remote
    for (var item in remoteItems) {
      newsMap[item.id] = item;
    }

    // 3. Filter and Sort
    List<NewsItem> news = newsMap.values.where((item) {
      return !item.isExpired || savedIds.contains(item.id);
    }).toList();

    news.sort((a, b) => b.publishDate.compareTo(a.publishDate));

    return news;
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

  /// Get list of seen news IDs
  static List<String> getSeenNewsIds(SharedPreferences prefs) {
    return prefs.getStringList(_seenKey) ?? [];
  }
}
