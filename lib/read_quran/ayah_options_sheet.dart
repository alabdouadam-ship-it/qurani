import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_repository.dart';

import 'highlight_models.dart';

/// Modal bottom sheet presenting the long-press options for an ayah:
/// highlight/un-highlight, share, translations (AR/EN/FR), and tafsir.
/// Returns the selected [AyahAction] (or `null` on dismiss); the caller
/// performs the side-effect for each case.
///
/// Previously the private `_showAyahOptions` in `read_quran_screen.dart`.
Future<AyahAction?> showAyahOptionsSheet(
  BuildContext context, {
  required AyahData ayah,
  required bool isHighlighted,
  required QuranEdition edition,
}) {
  return showModalBottomSheet<AyahAction>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_add),
              title: Text(isHighlighted ? l10n.bookmarks : l10n.addHighlight),
              onTap: () => Navigator.pop(sheetContext, AyahAction.pickColor),
            ),
            if (isHighlighted)
              ListTile(
                leading: const Icon(Icons.bookmark_remove),
                title: Text(l10n.removeHighlight),
                onTap: () =>
                    Navigator.pop(sheetContext, AyahAction.removeHighlight),
              ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(l10n.shareAyah),
              onTap: () => Navigator.pop(sheetContext, AyahAction.share),
            ),
            if (edition == QuranEdition.english ||
                edition == QuranEdition.french)
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.showArabicText),
                onTap: () =>
                    Navigator.pop(sheetContext, AyahAction.translateArabic),
              ),
            if (edition != QuranEdition.english)
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l10n.showEnglishTranslation),
                onTap: () =>
                    Navigator.pop(sheetContext, AyahAction.translateEnglish),
              ),
            if (edition != QuranEdition.french)
              ListTile(
                leading: const Icon(Icons.g_translate),
                title: Text(l10n.showFrenchTranslation),
                onTap: () =>
                    Navigator.pop(sheetContext, AyahAction.translateFrench),
              ),
            if (!edition.isTranslation && !edition.isTafsir)
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(l10n.showTafsir),
                onTap: () => Navigator.pop(sheetContext, AyahAction.tafsir),
              ),
          ],
        ),
      );
    },
  );
}
