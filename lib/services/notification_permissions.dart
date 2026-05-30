import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:permission_handler/permission_handler.dart';

/// Single source of truth for requesting the OS-level permissions the app's
/// notification features need on Android 13+ (`POST_NOTIFICATIONS` and
/// `SCHEDULE_EXACT_ALARM`).
///
/// ### Why this exists
///
/// Permission requests for the same two permissions were previously scattered
/// across two private helpers in `main.dart` (`_ensureNotificationPermission`
/// and `_ensureAdhanPermissions`). Splitting "request the notification
/// permissions this app needs" across multiple sites invites drift — one site
/// gaining an SDK gate the other lacks, or requesting one permission but not
/// the other. Consolidating into this gateway gives Adhan a single, named
/// entry point that requests the exact same set the same way.
///
/// ### Scope note (Wird reminders)
///
/// The on-demand Wird reminder flow
/// (`NotificationService.ensureWirdNotificationPermissions`) intentionally
/// keeps using flutter_local_notifications' own permission API rather than
/// routing through here. That path needs FLN's richer
/// `areNotificationsEnabled()` semantics (which detect notifications the user
/// disabled in system settings even on Android ≤12, something
/// `permission_handler` does not surface) and FLN's
/// `canScheduleExactNotifications()` probe that drives the edit-sheet warning.
/// Both paths request the same two OS permissions; only the mechanism differs,
/// and that difference is deliberate.
class NotificationPermissions {
  const NotificationPermissions._();

  static const MethodChannel _systemChannel = MethodChannel('qurani/system');

  /// Requests the baseline notification permissions Adhan needs, called once
  /// at app startup. No-op on web and on non-Android platforms (iOS requests
  /// its notification permissions via flutter_local_notifications during
  /// `NotificationService.init`).
  static Future<void> ensureBaselineForAdhan() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final sdk = await _androidSdkInt();
    if (sdk == null) return;

    // Both permissions only became runtime-gated at Android 13 (API 33);
    // on earlier versions the manifest declaration is sufficient.
    if (sdk < 33) return;

    // POST_NOTIFICATIONS — without it no notification (Adhan, Wird, news) is
    // ever shown on Android 13+.
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('[NotificationPermissions] notification request failed: $e');
    }

    // SCHEDULE_EXACT_ALARM — without it `AndroidAlarmManager.oneShotAt(
    // exact: true)` silently degrades to an inexact alarm that can drift by
    // 15+ minutes, making Adhan fire noticeably late.
    try {
      final status = await Permission.scheduleExactAlarm.status;
      if (!status.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (e) {
      // Older permission_handler builds may not know this permission on some
      // OEM devices; we degrade silently to inexact scheduling.
      debugPrint(
          '[NotificationPermissions] scheduleExactAlarm request failed: $e');
    }
  }

  static Future<int?> _androidSdkInt() async {
    try {
      return await _systemChannel.invokeMethod<int>('getSdkInt');
    } catch (_) {
      return null;
    }
  }
}
