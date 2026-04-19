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
  double _fontScale = 1.0;

  void _toggleFontScale() {
    setState(() {
      if (_fontScale == 1.0) {
        _fontScale = 1.25;
      } else if (_fontScale == 1.25) {
        _fontScale = 1.5;
      } else {
        _fontScale = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentLang = Localizations.localeOf(context).languageCode;
    
    final newsAsync = ref.watch(newsProvider);
    final savedIds = ref.watch(savedNewsIdsProvider);
    final unreadIdsAsync = ref.watch(unreadNewsIdsProvider);
    final hiddenIds = ref.watch(hiddenNewsIdsProvider);

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

        final unreadIds = unreadIdsAsync.value ?? {};

        // Strip hidden and language-incompatible elements
        final visibleNews = news.where((n) {
          if (hiddenIds.contains(n.id) && !savedIds.contains(n.id)) return false; // Allowed if saved
          return n.isVisibleForLanguage(currentLang);
        }).toList();

        final savedNews = visibleNews.where((n) => savedIds.contains(n.id)).toList();

        // Dynamically build categories
        final uniqueCategories = <String>[];
        for (var n in visibleNews) {
          final locCat = n.localizedCategory(currentLang);
          if (locCat != null && locCat.isNotEmpty && !uniqueCategories.contains(locCat)) {
            uniqueCategories.add(locCat);
          }
        }

        return DefaultTabController(
          length: 2 + uniqueCategories.length,
          child: ModernPageScaffold(
            title: l10n.newsAndNotifications,
            icon: Icons.notifications_active_outlined,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.text_increase,
                  color: _fontScale > 1.0 ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
                tooltip: 'Text Size',
                onPressed: _toggleFontScale,
              ),
            ],
            appBarBottom: TabBar(
              isScrollable: uniqueCategories.isNotEmpty,
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: [
                Tab(text: l10n.newsTabAll),
                Tab(text: l10n.newsTabSaved),
                ...uniqueCategories.map((c) => Tab(text: c)),
              ],
            ),
            body: TabBarView(
              children: [
                _PaginatedNewsList(
                  items: visibleNews, 
                  savedIds: savedIds, 
                  unreadIds: unreadIds, 
                  l10n: l10n,
                  fontScale: _fontScale,
                ),
                _PaginatedNewsList(
                  items: savedNews, 
                  savedIds: savedIds, 
                  unreadIds: unreadIds, 
                  l10n: l10n, 
                  isSavedTab: true,
                  fontScale: _fontScale,
                ),
                ...uniqueCategories.map((c) {
                  final catNews = visibleNews.where((n) => n.localizedCategory(currentLang) == c).toList();
                  return _PaginatedNewsList(
                    items: catNews,
                    savedIds: savedIds,
                    unreadIds: unreadIds,
                    l10n: l10n,
                    fontScale: _fontScale,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaginatedNewsList extends ConsumerStatefulWidget {
  final List<NewsItem> items;
  final Set<String> savedIds;
  final Set<String> unreadIds;
  final AppLocalizations l10n;
  final bool isSavedTab;
  final double fontScale;

  const _PaginatedNewsList({
    required this.items,
    required this.savedIds,
    required this.unreadIds,
    required this.l10n,
    this.isSavedTab = false,
    this.fontScale = 1.0,
  });

  @override
  ConsumerState<_PaginatedNewsList> createState() => _PaginatedNewsListState();
}

class _PaginatedNewsListState extends ConsumerState<_PaginatedNewsList> {
  late ScrollController _scrollController;
  int _currentLimit = 10;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_currentLimit < widget.items.length) {
        setState(() {
          _currentLimit += 10;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isSavedTab ? Icons.bookmark_outline : Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isSavedTab ? widget.l10n.noSavedNews : widget.l10n.noNewsAtTheMoment,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final displayedItems = widget.items.take(_currentLimit).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(newsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: displayedItems.length + (_currentLimit < widget.items.length ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displayedItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = displayedItems[index];
          return NewsCard(
            item: item,
            isSaved: widget.savedIds.contains(item.id),
            isNew: widget.unreadIds.contains(item.id),
            onToggleSave: () => ref.read(savedNewsIdsProvider.notifier).toggleSave(item.id),
            onHide: () => ref.read(hiddenNewsIdsProvider.notifier).hide(item.id),
            fontScale: widget.fontScale,
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
