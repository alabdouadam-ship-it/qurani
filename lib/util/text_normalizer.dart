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
    
    // Remove all Arabic diacritics (tashkeel) including extended range
    // Covers \u064B-\u065F (Fathatan..Sukoon..Superscript Alef..etc)
    // \u0670 is Maddah (superscript alef)
    // \u0640 is Tatweel (kashida)
    s = s.replaceAll(RegExp(r"[\u064B-\u065F\u0670\u0640]"), '');
    
    // Normalize alef variations (أ إ آ ٱ → ا)
    s = s.replaceAll(RegExp(r"[\u0622\u0623\u0625\u0671]"), '\u0627');
    
    // Normalize ta marbuta (ة → ه)
    s = s.replaceAll('\u0629', '\u0647');
    
    // Normalize Alef Maqsura case:
    // User requested to SEPARATE ى from ي.
    // So we ONLY handle Farsi Yeh (\u06CC) -> Arabic Yeh (\u064A)
    // We do NOT convert \u0649 (ى) to \u064A (ي) anymore.
    s = s.replaceAll('\u06CC', '\u064A');
    
    // Normalize waw with hamza (ؤ → و)
    s = s.replaceAll('\u0624', '\u0648');
    
    // Normalize yeh with hamza (ئ → ي)
    s = s.replaceAll('\u0626', '\u064A');
    
    // Normalize special characters often found in copy-pasted text
    // Remove "ALM" marks or other decorative Quranic symbols if present in usual search range
    // However, basic keyboard input shouldn't have them.
    
    return s.trim().toLowerCase();
  }
}

