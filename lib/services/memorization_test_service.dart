import 'dart:math';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/services/quran_constants.dart';
import 'package:qurani/services/preferences_service.dart';

class MemorizationTestService {
  MemorizationTestService._();
  static final MemorizationTestService instance = MemorizationTestService._();

  final _random = Random();

  int _getQuestionLimit() {
    return PreferencesService.getMemorizationQuestionLimit(); 
  }

  // Load ayahs for a surah
  Future<List<AyahBrief>> _loadSurahAyahs(int surahNumber) async {
    return await QuranRepository.instance
        .loadSurahAyahs(surahNumber, QuranEdition.simple);
  }

  // Load ayahs for a juz by scanning pages
  Future<List<AyahBrief>> _loadJuzAyahs(int juzNumber) async {
    final startPage = juzStartPages[juzNumber] ?? 1;
    final endPage = juzNumber < 30
        ? (juzStartPages[juzNumber + 1] ?? 604) - 1
        : 604;
    
    final List<AyahBrief> ayahs = [];
    for (int page = startPage; page <= endPage; page++) {
      try {
        final pageData = await QuranRepository.instance
            .loadPage(page, QuranEdition.simple);
        for (final ayahData in pageData.ayahs) {
          if (ayahData.juz == juzNumber) {
            final surahMeta = ayahData.surah;
            ayahs.add(AyahBrief(
              number: ayahData.number,
              numberInSurah: ayahData.numberInSurah,
              text: ayahData.text,
              surah: surahMeta,
            ));
          }
        }
      } catch (_) {
        // Skip page if error
        continue;
      }
    }
    return ayahs;
  }

  // Split ayah into two parts (first part <= half, remaining second)
  List<String> _splitAyahForCompletion(String ayahText) {
    final words = ayahText.trim().split(RegExp(r'\s+'));
    if (words.length <= 2) {
      return [ayahText, ''];
    }
    final halfIndex = (words.length / 2).floor();
    final firstPart = words.sublist(0, halfIndex).join(' ');
    final secondPart = words.sublist(halfIndex).join(' ');
    return [firstPart, secondPart];
  }

  // Generate question type 1: What ayah comes after this ayah?
  MemorizationQuestion? _generateNextAyahQuestion(
    AppLocalizations l10n,
    List<AyahBrief> ayahs,
    int currentIndex,
  ) {
    if (currentIndex >= ayahs.length - 1) return null; // No next ayah
    final currentAyah = ayahs[currentIndex];
    final nextAyah = ayahs[currentIndex + 1];

    // Use Set to ensure uniqueness
    final optionsSet = <String>{nextAyah.text};

    final availableIndices = List.generate(ayahs.length, (i) => i)
        ..remove(currentIndex)
        ..remove(currentIndex + 1);
    availableIndices.shuffle(_random);

    for (int i = 0; i < availableIndices.length && optionsSet.length < 4; i++) {
      optionsSet.add(ayahs[availableIndices[i]].text);
    }

    // If we couldn't find enough unique wrong answers (e.g. very short surah),
    // it's okay to have fewer options, but we must have at least 2
    if (optionsSet.length < 2) return null;

    final allOptions = optionsSet.toList();
    allOptions.shuffle(_random);
    final correctIndex = allOptions.indexOf(nextAyah.text);

    return MemorizationQuestion(
      type: QuestionType.nextAyah,
      text: l10n.memorizationQNextAyah(
        currentAyah.surah.name,
        currentAyah.text,
      ),
      options: allOptions,
      correctIndex: correctIndex,
      contextSurah: currentAyah.surah,
    );
  }

  // Generate question type 2: Complete the ayah
  MemorizationQuestion? _generateCompleteAyahQuestion(
    AppLocalizations l10n,
    List<AyahBrief> ayahs,
    int ayahIndex,
  ) {
    final ayah = ayahs[ayahIndex];
    final parts = _splitAyahForCompletion(ayah.text);
    if (parts[1].isEmpty) return null; // Too short to split

    final correctAnswer = parts[1];
    // Use Set to ensure uniqueness
    final optionsSet = <String>{correctAnswer};

    final availableIndices = List.generate(ayahs.length, (i) => i)
      ..remove(ayahIndex);
    availableIndices.shuffle(_random);

    for (int i = 0; i < availableIndices.length && optionsSet.length < 4; i++) {
      final wrongAyah = ayahs[availableIndices[i]];
      final wrongParts = _splitAyahForCompletion(wrongAyah.text);
      if (wrongParts[1].isNotEmpty) {
        optionsSet.add(wrongParts[1]);
      }
    }

    if (optionsSet.length < 2) return null;

    final allOptions = optionsSet.toList();
    allOptions.shuffle(_random);
    final correctIndex = allOptions.indexOf(correctAnswer);

    return MemorizationQuestion(
      type: QuestionType.completeAyah,
      text: l10n.memorizationQCompleteAyah(ayah.surah.name, parts[0]),
      options: allOptions,
      correctIndex: correctIndex,
      contextSurah: ayah.surah,
    );
  }

  // Generate surah info questions (only for surah mode)
  Future<List<MemorizationQuestion>> _generateSurahInfoQuestions(
    AppLocalizations l10n,
    SurahMeta surah,
    int ayahCount,
  ) async {
    // Surah number: distractors across the full 1..114 range make sense
    // because the user should already have a rough sense of where the surah
    // sits in the mus-haf.
    final options1 = _generateNumberOptions(surah.number, 114);
    // Ayah count: distractors need to sit close to the real count so the
    // question actually probes memorisation instead of being trivially
    // eliminated by gross size. We cluster within ±max(5, 10% of count) and
    // fall back to a widened range only if we cannot find enough unique
    // candidates (e.g. very small surahs like Al-Kawthar, 3 verses).
    final clusterSpread = (ayahCount * 0.1).round().clamp(5, 30);
    final options2 = _generateClusteredNumberOptions(
      correct: ayahCount,
      spread: clusterSpread,
      maxValue: 300,
    );

    return [
      // Question: Surah number
      MemorizationQuestion(
        type: QuestionType.surahNumber,
        text: l10n.memorizationQSurahNumber(surah.name),
        options: options1,
        correctIndex: options1.indexOf(surah.number.toString()),
        contextSurah: surah,
      ),
      // Question: Number of ayahs
      MemorizationQuestion(
        type: QuestionType.surahAyahCount,
        text: l10n.memorizationQSurahAyahCount(surah.name),
        options: options2,
        correctIndex: options2.indexOf(ayahCount.toString()),
        contextSurah: surah,
      ),
    ];
  }

  List<String> _generateNumberOptions(int correct, int max) {
    final options = <int>{correct};
    while (options.length < 4) {
      final candidate = _random.nextInt(max) + 1;
      if (candidate != correct) {
        options.add(candidate);
      }
    }
    final list = options.toList();
    list.shuffle(_random);
    return list.map((n) => n.toString()).toList();
  }

  /// Generates 4 unique options clustered around [correct] within ±[spread].
  /// If the local window cannot yield enough unique distractors the window
  /// expands progressively until we either gather 4 options or exceed
  /// [maxValue]. Guarantees at least 2 options are always returned.
  List<String> _generateClusteredNumberOptions({
    required int correct,
    required int spread,
    required int maxValue,
  }) {
    final options = <int>{correct};
    int windowSpread = spread;
    int attempts = 0;
    while (options.length < 4 && attempts < 200) {
      attempts++;
      final lower = (correct - windowSpread).clamp(1, maxValue);
      final upper = (correct + windowSpread).clamp(1, maxValue);
      final range = upper - lower;
      if (range <= 0) {
        // Window collapsed; widen and retry.
        windowSpread = (windowSpread * 2).clamp(1, maxValue);
        continue;
      }
      final candidate = lower + _random.nextInt(range + 1);
      if (candidate != correct) {
        options.add(candidate);
      }
      // If after many tries we still can't fill 4, widen the window so we
      // don't spin forever on very small surahs.
      if (attempts % 20 == 0 && options.length < 4) {
        windowSpread = (windowSpread * 2).clamp(1, maxValue);
      }
    }
    final list = options.toList();
    list.shuffle(_random);
    return list.map((n) => n.toString()).toList();
  }

  Future<List<MemorizationQuestion>> generateQuestions({
    required AppLocalizations l10n,
    List<int>? surahNumbers,
    List<int>? juzNumbers,
  }) async {
    final limit = _getQuestionLimit();
    final bool hasSurahs = surahNumbers != null && surahNumbers.isNotEmpty;
    final bool hasJuz = juzNumbers != null && juzNumbers.isNotEmpty;
    if (!hasSurahs && !hasJuz) {
      throw ArgumentError('Either surahNumbers or juzNumbers must be provided');
    }
    if (hasSurahs && hasJuz) {
      throw ArgumentError('Cannot specify both surahNumbers and juzNumbers');
    }

    final allQuestions = <MemorizationQuestion>[];

    if (hasSurahs) {
      // Generate questions from multiple surahs with equal distribution
      final List<List<MemorizationQuestion>> surahQuestions = [];
      
      for (final surahNumber in surahNumbers) {
        final ayahs = await _loadSurahAyahs(surahNumber);
        if (ayahs.isEmpty) continue;
        
        final surahQuestionsList = <MemorizationQuestion>[];
        
        // Generate questions from ayahs
        for (int i = 0; i < ayahs.length; i++) {
          final nextQuestion = _generateNextAyahQuestion(l10n, ayahs, i);
          if (nextQuestion != null) {
            surahQuestionsList.add(nextQuestion);
          }
          
          final completeQuestion = _generateCompleteAyahQuestion(l10n, ayahs, i);
          if (completeQuestion != null) {
            surahQuestionsList.add(completeQuestion);
          }
        }
        
        // Add surah info questions (only 2 per surah)
        final surahMeta = ayahs.first.surah;
        final surahInfoQuestions = await _generateSurahInfoQuestions(
          l10n,
          surahMeta,
          ayahs.length,
        );
        surahQuestionsList.addAll(surahInfoQuestions);
        
        surahQuestionsList.shuffle(_random);
        surahQuestions.add(surahQuestionsList);
      }
      
      // Distribute questions evenly from each surah
      int remaining = limit;
      
      while (remaining > 0 && surahQuestions.isNotEmpty) {
        for (int i = 0; i < surahQuestions.length && remaining > 0; i++) {
          if (surahQuestions[i].isEmpty) continue;
          final questionsFromThisSurah = (remaining / (surahQuestions.length - i)).ceil();
          final actualQuestions = questionsFromThisSurah > surahQuestions[i].length
              ? surahQuestions[i].length
              : questionsFromThisSurah;
          
          for (int j = 0; j < actualQuestions && surahQuestions[i].isNotEmpty && remaining > 0; j++) {
            allQuestions.add(surahQuestions[i].removeAt(0));
            remaining--;
          }
        }
        // Remove empty surah lists
        surahQuestions.removeWhere((list) => list.isEmpty);
      }
      
      // Shuffle final questions
      allQuestions.shuffle(_random);
      return allQuestions.take(limit).toList();
    } else {
      // Juz mode - now supports multiple Juzs
      final List<List<MemorizationQuestion>> juzQuestions = [];

      for (final juzNumber in juzNumbers!) {
        final ayahs = await _loadJuzAyahs(juzNumber);
        if (ayahs.isEmpty) continue;
        
        final juzQuestionsList = <MemorizationQuestion>[];

        // Generate questions from ayahs
        for (int i = 0; i < ayahs.length; i++) {
          final nextQuestion = _generateNextAyahQuestion(l10n, ayahs, i);
          if (nextQuestion != null) {
            juzQuestionsList.add(nextQuestion);
          }
          
          final completeQuestion = _generateCompleteAyahQuestion(l10n, ayahs, i);
          if (completeQuestion != null) {
            juzQuestionsList.add(completeQuestion);
          }
        }
        
        juzQuestionsList.shuffle(_random);
        juzQuestions.add(juzQuestionsList);
      }

      // Distribute questions evenly from each Juz
      int remaining = limit;
      
      while (remaining > 0 && juzQuestions.isNotEmpty) {
        for (int i = 0; i < juzQuestions.length && remaining > 0; i++) {
          if (juzQuestions[i].isEmpty) continue;
          // Dynamically calculate how many to take based on remaining collections
          final questionsFromThisJuz = (remaining / (juzQuestions.length - i)).ceil();
          final actualQuestions = questionsFromThisJuz > juzQuestions[i].length
              ? juzQuestions[i].length
              : questionsFromThisJuz;
          
          for (int j = 0; j < actualQuestions && juzQuestions[i].isNotEmpty && remaining > 0; j++) {
            allQuestions.add(juzQuestions[i].removeAt(0));
            remaining--;
          }
        }
        // Remove empty juz lists
        juzQuestions.removeWhere((list) => list.isEmpty);
      }

      // Shuffle and limit
      allQuestions.shuffle(_random);
      return allQuestions.take(limit).toList();
    }
  }
}

enum QuestionType {
  nextAyah,
  completeAyah,
  surahNumber,
  surahAyahCount,
}

class MemorizationQuestion {
  MemorizationQuestion({
    required this.type,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.contextSurah,
  });

  final QuestionType type;
  final String text;
  final List<String> options;
  final int correctIndex;
  final SurahMeta contextSurah;
}