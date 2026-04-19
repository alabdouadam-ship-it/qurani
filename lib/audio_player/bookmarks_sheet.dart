import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../l10n/app_localizations.dart';
import '../models/audio_bookmark.dart';
import '../models/surah.dart';
import '../services/preferences_service.dart';
import 'duration_formatter.dart';

/// Shows the bookmarks bottom sheet, with current-surah entries pinned first
/// and then ordered by creation date descending. When the user taps an entry
/// the sheet pops and invokes [onPlayBookmark]; when they delete one the
/// sheet refreshes in place. Extracted from the previous private
/// `_showBookmarksDialog` so the host screen is simpler and the sheet can be
/// reused.
Future<void> showAudioBookmarksSheet(
  BuildContext context, {
  required int currentSurahOrder,
  required List<Surah> surahs,
  required ValueChanged<AudioBookmark> onPlayBookmark,
}) async {
  final allBookmarks = await PreferencesService.getAudioBookmarks();

  if (!context.mounted) return;

  allBookmarks.sort((a, b) {
    if (a.surahId == currentSurahOrder && b.surahId != currentSurahOrder) {
      return -1;
    }
    if (b.surahId == currentSurahOrder && a.surahId != currentSurahOrder) {
      return 1;
    }
    return b.createdAt.compareTo(a.createdAt);
  });

  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return StatefulBuilder(
        builder: (sheetContext, setStateSheet) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.bookmarks,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (allBookmarks.isEmpty)
                  Expanded(child: Center(child: Text(l10n.noBookmarks))),
                if (allBookmarks.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: allBookmarks.length,
                      itemBuilder: (context, index) {
                        final bm = allBookmarks[index];
                        final duration = Duration(milliseconds: bm.positionMs);
                        final timeStr = formatPlaybackDuration(duration);

                        final surahName = surahs
                            .firstWhere(
                              (s) => s.order == bm.surahId,
                              orElse: () => Surah(
                                name: 'Surah ${bm.surahId}',
                                order: bm.surahId,
                                totalVerses: 0,
                              ),
                            )
                            .name;

                        return ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text('$surahName - $timeStr'),
                          subtitle: Text(
                            DateFormat.yMMMd().add_Hm().format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      bm.createdAt),
                                ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await PreferencesService.removeAudioBookmark(
                                  bm.id);
                              final newList =
                                  await PreferencesService.getAudioBookmarks();
                              newList.sort((a, b) {
                                if (a.surahId == currentSurahOrder &&
                                    b.surahId != currentSurahOrder) {
                                  return -1;
                                }
                                if (b.surahId == currentSurahOrder &&
                                    a.surahId != currentSurahOrder) {
                                  return 1;
                                }
                                return b.createdAt.compareTo(a.createdAt);
                              });
                              setStateSheet(() {
                                allBookmarks.clear();
                                allBookmarks.addAll(newList);
                              });
                            },
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onPlayBookmark(bm);
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
    },
  );
}
