import 'dart:io';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_timezone/flutter_timezone.dart';


import 'adhan_audio_manager.dart';
import 'logger.dart';
import 'preferences_service.dart';
import '../models/news_item.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Cached result of `NotificationManager.canUseFullScreenIntent()` probed
  /// at init time. On Android 14+ the permission is runtime-gated and often
  /// revoked by Google Play for non-alarm/calendar apps; we must downgrade to
  /// a heads-up notification when the OS won't honour the full-screen intent
  /// anyway. `true` on iOS/Android<14 (the field is unused on iOS).
  static bool _canUseFullScreenIntent = true;

  static const MethodChannel _systemChannel = MethodChannel('qurani/system');

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
    } catch (e, st) {
      Log.w('NotificationService', 'Could not set local timezone', e, st);
      // Fallback to UTC or default if needed, but usually timezone data is loaded
    }
    
    // Android initialization
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // iOS/macOS initialization
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );
    
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

    // Probe USE_FULL_SCREEN_INTENT once. On Android 14+ this permission is
    // revoked by Google Play for non-calendar/alarm apps, and setting
    // `fullScreenIntent: true` on a notification without the permission is a
    // silent no-op that still draws on the lock screen but never actually
    // takes over the screen. Caching the result lets us choose the correct
    // notification style up-front.
    if (Platform.isAndroid) {
      try {
        final bool granted = await _systemChannel
                .invokeMethod<bool>('canUseFullScreenIntent') ??
            false;
        _canUseFullScreenIntent = granted;
        Log.i('NotificationService',
            'canUseFullScreenIntent = $granted');
      } catch (e, st) {
        // Older builds of MainActivity.kt may not implement the method;
        // fall back to the conservative "off" state on Android 14+ (we
        // can't positively confirm), "on" otherwise.
        _canUseFullScreenIntent = false;
        Log.w('NotificationService', 'FSI probe failed', e, st);
      }
    }

    // Request permissions explicitly during init if possible, or leave to caller
    // We'll check in schedule methods

    _initialized = true;
    Log.i('NotificationService', 'Initialized');
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
    final tzTime = tz.TZDateTime.from(triggerTimeLocal, tz.local);
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) {
      Log.d('NotificationService', 'Adhan time is in the past, skipping');
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
      // Only request the full-screen takeover when the OS will actually
      // honour it. On Android 14+ the USE_FULL_SCREEN_INTENT permission is
      // runtime-gated; forcing `true` there produces a silent degradation
      // to a plain heads-up notification, which is indistinguishable from
      // `false` except for the cost of the UX lie.
      fullScreenIntent: _canUseFullScreenIntent,
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
    
    // iOS notification details.
    //
    // iOS requires the custom `sound:` file to physically exist in
    // `Library/Sounds/` at scheduling time — the OS copies its metadata
    // into the pending notification registry when `zonedSchedule` is
    // called. If the file is missing, the notification will silently fall
    // back to the default system sound (a short "ding"), with no warning
    // to the developer. To avoid that quietly-broken experience we
    // pre-validate that the file is installed and fall back to a
    // sound-less notification when it isn't.
    DarwinNotificationDetails darwinDetails;
    if (Platform.isIOS) {
      final resolved = await _resolveIosSoundFilename(soundKey);
      darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: resolved != null,
        sound: resolved,
      );
    } else {
      // On Android the Adhan audio is played by `AdhanScheduler` / the
      // native MediaPlayer; the local-notification is silent. We still
      // pass a non-null `sound:` so platform-side JSON contains the
      // string (legacy — harmless on Android where `playSound: false`
      // wins anyway).
      darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: isFajr ? '$soundKey-fajr.mp3' : '$soundKey.mp3',
      );
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      payload: soundKey,
    );
    Log.i('NotificationService', 'Scheduled Adhan notification for $tzTime');
  }

  /// Returns `$soundKey-ios.mp3` iff the file is actually installed under
  /// `Library/Sounds/`. Returns `null` if missing or empty so the caller
  /// can degrade gracefully (notification still fires but without the
  /// broken sound reference).
  static Future<String?> _resolveIosSoundFilename(String soundKey) async {
    try {
      final libDir = await getLibraryDirectory();
      final fileName = '$soundKey-ios.mp3';
      final file = File('${libDir.path}/Sounds/$fileName');
      if (!await file.exists()) {
        Log.w('NotificationService',
            'iOS sound missing for scheduling: $fileName');
        return null;
      }
      final len = await file.length();
      if (len == 0) {
        Log.w('NotificationService',
            'iOS sound empty for scheduling: $fileName');
        return null;
      }
      return fileName;
    } catch (e, st) {
      Log.w('NotificationService', 'iOS sound resolution error', e, st);
      return null;
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

  static Future<void> showNewsNotification(NewsItem item) async {
    await _ensureInitialized();
    final lang = PreferencesService.getLanguage();

    String titlePrefix = '';
    if (item.isFeatured) {
       titlePrefix = lang == 'ar' ? '⭐ عاجل: ' : (lang == 'fr' ? '⭐ Important: ' : '⭐ Featured: ');
    } else {
       titlePrefix = lang == 'ar' ? '📰 إعلان جديد: ' : (lang == 'fr' ? '📰 Nouvelle annonce: ' : '📰 New Announcement: ');
    }

    final androidDetails = AndroidNotificationDetails(
      'news_notifications_v1',
      'News & Announcements',
      channelDescription: 'Important updates from Qurani',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(item.description),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final int notificationId = _newsNotificationId(item.id);

    await _plugin.show(
      notificationId,
      '$titlePrefix${item.title}',
      item.description,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      payload: 'news_${item.id}',
    );
  }

  /// Stable 31-bit notification id for news items.
  ///
  /// `String.hashCode` (Dart's mixing hash) can produce negative values and
  /// collide across different strings. We fold a deterministic FNV-1a 32-bit
  /// hash into the upper half of the 31-bit positive int32 space so that:
  ///   * news IDs never collide with Adhan prayer IDs (which live in the
  ///     lower reserved range 1..99_999 + the fixed 9_999_999 stop id), and
  ///   * the id is always positive (required by the plugin on Android).
  static int _newsNotificationId(String id) {
    const int fnvOffset = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffset;
    for (final codeUnit in id.codeUnits) {
      hash = (hash ^ codeUnit) & 0xffffffff;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    // Namespace: bits 28-30 set to 0b101 (≈ 0x5000_0000) so news ids occupy
    // 0x5000_0000..0x5fff_ffff, well clear of every other producer in the
    // app. Mask to 28 bits before OR-ing to avoid sign bit contamination.
    return 0x50000000 | (hash & 0x0fffffff);
  }
}


