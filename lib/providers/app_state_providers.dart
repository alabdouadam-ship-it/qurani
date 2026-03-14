import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';

/// Provider for the app locale
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Listen to the legacy languageNotifier for now to stay synced
    // but eventually this notifier will handle the logic.
    final langCode = PreferencesService.getLanguage();
    return Locale(langCode);
  }

  void setLocale(Locale locale) {
    PreferencesService.saveLanguage(locale.languageCode);
    state = locale;
  }
}

/// Provider for the app theme ID
final themeProvider = NotifierProvider<ThemeNotifier, String>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<String> {
  @override
  String build() {
    return PreferencesService.getTheme();
  }

  void setTheme(String themeId) {
    PreferencesService.saveTheme(themeId);
    state = themeId;
  }
}

/// Provider for disabled screens
final disabledScreensProvider = NotifierProvider<DisabledScreensNotifier, Set<String>>(() {
  return DisabledScreensNotifier();
});

class DisabledScreensNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return PreferencesService.getDisabledScreens();
  }

  void toggleScreen(String screenId, bool isEnabled) {
    final current = state;
    final updated = Set<String>.from(current);
    if (isEnabled) {
      updated.remove(screenId);
    } else {
      updated.add(screenId);
    }
    PreferencesService.saveDisabledScreens(updated);
    state = updated;
  }
}
