class NotificationService {
  // Web stub - notifications not supported on web
  // Return a stub object that won't cause errors when checked for null
  static dynamic get plugin => _WebNotificationStub();
  static Function(String?)? onNotificationTap;
  
  static Future<void> init() async {}
  static Future<void> cancelAllPrayerAlerts() async {}

  static Future<void> scheduleSilentAlert({
    required int id,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
    String? payload,
  }) async {}

  static Future<void> scheduleAdhanNotification({
    required int id,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
    required String soundKey,
    bool isFajr = false,
  }) async {}

  static Future<void> scheduleRemainingAdhans({
    required Map<String, DateTime> times,
    required String soundKey,
    required Map<String, bool> toggles,
  }) async {}

  static Future<void> scheduleTestAdhanInSeconds(int secondsFromNow, {String title = 'Test Adhan', String body = ''}) async {}
}

class _WebNotificationStub {
  Future<dynamic> getNotificationAppLaunchDetails() async => null;
}
