class AdhanScheduler {
  static Future<void> init() async {}
  static Future<void> scheduleForTimes({
    required Map<String, DateTime> times,
    required Map<String, bool> toggles,
    required String soundKey,
  }) async {}
  
  // Stub for web - background Adhan not supported on web
  static Future<void> testAdhanPlaybackAfterSeconds(int seconds, String soundKey) async {
    // No-op on web
  }
}


