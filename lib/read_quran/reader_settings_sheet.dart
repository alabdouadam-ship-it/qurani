import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/mushaf_pdf_service.dart';
import 'package:qurani/services/preferences_service.dart';

/// Reader settings bottom sheet: auto-flip toggle, "start at last page"
/// toggle, reciter picker entry, mushaf style picker (PDF mode only), and
/// font-size slider.
///
/// The sheet reads directly from [PreferencesService] for the prefs-only
/// toggles (start-at-last-page, font size) because those don't require the
/// host screen to rebuild. The caller must supply callbacks for the
/// two stateful actions ([onAutoFlipChanged], [onFontSizeChanged]) and for
/// the two navigate-elsewhere actions ([onOpenReciterPicker],
/// [onOpenMushafStylePicker]) — the sheet pops itself before invoking the
/// latter so the new sheet/sheet chain doesn't stack on top.
///
/// Previously the private `_showSettingsSheet` in `read_quran_screen.dart`.
Future<void> showReaderSettingsSheet(
  BuildContext context, {
  required bool autoFlip,
  required ValueChanged<bool> onAutoFlipChanged,
  required bool isPdfMode,
  required MushafType pdfType,
  required VoidCallback onOpenReciterPicker,
  required VoidCallback onOpenMushafStylePicker,
  required VoidCallback onFontSizeChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      bool localAutoFlip = autoFlip;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.settings,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(l10n.readAutoFlip),
                    subtitle: Text(l10n.readAutoFlipDesc),
                    trailing: Switch(
                      value: localAutoFlip,
                      onChanged: (val) async {
                        setSheetState(() => localAutoFlip = val);
                        onAutoFlipChanged(val);
                        await PreferencesService.saveAutoFlipPage(val);
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(l10n.startAtLastPage),
                    subtitle: Text(l10n.startAtLastPageDesc),
                    trailing: Switch(
                      value: PreferencesService.getStartAtLastPage(),
                      onChanged: (val) async {
                        setSheetState(() {});
                        await PreferencesService.saveStartAtLastPage(val);
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(l10n.chooseReciter),
                    subtitle: Text(
                      AudioService.reciterDisplayName(
                        PreferencesService.getReciter(),
                        l10n.localeName,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onOpenReciterPicker();
                    },
                  ),
                  if (isPdfMode) ...[
                    const Divider(),
                    ListTile(
                      title: Text(l10n.mushafStyle),
                      subtitle: Text(pdfType == MushafType.blue
                          ? l10n.mushafTypeBlue
                          : pdfType == MushafType.green
                              ? l10n.mushafTypeGreen
                              : l10n.mushafTypeTajweed),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onOpenMushafStylePicker();
                      },
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    title: Text(
                        '${l10n.fontSize}: ${PreferencesService.getFontSize().toInt()}'),
                    subtitle: Slider(
                      value: PreferencesService.getFontSize(),
                      min: 16,
                      max: 28,
                      divisions: 3,
                      label:
                          '${PreferencesService.getFontSize().toInt()}',
                      onChanged: (val) async {
                        await PreferencesService.saveFontSize(val);
                        setSheetState(() {});
                        onFontSizeChanged();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
