/// Formats a [Duration] as `MM:SS` (or `HH:MM:SS` when hours > 0) using
/// zero-padded segments. Extracted from the previous private helpers
/// `_formatDuration` and `_fmt` in `audio_player_screen.dart`, which were
/// byte-for-byte equivalent implementations.
String formatPlaybackDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(d.inHours);
  final minutes = twoDigits(d.inMinutes.remainder(60));
  final seconds = twoDigits(d.inSeconds.remainder(60));
  return d.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
