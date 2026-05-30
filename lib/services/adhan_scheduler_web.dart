import 'preferences_service.dart';

class AdhanScheduler {
  static Future<void> init() async {}
  static Future<void> scheduleForTimes({
    required Map<String, DateTime> times,
    required Map<String, bool> toggles,
    required String soundKey,
  }) async {}

  // Web stubs for the scheduling-dedup API exposed by the IO implementation.
  // On web we don't have background alarms, so these always allow scheduling
  // (which itself is a no-op anyway).
  static Future<bool> shouldScheduleThroughDay({
    required String soundKey,
    required Map<String, bool> toggles,
    int daysAhead = 7,
  }) async =>
      false;

  static Future<void> markScheduledThroughDay({
    required String soundKey,
    required Map<String, bool> toggles,
    int daysAhead = 7,
  }) async {}

  static Future<void> invalidateScheduling() async {}

  // Web mirrors of the atomic write-and-invalidate helpers. On web there is
  // no background scheduling, so these just persist the preference.
  static Future<void> setPrayerEnabled(String prayerId, bool enabled) async {
    await PreferencesService.setBool('adhan_$prayerId', enabled);
  }

  static Future<void> setSound(String soundKey) async {
    await PreferencesService.saveAdhanSound(soundKey);
  }

  // Stub for web - background Adhan not supported on web
  static Future<void> testAdhanPlaybackAfterSeconds(int seconds, String soundKey) async {
    // No-op on web
  }
}


