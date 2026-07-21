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
    
    // Remove all Arabic diacritics, Quranic annotation marks, and invisible
    // formatting characters so search matches regardless of mushaf-style
    // decoration. Ranges covered:
    //   \u0610-\u061A  Arabic honorific/quranic signs (e.g. sallallahu)
    //   \u064B-\u065F  standard tashkeel (fathatan..sukoon..superscript alef)
    //   \u0670         superscript alef (maddah)
    //   \u06D6-\u06ED  Quranic annotation marks — this is the block that broke
    //                  filtering: surah names like "الأَحۡقَافِ" contain
    //                  U+06E1 (SMALL HIGH DOTLESS HEAD OF KHAH) between letters
    //   \u08D3-\u08FF  Arabic Extended-A combining marks
    //   \u0640         tatweel (kashida)
    //   \u200B-\u200F, \u2060-\u2064, \u00AD, \u061C, \uFEFF  zero-width /
    //                  bidi / formatting characters
    s = s.replaceAll(
        RegExp(
            r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF\u0640\u200B-\u200F\u2060-\u2064\u00AD\u061C\uFEFF]"),
        '');
    
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

