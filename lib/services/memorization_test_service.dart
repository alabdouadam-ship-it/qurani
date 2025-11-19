import 'dart:math';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/services/quran_constants.dart';

class MemorizationTestService {
  MemorizationTestService._();
  static final MemorizationTestService instance = MemorizationTestService._();

  final _random = Random();

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
    List<AyahBrief> ayahs,
    int currentIndex,
  ) {
    if (currentIndex >= ayahs.length - 1) return null; // No next ayah
    final currentAyah = ayahs[currentIndex];
    final nextAyah = ayahs[currentIndex + 1];
    
    // Get 3 wrong options from same surah/scope randomly
    final wrongOptions = <String>[];
    final availableIndices = List.generate(ayahs.length, (i) => i)
        ..remove(currentIndex)
        ..remove(currentIndex + 1);
    availableIndices.shuffle(_random);
    for (int i = 0; i < 3 && i < availableIndices.length; i++) {
      wrongOptions.add(ayahs[availableIndices[i]].text);
    }
    if (wrongOptions.length < 3) return null;
    
    final allOptions = [nextAyah.text, ...wrongOptions];
    allOptions.shuffle(_random);
    final correctIndex = allOptions.indexOf(nextAyah.text);
    
    return MemorizationQuestion(
      type: QuestionType.nextAyah,
      text: 'في ${currentAyah.surah.name}\nما هي الآية التي تأتي بعد الآية التالية؟\n${currentAyah.text}',
      options: allOptions,
      correctIndex: correctIndex,
      contextSurah: currentAyah.surah,
    );
  }

  // Generate question type 2: Complete the ayah
  MemorizationQuestion? _generateCompleteAyahQuestion(
    List<AyahBrief> ayahs,
    int ayahIndex,
  ) {
    final ayah = ayahs[ayahIndex];
    final parts = _splitAyahForCompletion(ayah.text);
    if (parts[1].isEmpty) return null; // Too short to split
    
    // Get 3 wrong options from same surah/scope
    final wrongOptions = <String>[];
    final availableIndices = List.generate(ayahs.length, (i) => i)
      ..remove(ayahIndex);
    availableIndices.shuffle(_random);
    for (int i = 0; i < 3 && i < availableIndices.length; i++) {
      final wrongAyah = ayahs[availableIndices[i]];
      final wrongParts = _splitAyahForCompletion(wrongAyah.text);
      if (wrongParts[1].isNotEmpty) {
        wrongOptions.add(wrongParts[1]);
      }
    }
    if (wrongOptions.length < 3) return null;
    
    final allOptions = [parts[1], ...wrongOptions];
    allOptions.shuffle(_random);
    final correctIndex = allOptions.indexOf(parts[1]);
    
    return MemorizationQuestion(
      type: QuestionType.completeAyah,
      text: 'في ${ayah.surah.name}\nأكمل قوله تعالى:\n${parts[0]}...',
      options: allOptions,
      correctIndex: correctIndex,
      contextSurah: ayah.surah,
    );
  }

  // Generate surah info questions (only for surah mode)
  Future<List<MemorizationQuestion>> _generateSurahInfoQuestions(
    SurahMeta surah,
    int ayahCount,
  ) async {
    final options1 = _generateNumberOptions(surah.number, 114);
    final options2 = _generateNumberOptions(ayahCount, 300);
    
    return [
      // Question: Surah number
      MemorizationQuestion(
        type: QuestionType.surahNumber,
        text: 'ما هو رقم ${surah.name} في القرآن الكريم؟',
        options: options1,
        correctIndex: options1.indexOf(surah.number.toString()),
        contextSurah: surah,
      ),
      // Question: Number of ayahs
      MemorizationQuestion(
        type: QuestionType.surahAyahCount,
        text: 'كم عدد آيات ${surah.name}؟',
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

  Future<List<MemorizationQuestion>> generateQuestions({
    List<int>? surahNumbers,
    int? juzNumber,
  }) async {
    final bool hasSurahs = surahNumbers != null && surahNumbers.isNotEmpty;
    final bool hasJuz = juzNumber != null;
    if (!hasSurahs && !hasJuz) {
      throw ArgumentError('Either surahNumbers or juzNumber must be provided');
    }
    if (hasSurahs && hasJuz) {
      throw ArgumentError('Cannot specify both surahNumbers and juzNumber');
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
          final nextQuestion = _generateNextAyahQuestion(ayahs, i);
          if (nextQuestion != null) {
            surahQuestionsList.add(nextQuestion);
          }
          
          final completeQuestion = _generateCompleteAyahQuestion(ayahs, i);
          if (completeQuestion != null) {
            surahQuestionsList.add(completeQuestion);
          }
        }
        
        // Add surah info questions (only 2 per surah)
        final surahMeta = ayahs.first.surah;
        final surahInfoQuestions = await _generateSurahInfoQuestions(
          surahMeta,
          ayahs.length,
        );
        surahQuestionsList.addAll(surahInfoQuestions);
        
        surahQuestionsList.shuffle(_random);
        surahQuestions.add(surahQuestionsList);
      }
      
      // Distribute questions evenly from each surah
      int remaining = 100;
      
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
      return allQuestions.take(100).toList();
    } else {
      // Juz mode - existing logic
      final ayahs = await _loadJuzAyahs(juzNumber!);
      if (ayahs.isEmpty) {
        throw Exception('No ayahs found for the selected scope');
      }

      // Generate questions from ayahs
      for (int i = 0; i < ayahs.length; i++) {
        final nextQuestion = _generateNextAyahQuestion(ayahs, i);
        if (nextQuestion != null) {
          allQuestions.add(nextQuestion);
        }
        
        final completeQuestion = _generateCompleteAyahQuestion(ayahs, i);
        if (completeQuestion != null) {
          allQuestions.add(completeQuestion);
        }
      }

      // Shuffle and limit to 100
      allQuestions.shuffle(_random);
      return allQuestions.take(100).toList();
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