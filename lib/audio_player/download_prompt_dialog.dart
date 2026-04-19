import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/download_service.dart';

/// Result of [promptAndDownloadSurah]. The three states let the caller
/// distinguish a user cancel (`cancelled`) from a completed (`success`) or
/// failed (`error` with message) attempt without having to thread a nullable
/// bool + separate error channel like the original inline code did.
class SurahDownloadResult {
  const SurahDownloadResult.cancelled()
      : success = false,
        cancelled = true,
        error = null;
  const SurahDownloadResult.success()
      : success = true,
        cancelled = false,
        error = null;
  const SurahDownloadResult.failure(this.error)
      : success = false,
        cancelled = false;

  final bool success;
  final bool cancelled;
  final String? error;
}

/// Shows a "download this surah?" confirmation, then a modal progress dialog
/// while [DownloadService.downloadSurah] runs. Returns a [SurahDownloadResult]
/// describing the outcome so the caller can update UI / show a SnackBar.
///
/// Extracted verbatim from the previous `_promptDownloadCurrentSurah` in
/// `audio_player_screen.dart` — behaviour is preserved, including the
/// `Future.microtask` trick that fires the download while the progress
/// dialog is building.
Future<SurahDownloadResult> promptAndDownloadSurah(
  BuildContext context, {
  required String reciterKey,
  required int surahOrder,
}) async {
  final l10n = AppLocalizations.of(context)!;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.downloadCurrentSurahTitle),
        content: Text(l10n.downloadCurrentSurahMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.download),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return const SurahDownloadResult.cancelled();
  }

  String? errorMessage;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      Future.microtask(() async {
        try {
          await DownloadService.downloadSurah(reciterKey, surahOrder);
          if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(true);
          }
        } catch (e) {
          errorMessage = e.toString();
          if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(false);
          }
        }
      });

      return AlertDialog(
        title: Text(l10n.downloadingSurah),
        content: const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    },
  );

  if (result == true) return const SurahDownloadResult.success();
  return SurahDownloadResult.failure(errorMessage);
}
