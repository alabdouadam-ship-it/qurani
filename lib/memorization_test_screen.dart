import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/memorization_test_service.dart';
import 'package:qurani/services/surah_service.dart';
import 'package:qurani/util/text_normalizer.dart';
import 'responsive_config.dart';
import 'models/surah.dart';
import 'test_questions_screen.dart';
import 'memorization_stats_screen.dart';

class MemorizationTestScreen extends StatefulWidget {
  const MemorizationTestScreen({super.key});

  @override
  State<MemorizationTestScreen> createState() => _MemorizationTestScreenState();
}

class _MemorizationTestScreenState extends State<MemorizationTestScreen> {
  final Set<int> _selectedSurahs = {};
  String _surahQuery = '';
  int? _selectedJuz;
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
      _selectedJuz = null;
      _isSurahMode = true;
    });
  }

  Future<void> _selectJuz(int juz) async {
    setState(() {
      _selectedJuz = juz;
      _selectedSurahs.clear();
      _isSurahMode = false;
    });
  }

  Widget _buildSurahSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    
    // Initialize/cached future to avoid rebuilding and losing focus
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
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد سور'));
        }
        
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
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }

        final allSurahs = snapshot.data!;
        final q = TextNormalizer.normalize(_surahQuery);
        final surahs = q.isEmpty
            ? allSurahs
            : allSurahs.where((s) => TextNormalizer.normalize(s.name).contains(q)).toList();
        
        // Responsive grid logic mirroring SurahGrid
        // Use screen width to determine columns, regardless of platform
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
                textAlign: TextAlign.right,
                onChanged: (v) => setState(() => _surahQuery = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'ابحث عن سورة...',
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
    if (_selectedSurahs.isEmpty && _selectedJuz == null) return;
    setState(() => _isGenerating = true);

    try {
      final questions = await MemorizationTestService.instance.generateQuestions(
        surahNumbers: _selectedSurahs.isEmpty ? null : _selectedSurahs.toList(),
        juzNumber: _selectedJuz,
      );

      if (!mounted) return;

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد أسئلة متاحة')),
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
            juzNumber: _selectedJuz,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.memorizationTest,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'إحصائيات',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MemorizationStatsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: colorScheme.primaryContainer.withAlpha((255 * 0.3).round()),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => setState(() {
                      _isSurahMode = true;
                      _selectedJuz = null;
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
          Expanded(
            child: _isSurahMode
                ? _buildSurahSelector()
                : _buildJuzSelector(),
          ),
          if (_selectedSurahs.isNotEmpty || _selectedJuz != null)
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
                      : const Text(
                          'بدء الاختبار',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
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
        final isSelected = _selectedJuz == juz;
        String juzLabel;
        if (juz == 29) {
          juzLabel = 'جزء تبارك';
        } else if (juz == 30) {
          juzLabel = 'جزء عم';
        } else {
          juzLabel = '${l10n.juzLabel} $juz';
        }
        return InkWell(
          onTap: () => _selectJuz(juz),
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
}