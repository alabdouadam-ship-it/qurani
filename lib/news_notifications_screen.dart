import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'models/news_item.dart';
import 'providers/news_provider.dart';
import 'services/news_service.dart';
import 'widgets/modern_ui.dart';
import 'widgets/news_card.dart';

class NewsNotificationsScreen extends ConsumerStatefulWidget {
  const NewsNotificationsScreen({super.key});

  @override
  ConsumerState<NewsNotificationsScreen> createState() => _NewsNotificationsScreenState();
}

class _NewsNotificationsScreenState extends ConsumerState<NewsNotificationsScreen> {

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    final newsAsync = ref.watch(newsProvider);
    final savedIds = ref.watch(savedNewsIdsProvider);
    final unreadIdsAsync = ref.watch(unreadNewsIdsProvider);

    // Filter news after loading
    return newsAsync.when(
      loading: () => ModernPageScaffold(
        title: l10n.newsAndNotifications,
        icon: Icons.notifications_active_outlined,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => ModernPageScaffold(
        title: l10n.newsAndNotifications,
        icon: Icons.notifications_active_outlined,
        body: Center(child: Text('Error: $err')),
      ),
      data: (news) {
        // Mark as seen when data is loaded (only for first time or refresh)
        if (news.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NewsNewsNotificationsLogic.markAsSeen(news);
          });
        }

        final savedNews = news.where((n) => savedIds.contains(n.id)).toList();
        final unreadIds = unreadIdsAsync.value ?? {};

        return DefaultTabController(
          length: 2,
          child: ModernPageScaffold(
            title: l10n.newsAndNotifications,
            icon: Icons.notifications_active_outlined,
            appBarBottom: TabBar(
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: [
                Tab(text: l10n.newsTabAll),
                Tab(text: l10n.newsTabSaved),
              ],
            ),
            body: TabBarView(
              children: [
                _buildNewsList(news, savedIds, unreadIds, l10n),
                _buildNewsList(savedNews, savedIds, unreadIds, l10n, isSavedTab: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewsList(List<NewsItem> items, Set<String> savedIds, Set<String> unreadIds, AppLocalizations l10n, {bool isSavedTab = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSavedTab ? Icons.bookmark_outline : Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              isSavedTab ? l10n.noSavedNews : l10n.noNewsAtTheMoment,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(newsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return NewsCard(
            item: item,
            isSaved: savedIds.contains(item.id),
            isNew: unreadIds.contains(item.id),
            onToggleSave: () => ref.read(savedNewsIdsProvider.notifier).toggleSave(item.id),
          );
        },
      ),
    );
  }
}

/// Helper class to avoid direct service calls in build
class NewsNewsNotificationsLogic {
  static void markAsSeen(List<NewsItem> news) {
    NewsService.markAllAsSeen(news.map((item) => item.id).toList());
  }
}
