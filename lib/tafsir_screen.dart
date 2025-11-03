import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'responsive_config.dart';

class TafsirScreen extends StatelessWidget {
  const TafsirScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.tafsir,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
      ),
      body: Center(
        child: Text(
          l10n.tafsir,
          style: TextStyle(
            fontSize: ResponsiveConfig.getFontSize(context, 18),
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}


