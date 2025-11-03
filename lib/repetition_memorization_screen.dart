import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'responsive_config.dart';
import 'widgets/surah_grid.dart';
import 'models/surah.dart';
import 'repetition_range_screen.dart';

class RepetitionMemorizationScreen extends StatelessWidget {
  const RepetitionMemorizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.repetitionMemorization,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
      ),
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


