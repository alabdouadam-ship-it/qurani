import 'dart:async';
import 'adhan_schedule_logic.dart';

/// Each date/prayer owns its timer; scheduling tomorrow cannot erase today.
class ForegroundAdhanTimers {
  ForegroundAdhanTimers({required this.fire, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final void Function(int) fire;
  final DateTime Function() clock;
  final Map<int, Timer> _timers = {};

  void schedule(Map<String, DateTime> times, Map<String, bool> toggles) {
    final now = clock();
    for (final entry in times.entries) {
      if (!['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].contains(entry.key)) {
        continue;
      }
      final id =
          AdhanScheduleLogic.dailyId(prayerId: entry.key, date: entry.value);
      _timers.remove(id)?.cancel();
      final delay = entry.value.difference(now);
      if (toggles[entry.key] != true ||
          delay <= Duration.zero ||
          delay > const Duration(hours: 24)) {
        continue;
      }
      _timers[id] = Timer(delay, () {
        _timers.remove(id);
        // iOS may suspend Dart timers while the app is backgrounded.
        if (AdhanScheduleLogic.isAlarmDue(
          now: clock(), scheduledAt: entry.value.millisecondsSinceEpoch)) {
          fire(id);
        }
      });
    }
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
