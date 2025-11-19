import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'adhan_audio_manager.dart';
import 'preferences_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _activeAdhanNotificationId = 9000000;
  static bool _initialized = false;
  
  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Function(String?)? onNotificationTap;
  
  static Future<void> init() async {
    await _ensureInitialized();
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == 'stop_adhan') {
          await AdhanAudioManager.stopAllAdhanPlayback();
          await cancelActiveAdhanNotification();
          final notificationId = response.id;
          if (notificationId != null) {
            await _plugin.cancel(notificationId);
          }
          return;
        }
        if (response.payload != null && response.payload != 'unknown') {
          onNotificationTap?.call(response.payload);
        }
      },
    );

    const adhanChannel = AndroidNotificationChannel(
      'prayer_adhans_default_v2',
      'Prayer Adhan',
      description: 'Adhan at prayer time',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const audioChannel = AndroidNotificationChannel(
      'quran_audio_playback',
      'Quran Audio Playback',
      description: 'Background Quran audio playback notification',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    const controlChannel = AndroidNotificationChannel(
      'prayer_adhans_control',
      'Adhan Controls',
      description: 'Silent notification to stop Adhan',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(adhanChannel);
    await androidPlugin?.createNotificationChannel(audioChannel);
    await androidPlugin?.createNotificationChannel(controlChannel);

    _initialized = true;
    print('[NotificationService] Initialized');
  }

  static Future<void> cancelAllPrayerAlerts() async {
    await _plugin.cancelAll();
  }

  static Future<void> scheduleSilentAlert({
    required int id,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _ensureInitialized();
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      print('[NotificationService] Silent alert scheduled with payload: $payload');
    } catch (e) {
      print('[NotificationService] Error scheduling silent alert: $e');
    }
  }

  static Future<void> scheduleAdhanNotification({
    required int id,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
    required String soundKey,
    bool isFajr = false,
  }) async {
    await _ensureInitialized();
    final tzTime = tz.TZDateTime.from(triggerTimeLocal, tz.local);
    // Decode prayer ID from notification ID
    final code = id % 10;
    String? prayerId;
    switch (code) {
      case 1: prayerId = 'fajr'; break;
      case 3: prayerId = 'dhuhr'; break;
      case 4: prayerId = 'asr'; break;
      case 5: prayerId = 'maghrib'; break;
      case 6: prayerId = 'isha'; break;
    }
    final payload = prayerId ?? 'unknown';
    
    final androidDetails = AndroidNotificationDetails(
      'prayer_adhans_default_v2',
      'Prayer Adhan',
      channelDescription: 'Adhan at prayer time',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      autoCancel: false,
      ongoing: false,
    );
    
    print('[NotificationService] Scheduling Adhan notification: id=$id, time=$tzTime, payload=$payload');
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload, // Pass prayer ID as payload
      );
      print('[NotificationService] Adhan notification scheduled successfully: id=$id, time=$tzTime, payload=$payload');
    } catch (e, stackTrace) {
      print('[NotificationService] Error scheduling Adhan notification: $e');
      print('[NotificationService] Stack trace: $stackTrace');
    }
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

  static int _dailyId({required String prayerId, required DateTime date}) {
    final ymd = date.year * 10000 + date.month * 100 + date.day;
    return ymd * 10 + _codeForPrayer(prayerId);
  }

  static Future<void> scheduleRemainingAdhans({
    required Map<String, DateTime> times,
    required String soundKey,
    required Map<String, bool> toggles,
  }) async {
    await _ensureInitialized();
    final now = DateTime.now();
    final lang = PreferencesService.getLanguage();
    print('[NotificationService] Scheduling notifications, current time: $now');
    for (final id in const ['fajr','dhuhr','asr','maghrib','isha']) {
      final enabled = toggles[id] ?? false;
      final t = times[id];
      if (!enabled || t == null) {
        print('[NotificationService] Skipping $id (enabled: $enabled, time: $t)');
        continue;
      }
      if (t.isAfter(now)) {
        // Schedule silent alert 5 minutes before prayer time
        final alertTime = t.subtract(const Duration(minutes: 5));
        if (alertTime.isAfter(now)) {
          // Use a different ID for the alert (add 1000000 to avoid conflicts)
          final alertId = _dailyId(prayerId: id, date: t) + 1000000;
          final prayerName = _localizedPrayerName(lang, id);
          final body = _silentAlertBody(lang, prayerName);
          print('[NotificationService] Scheduling silent alert for $id at $alertTime (alertId: $alertId)');
          try {
            await scheduleSilentAlert(
              id: alertId,
              triggerTimeLocal: alertTime,
              title: prayerName,
              body: body,
            );
            print('[NotificationService] Silent alert scheduled successfully');
          } catch (e) {
            print('[NotificationService] Error scheduling silent alert: $e');
          }
        } else {
          print('[NotificationService] Alert time passed for $id (alertTime: $alertTime)');
        }
        
        // Schedule Adhan notification at prayer time
        final adhanId = _dailyId(prayerId: id, date: t);
        print('[NotificationService] Scheduling Adhan notification for $id at $t (id: $adhanId)');
        try {
          await scheduleAdhanNotification(
            id: adhanId,
            triggerTimeLocal: t,
            title: id,
            body: '',
            soundKey: soundKey,
            isFajr: id == 'fajr',
          );
          print('[NotificationService] Adhan notification scheduled successfully');
        } catch (e) {
          print('[NotificationService] Error scheduling Adhan notification: $e');
        }
      } else {
        print('[NotificationService] Time passed for $id (time: $t)');
      }
    }
  }

  static Future<void> scheduleTestAdhanInSeconds(int secondsFromNow, {String title = 'Test Adhan', String body = ''}) async {
    await _ensureInitialized();
    final trigger = DateTime.now().add(Duration(seconds: secondsFromNow));
    await scheduleAdhanNotification(
      id: _dailyId(prayerId: 'test', date: trigger),
      triggerTimeLocal: trigger,
      title: title,
      body: body,
      soundKey: 'test',
      isFajr: false,
    );
  }

  static Future<void> showActiveAdhanNotification(String prayerId) async {
    await _ensureInitialized();
    final lang = PreferencesService.getLanguage();
    final name = _localizedPrayerName(lang, prayerId);
    String title;
    String body;
    switch (lang) {
      case 'en':
        title = 'Adhan - $name';
        body = 'Tap to stop the Adhan';
        break;
      case 'fr':
        title = 'Adhan - $name';
        body = 'Touchez pour arrêter l\'adhan';
        break;
      default:
        title = 'أذان $name';
        body = 'اضغط لإيقاف الأذان';
        break;
    }

    final stopLabel = _stopActionLabel(lang);
    final androidDetails = AndroidNotificationDetails(
      'prayer_adhans_control',
      'Adhan Controls',
      channelDescription: 'Silent notification to stop Adhan',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: false,
      actions: [
        AndroidNotificationAction(
          'stop_adhan',
          stopLabel,
          showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(
      _activeAdhanNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: prayerId,
    );
  }

  static Future<void> cancelActiveAdhanNotification() async {
    await _ensureInitialized();
    await _plugin.cancel(_activeAdhanNotificationId);
  }

  static String _localizedPrayerName(String lang, String id) {
    const namesAr = {
      'fajr': 'الفجر',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
    };
    const namesEn = {
      'fajr': 'Fajr',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
    };
    const namesFr = {
      'fajr': 'Fajr',
      'dhuhr': 'Dohr',
      'asr': 'Asr',
      'maghrib': 'Maghreb',
      'isha': 'Icha',
    };
    switch (lang) {
      case 'en':
        return namesEn[id] ?? id;
      case 'fr':
        return namesFr[id] ?? id;
      default:
        return namesAr[id] ?? id;
    }
  }

  static String _silentAlertBody(String lang, String prayerName) {
    switch (lang) {
      case 'en':
        return 'Adhan for $prayerName in 5 minutes';
      case 'fr':
        return 'Adhan de $prayerName dans 5 minutes';
      default:
        return 'سيحين أذان $prayerName بعد خمس دقائق';
    }
  }

  static String _stopActionLabel(String lang) {
    switch (lang) {
      case 'en':
        return 'Stop Adhan';
      case 'fr':
        return 'Arrêter l\'adhan';
      default:
        return 'إيقاف الأذان';
    }
  }
}


