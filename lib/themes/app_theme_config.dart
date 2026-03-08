import 'package:flutter/material.dart';

class AppThemeOption {
  const AppThemeOption({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.nameFr,
    required this.primaryColor,
    required this.accentColor,
    required this.textColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.gradientColors,
    required this.brightness,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String nameFr;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;
  final Color surfaceColor;
  final Color cardColor;
  final List<Color> gradientColors;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return nameEn;
      case 'fr':
        return nameFr;
      default:
        return nameAr;
    }
  }
}

class AppThemeConfig {
  static const String defaultThemeId = 'skyBlue';
  static const String deepNightThemeId = 'dark';

  static const List<AppThemeOption> themes = [
    AppThemeOption(
      id: 'skyBlue',
      nameAr: 'أزرق سماوي',
      nameEn: 'Sky Blue',
      nameFr: 'Bleu ciel',
      primaryColor: Color(0xFF4C9ED9),
      accentColor: Color(0xFF7DC6F5),
      textColor: Color(0xFF16324B),
      surfaceColor: Color(0xFFF4F9FE),
      cardColor: Color(0xFFE8F2FB),
      gradientColors: [Color(0xFF8FD0FF), Color(0xFFEAF5FF)],
      brightness: Brightness.light,
    ),
    AppThemeOption(
      id: 'green',
      nameAr: 'أخضر',
      nameEn: 'Green',
      nameFr: 'Vert',
      primaryColor: Color(0xFF2F7D4B),
      accentColor: Color(0xFF74B98B),
      textColor: Color(0xFF183528),
      surfaceColor: Color(0xFFF2F8F3),
      cardColor: Color(0xFFE3F0E6),
      gradientColors: [Color(0xFFA8D8B5), Color(0xFFF4FBF6)],
      brightness: Brightness.light,
    ),
    AppThemeOption(
      id: 'emerald',
      nameAr: 'زمردي',
      nameEn: 'Emerald Green',
      nameFr: 'Vert émeraude',
      primaryColor: Color(0xFF1C7C67),
      accentColor: Color(0xFF59B79A),
      textColor: Color(0xFF13362E),
      surfaceColor: Color(0xFFF0F9F5),
      cardColor: Color(0xFFDEF2EA),
      gradientColors: [Color(0xFF6AC9A9), Color(0xFFE8FAF2)],
      brightness: Brightness.light,
    ),
    AppThemeOption(
      id: 'royalPurple',
      nameAr: 'ملكي',
      nameEn: 'Royal Purple',
      nameFr: 'Violet royal',
      primaryColor: Color(0xFF5D3D91),
      accentColor: Color(0xFFA88BDA),
      textColor: Color(0xFF291A40),
      surfaceColor: Color(0xFFF6F1FB),
      cardColor: Color(0xFFE9DEF8),
      gradientColors: [Color(0xFF8662C7), Color(0xFFF0E7FD)],
      brightness: Brightness.light,
    ),
    AppThemeOption(
      id: 'warmSand',
      nameAr: 'رملي',
      nameEn: 'Warm Sand',
      nameFr: 'Sable chaud',
      primaryColor: Color(0xFF9B7A4F),
      accentColor: Color(0xFFD2B27F),
      textColor: Color(0xFF4C3921),
      surfaceColor: Color(0xFFFCF7EF),
      cardColor: Color(0xFFF4EBDD),
      gradientColors: [Color(0xFFE7D2B2), Color(0xFFFBF4E8)],
      brightness: Brightness.light,
    ),
    AppThemeOption(
      id: 'dark',
      nameAr: 'ليلي',
      nameEn: 'Deep Night',
      nameFr: 'Nuit profonde',
      primaryColor: Color(0xFF173B63),
      accentColor: Color(0xFF95B9EE),
      textColor: Color(0xFFF4F7FB),
      surfaceColor: Color(0xFF08131F),
      cardColor: Color(0xFF122235),
      gradientColors: [Color(0xFF09131F), Color(0xFF1A304B)],
      brightness: Brightness.dark,
    ),
    AppThemeOption(
      id: 'roseGold',
      nameAr: 'وردي ذهبي',
      nameEn: 'Rose Gold',
      nameFr: 'Or rose',
      primaryColor: Color(0xFFA86F6A),
      accentColor: Color(0xFFD5A19A),
      textColor: Color(0xFF4E2D2A),
      surfaceColor: Color(0xFFFFF7F5),
      cardColor: Color(0xFFF7E7E3),
      gradientColors: [Color(0xFFE0B1AA), Color(0xFFFFF1EE)],
      brightness: Brightness.light,
    ),
    AppThemeOption(
      id: 'tealOcean',
      nameAr: 'محيطي',
      nameEn: 'Teal Ocean',
      nameFr: 'Océan sarcelle',
      primaryColor: Color(0xFF1D7A84),
      accentColor: Color(0xFF67C0C5),
      textColor: Color(0xFF16383B),
      surfaceColor: Color(0xFFF1FAFA),
      cardColor: Color(0xFFDDF0F2),
      gradientColors: [Color(0xFF58B5BE), Color(0xFFEAF8F9)],
      brightness: Brightness.light,
    ),
  ];

  static const Map<String, String> legacyThemeAliases = {
    'gray': 'warmSand',
    'gold': 'warmSand',
    'orange': 'warmSand',
    'purple': 'royalPurple',
    'brown': 'warmSand',
    'lightBlue': 'skyBlue',
    'blueGrey': 'skyBlue',
    'teal': 'tealOcean',
    'oliveGreen': 'emerald',
    'beige': 'warmSand',
  };

  static String resolveThemeId(String? themeId) {
    final candidate = (themeId == null || themeId.isEmpty)
        ? defaultThemeId
        : themeId;
    for (final theme in themes) {
      if (theme.id == candidate) {
        return candidate;
      }
    }
    return legacyThemeAliases[candidate] ?? defaultThemeId;
  }

  static AppThemeOption getTheme(String? themeId) {
    final resolved = resolveThemeId(themeId);
    return themes.firstWhere(
      (theme) => theme.id == resolved,
      orElse: () => themes.first,
    );
  }

  static ThemeData themeDataFor(String? themeId) {
    final theme = getTheme(themeId);
    final colorScheme = theme.isDark
        ? ColorScheme.dark(
            primary: theme.primaryColor,
            onPrimary: Colors.white,
            secondary: theme.accentColor,
            onSecondary: theme.textColor,
            surface: theme.surfaceColor,
            onSurface: theme.textColor,
            primaryContainer: theme.cardColor,
            onPrimaryContainer: theme.textColor,
            outline: theme.textColor.withAlpha(70),
          )
        : ColorScheme.light(
            primary: theme.primaryColor,
            onPrimary: Colors.white,
            secondary: theme.accentColor,
            onSecondary: theme.textColor,
            surface: theme.surfaceColor,
            onSurface: theme.textColor,
            primaryContainer: theme.cardColor,
            onPrimaryContainer: theme.textColor,
            outline: theme.textColor.withAlpha(60),
          );

    final baseTextTheme = ThemeData(brightness: theme.brightness).textTheme;
    final borderColor = colorScheme.outline.withAlpha(85);

    return ThemeData(
      useMaterial3: true,
      brightness: theme.brightness,
      scaffoldBackgroundColor: theme.surfaceColor,
      colorScheme: colorScheme,
      canvasColor: theme.surfaceColor,
      shadowColor: colorScheme.shadow,
      cardColor: theme.cardColor,
      splashColor: theme.accentColor.withAlpha(24),
      highlightColor: theme.accentColor.withAlpha(16),
      textTheme: baseTextTheme.apply(
        bodyColor: theme.textColor,
        displayColor: theme.textColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: theme.cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(theme.primaryColor),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          elevation: MaterialStateProperty.all(0),
          padding: MaterialStateProperty.all(
            EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(theme.textColor),
          side: MaterialStateProperty.all(
            BorderSide(color: borderColor),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: theme.isDark ? const Color(0xFF182433) : theme.primaryColor,
        contentTextStyle: TextStyle(
          color: theme.isDark ? theme.textColor : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dividerColor: colorScheme.outline.withAlpha(40),
      iconTheme: IconThemeData(color: theme.textColor),
    );
  }
}
