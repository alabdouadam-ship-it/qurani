/// Foreground prayer monitoring with an injectable clock and data source.
class ForegroundAdhanMonitor {
  ForegroundAdhanMonitor({
    required this.loadTimes,
    required this.play,
    required this.isPlaying,
    required this.isEnabled,
    DateTime Function()? clock,
    this.onDayChanged,
    this.cacheRevision,
  }) : clock = clock ?? DateTime.now;

  final Future<Map<String, DateTime>?> Function(DateTime) loadTimes;
  final Future<void> Function(String) play;
  final bool Function() isPlaying;
  final bool Function(String) isEnabled;
  final DateTime Function() clock;
  final void Function()? onDayChanged;
  final int Function()? cacheRevision;
  DateTime? _day;
  Map<String, DateTime>? _times;
  final _played = <String>{};
  bool _checking = false;
  int _generation = 0;

  void invalidate() {
    _generation++;
    _times = null;
  }

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    final generation = _generation;
    final revision = cacheRevision?.call();
    try {
      final now = clock();
      final day = DateTime(now.year, now.month, now.day);
      if (_day != day) {
        final hadDay = _day != null;
        _day = day;
        _times = null; // Never retain yesterday's data if today's load fails.
        _played.clear();
        if (hadDay) onDayChanged?.call();
      }
      _times ??= await loadTimes(day);
      final afterLoad = clock();
      if (generation != _generation || revision != cacheRevision?.call() ||
          DateTime(afterLoad.year, afterLoad.month, afterLoad.day) != day) {
        _times = null;
        return;
      }
      if (_times == null || isPlaying()) return;
      for (final prayer in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        final time = _times![prayer];
        if (time == null) continue;
        final elapsed = afterLoad.difference(time);
        if (!elapsed.isNegative &&
            elapsed <= const Duration(seconds: 30) &&
            isEnabled(prayer) &&
            _played.add(prayer)) {
          await play(prayer);
          break;
        }
      }
    } finally {
      _checking = false;
    }
  }
}
