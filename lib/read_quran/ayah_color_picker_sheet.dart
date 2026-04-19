import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';

/// Shows a bottom sheet offering four highlight colors. Invokes
/// [onColorPicked] with the ARGB int value chosen by the user (matching
/// the values stored by `PreferencesService.saveAyahHighlight`).
///
/// Previously the private `_showColorPicker` in `read_quran_screen.dart`.
Future<void> showAyahColorPickerSheet(
  BuildContext context, {
  required ValueChanged<int> onColorPicked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      final colors = <Map<String, Object>>[
        {
          'name': l10n.colorDefault,
          'value': 0xFFFFF7C2,
          'color': const Color(0xFFFFF7C2),
        },
        {
          'name': l10n.colorRed,
          'value': 0xFFFFCDD2,
          'color': Colors.red.shade100,
        },
        {
          'name': l10n.colorBlue,
          'value': 0xFFBBDEFB,
          'color': Colors.blue.shade100,
        },
        {
          'name': l10n.colorGreen,
          'value': 0xFFC8E6C9,
          'color': Colors.green.shade100,
        },
      ];

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.addHighlight,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ...colors.map(
              (c) => ListTile(
                leading: CircleAvatar(backgroundColor: c['color'] as Color),
                title: Text(c['name'] as String),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onColorPicked(c['value'] as int);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}
