import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/models/repetition_passage.dart';
import 'package:qurani/models/surah.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/widgets/repetition_passage_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

const surahs = [
  Surah(order: 1, name: 'Al-Fatiha', totalVerses: 7),
  Surah(order: 2, name: 'Al-Baqara', totalVerses: 286),
  Surah(order: 3, name: 'Al-Imran', totalVerses: 200),
];
const example = (start: (surah: 1, verse: 6), end: (surah: 2, verse: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('inclusive bounds, intermediate surahs and invalid saved endpoints', () {
    final verses = [
      for (final s in surahs)
        for (int v = 1; v <= s.totalVerses; v++)
          if (example.contains(s.order, v)) (s.order, v),
    ];
    expect(verses, [(1, 6), (1, 7), (2, 1), (2, 2), (2, 3)]);
    const longer = (start: (surah: 1, verse: 7), end: (surah: 3, verse: 1));
    expect(longer.contains(2, 286), isTrue);
    expect(example.withStart((surah: 3, verse: 1)).end, (surah: 3, verse: 1));
    expect((start: example.end, end: example.start).isValid(surahs), isFalse);
    expect((start: example.start, end: (surah: 2, verse: 287)).isValid(surahs),
        isFalse);
  });
  test('five verses, two listens, three passes, then stop', () {
    RepetitionPosition? position = (verseIndex: 0, repeat: 0, pass: 0);
    final heard = <int>[];
    while (position != null) {
      heard.add(position.verseIndex);
      position = position.next(5, 2, 3);
    }
    expect(heard, List.generate(30, (i) => (i ~/ 2) % 5));
    expect((verseIndex: 0, repeat: 0, pass: 0).next(1, 1, 1), isNull);
  });
  test('remember defaults on, restores all four values and persists opt-out',
      () async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    expect(PreferencesService.rememberPassage, isTrue);
    expect(PreferencesService.lastPassage, openingPassage);
    await PreferencesService.savePassage(example, true);
    await PreferencesService.init();
    expect(PreferencesService.lastPassage, example);
    await PreferencesService.savePassage(example, false);
    await PreferencesService.init();
    expect(PreferencesService.rememberPassage, isFalse);
    expect(PreferencesService.lastPassage, openingPassage);
  });

  for (final lang in ['ar', 'fr', 'en']) {
    testWidgets(
        'localized passage editor validates and applies a draft ($lang)',
        (tester) async {
      RepetitionPassage? applied;
      bool? remember;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(lang),
        home: Scaffold(
            body: RepetitionPassageEditor(
          surahs: surahs,
          passage: openingPassage,
          remember: true,
          onApply: (p, r) {
            applied = p;
            remember = r;
          },
        )),
      ));
      await tester.pumpAndSettle();
      final editor = tester.element(find.byType(RepetitionPassageEditor));
      expect(Directionality.of(editor),
          lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      final l10n = AppLocalizations.of(editor)!;
      expect(find.text(l10n.passageStartSurah), findsOneWidget);
      List<DropdownButton<int>> fields() => tester
          .widgetList<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .toList();
      expect(fields()[1].items!.length, 7);
      fields()[1].onChanged!(6);
      await tester.pump();
      expect(fields()[3].items!.first.value, 6);
      fields()[2].onChanged!(2);
      await tester.pump();
      expect(fields()[3].items!.length, 286);
      fields()[3].onChanged!(3);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(applied, isNull);
      await tester.tap(find.text(l10n.applyPassage));
      expect(applied, example);
      expect(remember, isFalse);
    });

    testWidgets(
        'searchable surah dropdown and surah buttons picker filter and select surahs ($lang)',
        (tester) async {
      RepetitionPassage? applied;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(lang),
        home: Scaffold(
          body: RepetitionPassageEditor(
            surahs: surahs,
            passage: openingPassage,
            remember: true,
            onApply: (p, _) => applied = p,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final editor = tester.element(find.byType(RepetitionPassageEditor));
      final l10n = AppLocalizations.of(editor)!;

      // 1. Open Start Surah searchable dropdown list, search "Imran", and cancel via Back button
      await tester.tap(find.byKey(
          const ValueKey('start_surah_searchable_dropdown_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('surah_picker_search_field')),
          findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('surah_picker_search_field')), 'Imran');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('surah_list_item_1')), findsNothing);
      expect(find.byKey(const ValueKey('surah_list_item_3')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('surah_picker_back_button')));
      await tester.pumpAndSettle();

      // 2. Open End Surah dropdown, switch to Surah Buttons mode inside the picker, search "2", and tap the Surah button
      await tester.tap(
          find.byKey(const ValueKey('end_surah_searchable_dropdown_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('surah_picker_mode_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('surah_picker_search_field')), '2');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('surah_button_item_1')), findsNothing);
      expect(find.byKey(const ValueKey('surah_button_item_2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('surah_button_item_2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.applyPassage));
      expect(applied?.end.surah, 2);
    });
  }
}
