/// Pure, platform-free logic for Adhan scheduling.
///
/// No `dart:io`, no plugins, no SharedPreferences — every function here is a
/// pure function of its inputs, so it is unit-testable on the Dart VM without
/// a device or mocks. The plugin-bound `adhan_scheduler_io.dart` delegates to
/// these so the tricky arithmetic (ID derivation, the dedup fingerprint, the
/// DST-safe day cursor, the "should we reschedule?" decision) can be verified
/// in isolation. This is the same extraction pattern as `NotificationBudget`.
class AdhanScheduleLogic {
  const AdhanScheduleLogic._();

  /// The five daily prayers that can have an Adhan, in canonical order.
  /// Excludes `sunrise`/`imsak`, which never get an Adhan.
  static const List<String> adhanPrayers = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  /// Maps a prayer id to its single-digit alarm/notification code. Used as the
  /// low digit of [dailyId]. `sunrise` is 2 (kept for legacy id stability) even
  /// though it never gets an Adhan; unknown ids map to 0.
  static int codeForPrayer(String id) {
    switch (id) {
      case 'fajr':
        return 1;
      case 'sunrise':
        return 2;
      case 'dhuhr':
        return 3;
      case 'asr':
        return 4;
      case 'maghrib':
        return 5;
      case 'isha':
        return 6;
    }
    return 0;
  }

  /// Deterministic, collision-free notification/alarm id for a prayer on a
  /// given calendar date: `yyyymmdd * 10 + code`. Date-embedded so each day's
  /// prayer is a distinct pending entry, and stable so a reschedule overwrites
  /// (rather than duplicates) the same slot.
  static int dailyId({required String prayerId, required DateTime date}) {
    final ymd = date.year * 10000 + date.month * 100 + date.day;
    return ymd * 10 + codeForPrayer(prayerId);
  }

  /// Compact `yyyymmdd` integer key for a calendar day, ignoring time-of-day.
  static int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Order-independent fingerprint of a toggles map, so we can detect whether
  /// the user changed their Adhan prayer selection since the last scheduling
  /// pass. Keys are sorted so `{fajr:true, isha:false}` and
  /// `{isha:false, fajr:true}` produce identical strings.
  static String togglesFingerprint(Map<String, bool> toggles) {
    final keys = toggles.keys.toList()..sort();
    return keys.map((k) => '$k=${toggles[k] == true ? 1 : 0}').join(',');
  }

  /// Decides whether a 7-day (or [daysAhead]) scheduling pass needs to run,
  /// given the previously-persisted dedup state. Pure version of the body of
  /// `AdhanScheduler.shouldScheduleThroughDay` — the io side only supplies the
  /// stored values and `now`.
  ///
  /// Returns `true` (must reschedule) when the sound or toggles changed since
  /// last time, or when the persisted horizon doesn't cover today + [daysAhead].
  static bool shouldSchedule({
    required DateTime now,
    required String soundKey,
    required Map<String, bool> toggles,
    required int lastScheduledThrough,
    required String? lastSoundHash,
    required String? lastTogglesHash,
    int daysAhead = 7,
  }) {
    final today = dayKey(now);
    final target = dayKey(DateTime(now.year, now.month, now.day + daysAhead));
    final togglesHash = togglesFingerprint(toggles);
    if (lastSoundHash != soundKey || lastTogglesHash != togglesHash) {
      return true; // settings changed -> must re-schedule
    }
    // Need to reschedule if we haven't covered the full horizon, or if the
    // stored marker predates today (a new day has started).
    return lastScheduledThrough < target || lastScheduledThrough < today;
  }

  /// The list of calendar dates [today, today+1, ... today+(daysAhead-1)] using
  /// the DST-safe `DateTime(y, m, d + offset)` constructor rather than
  /// `add(Duration(days: n))` (which drifts ±1h across DST transitions and can
  /// skip or double a calendar day). Centralizing this guarantees every
  /// scheduling loop advances dates the same, correct way.
  static List<DateTime> scheduleDayCursors(DateTime today, {int daysAhead = 7}) {
    return List<DateTime>.generate(
      daysAhead,
      (i) => DateTime(today.year, today.month, today.day + i),
    );
  }

  /// Whether a "currently playing" flag with the given start timestamp should
  /// be treated as stale (left behind by a crashed/terminated isolate). Mirrors
  /// the staleness check in `AdhanAudioManager.syncPlayingStateFromPrefs`.
  ///
  /// [startMs] is the epoch-ms when playback was marked started (0 if unknown).
  /// Stale when there is no start time, or the elapsed time exceeds
  /// [maxDuration].
  static bool isPlayingFlagStale({
    required int startMs,
    required int nowMs,
    Duration maxDuration = const Duration(minutes: 6),
  }) {
    if (startMs == 0) return true;
    return (nowMs - startMs) > maxDuration.inMilliseconds;
  }
}
