import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../widgets/modern_ui.dart';

/// Transport control bar (prev / seek -10 / play-pause / seek +10 / next).
///
/// Previously `_buildTransportControls` inside `_AudioPlayerScreenState`;
/// extracted unchanged in behaviour. The play-pause button subscribes to
/// [player.playerStateStream] directly so it rebuilds only itself, not the
/// entire screen.
class AudioPlayerTransportControls extends StatelessWidget {
  const AudioPlayerTransportControls({
    super.key,
    required this.player,
    required this.isRtl,
    required this.color,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekBack10,
    required this.onSeekForward10,
    required this.onTogglePlayPause,
  });

  final AudioPlayer player;
  final bool isRtl;
  final ColorScheme color;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSeekBack10;
  final VoidCallback onSeekForward10;
  final VoidCallback onTogglePlayPause;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      IconButton(
        icon:
            Icon(isRtl ? Icons.skip_next_rounded : Icons.skip_previous_rounded),
        iconSize: 32,
        onPressed: onPrevious,
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: Icon(isRtl ? Icons.forward_10 : Icons.replay_10),
        iconSize: 28,
        onPressed: onSeekBack10,
      ),
      const SizedBox(width: 8),
      StreamBuilder<PlayerState>(
        stream: player.playerStateStream,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.95, end: playing ? 1.05 : 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: IconButton(
                  icon: Icon(playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill),
                  iconSize: 44,
                  color: color.primary,
                  onPressed: onTogglePlayPause,
                ),
              );
            },
          );
        },
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: Icon(isRtl ? Icons.replay_10 : Icons.forward_10),
        iconSize: 28,
        onPressed: onSeekForward10,
      ),
      const SizedBox(width: 8),
      IconButton(
        icon:
            Icon(isRtl ? Icons.skip_previous_rounded : Icons.skip_next_rounded),
        iconSize: 32,
        onPressed: onNext,
      ),
    ];
    return ModernSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: controls,
          ),
        ),
      ),
    );
  }
}
