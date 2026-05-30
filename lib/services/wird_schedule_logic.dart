/// Pure, platform-free logic for Wird reminder scheduling.
///
/// No SQLite, no notifications plugin — just the arithmetic that decides
/// notification ids, which days fall in the rolling window, and whether a
/// wird is due for its daily-count reset. Extracted from `WirdService` and
/// `NotificationService` so it can be unit-tested on the Dart VM (same pattern
/// as `NotificationBudget` and `AdhanScheduleLogic`).
class WirdScheduleLogic {
  const WirdScheduleLogic._();

  /// 31-bit positive notification id for a wird occurrence on [weekday]
  /// (`DateTime.weekday`, 1=Mon..7=Sun).
  ///
  /// Bit layout (must stay in lockstep with the cancel-side brute force):
  ///   * bits 28..30 = `0b110` → `0x60000000` prefix (disjoint from the news
  ///     `0x50000000` namespace and the Adhan `yyyymmdd*10+code` range).
  ///   * bits  3..27 = 25 bits of FNV-1a(wirdId) — separates per-wird hashes.
  ///   * bits  0..2  = weekday (1..7) in 3 bits.
  ///
  /// Because only weekday (not the full date) is encoded, two occurrences of
  /// the same wird on the same weekday share an id — intentional: the rolling
  /// window only ever has one pending entry per (wird, weekday), so a new
  /// schedule correctly overwrites a stale next-week one.
  static int notificationId({required String wirdId, required int weekday}) {
    const int fnvOffset = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffset;
    for (final codeUnit in wirdId.codeUnits) {
      hash = (hash ^ codeUnit) & 0xffffffff;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    final wirdBits = (hash & 0x01ffffff) << 3;
    final weekdayBits = weekday & 0x07;
    return 0x60000000 | wirdBits | weekdayBits;
  }

  /// The fixed id used for the wird *test* notification: hash-bits 0 and
  /// weekday 0, which real scheduling (weekday 1..7) can never produce, so a
  /// test never collides with a live reminder.
  static const int testNotificationId = 0x60000000;

  /// Computes the concrete trigger times for a wird's rolling notification
  /// window, given the wird's active [daysOfWeek] (1..7), its reminder
  /// [hour]/[minute], the current instant [now], and the [horizon] in days
  /// (≤7, possibly shrunk by the iOS budget).
  ///
  /// Rules (pure mirror of `WirdService._rescheduleOne`'s loop):
  ///   * Walk offsets `0..horizon-1` from today.
  ///   * Skip days not in [daysOfWeek].
  ///   * Take only the NEAREST future occurrence of each weekday (the id
  ///     namespace has one slot per weekday, so a second is redundant).
  ///   * Skip a trigger time already in the past.
  ///   * Skip offset 0 (today) when [alreadyDoneToday] is true.
  ///
  /// Returns the trigger [DateTime]s in chronological order. Callers schedule
  /// one notification per returned time.
  static List<DateTime> windowTriggers({
    required DateTime now,
    required List<int> daysOfWeek,
    required int hour,
    required int minute,
    required bool alreadyDoneToday,
    int horizon = 7,
  }) {
    final triggers = <DateTime>[];
    final scheduledWeekdays = <int>{};
    for (int offset = 0; offset < horizon; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (!daysOfWeek.contains(day.weekday)) continue;
      if (scheduledWeekdays.contains(day.weekday)) continue;

      final triggerAt = DateTime(day.year, day.month, day.day, hour, minute);
      if (triggerAt.isBefore(now)) continue;
      if (offset == 0 && alreadyDoneToday) continue;

      triggers.add(triggerAt);
      scheduledWeekdays.add(day.weekday);
    }
    return triggers;
  }

  /// Whether a wird is due for its once-per-day count reset: its
  /// [lastUpdatedDate] (calendar date, or null if never touched) is strictly
  /// before [today], AND [today]'s weekday is in the wird's [daysOfWeek]
  /// schedule. Wirds not scheduled today are left alone so an idle day doesn't
  /// wipe a previous active day's progress.
  static bool isDueForDailyReset({
    required DateTime today,
    required DateTime? lastUpdatedDate,
    required List<int> daysOfWeek,
  }) {
    if (!daysOfWeek.contains(today.weekday)) return false;
    if (lastUpdatedDate == null) return true;
    final lastDay =
        DateTime(lastUpdatedDate.year, lastUpdatedDate.month, lastUpdatedDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return lastDay.isBefore(todayDay);
  }
}
