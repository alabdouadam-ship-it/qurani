import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_repository.dart';

import 'edition_label.dart';

/// A simple two-level edition picker bottom sheet.
///
/// Level 1 lists the Arabic scripts directly, then a "Translations ›" row and
/// a "Tafsir ›" row. Tapping a category swaps the sheet body to that category's
/// list (with a back arrow). Returns the chosen [QuranEdition], or null on
/// dismiss. A bottom sheet (not nested popup menus) is used because it gives
/// big tap targets, scrolls cleanly for many tafsir books, and reads correctly
/// in RTL — friendlier for non-technical users.
///
/// [selectable] optionally narrows what may be offered. The secondary-edition
/// pickers use it to drop `irab` and, for the fallback, whatever the preferred
/// secondary already covers. A category row is hidden when nothing in it
/// survives the filter, so the user never opens an empty submenu.
Future<QuranEdition?> showEditionPickerSheet(
  BuildContext context, {
  required QuranEdition current,
  List<QuranEdition>? selectable,
}) {
  return showModalBottomSheet<QuranEdition>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      // Always start at the top-level menu (Arabic scripts + Translations ›
      // + Tafsir ›), regardless of which edition is currently selected, so the
      // picker is reinitialized on every open.
      EditionCategory? openCategory;

      final Set<String>? allowedIds =
          selectable == null ? null : {for (final e in selectable) e.id};
      List<QuranEdition> allow(List<QuranEdition> list) => allowedIds == null
          ? list
          : list.where((e) => allowedIds.contains(e.id)).toList();

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);

          Widget tile(QuranEdition e) => ListTile(
                leading: e == current
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : const SizedBox(width: 24),
                title: Text(editionLabel(e, l10n)),
                onTap: () => Navigator.pop(sheetContext, e),
              );

          Widget categoryRow(String label, EditionCategory cat) => ListTile(
                leading: Icon(
                  cat == EditionCategory.tafsir
                      ? Icons.menu_book_outlined
                      : Icons.translate_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setSheetState(() => openCategory = cat),
              );

          final List<Widget> body;
          if (openCategory == null) {
            final scripts = allow(QuranEditions.arabicScripts);
            final translations = allow(QuranEditions.translations);
            final tafsirs = allow(QuranEditions.tafsirs);
            body = [
              ...scripts.map(tile),
              if (scripts.isNotEmpty &&
                  (translations.isNotEmpty || tafsirs.isNotEmpty))
                const Divider(),
              if (translations.isNotEmpty)
                categoryRow(l10n.editionTranslationsCategory,
                    EditionCategory.translation),
              if (tafsirs.isNotEmpty)
                categoryRow(
                    l10n.editionTafsirCategory, EditionCategory.tafsir),
            ];
          } else {
            final list = allow(openCategory == EditionCategory.translation
                ? QuranEditions.translations
                : QuranEditions.tafsirs);
            body = [
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: Text(openCategory == EditionCategory.translation
                    ? l10n.editionTranslationsCategory
                    : l10n.editionTafsirCategory),
                onTap: () => setSheetState(() => openCategory = null),
              ),
              const Divider(height: 1),
              ...list.map(tile),
            ];
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...body,
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
