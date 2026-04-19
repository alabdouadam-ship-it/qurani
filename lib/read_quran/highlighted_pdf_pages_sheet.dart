import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_constants.dart';
import 'package:qurani/services/quran_repository.dart';

/// Shows the list of bookmarked PDF pages as a modal bottom sheet.
/// Tapping a row invokes [onOpenPage]; tapping the trash icon invokes
/// [onDeletePage]. Both callbacks receive the page number; the caller is
/// responsible for toggling the stored bookmark and for navigating.
///
/// Previously the private `_openHighlightedPdfPagesSheet` in
/// `read_quran_screen.dart`.
Future<void> showHighlightedPdfPagesSheet(
  BuildContext context, {
  required List<int> sortedPages,
  required Future<List<SurahMeta>> surahListFuture,
  required ValueChanged<int> onOpenPage,
  required ValueChanged<int> onDeletePage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                l10n.bookmarks,
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (sortedPages.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(l10n.noBookmarks),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sortedPages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final page = sortedPages[index];
                    int surahNum = 1;
                    for (final entry in surahStartPages.entries) {
                      if (entry.value <= page) {
                        if (entry.key > surahNum) surahNum = entry.key;
                      }
                    }

                    return FutureBuilder<List<SurahMeta>>(
                      future: surahListFuture,
                      builder: (context, snapshot) {
                        String subtitle = '${l10n.page} $page';
                        if (snapshot.hasData) {
                          final s = snapshot.data!.firstWhere(
                            (s) => s.number == surahNum,
                            orElse: () => snapshot.data!.first,
                          );
                          subtitle = '${s.name} • $subtitle';
                        }

                        return ListTile(
                          leading: Icon(Icons.bookmark,
                              color: theme.colorScheme.primary),
                          title: Text(subtitle,
                              textDirection: TextDirection.rtl),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              onDeletePage(page);
                            },
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onOpenPage(page);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
