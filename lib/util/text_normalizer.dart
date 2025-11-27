/// Utility class for normalizing Arabic text for search purposes.
/// Removes diacritics (tashkeel) and normalizes character variations.
class TextNormalizer {
  /// Normalizes Arabic text by:
  /// 1. Removing all diacritics (tashkeel)
  /// 2. Normalizing character variations (أ إ آ → ا, ة → ه, ى → ي, etc.)
  /// 3. Trimming whitespace
  /// 
  /// This makes search accent-insensitive and handles different Arabic character forms.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    
    String s = input;
    
    // Remove all Arabic diacritics (tashkeel)
    // Range \u064B-\u0652 covers: Fathatan, Dammatan, Kasratan, Fatha, Damma, Kasra, Shadda, Sukun
    // \u0670 is Maddah (superscript alef)
    // \u0640 is Tatweel (kashida)
    s = s.replaceAll(RegExp(r"[\u064B-\u0652\u0670\u0640]"), '');
    
    // Normalize alef variations (أ إ آ ٱ → ا)
    // \u0622 = آ (Alef with Madda above)
    // \u0623 = أ (Alef with Hamza above)
    // \u0625 = إ (Alef with Hamza below)
    // \u0671 = ٱ (Alef Wasla - used in Quranic text)
    s = s.replaceAll(RegExp(r"[\u0622\u0623\u0625\u0671]"), '\u0627');
    
    // Normalize ta marbuta (ة → ه)
    s = s.replaceAll('\u0629', '\u0647');
    
    // Normalize alef maksura (ى → ي)
    s = s.replaceAll('\u0649', '\u064A');
    
    // Normalize waw with hamza (ؤ → و)
    s = s.replaceAll('\u0624', '\u0648');
    
    // Normalize yeh with hamza (ئ → ي)
    s = s.replaceAll('\u0626', '\u064A');
    
    // Note: We don't use toLowerCase() for Arabic text as it doesn't work correctly
    // Arabic characters don't have case distinctions like Latin characters
    
    return s.trim().toLowerCase();
  }
}

