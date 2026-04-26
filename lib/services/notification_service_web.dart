/// Web mirror of [WirdTestResult] in `notification_service_io.dart`.
///
/// Kept in sync with the io-side enum so `wird_edit_sheet.dart` can
/// switch on the return value without `kIsWeb` branches. Web has no
/// native notification channel for wird reminders, so the stub
/// unconditionally reports [ok] — the caller's SnackBar still fires and
/// the user sees a coherent UI, even though nothing is actually posted.
enum WirdTestResult {
  ok,
  notificationPermissionDenied,
  unknownError,
}

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

  // Daily Wird reminders — web has no local-notification equivalent, so
  // these are silent no-ops. WirdService treats a missing notification
  // schedule as acceptable degradation; the feature still works on web
  // minus the reminders.
  static Future<void> scheduleWirdOneShot({
    required String wirdId,
    required DateTime occurrenceDate,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
  }) async {}

  static Future<void> cancelWirdNotifications(String wirdId) async {}

  static Future<WirdTestResult> sendWirdTestNotification({
    required String title,
    required String body,
  }) async => WirdTestResult.ok;

  /// Web has no runtime notification permission gate (the browser handles
  /// it separately and the wird UI isn't rendered on web anyway). Report
  /// "granted" so the edit sheet's toggle accepts the switch flip.
  static Future<bool> ensureWirdNotificationPermissions() async => true;

  /// Web has no concept of "exact alarm" — notifications are either
  /// shown now or not at all. Report `null` (unknown) so the UI
  /// suppresses any exact-alarm warning.
  static Future<bool?> canScheduleExactWirdReminders() async => null;
}

class _WebNotificationStub {
  Future<dynamic> getNotificationAppLaunchDetails() async => null;
}
