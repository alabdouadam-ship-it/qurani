// Smoke tests for the app's theme + localization wiring.
//
// NOTE: We intentionally do NOT pump the full `QuraniApp` widget here.
// `QuraniApp`'s home (`OptionsScreen`) kicks off plugin- and network-backed
// work in `initState`/`didChangeDependencies` (NewsService→dio, prayer-times
// DB via path_provider, in_app_update), none of which have a platform binding
// in a plain `flutter test` and would make this smoke test flaky.
//
// Instead we verify the pieces that are pure Dart/Flutter: that a
// `ProviderScope` + `MaterialApp` built from `AppThemeConfig` mounts and
// renders, and that theme resolution behaves as the app relies on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qurani/themes/app_theme_config.dart';

void main() {
  testWidgets('MaterialApp built from AppThemeConfig mounts and renders',
      (WidgetTester tester) async {
    final theme = AppThemeConfig.getTheme(AppThemeConfig.defaultThemeId);
    final themeData = AppThemeConfig.themeDataFor(theme.id);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: themeData,
          home: const Scaffold(
            body: Center(child: Text('Qurani')),
          ),
        ),
      ),
    );

    expect(find.text('Qurani'), findsOneWidget);
    // The resolved ThemeData should carry the theme's surface color as the
    // scaffold background, confirming themeDataFor wired the option through.
    final BuildContext context = tester.element(find.text('Qurani'));
    expect(Theme.of(context).scaffoldBackgroundColor, theme.surfaceColor);
  });

  group('AppThemeConfig.resolveThemeId', () {
    test('returns the default theme for null/empty input', () {
      expect(AppThemeConfig.resolveThemeId(null), AppThemeConfig.defaultThemeId);
      expect(AppThemeConfig.resolveThemeId(''), AppThemeConfig.defaultThemeId);
    });

    test('passes through a known theme id unchanged', () {
      expect(AppThemeConfig.resolveThemeId('dark'), 'dark');
    });

    test('maps a legacy alias to its replacement', () {
      // 'gray'/'gold'/'brown' etc. were folded into 'warmSand'.
      expect(AppThemeConfig.resolveThemeId('gold'), 'warmSand');
    });

    test('falls back to default for an unknown id', () {
      expect(
        AppThemeConfig.resolveThemeId('no-such-theme'),
        AppThemeConfig.defaultThemeId,
      );
    });
  });
}
