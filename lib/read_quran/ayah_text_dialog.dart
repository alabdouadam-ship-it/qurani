import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';

/// Shows a scrollable text dialog with a Close action. Used for ayah
/// translations and tafsir so the two previous methods
/// (`_showTranslation`, `_showTafsir`) share a single implementation.
Future<void> showAyahTextDialog(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      );
    },
  );
}
