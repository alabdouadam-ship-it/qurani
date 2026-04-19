import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../l10n/app_localizations.dart';

/// Shows the playback-speed slider dialog. Calls [onChanged] live while the
/// user drags the slider (same semantics as the previous inline version in
/// `audio_player_screen.dart`).
///
/// [player] is needed because the original implementation also invoked
/// `player.setSpeed(value)` on every change so the audio updates in
/// real-time, which is a nicer UX than only committing on OK.
Future<void> showPlaybackSpeedDialog(
  BuildContext context, {
  required double initialSpeed,
  required AudioPlayer player,
  required ValueChanged<double> onChanged,
}) {
  double current = initialSpeed;
  return showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l10n.playbackSpeed),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: current,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  label: '${current.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    setDialogState(() => current = value);
                    player.setSpeed(value);
                    onChanged(value);
                  },
                ),
                Text('${current.toStringAsFixed(1)}x'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
