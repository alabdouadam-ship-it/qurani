import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_constants.dart';

/// Shows a modal bottom sheet listing all 30 juz with their starting
/// page, and resolves to the chosen page number (or `null` on dismiss).
///
/// Previously the private `_openJuzPicker` in `read_quran_screen.dart`.
Future<int?> showJuzPickerSheet(BuildContext context) async {
  final entries = juzStartPages.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final selected = await showModalBottomSheet<MapEntry<int, int>>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              l10n.chooseJuz,
              style: Theme.of(sheetContext)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text('${l10n.juzLabel} ${entry.key}'),
                    subtitle: Text('${l10n.page} ${entry.value}'),
                    onTap: () => Navigator.pop(sheetContext, entry),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: entries.length,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
  return selected?.value;
}
