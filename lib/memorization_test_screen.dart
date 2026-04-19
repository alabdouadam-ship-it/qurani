import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/memorization_test_service.dart';
import 'package:qurani/services/surah_service.dart';
import 'package:qurani/util/text_normalizer.dart';
import 'responsive_config.dart';
import 'models/surah.dart';
import 'test_questions_screen.dart';
import 'memorization_stats_screen.dart';

import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/widgets/empty_state_view.dart';
import 'package:qurani/widgets/modern_ui.dart';

class MemorizationTestScreen extends StatefulWidget {
  const MemorizationTestScreen({super.key});

  @override
  State<MemorizationTestScreen> createState() => _MemorizationTestScreenState();
}

class _MemorizationTestScreenState extends State<MemorizationTestScreen> {
  final Set<int> _selectedSurahs = {};
  String _surahQuery = '';
  final Set<int> _selectedJuzs = {};
  bool _isSurahMode = true;
  bool _isGenerating = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  Future<List<Surah>>? _surahsFuture;
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _surahQuery);
    _searchFocus = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSurah(Surah surah) {
    setState(() {
      if (_selectedSurahs.contains(surah.order)) {
        _selectedSurahs.remove(surah.order);
      } else {
        _selectedSurahs.add(surah.order);
      }
      _selectedJuzs.clear();
      _isSurahMode = true;
    });
  }

  void _toggleJuz(int juz) {
    setState(() {
      if (_selectedJuzs.contains(juz)) {
        _selectedJuzs.remove(juz);
      } else {
        _selectedJuzs.add(juz);
      }
      _selectedSurahs.clear();
      _isSurahMode = false;
    });
  }

  Widget _buildSurahSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);

    final currentLocale = Localizations.localeOf(context);
    if (_surahsFuture == null || _lastLocale?.languageCode != currentLocale.languageCode) {
      _lastLocale = currentLocale;
      _surahsFuture = SurahService.getLocalizedSurahs(currentLocale.languageCode);
    }

    return FutureBuilder<List<Surah>>(
      future: _surahsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final l10n = AppLocalizations.of(context)!;
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(l10n.noSurahsAvailable));
        }

        if (snapshot.hasError) {
          debugPrint('[MemorizationTestScreen] load surahs error: ${snapshot.error}');
          return EmptyStateView(
            icon: Icons.error_outline,
            iconColor: Theme.of(context).colorScheme.error,
            title: l10n.unknownError,
            primaryAction: EmptyStateAction(
              label: l10n.retry,
              icon: Icons.refresh,
              onPressed: () {
                setState(() {
                  _surahsFuture = SurahService.getLocalizedSurahs(
                    Localizations.localeOf(context).languageCode,
                  );
                });
              },
            ),
          );
        }

        final allSurahs = snapshot.data!;
        final q = TextNormalizer.normalize(_surahQuery);
        final surahs = q.isEmpty
            ? allSurahs
            : allSurahs.where((s) => TextNormalizer.normalize(s.name).contains(q)).toList();

        final width = MediaQuery.of(context).size.width;
        int crossAxisCount;
        if (width >= 1200) {
          crossAxisCount = 6;
        } else if (width >= 800) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 2; // Mobile / Small screens
        }

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isSmallScreen ? 12 : 16, 12, isSmallScreen ? 12 : 16, 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                onChanged: (v) => setState(() => _surahQuery = v),
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
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: crossAxisCount <= 3 ? 2.5 : 2.0,
                ),
                itemCount: surahs.length,
                itemBuilder: (context, index) {
                  final surah = surahs[index];
                  final isSelected = _selectedSurahs.contains(surah.order);

                  return InkWell(
                    onTap: () => _toggleSurah(surah),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surface,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withAlpha((255 * 0.3).round()),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          surah.name,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
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

  Future<void> _startTest() async {
    if (_selectedSurahs.isEmpty && _selectedJuzs.isEmpty) return;
    setState(() => _isGenerating = true);

    final l10n = AppLocalizations.of(context)!;
    try {
      final questions = await MemorizationTestService.instance.generateQuestions(
        l10n: l10n,
        surahNumbers: _selectedSurahs.isEmpty ? null : _selectedSurahs.toList(),
        juzNumbers: _selectedJuzs.isEmpty ? null : _selectedJuzs.toList(),
      );

      if (!mounted) return;

      if (questions.isEmpty) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noQuestionsAvailable)),
        );
        setState(() => _isGenerating = false);
        return;
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TestQuestionsScreen(
            questions: questions,
            surahNumbers: _selectedSurahs.isEmpty ? null : _selectedSurahs.toList(),

            juzNumber: _selectedJuzs.isNotEmpty ? _selectedJuzs.first : null, // Providing first Juz just for stats compatibility if needed, though strictly we should update stats too if it takes single int
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.testErrorGeneric(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return ModernPageScaffold(
      title: l10n.memorizationTest,
      icon: Icons.quiz_rounded,
      subtitle: l10n.memorizationTestDescription,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          tooltip: l10n.settings,
          onPressed: () => _showSettingsDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded),
          tooltip: l10n.statisticsTitle,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MemorizationStatsScreen(),
              ),
            );
          },
        ),
      ],
      body: Column(
        children: [
          ModernSurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => setState(() {
                      _isSurahMode = true;
                      _selectedJuzs.clear();
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isSurahMode
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: _isSurahMode
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    child: Text(l10n.surah),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => setState(() {
                      _isSurahMode = false;
                      _selectedSurahs.clear();
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: !_isSurahMode
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: !_isSurahMode
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    child: Text(l10n.juzLabel),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isSurahMode
                ? _buildSurahSelector()
                : _buildJuzSelector(),
          ),

          if (_selectedSurahs.isNotEmpty || _selectedJuzs.isNotEmpty)
            SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.05).round()),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _isGenerating ? null : _startTest,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l10n.startTestButton,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJuzSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    final l10n = AppLocalizations.of(context)!;
    
    // Responsive grid logic for Juz selector
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (width >= 1200) {
      crossAxisCount = 6;
    } else if (width >= 800) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 2; // Mobile
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: crossAxisCount <= 3 ? 2.5 : 2.0,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        final juz = index + 1;
        final isSelected = _selectedJuzs.contains(juz);
        String juzLabel;
        if (juz == 29) {
          juzLabel = l10n.juzTabarak;
        } else if (juz == 30) {
          juzLabel = l10n.juzAmma;
        } else {
          juzLabel = '${l10n.juzLabel} $juz';
        }
        return InkWell(
          onTap: () => _toggleJuz(juz),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surface,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withAlpha((255 * 0.3).round()),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                juzLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final currentLimit = PreferencesService.getMemorizationQuestionLimit();
    int? selectedLimit = currentLimit;

    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.testSettingsTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(l10n.maxQuestionsLabel),
                   const SizedBox(height: 8),
                   DropdownButton<int>(
                     value: selectedLimit,
                     isExpanded: true,
                     items: [10, 15, 20, 25, 30, 40, 50, 75, 100, 200].map((int value) {
                       return DropdownMenuItem<int>(
                         value: value,
                         child: Text(value.toString()),
                       );
                     }).toList(),
                     onChanged: (int? newValue) {
                       if (newValue != null) {
                         setState(() {
                           selectedLimit = newValue;
                         });
                       }
                     },
                   ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedLimit != null) {
                      PreferencesService.saveMemorizationQuestionLimit(selectedLimit!);
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }
}