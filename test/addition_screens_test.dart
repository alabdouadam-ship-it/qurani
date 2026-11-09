import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/backup_screen.dart';
import 'package:qurani/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Widget app(String lang, Widget screen) => ProviderScope(
      child: MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen));
  for (final lang in ['ar', 'en', 'fr']) {
    testWidgets('backup actions work in $lang',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app(lang, const BackupScreen()));
      await tester.pumpAndSettle();
      final l10n =
          AppLocalizations.of(tester.element(find.byType(BackupScreen)))!;
      expect(find.text(l10n.backupExport), findsOneWidget);
      expect(find.text(l10n.backupImport), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('settings labels and icons fit on a narrow screen in $lang',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(app(lang, const SettingsScreen()));
      final tiles = find.byType(ListTile);
      expect(tiles, findsNWidgets(9));
      for (final tile in tiles.evaluate().map((e) => e.widget)) {
        final item = tile as ListTile;
        final button = find.byWidget(item);
        await tester.ensureVisible(button);
        final bounds = tester.getRect(button);
        final title = tester.getRect(find.byWidget(item.title!));
        final icon = tester.getRect(find.byWidget(item.leading!));
        expect(bounds.contains(title.center), isTrue);
        expect(title.bottom, lessThanOrEqualTo(bounds.bottom));
        expect(bounds.contains(icon.center), isTrue);
        expect(icon.overlaps(title), isFalse);
        final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: find.byWidget(item.title!), matching: find.byType(RichText)));
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
