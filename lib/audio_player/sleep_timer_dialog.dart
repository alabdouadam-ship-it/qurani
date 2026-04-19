import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shows the sleep-timer radio dialog. Invokes [onSet] exactly once — with
/// `null` when the user picks "Off" or the dedicated Off action, or with the
/// chosen minute value when they confirm. Preserves the original behaviour
/// of the inline `_showSleepTimerDialog`.
Future<void> showSleepTimerDialog(
  BuildContext context, {
  required int? currentMinutes,
  required ValueChanged<int?> onSet,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      int? tempSelected = currentMinutes;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.sleepTimer),
            content: RadioGroup<int?>(
              groupValue: tempSelected,
              onChanged: (value) =>
                  setDialogState(() => tempSelected = value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int?>(
                    title: Text(l10n.off),
                    value: null,
                  ),
                  RadioListTile<int?>(
                    title: Text('15 ${l10n.minutes}'),
                    value: 15,
                  ),
                  RadioListTile<int?>(
                    title: Text('30 ${l10n.minutes}'),
                    value: 30,
                  ),
                  RadioListTile<int?>(
                    title: Text('60 ${l10n.minutes}'),
                    value: 60,
                  ),
                  RadioListTile<int?>(
                    title: Text('90 ${l10n.minutes}'),
                    value: 90,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  onSet(null);
                  Navigator.pop(dialogContext);
                },
                child: Text(l10n.off),
              ),
              TextButton(
                onPressed: () {
                  onSet(tempSelected);
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    },
  );
}
