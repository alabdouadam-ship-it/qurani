import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:qurani/services/preferences_service.dart';

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
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        const NotificationDetails(android: androidDetails),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Silently ignore scheduling errors (e.g., exact alarms not permitted)
    }
  }

  // Schedule an audible adhan at the exact prayer time. On Android 8+, sound is tied to the channel.
  // We create/use a channel per selected sound so changing sound takes effect.
  // If custom raw sounds are not packaged, Android will use default notification sound.
  static Future<void> scheduleAdhanNotification({
    required int id,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
    required String soundKey, // e.g., 'afs', 'basit', 'mecca', 'medina', 'ibrahim-jabr-masr'
    bool isFajr = false,
  }) async {
    final tzTime = tz.TZDateTime.from(triggerTimeLocal, tz.local);

    // Channel id & name per sound selection (and fajr variant)
    final channelSuffix = isFajr ? '${soundKey}_fajr' : soundKey;
    final channelId = 'prayer_adhan_$channelSuffix';
    final channelName = 'Prayer Adhan ($channelSuffix)';

    // Attempt to use a raw resource sound if present (Android only). If not present, system default plays.
    // Raw resource names must be lowercase, underscores only, without extension
    final rawBaseName = isFajr ? '${_normalizeSoundKey(soundKey)}_fajr' : _normalizeSoundKey(soundKey);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Adhan at prayer time',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      // If you add the matching file under android/app/src/main/res/raw, it will be used automatically
      sound: RawResourceAndroidNotificationSound(rawBaseName),
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
      enableVibration: true,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        NotificationDetails(android: androidDetails),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Ignore scheduling failures
    }
  }

  static String _normalizeSoundKey(String key) {
    return key
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim()
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static int _codeForPrayer(String id) {
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

  // Create a per-day unique id to avoid overwriting multiple days
  static int _dailyId({required String prayerId, required DateTime date}) {
    final ymd = date.year * 10000 + date.month * 100 + date.day;
    return ymd * 10 + _codeForPrayer(prayerId);
  }

  // Batch schedule remaining adhans for today based on toggles and selected sound
  static Future<void> scheduleRemainingAdhans({
    required Map<String, DateTime> times,
    required String soundKey,
    required Map<String, bool> toggles,
  }) async {
    final now = DateTime.now();
    for (final id in const ['fajr','dhuhr','asr','maghrib','isha']) {
      final enabled = toggles[id] ?? false;
      final t = times[id];
      if (!enabled || t == null) continue;
      if (t.isAfter(now)) {
        await scheduleAdhanNotification(
          id: _dailyId(prayerId: id, date: t),
          triggerTimeLocal: t,
          title: id, // localized title not critical for background; foreground UI shows details
          body: '',
          soundKey: soundKey,
          isFajr: id == 'fajr',
        );
      }
    }
  }
}



