import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'models/news_item.dart';
import 'services/news_service.dart';
import 'widgets/modern_ui.dart';
import 'widgets/news_card.dart';

class NewsNotificationsScreen extends StatefulWidget {
  const NewsNotificationsScreen({super.key});

  @override
  State<NewsNotificationsScreen> createState() => _NewsNotificationsScreenState();
}

class _NewsNotificationsScreenState extends State<NewsNotificationsScreen> {
  List<NewsItem> _allNews = [];
  Set<String> _savedIds = {};
  Set<String> _newIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool isManual = false}) async {
    if (!isManual) setState(() => _isLoading = true);
    try {
      final news = await NewsService.getNews(forceRefresh: isManual);
      final prefs = await SharedPreferences.getInstance();
      final savedIds = NewsService.getSavedNewsIds(prefs);
      final seenIds = NewsService.getSeenNewsIds(prefs);
      
      if (mounted) {
        setState(() {
          _allNews = news;
          _savedIds = savedIds;
          _newIds = news.map((n) => n.id).where((id) => !seenIds.contains(id)).toSet();
          _isLoading = false;
        });
        
        // Mark as seen after loading
        if (news.isNotEmpty) {
          NewsService.markAllAsSeen(news.map((n) => n.id).toList());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSave(String id) async {
    final isSaved = await NewsService.toggleSaveNews(id);
    setState(() {
      if (isSaved) {
        _savedIds.add(id);
      } else {
        _savedIds.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Filter saved news
    final savedNews = _allNews.where((n) => _savedIds.contains(n.id)).toList();

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
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildNewsList(_allNews, l10n),
                  _buildNewsList(savedNews, l10n, isSavedTab: true),
                ],
              ),
      ),
    );
  }

  Widget _buildNewsList(List<NewsItem> items, AppLocalizations l10n, {bool isSavedTab = false}) {
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
      onRefresh: () => _loadData(isManual: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return NewsCard(
            item: item,
            isSaved: _savedIds.contains(item.id),
            isNew: _newIds.contains(item.id),
            onToggleSave: () => _toggleSave(item.id),
          );
        },
      ),
    );
  }
}
