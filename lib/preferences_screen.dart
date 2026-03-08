import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/themes/app_theme_config.dart';
import 'package:qurani/widgets/theme_selector.dart';
import 'responsive_config.dart';
import 'services/preferences_service.dart';
import 'util/arabic_font_utils.dart';
import 'main.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {

  String? _selectedTheme;
  String? _selectedLanguage;
  double _selectedFontSize = 22.0;
  String _selectedArabicFont = ArabicFontUtils.fontAmiri;
  final List<String> _fontKeys = const [
    ArabicFontUtils.fontAmiri,
    ArabicFontUtils.fontKfgqpcSmall,
    ArabicFontUtils.fontKfgqpcLarge,
  ];
  final Map<String, Map<String, String>> _arabicFontLabels = {
    ArabicFontUtils.fontAmiri: {
      'ar': 'أميري قرآن',
      'en': 'Amiri Quran',
      'fr': 'Amiri Quran',
    },
    ArabicFontUtils.fontKfgqpcSmall: {
      'ar': 'حفص مجود (حروف صغيرة)',
      'en': 'KFGQPC Tajweed (Small)',
      'fr': 'KFGQPC Tajweed (petites lettres)',
    },
    ArabicFontUtils.fontKfgqpcLarge: {
      'ar': 'حفص مجود (حروف كبيرة)',
      'en': 'KFGQPC Tajweed (Large)',
      'fr': 'KFGQPC Tajweed (grandes lettres)',
    },
  };
  
  @override
  void initState() {
    super.initState();

    
    _selectedTheme = PreferencesService.getTheme();
    final savedLang = PreferencesService.getLanguage();
    _selectedLanguage = savedLang == 'en' ? 'en' : savedLang == 'fr' ? 'fr' : 'ar';
    _selectedFontSize = PreferencesService.getFontSize();
    _selectedArabicFont = PreferencesService.getArabicFontFamily();
    if (!_fontKeys.contains(_selectedArabicFont)) {
      _selectedArabicFont = ArabicFontUtils.fontAmiri;
    }
  }

  List<String> _getLanguageOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [l10n.arabic, l10n.english, l10n.french];
  }

  List<String> _getArabicFontDisplayNames(BuildContext context) {
    final langCode = _getCurrentLangCode(context);
    return _fontKeys.map((key) => _arabicFontLabels[key]![langCode]!).toList();
  }

  String _getArabicFontLabel(String? fontKey, BuildContext context) {
    final langCode = _getCurrentLangCode(context);
    final key = fontKey ?? ArabicFontUtils.fontAmiri;
    return _arabicFontLabels[key]?[langCode] ?? _arabicFontLabels[ArabicFontUtils.fontAmiri]![langCode]!;
  }

  String _getArabicFontKeyFromLabel(String label, BuildContext context) {
    final langCode = _getCurrentLangCode(context);
    for (final entry in _arabicFontLabels.entries) {
      if (entry.value[langCode] == label) {
        return entry.key;
      }
    }
    return ArabicFontUtils.fontAmiri;
  }

  String _getLanguageCode(String languageName, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (languageName == l10n.english) return 'en';
    if (languageName == l10n.french) return 'fr';
    return 'ar';
  }

  String _getLanguageNameFromCode(String code, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (code == 'en') return l10n.english;
    if (code == 'fr') return l10n.french;
    return l10n.arabic;
  }

  // Font size options
  List<String> _getFontSizeDisplayNames(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      '${l10n.small} (16)',
      '${l10n.medium} (20)',
      '${l10n.large} (24)',
      '${l10n.extraLarge} (28)',
    ];
  }

  String _getFontSizeDisplayName(double fontSize, BuildContext context) {
    // Snap any incoming value to the nearest step of 4: [16, 20, 24, 28]
    final steps = <double>[16, 20, 24, 28];
    double nearest = steps.first;
    double bestDiff = (fontSize - nearest).abs();
    for (final s in steps) {
      final d = (fontSize - s).abs();
      if (d < bestDiff) {
        bestDiff = d;
        nearest = s;
      }
    }
    final l10n = AppLocalizations.of(context)!;
    if (nearest == 16.0) return '${l10n.small} (16)';
    if (nearest == 20.0) return '${l10n.medium} (20)';
    if (nearest == 24.0) return '${l10n.large} (24)';
    if (nearest == 28.0) return '${l10n.extraLarge} (28)';
    return '${l10n.large} (24)';
  }

  double _getFontSizeFromDisplayName(String displayName, BuildContext context) {
    if (displayName.contains('16')) return 16.0;
    if (displayName.contains('20')) return 20.0;
    if (displayName.contains('24')) return 24.0;
    if (displayName.contains('28')) return 28.0;
    return 24.0;
  }



  // Get current language code from context locale
  String _getCurrentLangCode(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode;
  }

  // Get display names for reciters based on current language




  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    final l10n = AppLocalizations.of(context)!;
    final currentTheme = AppThemeConfig.getTheme(_selectedTheme);
    final overlayBrightness = Theme.of(context).brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.preferences,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: overlayBrightness,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              currentTheme.gradientColors.first.withAlpha(currentTheme.isDark ? 110 : 65),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: ResponsiveConfig.getPadding(context),
            child: _buildSingleColumnLayout(context, l10n, isSmallScreen),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleColumnLayout(BuildContext context, AppLocalizations l10n, bool isSmallScreen) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            children: [
              ThemeSelector(
                selectedThemeId: _selectedTheme ?? AppThemeConfig.defaultThemeId,
                onThemeSelected: (String themeId) async {
                  setState(() {
                    _selectedTheme = themeId;
                  });
                  await PreferencesService.saveTheme(themeId);
                },
              ),
              const SizedBox(height: 14),
              _buildDropdownSection(
                context,
                title: l10n.language,
                icon: Icons.language,
                iconColor: Colors.teal,
                initialValue: _selectedLanguage != null ? _getLanguageNameFromCode(_selectedLanguage!, context) : l10n.arabic,
                items: _getLanguageOptions(context),
                onChanged: (String? value) async {
                  final newLangCode = _getLanguageCode(value!, context);
                  final appState = QuraniApp.of(context);
                  setState(() {
                    _selectedLanguage = newLangCode;
                  });
                  await PreferencesService.saveLanguage(newLangCode);
                  if (!mounted) return;
                  appState.setLocale(Locale(newLangCode));
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 14),
              _buildDropdownSection(
                context,
                title: l10n.arabicFont,
                icon: Icons.font_download,
                iconColor: Colors.brown,
                initialValue: _getArabicFontLabel(_selectedArabicFont, context),
                items: _getArabicFontDisplayNames(context),
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _selectedArabicFont = _getArabicFontKeyFromLabel(value, context);
                  });
                },
              ),
              const SizedBox(height: 14),
              _buildDropdownSection(
                context,
                title: l10n.fontSize,
                icon: Icons.text_fields,
                iconColor: Colors.indigo,
                initialValue: _getFontSizeDisplayName(_selectedFontSize, context),
                items: _getFontSizeDisplayNames(context),
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _selectedFontSize = _getFontSizeFromDisplayName(value, context);
                  });
                },
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _savePreferences,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
            child: Text(
              l10n.savePreferences,
              style: TextStyle(
                fontSize: ResponsiveConfig.getFontSize(context, 16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }





  Widget _buildDropdownSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required String? initialValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(
            Theme.of(context).brightness == Brightness.dark ? 100 : 150,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withAlpha(36),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        iconColor.withAlpha(220),
                        iconColor.withAlpha(130),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveConfig.getFontSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: initialValue,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withAlpha((255 * 0.5).round())),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withAlpha((255 * 0.5).round())),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withAlpha(
                      Theme.of(context).brightness == Brightness.dark ? 180 : 235,
                    ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(
                fontSize: ResponsiveConfig.getFontSize(context, 14),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
              ),
              items: items.map((String item) {
                final l10n = AppLocalizations.of(context)!;
                final isPlaceholder = item == l10n.selectReciter;
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: ResponsiveConfig.getFontSize(context, 14),
                      color: isPlaceholder
                          ? Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.5).round())
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePreferences() async {
    final l10n = AppLocalizations.of(context)!;
    final appState = QuraniApp.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await PreferencesService.saveTheme(
      _selectedTheme ?? AppThemeConfig.defaultThemeId,
    );
    await PreferencesService.saveFontSize(_selectedFontSize);
    await PreferencesService.saveArabicFontFamily(_selectedArabicFont);
    if (_selectedLanguage != null) {
      await PreferencesService.saveLanguage(_selectedLanguage!);
      if (!mounted) return;
      appState.setLocale(Locale(_selectedLanguage!));
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.preferencesSavedSuccessfully),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}



