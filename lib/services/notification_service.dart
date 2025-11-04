import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  static Future<void> cancelAllPrayerAlerts() async {
    await _plugin.cancelAll();
  }

  static Future<void> scheduleSilentAlert({
    required int id,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
  }) async {
    final tz.TZDateTime tzTime = tz.TZDateTime.from(triggerTimeLocal, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'prayer_alerts',
      'Prayer Alerts',
      channelDescription: 'Silent alerts 5 minutes before prayer times',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      ongoing: false,
      category: AndroidNotificationCategory.reminder,
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(android: androidDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}



