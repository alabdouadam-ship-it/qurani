import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_item.dart';
import 'notification_service_io.dart';
import 'preferences_service.dart';
import 'supabase_config.dart';

class NewsService {
  /// Supabase table that is the SINGLE source of remote news. When Supabase
  /// is configured we fetch from here; the result is normalised into the
  /// `{ "news": [...] }` JSON shape and written to the cache, so all
  /// downstream logic (parse / merge / seen / GC / notifications / offline
  /// fallback) is unchanged. There is intentionally NO remote JSON-URL fetch
  /// and NO bundled initial asset — if Supabase is unavailable/empty we serve
  /// the last cached news, and nothing if the cache is empty too.
  static const String _newsTable = 'news_items';
  
  static const String _cacheKey = 'news_cache';
  static const String _lastFetchKey = 'news_last_fetch';
  static const String _savedKey = 'news_saved_ids';
  static const String _seenKey = 'news_seen_ids';
  static const String _hasEverSeenKey = 'news_has_ever_seen';
  
  static final ValueNotifier<int> unseenCountNotifier = ValueNotifier<int>(0);

  /// Fetches news with caching logic
  static Future<List<NewsItem>> getNews({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Try to fetch from remote if cache is old (> 24h) or forced
    final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (forceRefresh || now - lastFetch > const Duration(hours: 24).inMilliseconds) {
      await _fetchRemote(prefs);
    }
    
    // 2. Load Data
    // News comes solely from Supabase (cached). There is no bundled initial
    // asset and no remote JSON fallback — if the cache is empty (e.g. first
    // launch offline with no DB), the news list is simply empty and the UI
    // shows its empty state. No error is surfaced to the user.
    final String? cachedJson = prefs.getString(_cacheKey);
    final List<NewsItem> cachedItems = cachedJson != null ? parseNews(cachedJson) : [];

    final savedIds = getSavedNewsIds(prefs);
    
    // Run Garbage Collection
    final allItemsRaw = <String, NewsItem>{};
    for (var item in cachedItems) { allItemsRaw[item.id] = item; }
    await _runGarbageCollection(prefs, allItemsRaw.values.toList());

    final news = mergeAndFilterNews(
      assetItems: const [],
      remoteItems: cachedItems,
      savedIds: savedIds,
      deviceCountry: deviceCountryCode(),
    );

    // Read Global App Installation Baseline
    final installTimeMs = prefs.getInt('app_install_time') ?? 0;
    final installTime = DateTime.fromMillisecondsSinceEpoch(installTimeMs);

    // 4. Calculate Unseen Count & Notifications
    final hasEverSeen = prefs.getBool(_hasEverSeenKey) ?? false;
    if (!hasEverSeen) {
      unseenCountNotifier.value = 0;
    } else {
      final seenIds = prefs.getStringList(_seenKey) ?? [];
      final unseenItems = news.where((item) => !seenIds.contains(item.id)).toList();
      unseenCountNotifier.value = unseenItems.length;

      // Handle Push Notifications for unseen items
      final notifiedIds = prefs.getStringList('news_notified_ids') ?? [];
      
      List<String> newlyNotified = [];
      // Cap notifications per sync to avoid flooding the user when the
      // app first syncs a large backlog of unseen items.
      const int maxNotificationsPerBatch = 3;
      for (final item in unseenItems) {
        if (newlyNotified.length >= maxNotificationsPerBatch) break;
        // PUSH RULE: The app must have been installed BEFORE the news was published.
        final isAfterInstall = !item.publishDate.isBefore(installTime);
        
        if (item.sendNotification && !notifiedIds.contains(item.id) && isAfterInstall) {
          try {
            if (newlyNotified.isNotEmpty) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
            await NotificationService.showNewsNotification(item);
            newlyNotified.add(item.id);
          } catch (e) {
            debugPrint('[NewsService] Failed to notify: $e');
          }
        }
      }
      
      if (newlyNotified.isNotEmpty) {
        notifiedIds.addAll(newlyNotified);
        await prefs.setStringList('news_notified_ids', notifiedIds);
      }
    }
    
    return news;
  }

  static const String _hiddenKey = 'news_hidden_ids';

  static Future<void> _runGarbageCollection(SharedPreferences prefs, List<NewsItem> allItems) async {
    final seenIds = prefs.getStringList(_seenKey) ?? [];
    final savedIds = getSavedNewsIds(prefs);
    final notifiedIds = prefs.getStringList('news_notified_ids') ?? [];
    final hiddenIds = prefs.getStringList(_hiddenKey) ?? [];

    final validItemIds = allItems.map((e) => e.id).toSet();
    final expiredIds = allItems.where((e) => e.isExpired).map((e) => e.id).toSet();

    bool shouldKeep(String id) {
      if (savedIds.contains(id)) return true; // Strictly conserve user saved items
      if (expiredIds.contains(id)) return false; // Clean expired
      if (!validItemIds.contains(id)) return false; // Clean ghost/dropped IDs
      return true;
    }

    final newSeenIds = seenIds.where(shouldKeep).toList();
    if (newSeenIds.length != seenIds.length) {
      await prefs.setStringList(_seenKey, newSeenIds);
    }
    
    final newNotifiedIds = notifiedIds.where(shouldKeep).toList();
    if (newNotifiedIds.length != notifiedIds.length) {
      await prefs.setStringList('news_notified_ids', newNotifiedIds);
    }

    // Prune hidden IDs the same way (previously this set grew unbounded —
    // every swipe-to-hide added an ID and nothing ever removed dead ones).
    // A hidden item that expired or no longer exists need not stay hidden.
    final newHiddenIds = hiddenIds.where(shouldKeep).toList();
    if (newHiddenIds.length != hiddenIds.length) {
      await prefs.setStringList(_hiddenKey, newHiddenIds);
    }
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
  ///
  /// [deviceCountry] is the device-locale country (ISO alpha-2) used for
  /// country targeting. When null, only "exclude" rules that can't match an
  /// unknown country are skipped (see [NewsItem.isVisibleForCountry]). Saved
  /// items always bypass expiry but still respect country targeting — a user
  /// can't save an item they were never shown anyway.
  static List<NewsItem> mergeAndFilterNews({
    required List<NewsItem> assetItems,
    required List<NewsItem> remoteItems,
    required Set<String> savedIds,
    String? deviceCountry,
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
      // Country targeting (Option A — client-side display filter).
      if (!item.isVisibleForCountry(deviceCountry)) return false;
      return !item.isExpired || savedIds.contains(item.id);
    }).toList();

    news.sort((a, b) {
      if (a.isFeatured && !b.isFeatured) return -1;
      if (!a.isFeatured && b.isFeatured) return 1;
      return b.publishDate.compareTo(a.publishDate);
    });

    return news;
  }

  /// Country (ISO 3166-1 alpha-2, uppercase) used for news country targeting.
  ///
  /// Prefers the PHYSICAL country resolved from the user's GPS during
  /// prayer-time setup (location permission already granted), because the
  /// device locale only reflects the chosen UI language — an English-set phone
  /// in France reports `US`, which would mis-target news. Falls back to the
  /// locale country when location was never resolved (prayer times not set up).
  static String deviceCountryCode() {
    final fromLocation = PreferencesService.getLocationCountryCode();
    if (fromLocation.isNotEmpty) return fromLocation;
    final cc = ui.PlatformDispatcher.instance.locale.countryCode;
    return (cc ?? '').trim().toUpperCase();
  }

  static Future<void> _fetchRemote(SharedPreferences prefs) async {
    // Supabase is the ONLY remote source. When it isn't linked/ready, or
    // returns no usable data, we leave the existing cache untouched so the
    // last-known news keeps showing. No JSON-URL fetch is performed.
    if (SupabaseConfig.isReady) {
      final jsonStr = await _fetchFromSupabase();
      if (jsonStr != null) {
        await prefs.setString(_cacheKey, jsonStr);
        await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
        if (kDebugMode) debugPrint('[NewsService] Supabase fetch successful');
        return;
      }
      if (kDebugMode) {
        debugPrint('[NewsService] Supabase unavailable/empty; keeping cache');
      }
    }
  }

  /// Queries the Supabase `news_items` table and normalises rows back into the
  /// legacy `{ "news": [...] }` JSON string consumed by [parseNews]. Returns
  /// null on any error OR when the table is empty, so the caller keeps the
  /// existing cache instead of overwriting it with an empty set.
  ///
  /// RLS already restricts anon reads to published, in-validity-window rows
  /// (see migration 0002); we still request a generous window and let the
  /// existing expiry filter in [mergeAndFilterNews] do the final pass so saved
  /// items keep working exactly as before.
  static Future<String?> _fetchFromSupabase() async {
    try {
      final rows = await SupabaseConfig.client
          .from(_newsTable)
          .select()
          .order('publish_date', ascending: false);

      final list = (rows as List)
          .map((r) => _rowToLegacyJson(r as Map<String, dynamic>))
          .toList();
      // DB reachable but empty → return null so the caller preserves the
      // current cache rather than blanking it.
      if (list.isEmpty) {
        if (kDebugMode) {
          debugPrint('[NewsService] Supabase returned 0 rows; keeping cache');
        }
        return null;
      }
      return json.encode({'news': list});
    } catch (e) {
      if (kDebugMode) debugPrint('[NewsService] _fetchFromSupabase error: $e');
      return null;
    }
  }

  /// Maps a `news_items` DB row to the exact key shape `NewsItem.fromJson`
  /// expects. `fromJson` reads a MIX of camelCase (`mediaUrl`, `sourceUrl`,
  /// `publishDate`, `validUntil`) and snake/other (`category_ar`,
  /// `target_languages`, `featured`/`is_featured`, `push`) — so we translate
  /// the snake_case DB columns precisely to those keys.
  static Map<String, dynamic> _rowToLegacyJson(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'type': row['type'],
      'mediaUrl': row['media_url'],
      'sourceUrl': row['source_url'],
      'publishDate': row['publish_date'],
      'validUntil': row['valid_until'],
      'language': row['language'],
      'category_ar': row['category_ar'],
      'category_en': row['category_en'],
      'category_fr': row['category_fr'],
      'target_languages': row['target_languages'],
      'target_countries': row['target_countries'],
      'excluded_countries': row['excluded_countries'],
      'is_featured': row['is_featured'],
      'push': row['send_notification'],
    };
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
