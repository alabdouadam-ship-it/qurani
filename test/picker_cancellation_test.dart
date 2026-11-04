import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/read_quran/page_picker_sheet.dart';
import 'package:qurani/widgets/repetition_passage_editor.dart';
import 'package:qurani/models/repetition_passage.dart';
import 'package:qurani/models/surah.dart';

void main() {
  for (final lang in ['ar', 'fr', 'en']) {
    testWidgets('cancel focused page picker during closing animation ($lang)',
        (tester) async {
      int? result = 99;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async {
                    result = await showPagePickerSheet(context,
                        currentPage: 1, totalPages: 604);
                  },
                  child: const Text('open'),
                ))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '20');
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(TextField)))!;
      await tester.tap(find.text(l10n.cancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result, isNull);
    });
    testWidgets(
        'cancel repetition start dropdown and dismiss unsaved settings ($lang)',
        (tester) async {
      RepetitionPassage applied = openingPassage;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => RepetitionPassageEditor(
                              surahs: const [
                                Surah(
                                    order: 1,
                                    name: 'Al-Fatiha',
                                    totalVerses: 7),
                                Surah(
                                    order: 2,
                                    name: 'Al-Baqara',
                                    totalVerses: 286)
                              ],
                              passage: applied,
                              remember: true,
                              onApply: (p, r) {
                                applied = p;
                                Navigator.pop(context);
                              },
                            )),
                    child: const Text('open')))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final index in [0, 1, 2, 3]) {
        await tester.tap(find.byType(DropdownButton<int>).at(index));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final startVerse = tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>).at(1));
      startVerse.onChanged!(6);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(applied, openingPassage);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<DropdownButton<int>>(
                  find.byType(DropdownButton<int>).at(1))
              .value,
          1);
    });
  }
}
