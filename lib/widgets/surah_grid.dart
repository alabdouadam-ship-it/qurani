import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/surah.dart';
import '../services/preferences_service.dart';
import '../services/queue_service.dart';
import '../services/surah_service.dart';
import '../util/text_normalizer.dart';
import 'package:qurani/l10n/app_localizations.dart';

class SurahGrid extends StatefulWidget {
  final ValueChanged<Surah> onTapSurah;
  final EdgeInsets? padding;
  final bool showQueueActions;
  final bool allowHighlight;

  const SurahGrid({
    super.key,
    required this.onTapSurah,
    this.padding,
    this.showQueueActions = true,
    this.allowHighlight = false,
  });

  @override
  State<SurahGrid> createState() => _SurahGridState();
}

class _SurahGridState extends State<SurahGrid> {
  late Future<List<Surah>> _future;
  String _query = '';
  Set<int> _featuredSurahs = <int>{};
  final QueueService _queueService = QueueService();
  bool get _hasLongPressActions => widget.showQueueActions || widget.allowHighlight;


  void _showSurahOptions(BuildContext context, Surah surah) {
    if (!_hasLongPressActions) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final isCurrentlyFeatured = widget.allowHighlight && _featuredSurahs.contains(surah.order);
    final isCurrentlyInQueue = widget.showQueueActions ? _queueService.contains(surah.order) : false;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(l10n.listenQuran),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onTapSurah(surah);
                },
              ),
              if (widget.allowHighlight)
                ListTile(
                  leading: Icon(
                    isCurrentlyFeatured ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade600,
                  ),
                  title: Text(
                    isCurrentlyFeatured ? l10n.removeFeatureSurah : l10n.featureSurah,
                  ),
                  onTap: () async {
                    final navigator = Navigator.of(sheetContext);
                    final nowFeatured = await PreferencesService.toggleListenFeaturedSurah(surah.order);
                    if (!mounted) return;
                    setState(() {
                      if (nowFeatured) {
                        _featuredSurahs.add(surah.order);
                      } else {
                        _featuredSurahs.remove(surah.order);
                      }
                    });
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(nowFeatured ? l10n.surahFeatured : l10n.surahUnfeatured),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              if (widget.showQueueActions)
                ListTile(
                  leading: Icon(
                    isCurrentlyInQueue ? Icons.remove_circle : Icons.add_circle,
                  ),
                  title: Text(
                    isCurrentlyInQueue ? l10n.clearQueue : l10n.addToQueue,
                  ),
                  onTap: () {
                    if (isCurrentlyInQueue) {
                      _queueService.removeFromQueue(surah.order);
                    } else {
                      _queueService.addToQueue(surah.order);
                    }
                    if (mounted) {
                      setState(() {});
                    }
                    Navigator.pop(sheetContext);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          isCurrentlyInQueue ? l10n.clearQueue : l10n.addToQueue,
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    _future = SurahService.getLocalizedSurahs(lang);
    _featuredSurahs = widget.allowHighlight
        ? PreferencesService.getListenFeaturedSurahs()
        : <int>{};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    
    // Optimize for web
    int crossAxisCount;
    if (kIsWeb) {
      final width = size.width;
      if (width >= 1600) {
        crossAxisCount = 12;
      } else if (width >= 1200) {
        crossAxisCount = 10;
      } else if (width >= 900) {
        crossAxisCount = 8;
      } else if (width >= 600) {
        crossAxisCount = 4;
      } else {
        crossAxisCount = 2; // Mobile web
      }
    } else {
      crossAxisCount = size.width >= 768 ? 4 : 2;
    }
    
    return FutureBuilder<List<Surah>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading Surahs: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final surahs = snapshot.data!;
        final l10n = AppLocalizations.of(context)!;
        final q = TextNormalizer.normalize(_query);
        final filtered = q.isEmpty
            ? surahs
            : surahs.where((s) => TextNormalizer.normalize(s.name).contains(q)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.pleaseSelectSurah,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.searchSurah,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: widget.padding ?? const EdgeInsets.fromLTRB(12, 12, 12, 50),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: kIsWeb ? 8 : 12,
                  mainAxisSpacing: kIsWeb ? 8 : 12,
                  childAspectRatio: crossAxisCount <= 4 ? 1.8 : 3.0,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final surah = filtered[index];
                  final isFeatured = widget.allowHighlight && _featuredSurahs.contains(surah.order);
                  final isInQueue = widget.showQueueActions ? _queueService.contains(surah.order) : false;
                  final backgroundColor = isFeatured
                      ? Color.alphaBlend(
                          Colors.amber.withAlpha((255 * (theme.brightness == Brightness.dark ? 0.18 : 0.28)).round()),
                          color.surface,
                        )
                      : color.surface;
                  final borderColor =
                      isFeatured ? Colors.amber.shade600 : color.outline.withAlpha((255 * 0.3).round());
                  final boxShadow = isFeatured
                      ? [
                          BoxShadow(
                            color: Colors.amber.shade200
                                .withAlpha((255 * (theme.brightness == Brightness.dark ? 0.25 : 0.4)).round()),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null;

                  return InkWell(
                    onTap: () => widget.onTapSurah(surah),
                    onLongPress: _hasLongPressActions ? () => _showSurahOptions(context, surah) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: backgroundColor,
                        border: Border.all(color: borderColor, width: isFeatured ? 1.4 : 1.0),
                        boxShadow: boxShadow,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: kIsWeb ? 6 : 12,
                        vertical: kIsWeb ? 3 : 10,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.primary.withAlpha((255 * 0.1).round()),
                            foregroundColor: color.primary,
                            radius: kIsWeb ? 12 : 18,
                            child: Text(
                              '${surah.order}',
                              style: const TextStyle(fontSize: kIsWeb ? 10 : 14),
                            ),
                          ),
                          const SizedBox(width: kIsWeb ? 4 : 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  surah.name.replaceAll(RegExp(r'^سُورَةُ\s+'), ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: color.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: kIsWeb ? 11 : null,
                                  ),
                                ),
                                if (!kIsWeb || crossAxisCount <= 10) ...[
                                  const SizedBox(height: kIsWeb ? 1 : 4),
                                  Text(
                                    '${surah.totalVerses} ${l10n.verses}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: color.onSurface.withAlpha((255 * 0.6).round()),
                                      fontSize: kIsWeb ? 9 : null,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.showQueueActions && isInQueue)
                            Icon(
                              Icons.queue_music,
                              size: kIsWeb ? 12 : 18,
                              color: color.primary,
                            ),
                          if (isFeatured)
                            Padding(
                              padding: const EdgeInsets.only(left: kIsWeb ? 2 : 6),
                              child: Icon(
                                Icons.star,
                                size: kIsWeb ? 12 : 18,
                                color: Colors.amber.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}


