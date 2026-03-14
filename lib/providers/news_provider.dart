import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';

/// Provider for the list of NewsItems
final newsProvider = AsyncNotifierProvider<NewsNotifier, List<NewsItem>>(() {
  return NewsNotifier();
});

class NewsNotifier extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    return _fetchNews(forceRefresh: false);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchNews(forceRefresh: true));
  }

  Future<List<NewsItem>> _fetchNews({required bool forceRefresh}) async {
    // getNews handles asset loading and remote fetching internally
    return await NewsService.getNews(forceRefresh: forceRefresh);
  }
}

/// Provider for unread news IDs
final unreadNewsIdsProvider = FutureProvider<Set<String>>((ref) async {
  final news = await ref.watch(newsProvider.future);
  final prefs = await SharedPreferences.getInstance();
  final seenIds = NewsService.getSeenNewsIds(prefs);
  
  return news
      .map((item) => item.id)
      .where((id) => !seenIds.contains(id))
      .toSet();
});

/// Provider for saved news IDs
final savedNewsIdsProvider = StateNotifierProvider<SavedNewsNotifier, Set<String>>((ref) {
  return SavedNewsNotifier();
});

class SavedNewsNotifier extends StateNotifier<Set<String>> {
  SavedNewsNotifier() : super({}) {
    _loadSavedIds();
  }

  Future<void> _loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    state = NewsService.getSavedNewsIds(prefs);
  }

  Future<void> toggleSave(String id) async {
    final isSaved = await NewsService.toggleSaveNews(id);
    if (isSaved) {
      state = {...state, id};
    } else {
      state = state.where((item) => item != id).toSet();
    }
  }
}

/// Provider for the number of unseen news items
final unseenNewsCountProvider = Provider<int>((ref) {
  final unreadIdsAsync = ref.watch(unreadNewsIdsProvider);
  
  return unreadIdsAsync.maybeWhen(
    data: (ids) => ids.length,
    orElse: () => 0,
  );
});
