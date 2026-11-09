import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'prayer_times_service.dart';
import 'preferences_service.dart';
import 'adhan_schedule_logic.dart';

class AdhanDiagnostic {
  final MapEntry<String, DateTime>? next;
  final bool? notifications;
  final bool? sound;
  final bool? exactAlarms;
  final bool? location;
  final bool? locationService;
  final bool? batteryUnrestricted;
  final bool? pendingOnIOS;
  final bool calendarAvailable;
  final int enabledCount;
  const AdhanDiagnostic(
      {this.next,
      this.notifications,
      this.sound,
      this.exactAlarms,
      this.location,
      this.locationService,
      this.batteryUnrestricted,
      this.pendingOnIOS,
      required this.calendarAvailable,
      required this.enabledCount});
}

MapEntry<String, DateTime>? nextEnabledAdhan(
    Iterable<Map<String, DateTime>> calendars,
    Map<String, bool> toggles,
    DateTime now) {
  MapEntry<String, DateTime>? result;
  for (final calendar in calendars) {
    for (final e in calendar.entries) {
      if (!AdhanScheduleLogic.adhanPrayers.contains(e.key) ||
          toggles[e.key] != true ||
          !e.value.isAfter(now)) {
        continue;
      }
      if (result == null || e.value.isBefore(result.value)) result = e;
    }
  }
  return result;
}

class AdhanDiagnosticService {
  static Future<T?> _probe<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  static Future<AdhanDiagnostic> read() async {
    final now = DateTime.now();
    final toggles = {
      for (final p in AdhanScheduleLogic.adhanPrayers)
        p: PreferencesService.getBool('adhan_$p') ?? false
    };
    final calendars = <Map<String, DateTime>>[];
    for (var i = 0; i < 8; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final times = await PrayerTimesService.getTimesForDate(
          year: d.year, month: d.month, day: d.day);
      if (times != null) calendars.add(times);
    }
    final next = nextEnabledAdhan(calendars, toggles, now);
    final AndroidFlutterLocalNotificationsPlugin? android =
        NotificationService.plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final IOSFlutterLocalNotificationsPlugin? ios = NotificationService.plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    final iosPermissions = await _probe(() async => ios?.checkPermissions());
    final notificationAllowed = defaultTargetPlatform == TargetPlatform.iOS
        ? iosPermissions?.isEnabled
        : await _probe(() async => android?.areNotificationsEnabled());
    final permission = await _probe(() => Geolocator.checkPermission());
    final pending = defaultTargetPlatform == TargetPlatform.iOS
        ? await _probe<List<PendingNotificationRequest>>(
            () => NotificationService.plugin.pendingNotificationRequests())
        : null;
    return AdhanDiagnostic(
        next: next,
        notifications: notificationAllowed,
        sound: iosPermissions?.isSoundEnabled,
        exactAlarms:
            await _probe(() async => android?.canScheduleExactNotifications()),
        location: permission == null
            ? null
            : permission == LocationPermission.always ||
                permission == LocationPermission.whileInUse,
        locationService:
            await _probe(() => Geolocator.isLocationServiceEnabled()),
        batteryUnrestricted: defaultTargetPlatform == TargetPlatform.android
            ? await _probe(() async =>
                (await Permission.ignoreBatteryOptimizations.status).isGranted)
            : null,
        pendingOnIOS: pending == null || next == null
            ? null
            : pending.any((e) =>
                e.id ==
                AdhanScheduleLogic.dailyId(
                    prayerId: next.key, date: next.value)),
        calendarAvailable: calendars.isNotEmpty,
        enabledCount: toggles.values.where((e) => e).length);
  }
}
