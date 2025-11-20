import 'package:flutter/material.dart';
import 'package:qurani/services/memorization_stats_service.dart';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'responsive_config.dart';

class MemorizationStatsScreen extends StatefulWidget {
  const MemorizationStatsScreen({super.key});

  @override
  State<MemorizationStatsScreen> createState() => _MemorizationStatsScreenState();
}

class _MemorizationStatsScreenState extends State<MemorizationStatsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  List<_AggRow> _surahRows = const [];
  List<_AggRow> _juzRows = const [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await MemorizationStatsService.instance.getStatistics();

    // Use persisted per-surah and per-juz aggregations
    final Map<String, dynamic> surahAggRaw = (stats['surahAgg'] as Map?)?.map((k,v)=>MapEntry(k.toString(), v)) ?? {};
    final Map<String, dynamic> juzAggRaw = (stats['juzAgg'] as Map?)?.map((k,v)=>MapEntry(k.toString(), v)) ?? {};

    final Map<int, int> surahCount = { for (int i=1;i<=114;i++) i: (surahAggRaw['$i'] is Map ? ((surahAggRaw['$i'] as Map)['count'] as int? ?? 0) : 0) };
    final Map<int, int> surahCorrect = { for (int i=1;i<=114;i++) i: (surahAggRaw['$i'] is Map ? ((surahAggRaw['$i'] as Map)['correct'] as int? ?? 0) : 0) };
    final Map<int, int> surahTotal = { for (int i=1;i<=114;i++) i: (surahAggRaw['$i'] is Map ? ((surahAggRaw['$i'] as Map)['total'] as int? ?? 0) : 0) };

    final Map<int, int> juzCount = { for (int i=1;i<=30;i++) i: (juzAggRaw['$i'] is Map ? ((juzAggRaw['$i'] as Map)['count'] as int? ?? 0) : 0) };
    final Map<int, int> juzCorrect = { for (int i=1;i<=30;i++) i: (juzAggRaw['$i'] is Map ? ((juzAggRaw['$i'] as Map)['correct'] as int? ?? 0) : 0) };
    final Map<int, int> juzTotal = { for (int i=1;i<=30;i++) i: (juzAggRaw['$i'] is Map ? ((juzAggRaw['$i'] as Map)['total'] as int? ?? 0) : 0) };
    List<_AggRow> buildRows(int maxId, Map<int,int> countMap, Map<int,int> correctMap, Map<int,int> totalMap) {
      final rows = <_AggRow>[];
      for (int id=1; id<=maxId; id++) {
        final c = countMap[id] ?? 0;
        final corr = correctMap[id] ?? 0;
        final tot = totalMap[id] ?? 0;
        final pct = tot > 0 ? ((corr / tot) * 100).round() : 0;
        rows.add(_AggRow(id: id, count: c, percent: pct));
      }
      rows.sort((a,b){
        final byPct = b.percent.compareTo(a.percent);
        if (byPct != 0) return byPct;
        return a.id.compareTo(b.id);
      });
      return rows;
    }
    List<_AggRow> surahRows = buildRows(114, surahCount, surahCorrect, surahTotal);
    List<_AggRow> juzRows = buildRows(30, juzCount, juzCorrect, juzTotal);

    // Already sorted above
    if (mounted) {
      setState(() {
        _stats = stats;
        _surahRows = surahRows;
        _juzRows = juzRows;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearStats() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإحصائيات'),
        content: const Text('هل أنت متأكد أنك تريد حذف جميع الإحصائيات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await MemorizationStatsService.instance.clearAllStats();
      if (mounted) {
        await _loadStats();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات الاختبارات'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف الإحصائيات',
            onPressed: _clearStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('لا توجد إحصائيات'))
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: ListView(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    children: [
                      // Total Score Card
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                'العلامات المتراكمة',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_stats!['totalScore']}',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tests count only (no header, no average)
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildStatRow(
                            'عدد الاختبارات',
                            '${_stats!['totalTests']}',
                            theme,
                            colorScheme,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Aggregated tabs: Surahs vs Juz
                      DefaultTabController(
                        length: 2,
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                const TabBar(
                                  tabs: [
                                    Tab(text: 'سور'),
                                    Tab(text: 'أجزاء'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 360,
                                  child: TabBarView(
                                    children: [
                                      _buildSurahAggList(theme, colorScheme),
                                      _buildJuzAggList(theme, colorScheme),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Surah Mastery Card
                      if ((_stats!['surahMastery'] as Map<int, int>).isNotEmpty) ...[
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'نسبة الإتقان لكل سورة',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<List<SurahMeta>>(
                                  future: QuranRepository.instance.loadAllSurahs(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    final mastery = _stats!['surahMastery'] as Map<int, int>;
                                    final masteryList = mastery.entries.toList()
                                      ..sort((a, b) => b.value.compareTo(a.value));
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: masteryList.length,
                                      itemBuilder: (context, index) {
                                        final entry = masteryList[index];
                                        final surah = snapshot.data!.firstWhere(
                                          (s) => s.number == entry.key,
                                          orElse: () => SurahMeta(
                                            number: entry.key,
                                            name: 'سورة $entry.key',
                                            englishName: 'Surah $entry.key',
                                            englishNameTranslation: '',
                                            revelationType: '',
                                          ),
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  surah.name,
                                                  textDirection: TextDirection.rtl,
                                                  style: theme.textTheme.bodyMedium,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                '${entry.value}%',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _getPercentageColor(
                                                    entry.value,
                                                    colorScheme,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Recent Tests Card
                      if ((_stats!['recentTests'] as List).isNotEmpty) ...[
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الاختبارات الأخيرة',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: (_stats!['recentTests'] as List).length,
                                  itemBuilder: (context, index) {
                                    final test = (_stats!['recentTests'] as List)[index];
                                    final timestamp = DateTime.fromMillisecondsSinceEpoch(
                                      test['timestamp'] as int,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  test['surahNumber'] != null
                                                      ? 'سورة ${test['surahNumber']}'
                                                      : 'جزء ${test['juzNumber']}',
                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${test['correctAnswers']} / ${test['totalQuestions']} • ${test['percentage']}% • ${test['score']} علامة',
                                                  style: theme.textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatDate(timestamp),
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatRow(String label, String value, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Color _getPercentageColor(int percentage, ColorScheme colorScheme) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSurahAggList(ThemeData theme, ColorScheme colorScheme) {
    return FutureBuilder<List<SurahMeta>>(
      future: QuranRepository.instance.loadAllSurahs(),
      builder: (context, snapshot) {
        final rows = _surahRows;
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final surahs = snapshot.data!;
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final r = rows[index];
              final meta = surahs.firstWhere(
                (s) => s.number == r.id,
                orElse: () => SurahMeta(
                  number: r.id,
                  name: 'سورة ${r.id}',
                  englishName: '',
                  englishNameTranslation: '',
                  revelationType: '',
                ),
              );
            return ListTile(
              title: Text(meta.name, textDirection: TextDirection.rtl),
              trailing: Text('${r.count} ×  |  ${r.percent}%', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            );
          },
        );
      },
    );
  }

  Widget _buildJuzAggList(ThemeData theme, ColorScheme colorScheme) {
    final rows = _juzRows;
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final r = rows[index];
        return ListTile(
          title: Text('جزء ${r.id}', textDirection: TextDirection.rtl),
          trailing: Text('${r.count} ×  |  ${r.percent}%', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'منذ ${diff.inMinutes} دقيقة';
      }
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _AggRow {
  final int id;
  final int count;
  final int percent;
  const _AggRow({required this.id, required this.count, required this.percent});
}
