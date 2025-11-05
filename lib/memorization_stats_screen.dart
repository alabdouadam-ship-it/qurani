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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await MemorizationStatsService.instance.getStatistics();
    if (mounted) {
      setState(() {
        _stats = stats;
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
    final l10n = AppLocalizations.of(context)!;
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
                      // General Stats Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إحصائيات عامة',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildStatRow(
                                'عدد الاختبارات',
                                '${_stats!['totalTests']}',
                                theme,
                                colorScheme,
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                'متوسط نسبة الإتقان',
                                '${_stats!['averagePercentage']}%',
                                theme,
                                colorScheme,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Last & Best Results Cards
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('آخر النتائج (سور)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildLastMapList(_stats!['lastSurah'] as Map?, isSurah: true, theme: theme, colorScheme: colorScheme),
                              const SizedBox(height: 16),
                              Text('أفضل النتائج (سور)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildLastMapList(_stats!['bestSurah'] as Map?, isSurah: true, theme: theme, colorScheme: colorScheme),
                              const SizedBox(height: 16),
                              Text('آخر النتائج (أجزاء)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildLastMapList(_stats!['lastJuz'] as Map?, isSurah: false, theme: theme, colorScheme: colorScheme),
                              const SizedBox(height: 16),
                              Text('أفضل النتائج (أجزاء)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildLastMapList(_stats!['bestJuz'] as Map?, isSurah: false, theme: theme, colorScheme: colorScheme),
                            ],
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

  Widget _buildLastMapList(Map? map, {required bool isSurah, required ThemeData theme, required ColorScheme colorScheme}) {
    if (map == null || map.isEmpty) return const Text('لا توجد بيانات');
    final entries = (map as Map).entries.toList()
      ..sort((a, b) => (b.value['timestamp'] as int).compareTo(a.value['timestamp'] as int));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length.clamp(0, 10),
      itemBuilder: (context, index) {
        final e = entries[index];
        final keyNum = int.tryParse(e.key.toString()) ?? 0;
        final perc = (e.value['percentage'] as int?) ?? 0;
        final ts = (e.value['timestamp'] as int?) ?? 0;
        final when = DateTime.fromMillisecondsSinceEpoch(ts);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isSurah ? 'سورة $keyNum' : 'جزء $keyNum',
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '$perc%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getPercentageColor(perc, colorScheme),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDate(when),
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
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
