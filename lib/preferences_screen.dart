import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
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
  final TextEditingController _nameController = TextEditingController();
  String? _selectedReciter;
  String? _selectedTheme;
  String? _selectedLanguage;
  double _selectedFontSize = 22.0;
  String _selectedArabicFont = ArabicFontUtils.fontAmiri;
  final List<String> _fontKeys = const [
    ArabicFontUtils.fontAmiri,
    ArabicFontUtils.fontScheherazade,
    ArabicFontUtils.fontLateef,
  ];
  final Map<String, Map<String, String>> _arabicFontLabels = {
    ArabicFontUtils.fontAmiri: {
      'ar': 'أميري قرآن',
      'en': 'Amiri Quran',
      'fr': 'Amiri Quran',
    },
    ArabicFontUtils.fontScheherazade: {
      'ar': 'شهرزاد الجديدة',
      'en': 'Scheherazade New',
      'fr': 'Scheherazade New',
    },
    ArabicFontUtils.fontLateef: {
      'ar': 'لطيف',
      'en': 'Lateef',
      'fr': 'Lateef',
    },
  };
  int _verseRepeatCount = 10;
  // Removed unused Quran version labels

  // Removed unused Quran version mapping helpers
  
  // Reciter options (key: reciter code matching folder name; values: localized display names)
  final Map<String, Map<String, String>> _reciterMap = {
    'basit': {
      'ar': 'عبدالباسط عبدالصمد',
      'en': 'Abdulbasit Abdulsamad',
      'fr': 'Abdulbasit Abdulsamad',
    },
    'afs': {
      'ar': 'العفاسي',
      'en': 'Mishary Alafasy',
      'fr': 'Mishary Alafasy',
    },
    'sds': {
      'ar': 'عبدالرحمن السديس',
      'en': 'Abdulrahman Al Sudais',
      'fr': 'Abdulrahman Al Sudais',
    },
    'frs_a': {
      'ar': 'فارس عباد',
      'en': 'Fares Abbad',
      'fr': 'Fares Abbad',
    },
    'husr': {
      'ar': 'الحصري',
      'en': 'Mahmoud Al Husary',
      'fr': 'Mahmoud Al Husary',
    },
    'minsh': {
      'ar': 'المنشاوي',
      'en': 'Mohamed Al Manshawi',
      'fr': 'Mohamed Al Manshawi',
    },
    'suwaid': {
      'ar': 'أيمن سويد',
      'en': 'Ayman Suwaid',
      'fr': 'Ayman Suwaid',
    },
  };
  
  // Theme options (placeholder only, no actual options yet)
  
  // Removed unused Tafsir labels

  // Get keys only (Arabic names for saving)
  List<String> get _reciterKeys => _reciterMap.keys.toList();
  // Removed unused _tafsirKeys
  
  // Theme options with codes and localized display names
  static const String _themeGreen = 'green';
  static const String _themeBlue = 'blue';
  static const String _themePink = 'pink';
  static const String _themeDark = 'dark';

  // Display labels per language code
  final Map<String, Map<String, String>> _themeLabels = {
    _themeGreen: {
      'ar': 'أخضر',
      'en': 'Green',
      'fr': 'Vert',
    },
    _themeBlue: {
      'ar': 'أزرق',
      'en': 'Blue',
      'fr': 'Bleu',
    },
    _themePink: {
      'ar': 'وردي',
      'en': 'Pink',
      'fr': 'Rose',
    },
    _themeDark: {
      'ar': 'داكن',
      'en': 'Dark',
      'fr': 'Sombre',
    },
  };

  List<String> _getThemeDisplayNames(BuildContext context) {
    final langCode = _getCurrentLangCode(context);
    return [_themeGreen, _themeBlue, _themePink, _themeDark]
        .map((code) => _themeLabels[code]![langCode]!)
        .toList();
  }

  String? _getThemeLabelFromCode(String? code, BuildContext context) {
    if (code == null) return null;
    final langCode = _getCurrentLangCode(context);
    return _themeLabels[code]?[langCode];
  }

  String? _getThemeCodeFromLabel(String? label, BuildContext context) {
    if (label == null) return null;
    final langCode = _getCurrentLangCode(context);
    for (final entry in _themeLabels.entries) {
      if (entry.value[langCode] == label) return entry.key;
    }
    return null;
  }
  
  @override
  void initState() {
    super.initState();
    _nameController.text = PreferencesService.getUserName();
    // Load saved reciter key and convert to display name
    final savedReciterKey = PreferencesService.getReciter();
    
    _selectedTheme = PreferencesService.getTheme();
    final savedLang = PreferencesService.getLanguage();
    _selectedLanguage = savedLang == 'en' ? 'en' : savedLang == 'fr' ? 'fr' : 'ar';
    _selectedFontSize = PreferencesService.getFontSize();
    _verseRepeatCount = PreferencesService.getVerseRepeatCount();
    _selectedArabicFont = PreferencesService.getArabicFontFamily();
    if (!_fontKeys.contains(_selectedArabicFont)) {
      _selectedArabicFont = ArabicFontUtils.fontAmiri;
    }
    
    // Note: We'll convert keys to display names in build method after context is available
    _selectedReciter = _reciterMap.containsKey(savedReciterKey) ? savedReciterKey : 'afs';
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

  Widget _buildVerseRepeatSection(BuildContext context) {
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.repeat,
                    color: theme.colorScheme.secondary,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.verseRepeatCount,
                        style: TextStyle(
                          fontSize: ResponsiveConfig.getFontSize(context, 16),
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.verseRepeatCountHint,
                        style: TextStyle(
                          fontSize: ResponsiveConfig.getFontSize(context, 13),
                          color: theme.colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _verseRepeatCount.toDouble(),
                    min: 1,
                    max: 25,
                    divisions: 24,
                    label: '$_verseRepeatCount',
                    onChanged: (value) {
                      setState(() {
                        _verseRepeatCount = value.round();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_verseRepeatCount',
                    style: TextStyle(
                      fontSize: ResponsiveConfig.getFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Get current language code from context locale
  String _getCurrentLangCode(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode;
  }

  // Get display names for reciters based on current language
  List<String> _getReciterDisplayNames(BuildContext context) {
    final langCode = _getCurrentLangCode(context);
    return _reciterKeys.map((key) => _reciterMap[key]![langCode]!).toList();
  }

  // Get display names for tafsir based on current language
  // Removed unused Tafsir mapping helpers

  // Get Arabic key from display name
  String? _getReciterKeyFromDisplayName(String? displayName, BuildContext context) {
    if (displayName == null) return null;
    final langCode = _getCurrentLangCode(context);
    for (var entry in _reciterMap.entries) {
      if (entry.value[langCode] == displayName) return entry.key;
    }
    return null;
  }



  // Get display name from saved Arabic key
  String? _getReciterDisplayNameFromKey(String? key, BuildContext context) {
    final langCode = _getCurrentLangCode(context);
    final lookupKey = (key != null && _reciterMap.containsKey(key)) ? key : 'afs';
    return _reciterMap[lookupKey]?[langCode];
  }



  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.preferences,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.light,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveConfig.getPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withAlpha((255 * 0.1).round()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person, color: Colors.teal, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.name,
                            style: TextStyle(
                              fontSize: ResponsiveConfig.getFontSize(context, 16),
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: l10n.enterYourName,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            const Color(0xFF2C2C2C),
                            const Color(0xFF1E1E1E),
                          ]
                        : [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withAlpha((255 * 0.5).round())
                          : Theme.of(context).colorScheme.primary.withAlpha((255 * 0.3).round()),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.tune,
                      size: isSmallScreen ? 40 : 50,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              _buildDropdownSection(
                context,
                title: l10n.reciter,
                icon: Icons.mic,
                iconColor: Colors.purple,
                initialValue: _getReciterDisplayNameFromKey(
                      (_selectedReciter == null || _selectedReciter!.isEmpty) ? 'afs' : _selectedReciter!,
                      context,
                    ) ??
                    _getReciterDisplayNames(context).first,
                items: _getReciterDisplayNames(context),
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _selectedReciter = _getReciterKeyFromDisplayName(value, context) ?? 'afs';
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildDropdownSection(
                context,
                title: l10n.theme,
                icon: Icons.palette,
                iconColor: Colors.orange,
                initialValue: _getThemeLabelFromCode(_selectedTheme ?? 'green', context)!,
                items: _getThemeDisplayNames(context),
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _selectedTheme = _getThemeCodeFromLabel(value, context) ?? 'green';
                  });
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              _buildVerseRepeatSection(context),
              const SizedBox(height: 16),
              _buildDropdownSection(
                context,
                title: l10n.language,
                icon: Icons.language,
                iconColor: Colors.teal,
                initialValue: _selectedLanguage != null ? _getLanguageNameFromCode(_selectedLanguage!, context) : l10n.arabic,
                items: _getLanguageOptions(context),
                onChanged: (String? value) async {
                  final newLangCode = _getLanguageCode(value!, context);
                  setState(() {
                    _selectedLanguage = newLangCode;
                  });
                  // Wait for saving language before updating locale
                  await PreferencesService.saveLanguage(newLangCode);
                  // Update app locale after saving
                  QuraniApp.of(context).setLocale(Locale(newLangCode));
                  // Force rebuild to update all dropdowns
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 24),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
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
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withAlpha((255 * 0.5).round())),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withAlpha((255 * 0.5).round())),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
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
    // Persist
    await PreferencesService.saveUserName(_nameController.text.trim());
    await PreferencesService.saveReciter(_selectedReciter ?? 'afs');
    await PreferencesService.saveTheme(_selectedTheme ?? 'green');
    await PreferencesService.saveFontSize(_selectedFontSize);
    await PreferencesService.saveVerseRepeatCount(_verseRepeatCount);
    await PreferencesService.saveArabicFontFamily(_selectedArabicFont);
      // Theme change will be handled by the notifier in main.dart
    if (_selectedLanguage != null) {
      await PreferencesService.saveLanguage(_selectedLanguage!);
      // Update app locale after saving
      QuraniApp.of(context).setLocale(Locale(_selectedLanguage!));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.preferencesSavedSuccessfully),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    // Return to the previous screen (typically Settings)
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}



