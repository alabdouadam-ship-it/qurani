import 'package:flutter/material.dart';
import '../services/irab_service.dart';
import '../services/preferences_service.dart';

/// Color scheme for syntactic roles.
class IrabColors {
  static Color getColorForRole(String role, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Verbs
    if (role.contains('فعل ماضٍ') ||
        role.contains('فعل مضارع') ||
        role.contains('فعل أمر')) {
      return isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);
    }

    // Subject
    if (role == 'فاعل' || role == 'نائب فاعل') {
      return isDark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32);
    }

    // Object
    if (role == 'مفعول به' || role.contains('مفعول')) {
      return isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0);
    }

    // Nominal subject (mubtada)
    if (role == 'مبتدأ') {
      return isDark ? const Color(0xFFFFCC80) : const Color(0xFFE65100);
    }

    // Predicate (khabar)
    if (role == 'خبر' ||
        role.contains('خبر حرف ناسخ') ||
        role.contains('خبر فعل ناسخ')) {
      return isDark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A);
    }

    // Particles
    if (role.contains('حرف جر') ||
        role.contains('حرف عطف') ||
        role.contains('حرف غير عامل') ||
        role.contains('حرف نداء') ||
        role.contains('حرف شرط') ||
        role.contains('حرف ناسخ') ||
        role.contains('حرف جزم') ||
        role.contains('حرف نصب') ||
        role.contains('حرف مصدري')) {
      return isDark ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);
    }

    // Adjective (na't)
    if (role == 'نعت') {
      return isDark ? const Color(0xFF80CBC4) : const Color(0xFF00695C);
    }

    // Possessive (mudaf ilayhi)
    if (role == 'مضاف إليه') {
      return isDark ? const Color(0xFF80DEEA) : const Color(0xFF00838F);
    }

    // Idhafa / possessive construct subject
    if (role.contains('اسم حرف ناسخ') || role.contains('اسم فعل ناسخ')) {
      return isDark ? const Color(0xFFF48FB1) : const Color(0xFFAD1457);
    }

    // Demonstrative / relative pronouns
    if (role.contains('اسم إشارة') || role.contains('اسم موصول')) {
      return isDark ? const Color(0xFFFFAB91) : const Color(0xFFBF360C);
    }

    // Adverb of time/place
    if (role.contains('ظرف')) {
      return isDark ? const Color(0xFFB39DDB) : const Color(0xFF4527A0);
    }

    // Prepositional object
    if (role == 'اسم مجرور') {
      return isDark ? const Color(0xFF81D4FA) : const Color(0xFF0277BD);
    }

    // Badal (substitute)
    if (role == 'بدل') {
      return isDark ? const Color(0xFFA5D6A7) : const Color(0xFF388E3C);
    }

    // Hal (circumstantial)
    if (role == 'حال') {
      return isDark ? const Color(0xFFDCE775) : const Color(0xFF827717);
    }

    // Tamyiz (specification)
    if (role == 'تمييز') {
      return isDark ? const Color(0xFFFFD54F) : const Color(0xFFF57F17);
    }

    // Default
    return isDark ? Colors.white70 : Colors.black87;
  }
}

/// Widget that renders a verse with word-by-word إعراب annotations.
class IrabVerseWidget extends StatelessWidget {
  final IrabVerse verse;
  final double? fontSize;

  const IrabVerseWidget({
    super.key,
    required this.verse,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final baseFontSize = fontSize ?? PreferencesService.getFontSize();
    final annotationFontSize = baseFontSize * 0.55;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        spacing: 12,
        runSpacing: 16,
        alignment: WrapAlignment.start,
        children: verse.words.map((word) {
          final color = IrabColors.getColorForRole(word.primaryRole, brightness);
          final annotation = word.annotation;

          return IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Arabic word
                Text(
                  word.word,
                  style: TextStyle(
                    fontSize: baseFontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.8,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                // Annotation
                if (annotation.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(brightness == Brightness.dark ? 30 : 20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      annotation,
                      style: TextStyle(
                        fontSize: annotationFontSize,
                        color: color,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
