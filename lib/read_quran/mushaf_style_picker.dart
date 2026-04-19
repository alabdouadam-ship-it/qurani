import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/mushaf_pdf_service.dart';

/// Shows a modal bottom sheet letting the user pick a [MushafType].
/// Invokes [onSelected] with the chosen type (only when it differs from
/// [currentType]); the caller is responsible for reacting (e.g. updating
/// preferences and reloading the PDF).
///
/// Previously the private `_showMushafStylePicker` in
/// `read_quran_screen.dart`.
Future<void> showMushafStylePickerSheet(
  BuildContext context, {
  required MushafType currentType,
  required ValueChanged<MushafType> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.mushafStyle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ...MushafType.values.map((type) {
                String typeName;
                switch (type) {
                  case MushafType.blue:
                    typeName = l10n.mushafTypeBlue;
                    break;
                  case MushafType.green:
                    typeName = l10n.mushafTypeGreen;
                    break;
                  case MushafType.tajweed:
                    typeName = l10n.mushafTypeTajweed;
                    break;
                }

                return ListTile(
                  title: Text(typeName),
                  trailing: currentType == type
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (currentType != type) {
                      onSelected(type);
                    }
                  },
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
