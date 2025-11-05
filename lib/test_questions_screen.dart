import 'package:flutter/material.dart';
import 'package:qurani/services/memorization_test_service.dart';
import 'package:qurani/services/memorization_stats_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'responsive_config.dart';

class TestQuestionsScreen extends StatefulWidget {
  const TestQuestionsScreen({
    super.key,
    required this.questions,
    this.surahNumbers,
    this.juzNumber,
  });

  final List<MemorizationQuestion> questions;
  final List<int>? surahNumbers;
  final int? juzNumber;

  @override
  State<TestQuestionsScreen> createState() => _TestQuestionsScreenState();
}

class _TestQuestionsScreenState extends State<TestQuestionsScreen> {
  int _currentIndex = 0;
  int? _selectedAnswer;
  final Map<int, int?> _answers = {};
  final Map<int, bool> _results = {};
  bool _isShowingResult = false;
  int _totalScore = 0;
  bool _isFinished = false;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _loadTotalScore();
  }

  Future<void> _loadTotalScore() async {
    final totalScore = await MemorizationStatsService.instance.getTotalScore();
    if (mounted) {
      setState(() {
        _totalScore = totalScore;
      });
    }
  }

  void _selectAnswer(int index) {
    if (_isShowingResult) return;
    setState(() => _selectedAnswer = index);
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || _isShowingResult) return;
    
    final question = widget.questions[_currentIndex];
    final isCorrect = _selectedAnswer == question.correctIndex;
    
    setState(() {
      _answers[_currentIndex] = _selectedAnswer;
      _results[_currentIndex] = isCorrect;
      _isShowingResult = true;
      _selectedAnswer = null;
    });
    
    // Wait based on answer correctness
    await Future.delayed(Duration(seconds: isCorrect ? 1 : 3));
    
    if (!mounted) return;
    
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = _answers[_currentIndex];
        _isShowingResult = false;
      });
    } else {
      _showResults();
    }
  }

  void _nextQuestion() {
    if (_isShowingResult) return;
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = _answers[_currentIndex];
      });
    } else {
      _showResults();
    }
  }

  void _previousQuestion() {
    if (_isShowingResult) return;
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _selectedAnswer = _answers[_currentIndex];
      });
    }
  }

  Future<void> _exitTest() async {
    if (_isFinished) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exitTestTitle),
        content: Text(l10n.exitTestConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.endLabel),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _showResults();
    }
  }

  Future<void> _showResults() async {
    if (_isFinished) return;
    _isFinished = true;
    final correct = _results.values.where((v) => v == true).length;
    final total = widget.questions.length;
    final percentage = (correct / total * 100).round();
    final score = correct * 10; // 10 points per correct answer
    int newTotalScore = _totalScore;
    try {
      // Save test result
      await MemorizationStatsService.instance.saveTestResult(
        surahNumber: widget.surahNumbers?.isNotEmpty == true ? widget.surahNumbers!.first : null,
        juzNumber: widget.juzNumber,
        correctAnswers: correct,
        totalQuestions: total,
        score: score,
      );
      // Reload total score
      newTotalScore = await MemorizationStatsService.instance.getTotalScore();
    } catch (_) {
      // Ignore saving errors and continue to show results
    }
    
    if (!mounted) return;
    String emoji;
    String headline;
    String sub;
    if (percentage >= 90) {
      emoji = '🌟';
      headline = 'ما شاء الله!';
      sub = 'إتقان رائع! استمر على هذا المستوى';
    } else if (percentage >= 75) {
      emoji = '👍';
      headline = 'أحسنت!';
      sub = 'نتيجة ممتازة، بضع مراجعات وستصل للكمال';
    } else if (percentage >= 50) {
      emoji = '🙂';
      headline = 'جيد!';
      sub = 'تابع المراجعة، التقدم واضح';
    } else {
      emoji = '💪';
      headline = 'لا بأس!';
      sub = 'المحاولة تصنع الفرق، أعد الاختبار بعد مراجعة الأخطاء';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(headline, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sub),
              const SizedBox(height: 12),
              // Current test results
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نتيجة الاختبار الحالي',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.correctAnswersLabel(correct, total)),
                    const SizedBox(height: 4),
                    Text(l10n.percentageLabel(percentage)),
                    const SizedBox(height: 4),
                    Text(l10n.earnedScoreLabel(score)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Total score
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.totalScoreLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$newTotalScore',
                      style: TextStyle(
                        fontSize: PreferencesService.getFontSize() + 2,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close results dialog
              // Navigate back to app root (home screen)
              Future.microtask(() {
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              });
            },
            child: Text(l10n.endLabel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close results
              Navigator.of(context).pop(); // Close test screen
            },
            child: Text(l10n.newTestLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.memorizationTest)),
        body: const Center(child: Text('لا توجد أسئلة')),
      );
    }

    final question = widget.questions[_currentIndex];
    final hasAnswered = _answers.containsKey(_currentIndex);
    final isCorrect = _results[_currentIndex] ?? false;
    final currentCorrect = _results.values.where((v) => v == true).length;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _exitTest();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${_currentIndex + 1} / ${widget.questions.length}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveConfig.getFontSize(context, 18),
            ),
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _exitTest,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green.shade300),
                    const SizedBox(width: 4),
                    Text(
                      '$currentCorrect',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.star, size: 18, color: Colors.amber.shade300),
                    const SizedBox(width: 4),
                    Text(
                      '$_totalScore',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: ResponsiveConfig.getPadding(context),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / widget.questions.length,
                  backgroundColor: colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                question.text,
                                textDirection: TextDirection.rtl,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: PreferencesService.getFontSize() + 4,
                                  fontWeight: FontWeight.bold,
                                  height: 1.9,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...question.options.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          final isSelected = _selectedAnswer == index;
                          final isCorrectOption = index == question.correctIndex;
                          final selectedIndex = _answers[_currentIndex];
                          Color? backgroundColor;
                          Color? textColor;

                          if (hasAnswered) {
                            if (isCorrectOption) {
                              backgroundColor = Colors.green.withOpacity(0.2);
                              textColor = Colors.green.shade700;
                            } else if (selectedIndex == index && !isCorrect) {
                              backgroundColor = Colors.red.withOpacity(0.2);
                              textColor = Colors.red.shade700;
                            }
                          } else if (isSelected) {
                            backgroundColor = colorScheme.primaryContainer.withOpacity(0.3);
                            textColor = colorScheme.onPrimaryContainer;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              elevation: isSelected ? 4 : 1,
                              color: backgroundColor,
                              child: InkWell(
                                onTap: hasAnswered || _isShowingResult ? null : () => _selectAnswer(index),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.surfaceVariant,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}', // 1, 2, 3, 4
                                            style: TextStyle(
                                              color: isSelected
                                                  ? colorScheme.onPrimary
                                                  : colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.bold,
                                              fontSize: PreferencesService.getFontSize(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          option,
                                          textDirection: TextDirection.rtl,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: textColor ?? colorScheme.onSurface,
                                          fontSize: PreferencesService.getFontSize(),
                                          height: 1.7,
                                        ),
                                        ),
                                      ),
                                      if (hasAnswered && isCorrectOption)
                                        const Icon(Icons.check_circle, color: Colors.green),
                                      if (hasAnswered && selectedIndex == index && !isCorrect && !isCorrectOption)
                                        const Icon(Icons.cancel, color: Colors.red),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_currentIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isShowingResult ? null : _previousQuestion,
                          child: Text(l10n.previousLabel),
                        ),
                      ),
                    if (_currentIndex > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: hasAnswered
                          ? FilledButton(
                              onPressed: _isShowingResult ? null : _nextQuestion,
                              child: Text(_currentIndex < widget.questions.length - 1
                                  ? l10n.nextLabel
                                  : l10n.showResultsLabel),
                            )
                          : FilledButton(
                              onPressed: _selectedAnswer == null || _isShowingResult ? null : _submitAnswer,
                              child: Text(l10n.confirmAnswerLabel),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}