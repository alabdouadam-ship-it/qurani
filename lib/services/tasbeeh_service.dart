import 'package:shared_preferences/shared_preferences.dart';

class TasbeehService {
  static const String _keyPhrases = 'tasbeeh_phrases';
  static const String _keyTotalCounts = 'tasbeeh_total_counts';

  static const List<String> defaultPhrases = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'أستغفر الله',
    'لا حول ولا قوة إلا بالله',
    'سبحان الله وبحمده، سبحان الله العظيم',
    'اللهم صلي على سيدنا محمد وعلى آل سيدنا محمد',
    'رضيتُ بالله ربًّا، وبالإسلام دينًا، وبمحمدٍ ﷺ نبيًّا ورسولًا.',
    'حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم',
    'يا حي يا قيوم برحمتك أستغيث',
    'اللهم اغفر لي ولوالدي وللمؤمنين والمؤمنات',
    'اللهم إنك عفو تحب العفو فاعفُ عني',
    'اللهم لك الحمد كما ينبغي لجلال وجهك وعظيم سلطانك',
    'اللهم ثبت قلبي على دينك',
    'اللهم اجعلني من التوابين واجعلني من المتطهرين',
    'اللهم إني أسألك الجنة وأعوذ بك من النار',
    'اللهم اشرح لي صدري ويسر لي أمري',
  ];

  static Future<List<String>> getPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    final phrases = prefs.getStringList(_keyPhrases);
    // Return user phrases if they exist, otherwise return default phrases
    // We always start with default phrases, then user can add/remove from them
    if (phrases != null && phrases.isNotEmpty) {
      return phrases;
    }
    // First time - initialize with default phrases
    await prefs.setStringList(_keyPhrases, List<String>.from(defaultPhrases));
    return List<String>.from(defaultPhrases);
  }

  static Future<bool> hasUserPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    final phrases = prefs.getStringList(_keyPhrases);
    return phrases != null && phrases.isNotEmpty;
  }

  static Future<void> savePhrases(List<String> phrases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPhrases, phrases);
  }

  static Future<Map<int, int>> getTotalCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final countsJson = prefs.getString(_keyTotalCounts);
    if (countsJson == null || countsJson.isEmpty) return {};
    try {
      // Simple parsing: "0:5,1:10" -> {0:5, 1:10}
      final Map<int, int> result = {};
      final pairs = countsJson.split(',');
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final key = int.tryParse(parts[0]);
          final value = int.tryParse(parts[1]);
          if (key != null && value != null) {
            result[key] = value;
          }
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveTotalCounts(Map<int, int> counts) async {
    final prefs = await SharedPreferences.getInstance();
    if (counts.isEmpty) {
      await prefs.remove(_keyTotalCounts);
      return;
    }
    final pairs = counts.entries.map((e) => '${e.key}:${e.value}').join(',');
    await prefs.setString(_keyTotalCounts, pairs);
  }

  static Future<void> incrementCount(int index) async {
    final counts = await getTotalCounts();
    counts[index] = (counts[index] ?? 0) + 1;
    await saveTotalCounts(counts);
  }

  static Future<void> resetSessionCount(int index) async {
    // Session counts are in-memory only, no need to save
  }

  static Future<void> resetAllCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTotalCounts);
  }

  static Future<void> addPhrase(String phrase) async {
    // Get current phrases (default or user-modified)
    final phrases = await getPhrases();
    phrases.add(phrase);
    await savePhrases(phrases);
  }

  static Future<void> removePhrase(int index) async {
    // Get current phrases (default or user-modified)
    final phrases = await getPhrases();
    if (index >= 0 && index < phrases.length) {
      // Remove the phrase
      phrases.removeAt(index);
      await savePhrases(phrases);
      
      // Also remove counts for this index and shift remaining counts
      final counts = await getTotalCounts();
      final newCounts = <int, int>{};
      for (final entry in counts.entries) {
        if (entry.key < index) {
          newCounts[entry.key] = entry.value;
        } else if (entry.key > index) {
          newCounts[entry.key - 1] = entry.value;
        }
        // Skip entry.key == index (deleted phrase)
      }
      await saveTotalCounts(newCounts);
    }
  }
}
