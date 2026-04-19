import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';

import 'highlight_models.dart';

/// Shows the list of [entries] (caller-prepared) as a draggable bottom
/// sheet and resolves to the entry the user tapped (or `null` if the
/// sheet was dismissed).
///
/// The caller owns loading + sorting the entries so this file stays
/// decoupled from `QuranRepository`; previously `_openHighlightedAyahsSheet`
/// in `read_quran_screen.dart`.
Future<HighlightedAyah?> showHighlightedAyahsSheet(
  BuildContext context, {
  required List<HighlightedAyah> entries,
}) {
  return showModalBottomSheet<HighlightedAyah>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      final theme = Theme.of(sheetContext);
      final height =
          ((MediaQuery.of(sheetContext).size.height * 0.6).clamp(320.0, 520.0))
              .toDouble();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  l10n.highlightedAyahs,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(entry.color),
                          foregroundColor: Colors.black87,
                          child: Text(
                            entry.ayah.numberInSurah.toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          entry.ayah.surah.name,
                          textDirection: TextDirection.rtl,
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          '${entry.ayah.surah.englishName} • ${l10n.page} ${entry.ayah.page}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(sheetContext, entry),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
