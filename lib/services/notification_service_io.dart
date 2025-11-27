import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_timezone/flutter_timezone.dart';


import 'adhan_audio_manager.dart';
import 'preferences_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  
  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Function(String?)? onNotificationTap;
  
  static Future<void> init() async {
    await _ensureInitialized();
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final dynamic result = await FlutterTimezone.getLocalTimezone();
      String timeZoneName;
      if (result is String) {
        timeZoneName = result;
      } else {
        // Handle TimezoneInfo object (likely has .id or .name)
        // Using dynamic to avoid import issues if class is not available
        try {
          timeZoneName = (result as dynamic).id;
        } catch (_) {
          timeZoneName = result.toString();
        }
      }
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('[NotificationService] Could not set local timezone: $e');
      // Fallback to UTC or default if needed, but usually timezone data is loaded
    }
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == 'stop_adhan' || response.payload == 'stop_adhan') {
          await AdhanAudioManager.stopAllAdhanPlayback();
          // Cancel the notification that triggered this action
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




    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(adhanChannel);



    // Request permissions explicitly during init if possible, or leave to caller
    // We'll check in schedule methods

    _initialized = true;
    print('[NotificationService] Initialized');
  }

  static Future<void> cancelAllPrayerAlerts() async {
    await _plugin.cancelAll();
  }


  static Future<void> scheduleAdhanNotification({
    required int id,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
    required String soundKey,
    bool isFajr = false,
  }) async {
    // Note: This is just a notification, actual Adhan playback is handled by AdhanScheduler
    await _ensureInitialized();
    final tz_time = tz.TZDateTime.from(triggerTimeLocal, tz.local);
    if (tz_time.isBefore(tz.TZDateTime.now(tz.local))) {
      print('[NotificationService] Adhan time is in the past, skipping');
      return;
    }
    
    final lang = PreferencesService.getLanguage();
    final stopLabel = _stopActionLabel(lang);
    
    final androidDetails = AndroidNotificationDetails(
      'prayer_adhans_default_v2',
      'Prayer Adhan',
      channelDescription: 'Adhan at prayer time',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false, // Sound handled by AdhanScheduler
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'stop_adhan',
          stopLabel,
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz_time,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      payload: soundKey,
    );
    print('[NotificationService] Scheduled Adhan notification for $tz_time');
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
    
    for (final entry in times.entries) {
      final prayerId = entry.key;
      final time = entry.value;
      
      if (prayerId == 'sunrise' || prayerId == 'imsak') continue;
      if (!(toggles[prayerId] ?? false)) continue;
      if (time.isBefore(now)) continue;
      
      final baseId = _dailyId(prayerId: prayerId, date: time);
      final name = _localizedPrayerName(lang, prayerId);
      
      
      // Schedule Adhan notification
      final title = lang == 'ar' ? 'أذان $name' : 'Adhan - $name';
      final body = lang == 'ar' ? 'حان وقت صلاة $name' : (lang == 'fr' ? 'Il est temps de prier $name' : 'Time for $name prayer');
      
      await scheduleAdhanNotification(
        id: baseId,
        triggerTimeLocal: time,
        title: title,
        body: body,
        soundKey: soundKey,
        isFajr: prayerId == 'fajr',
      );
    }
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


