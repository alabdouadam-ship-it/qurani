import 'dart:ui' show Locale;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/preferences_service.dart';

part 'app_state_providers.g.dart';

/// Notifier for the app locale.
///
/// Class is intentionally named `LocaleNotifier` rather than `Locale` because
/// `Locale` would collide with `dart:ui.Locale` (the state type). Codegen
/// therefore generates `localeNotifierProvider`; the `localeProvider`
/// forwarder below preserves the pre-codegen public name so every
/// `ref.watch(localeProvider)` / `ref.read(localeProvider.notifier).setLocale`
/// callsite continues to work unchanged.
@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale build() {
    final langCode = PreferencesService.getLanguage();
    return Locale(langCode);
  }

  void setLocale(Locale locale) {
    PreferencesService.saveLanguage(locale.languageCode);
    state = locale;
  }
}

/// Back-compat alias for the pre-codegen `localeProvider` symbol.
final localeProvider = localeNotifierProvider;

/// Notifier for the app theme id.
///
/// Name stays `ThemeNotifier` to avoid colliding with Material's `Theme`
/// widget when callers import both `material.dart` and this file. See the
/// `localeProvider` note above.
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  String build() {
    return PreferencesService.getTheme();
  }

  void setTheme(String themeId) {
    PreferencesService.saveTheme(themeId);
    state = themeId;
  }
}

/// Back-compat alias for the pre-codegen `themeProvider` symbol.
final themeProvider = themeNotifierProvider;

/// Notifier for the set of user-disabled screen ids.
@riverpod
class DisabledScreensNotifier extends _$DisabledScreensNotifier {
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

/// Back-compat alias for the pre-codegen `disabledScreensProvider` symbol.
final disabledScreensProvider = disabledScreensNotifierProvider;
