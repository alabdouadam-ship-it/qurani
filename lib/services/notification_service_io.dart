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
    final tz_time = tz.TZDateTime.from(triggerTimeLocal, tz.local);
    if (tz_time.isBefore(tz.TZDateTime.now(tz.local))) {
      print('[NotificationService] Alert time is in the past, skipping');
      return;
    }
    
    final androidDetails = AndroidNotificationDetails(
      'prayer_adhans_default_v2',
      'Prayer Adhan',
      channelDescription: 'Adhan at prayer time',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    );
    
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz_time,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      payload: payload,
    );
    print('[NotificationService] Scheduled silent alert for $tz_time');
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
    );
    
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz_time,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
      
      // Schedule 5-minute reminder
      final alertTime = time.subtract(const Duration(minutes: 5));
      if (alertTime.isAfter(now)) {
        await scheduleSilentAlert(
          id: baseId + 1000,
          triggerTimeLocal: alertTime,
          title: lang == 'ar' ? 'تذكير بالصلاة' : (lang == 'fr' ? 'Rappel de prière' : 'Prayer Reminder'),
          body: _silentAlertBody(lang, name),
          payload: prayerId,
        );
      }
      
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

  static Future<void> scheduleTestAdhanInSeconds(int secondsFromNow, {String title = 'Test Adhan', String body = ''}) async {
    await _ensureInitialized();
    final triggerTime = DateTime.now().add(Duration(seconds: secondsFromNow));
    
    await scheduleAdhanNotification(
      id: 999999,
      triggerTimeLocal: triggerTime,
      title: title,
      body: body,
      soundKey: PreferencesService.getAdhanSound(),
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


