import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MemorizationStatsService {
  MemorizationStatsService._();
  static final MemorizationStatsService instance = MemorizationStatsService._();

  static const String _keySurahMastery = 'memorization_surah_mastery';
  static const String _keyTotalScore = 'memorization_total_score';
  static const String _keyTestHistory = 'memorization_test_history';
  static const String _keyTotalTests = 'memorization_total_tests';
  static const String _keyTotalCorrectSum = 'memorization_total_correct_sum';
  static const String _keyTotalQuestionsSum = 'memorization_total_questions_sum';
  static const String _keyLastSurah = 'memorization_last_surah_map';
  static const String _keyBestSurah = 'memorization_best_surah_map';
  static const String _keyLastJuz = 'memorization_last_juz_map';
  static const String _keyBestJuz = 'memorization_best_juz_map';
  static const String _keySurahAgg = 'memorization_surah_agg'; // { "1": {count, correct, total}, ... }
  static const String _keyJuzAgg = 'memorization_juz_agg';     // { "1": {count, correct, total}, ... }

  Future<void> saveTestResult({
    required int? surahNumber,
    required int? juzNumber,
    required int correctAnswers,
    required int totalQuestions,
    required int score,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update total score
    final currentTotal = prefs.getInt(_keyTotalScore) ?? 0;
    await prefs.setInt(_keyTotalScore, currentTotal + score);

    // Update running totals for stats
    final totalTests = prefs.getInt(_keyTotalTests) ?? 0;
    await prefs.setInt(_keyTotalTests, totalTests + 1);
    final totalCorrectSum = prefs.getInt(_keyTotalCorrectSum) ?? 0;
    await prefs.setInt(_keyTotalCorrectSum, totalCorrectSum + correctAnswers);
    final totalQuestionsSum = prefs.getInt(_keyTotalQuestionsSum) ?? 0;
    await prefs.setInt(_keyTotalQuestionsSum, totalQuestionsSum + totalQuestions);

    // Add to test history first
    final history = await getTestHistory();

    // Update surah mastery if surah mode - calculate average from all tests
    if (surahNumber != null) {
      final masteryMap = await getSurahMastery();

      // Update persistent aggregation for surah
      final surahAggStr = prefs.getString(_keySurahAgg);
      final Map<String, dynamic> surahAgg = surahAggStr == null || surahAggStr.isEmpty
          ? {}
          : (json.decode(surahAggStr) as Map<String, dynamic>);
      final String key = '$surahNumber';
      final Map<String, dynamic> current = (surahAgg[key] as Map?)?.cast<String, dynamic>() ?? {};
      final int prevCount = (current['count'] as int?) ?? 0;
      final int prevCorrect = (current['correct'] as int?) ?? 0;
      final int prevTotal = (current['total'] as int?) ?? 0;
      final int newCount = prevCount + 1;
      final int newCorrect = prevCorrect + correctAnswers;
      final int newTotal = prevTotal + totalQuestions;
      surahAgg[key] = {'count': newCount, 'correct': newCorrect, 'total': newTotal};
      await prefs.setString(_keySurahAgg, json.encode(surahAgg));

      // Update mastery percentage from aggregated sums
      final int averagePercentage = newTotal > 0 ? (newCorrect / newTotal * 100).round() : 0;
      masteryMap[surahNumber] = averagePercentage;

      await prefs.setString(_keySurahMastery, json.encode(masteryMap));
    }
    history.add({
      'surahNumber': surahNumber,
      'juzNumber': juzNumber,
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'score': score,
      'percentage': (correctAnswers / totalQuestions * 100).round(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    // Keep last 100 tests
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }
    await prefs.setString(_keyTestHistory, json.encode(history));

    // Persist last/best summaries for fast, reliable access (kept for backwards-compatibility, but not used in UI)
    final int percentage = (correctAnswers / totalQuestions * 100).round();
    if (surahNumber != null) {
      final lastSurahStr = prefs.getString(_keyLastSurah);
      final Map<String, dynamic> lastSurah = lastSurahStr == null || lastSurahStr.isEmpty ? {} : (json.decode(lastSurahStr) as Map<String, dynamic>);
      lastSurah['$surahNumber'] = {
        'percentage': percentage,
        'score': score,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_keyLastSurah, json.encode(lastSurah));

      final bestSurahStr = prefs.getString(_keyBestSurah);
      final Map<String, dynamic> bestSurah = bestSurahStr == null || bestSurahStr.isEmpty ? {} : (json.decode(bestSurahStr) as Map<String, dynamic>);
      final prev = bestSurah['$surahNumber'] as Map<String, dynamic>?;
      if (prev == null || (prev['percentage'] as int? ?? 0) < percentage) {
        bestSurah['$surahNumber'] = {
          'percentage': percentage,
          'score': score,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        await prefs.setString(_keyBestSurah, json.encode(bestSurah));
      }
    }
    if (juzNumber != null) {
      // Update persistent aggregation for juz
      final juzAggStr = prefs.getString(_keyJuzAgg);
      final Map<String, dynamic> juzAgg = juzAggStr == null || juzAggStr.isEmpty
          ? {}
          : (json.decode(juzAggStr) as Map<String, dynamic>);
      final String key = '$juzNumber';
      final Map<String, dynamic> current = (juzAgg[key] as Map?)?.cast<String, dynamic>() ?? {};
      final int prevCount = (current['count'] as int?) ?? 0;
      final int prevCorrect = (current['correct'] as int?) ?? 0;
      final int prevTotal = (current['total'] as int?) ?? 0;
      juzAgg[key] = {
        'count': prevCount + 1,
        'correct': prevCorrect + correctAnswers,
        'total': prevTotal + totalQuestions,
      };
      await prefs.setString(_keyJuzAgg, json.encode(juzAgg));

      // Optionally maintain last/best for backward compatibility
      final lastJuzStr = prefs.getString(_keyLastJuz);
      final Map<String, dynamic> lastJuz = lastJuzStr == null || lastJuzStr.isEmpty ? {} : (json.decode(lastJuzStr) as Map<String, dynamic>);
      lastJuz['$juzNumber'] = {
        'percentage': percentage,
        'score': score,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_keyLastJuz, json.encode(lastJuz));

      final bestJuzStr = prefs.getString(_keyBestJuz);
      final Map<String, dynamic> bestJuz = bestJuzStr == null || bestJuzStr.isEmpty ? {} : (json.decode(bestJuzStr) as Map<String, dynamic>);
      final prev = bestJuz['$juzNumber'] as Map<String, dynamic>?;
      if (prev == null || (prev['percentage'] as int? ?? 0) < percentage) {
        bestJuz['$juzNumber'] = {
          'percentage': percentage,
          'score': score,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        await prefs.setString(_keyBestJuz, json.encode(bestJuz));
      }
    }
  }

  Future<Map<int, int>> getSurahMastery() async {
    final prefs = await SharedPreferences.getInstance();
    final masteryJson = prefs.getString(_keySurahMastery);
    if (masteryJson == null || masteryJson.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = json.decode(masteryJson);
      return decoded.map((k, v) => MapEntry(int.parse(k), v as int));
    } catch (_) {
      return {};
    }
  }

  Future<int> getTotalScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalScore) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getTestHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_keyTestHistory);
    if (historyJson == null || historyJson.isEmpty) return [];
    try {
      final dynamic decodedRoot = json.decode(historyJson);
      List<dynamic> asList;
      if (decodedRoot is List) {
        asList = decodedRoot;
      } else if (decodedRoot is Map<String, dynamic>) {
        // Some legacy or corrupted formats; try common wrappers
        if (decodedRoot['history'] is List) {
          asList = decodedRoot['history'] as List;
        } else if (decodedRoot['items'] is List) {
          asList = decodedRoot['items'] as List;
        } else {
          // Single entry map, wrap as list
          asList = [decodedRoot];
        }
      } else {
        return [];
      }
      return asList
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    final mastery = await getSurahMastery();
    final totalScore = await getTotalScore();
    final history = await getTestHistory();

    final prefs = await SharedPreferences.getInstance();

    // Read persistent aggregated maps
    Map<String, dynamic> surahAgg = {};
    Map<String, dynamic> juzAgg = {};
    try {
      final sa = prefs.getString(_keySurahAgg);
      final ja = prefs.getString(_keyJuzAgg);
      if (sa != null && sa.isNotEmpty) surahAgg = (json.decode(sa) as Map).cast<String, dynamic>();
      if (ja != null && ja.isNotEmpty) juzAgg = (json.decode(ja) as Map).cast<String, dynamic>();
    } catch (_) {}

    // Totals (tests, correct, questions) from counters if available, otherwise compute from aggregates
    final int counterTests = prefs.getInt(_keyTotalTests) ?? 0;
    final int counterCorrect = prefs.getInt(_keyTotalCorrectSum) ?? 0;
    final int counterQuestions = prefs.getInt(_keyTotalQuestionsSum) ?? 0;

    int aggTests = 0;
    int aggCorrect = 0;
    int aggQuestions = 0;
    for (final m in [...surahAgg.values, ...juzAgg.values]) {
      if (m is Map) {
        aggTests += (m['count'] as int?) ?? 0;
        aggCorrect += (m['correct'] as int?) ?? 0;
        aggQuestions += (m['total'] as int?) ?? 0;
      }
    }

    final totalTests = counterTests != 0 ? counterTests : (history.length > 0 ? history.length : aggTests);
    final totalCorrect = counterCorrect != 0 ? counterCorrect : (aggCorrect);
    final totalQuestions = counterQuestions != 0 ? counterQuestions : (aggQuestions);
    final averagePercentage = totalQuestions > 0 ? (totalCorrect / totalQuestions * 100).round() : 0;

    return {
      'totalScore': totalScore,
      'totalTests': totalTests,
      'averagePercentage': averagePercentage,
      'surahMastery': mastery,
      'recentTests': history.take(10).toList(),
      'surahAgg': surahAgg,
      'juzAgg': juzAgg,
    };
  }

  Future<void> clearAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySurahMastery);
    await prefs.remove(_keyTotalScore);
    await prefs.remove(_keyTestHistory);
    await prefs.remove(_keyTotalTests);
    await prefs.remove(_keyTotalCorrectSum);
    await prefs.remove(_keyTotalQuestionsSum);
    await prefs.remove(_keyLastSurah);
    await prefs.remove(_keyBestSurah);
    await prefs.remove(_keyLastJuz);
    await prefs.remove(_keyBestJuz);
  }
}
