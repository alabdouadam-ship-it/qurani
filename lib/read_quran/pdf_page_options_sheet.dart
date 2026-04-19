import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';

/// Shows a long-press options sheet for a PDF page. Currently the only
/// option is bookmark-toggle; extract point is deliberate so future
/// options (share, translate, etc.) can be added without touching the
/// reader screen.
///
/// Previously the private `_showPdfPageOptions` in
/// `read_quran_screen.dart`.
Future<void> showPdfPageOptionsSheet(
  BuildContext context, {
  required bool isHighlighted,
  required VoidCallback onToggleBookmark,
}) {
  return showModalBottomSheet<void>(
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
            ListTile(
              leading: Icon(
                isHighlighted ? Icons.bookmark_remove : Icons.bookmark_add,
                color: isHighlighted
                    ? Theme.of(sheetContext).colorScheme.error
                    : null,
              ),
              title: Text(
                  isHighlighted ? l10n.removeBookmark : l10n.bookmarkPage),
              onTap: () {
                Navigator.pop(sheetContext);
                onToggleBookmark();
              },
            ),
          ],
        ),
      );
    },
  );
}
