import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_item.dart';
import '../services/news_service.dart';
import 'app_state_providers.dart';

part 'news_provider.g.dart';

/// Provider for the list of NewsItems.
///
/// Codegen generates `newsProvider` (AsyncNotifierProvider) from this class
/// so existing callsites `ref.watch(newsProvider)` /
/// `ref.read(newsProvider.notifier).refresh()` continue to work unchanged.
@riverpod
class News extends _$News {
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

/// Provider for unread news IDs. Derived from [newsProvider].
///
/// Mirrors EXACTLY the visibility rules the News screen applies when building
/// its list, so the home badge can never count items the user won't actually
/// see. Country targeting is already applied upstream in `NewsService.getNews`;
/// here we additionally honour:
///   * language targeting (`isVisibleForLanguage` against the app language), and
///   * hidden (swipe-dismissed) items — unless the item is saved.
@riverpod
Future<Set<String>> unreadNewsIds(UnreadNewsIdsRef ref) async {
  final news = await ref.watch(newsProvider.future);
  final prefs = await SharedPreferences.getInstance();
  final seenIds = NewsService.getSeenNewsIds(prefs);

  // Reactive inputs so the badge updates on language change / hide / save.
  final lang = ref.watch(localeProvider).languageCode;
  final hiddenIds = ref.watch(hiddenNewsIdsProvider);
  final savedIds = ref.watch(savedNewsIdsProvider);

  bool isVisible(NewsItem item) {
    // Hidden items don't count, unless the user saved them (still reachable
    // in the Saved tab) — matches NewsNotificationsScreen's `visibleNews`.
    if (hiddenIds.contains(item.id) && !savedIds.contains(item.id)) return false;
    return item.isVisibleForLanguage(lang);
  }

  return news
      .where(isVisible)
      .map((item) => item.id)
      .where((id) => !seenIds.contains(id))
      .toSet();
}

/// Provider for saved (bookmarked) news IDs.
///
/// Replaces the legacy `SavedNewsNotifier extends StateNotifier<Set<String>>`
/// with a codegen'd NotifierProvider. Same exposed API: state is a plain
/// `Set<String>` and callers use `ref.read(savedNewsIdsProvider.notifier)
/// .toggleSave(id)`.
@riverpod
class SavedNewsIds extends _$SavedNewsIds {
  @override
  Set<String> build() {
    // Fire-and-forget disk load; initial state is empty until the future
    // completes and sets `state`, matching the pre-migration behaviour.
    _loadSavedIds();
    return <String>{};
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

/// Provider for the number of unseen news items. Derived from
/// [unreadNewsIdsProvider].
@riverpod
int unseenNewsCount(UnseenNewsCountRef ref) {
  final unreadIdsAsync = ref.watch(unreadNewsIdsProvider);
  return unreadIdsAsync.maybeWhen(
    data: (ids) => ids.length,
    orElse: () => 0,
  );
}

/// Provider for hidden (swipe-to-dismiss) news IDs.
///
/// Replaces the legacy `HiddenNewsNotifier extends StateNotifier<Set<String>>`
/// with a codegen'd NotifierProvider. Same exposed API.
@riverpod
class HiddenNewsIds extends _$HiddenNewsIds {
  @override
  Set<String> build() {
    _loadHiddenIds();
    return <String>{};
  }

  Future<void> _loadHiddenIds() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList('news_hidden_ids') ?? []).toSet();
  }

  Future<void> hide(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final newSet = {...state, id};
    await prefs.setStringList('news_hidden_ids', newSet.toList());
    state = newSet;
  }
}
