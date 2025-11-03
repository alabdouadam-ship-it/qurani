import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MemorizationStatsService {
  MemorizationStatsService._();
  static final MemorizationStatsService instance = MemorizationStatsService._();

  static const String _keySurahMastery = 'memorization_surah_mastery';
  static const String _keyTotalScore = 'memorization_total_score';
  static const String _keyTestHistory = 'memorization_test_history';

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

    // Add to test history first
    final history = await getTestHistory();

    // Update surah mastery if surah mode - calculate average from all tests
    if (surahNumber != null) {
      final masteryMap = await getSurahMastery();
      
      // Get all tests for this surah (including the new one we're about to add)
      final surahTests = history.where((test) => 
        test['surahNumber'] == surahNumber
      ).toList();
      
      // Add current test to the list for calculation
      surahTests.add({
        'surahNumber': surahNumber,
        'correctAnswers': correctAnswers,
        'totalQuestions': totalQuestions,
      });
      
      // Calculate average percentage
      final totalCorrect = surahTests.fold<int>(0, (sum, test) => 
        sum + (test['correctAnswers'] as int? ?? 0)
      );
      final totalQuestionsSum = surahTests.fold<int>(0, (sum, test) => 
        sum + (test['totalQuestions'] as int? ?? 0)
      );
      final averagePercentage = totalQuestionsSum > 0
          ? (totalCorrect / totalQuestionsSum * 100).round()
          : 0;
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
      final List<dynamic> decoded = json.decode(historyJson);
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    final mastery = await getSurahMastery();
    final totalScore = await getTotalScore();
    final history = await getTestHistory();
    
    final totalTests = history.length;
    final totalCorrect = history.fold<int>(0, (sum, test) => sum + (test['correctAnswers'] as int? ?? 0));
    final totalQuestions = history.fold<int>(0, (sum, test) => sum + (test['totalQuestions'] as int? ?? 0));
    final averagePercentage = totalQuestions > 0
        ? (totalCorrect / totalQuestions * 100).round()
        : 0;

    return {
      'totalScore': totalScore,
      'totalTests': totalTests,
      'averagePercentage': averagePercentage,
      'surahMastery': mastery,
      'recentTests': history.take(10).toList(),
    };
  }

  Future<void> clearAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySurahMastery);
    await prefs.remove(_keyTotalScore);
    await prefs.remove(_keyTestHistory);
  }
}
