import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'widgets/surah_grid.dart';
import 'widgets/modern_ui.dart';
import 'models/surah.dart';
import 'repetition_range_screen.dart';

class RepetitionMemorizationScreen extends StatelessWidget {
  const RepetitionMemorizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ModernPageScaffold(
      title: l10n.repetitionMemorization,
      icon: Icons.repeat_rounded,
      subtitle: l10n.localeName == 'ar'
          ? 'اختر السورة ثم حدّد المدى المناسب لمراجعة الحفظ بتكرار هادئ ومنظم.'
          : l10n.localeName == 'fr'
              ? 'Choisissez une sourate puis définissez la plage de répétition dans une interface plus claire.'
              : 'Choose a surah and set the repetition range in a calmer memorization flow.',
      body: SurahGrid(
        onTapSurah: (Surah s) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RepetitionRangeScreen(surah: s),
            ),
          );
        },
        showQueueActions: false,
        allowHighlight: false,
      ),
    );
  }
}


