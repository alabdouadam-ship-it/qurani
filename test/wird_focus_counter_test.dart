import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/models/wird_model.dart';
import 'package:qurani/widgets/wird_focus_counter.dart';

void main() {
  testWidgets('Arabic counter remains tappable after rotating a short phone',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var wird = Wird.create(
      title: 'استغفار',
      dhikrText: List.filled(20, 'أستغفر الله').join(' '),
      targetCount: 100,
      daysOfWeek: [1],
    ).copyWith(currentCount: 98);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
          appBar: AppBar(),
          body: StatefulBuilder(
            builder: (context, setState) => WirdFocusCounter(
              wird: wird,
              onTap: () => setState(() =>
                  wird = wird.copyWith(currentCount: wird.currentCount + 1)),
            ),
          )),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('98'));
    await tester.tap(find.text('98'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(780, 300);
    await tester.pumpAndSettle();
    expect(find.text('99').hitTestable(), findsOneWidget);
    await tester.tap(find.text('99'));
    await tester.pump();
    expect(find.text('100').hitTestable(), findsOneWidget);
    expect(
        find.byIcon(Icons.check_circle_rounded).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
