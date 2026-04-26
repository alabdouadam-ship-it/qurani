import 'dart:io';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_timezone/flutter_timezone.dart';


import 'adhan_audio_manager.dart';
import 'logger.dart';
import 'preferences_service.dart';
import '../models/news_item.dart';

/// Outcome of [NotificationService.sendWirdTestNotification]. Lets the UI
/// show a failure reason precise enough to be actionable:
///   * [ok] — the notification was posted. If the user doesn't see it,
///     the issue is outside our process (Do Not Disturb, OEM app-kill).
///   * [notificationPermissionDenied] — `POST_NOTIFICATIONS` is not
///     granted. The UI should point the user to app notification
///     settings.
///   * [unknownError] — any other exception. Logged with stack trace;
///     the UI should show a generic "try again" message.
enum WirdTestResult {
  ok,
  notificationPermissionDenied,
  unknownError,
}

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

  // ---------------------------------------------------------------------------
  // Daily Wird reminders
  //
  // Owned by `WirdService`; kept here so all notification scheduling
  // (channel setup, timezone math, permission probing) lives in one place.
  //
  // ID layout (31-bit positive):
  //   bits 28..30 = 0b110 -> 0x60000000 prefix (disjoint from news 0x50..)
  //   bits  3..27 = 25 bits of FNV-1a(wirdId) — keeps per-wird hashes apart
  //   bits  0..2  = (occurrenceDate.weekday) encoded into 3 bits
  //
  // That last slice means two occurrences of the *same* wird on the *same*
  // weekday-in-a-year-apart collide — deliberately: we only ever schedule
  // a 7-day rolling window, so at most one entry per (wird, weekday) can
  // exist at a time. Collision with a stale next-week entry is the correct
  // behaviour: the new schedule replaces the old one.
  // ---------------------------------------------------------------------------

  /// The single channel all wird reminders post to.
  ///
  /// Design:
  ///   - `playSound: false` + `enableVibration: false` — wird reminders are
  ///     meditative, not interruptive. The user asked for fully silent
  ///     delivery so they're never startled by a reminder.
  ///   - `Importance.defaultImportance` — still surfaces as a heads-up
  ///     banner at the scheduled moment so the silent reminder is *seen*.
  ///     `Importance.low` would hide it in the tray only, which defeats
  ///     the purpose of a timed reminder.
  ///
  /// ### Why the `_v2` id suffix
  /// Android 8+ **locks** a channel's sound/vibration/importance after
  /// `createNotificationChannel` — subsequent calls with the same id are
  /// ignored. Shipping v1 with sound enabled then silencing it in v2
  /// requires a fresh channel id, plus a one-time delete of the old v1
  /// channel so the user doesn't end up with two "Daily Wird Reminders"
  /// entries in system settings. See [_ensureWirdChannel] for the
  /// migration.
  static const AndroidNotificationChannel _wirdChannel =
      AndroidNotificationChannel(
    'wird_reminders_v2',
    'Daily Wird Reminders',
    description: 'Silent reminders for your daily adhkar schedule',
    importance: Importance.defaultImportance,
    playSound: false,
    enableVibration: false,
  );

  /// Schedules one notification at [triggerTimeLocal] for the given wird.
  /// Safe to call repeatedly for the same (wird, date) pair — the plugin
  /// replaces any pending notification with the same id.
  ///
  /// [occurrenceDate] is only used for id derivation; the actual fire time
  /// comes from [triggerTimeLocal].
  static Future<void> scheduleWirdOneShot({
    required String wirdId,
    required DateTime occurrenceDate,
    required DateTime triggerTimeLocal,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    await _ensureWirdChannel();

    final tzTime = tz.TZDateTime.from(triggerTimeLocal, tz.local);
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) {
      // Caller should have filtered these out, but double-guarding is cheap.
      return;
    }

    final lang = PreferencesService.getLanguage();
    final notifTitle = lang == 'ar'
        ? 'تذكير بالورد: $title'
        : (lang == 'fr' ? 'Rappel de Wird : $title' : 'Wird reminder: $title');

    final androidDetails = AndroidNotificationDetails(
      _wirdChannel.id,
      _wirdChannel.name,
      channelDescription: _wirdChannel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      // Long dhikr text can wrap past one line — BigTextStyle lets the user
      // see the full reminder without tapping.
      styleInformation: BigTextStyleInformation(body),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final id = _wirdNotifId(wirdId: wirdId, occurrence: occurrenceDate);

    await _scheduleWirdZoned(
      id: id,
      title: notifTitle,
      body: body,
      when: tzTime,
      details:
          NotificationDetails(android: androidDetails, iOS: darwinDetails),
      payload: 'wird_$wirdId',
    );
  }

  /// Cancels every pending wird notification for the given [wirdId].
  ///
  /// We brute-force 7 weekday slots rather than scanning
  /// `pendingNotificationRequests()` because:
  ///   1. The plugin's pending-list API is async + expensive on Android
  ///      (cross-boundary AIDL call), and
  ///   2. Our id namespace already reserves exactly 7 slots per wird, so a
  ///      bounded loop is trivially correct.
  static Future<void> cancelWirdNotifications(String wirdId) async {
    await _ensureInitialized();
    for (int weekday = 1; weekday <= 7; weekday++) {
      final id = _wirdNotifIdRaw(wirdId: wirdId, weekday: weekday);
      await _plugin.cancel(id);
    }
  }

  /// Fires a wird-channel notification **immediately** so the user can
  /// verify that notifications from this app actually reach the status
  /// bar.
  ///
  /// ### Why immediate (`plugin.show`) instead of scheduled (`zonedSchedule`)
  ///
  /// The previous implementation scheduled a one-shot 5 seconds in the
  /// future. That routes through:
  ///   Plugin → AlarmManager → Doze decision → NotificationManager
  /// Any failure at steps 2-3 (denied `SCHEDULE_EXACT_ALARM`, aggressive
  /// OEM battery-saver, fallback to inexact that Doze then defers by
  /// 15+ minutes) produces a silent no-show. The user sees the "test
  /// scheduled" SnackBar, then nothing — which is exactly the bug being
  /// debugged.
  ///
  /// `plugin.show()` bypasses the AlarmManager path entirely and posts
  /// directly to NotificationManager. If *this* doesn't render, the
  /// fault is narrowed to one of three concrete things the user can fix:
  ///   1. `POST_NOTIFICATIONS` not granted (Android 13+).
  ///   2. The notification channel disabled in system settings.
  ///   3. The app blocked at the OS level (Do Not Disturb, OEM block).
  ///
  /// Scheduled wird reminders still use `zonedSchedule` + exact alarms
  /// (see [_scheduleWirdZoned]) because a scheduled reminder *must* fire
  /// at a specific future time — `plugin.show()` can't do that.
  ///
  /// ### Opportunistic permission priming
  ///
  /// Users press Test when they want notifications to work. That's the
  /// ideal moment to re-prompt for any runtime permission that may have
  /// been denied at cold start: `POST_NOTIFICATIONS` (without which the
  /// test itself can't render) and `SCHEDULE_EXACT_ALARM` (without which
  /// the real scheduled reminders drift under Doze). Requesting both
  /// here means a single Test tap is enough to un-break the whole
  /// reminder pipeline.
  ///
  /// ### Id allocation
  ///
  /// The fixed test id `0x60000000` has hash-bits = 0 and weekday = 0,
  /// and weekday 0 is never produced by real scheduling (the real range
  /// is 1..7) — so tests never collide with live reminders, and two
  /// back-to-back test taps overwrite each other.
  static Future<WirdTestResult> sendWirdTestNotification({
    required String title,
    required String body,
  }) async {
    try {
      final granted = await ensureWirdNotificationPermissions();
      if (!granted) {
        Log.w('NotificationService',
            'Wird test aborted: POST_NOTIFICATIONS denied');
        return WirdTestResult.notificationPermissionDenied;
      }

      final lang = PreferencesService.getLanguage();
      final notifTitle = lang == 'ar'
          ? 'اختبار تذكير الورد: $title'
          : (lang == 'fr'
              ? 'Test de rappel de Wird : $title'
              : 'Wird test: $title');

      final androidDetails = AndroidNotificationDetails(
        _wirdChannel.id,
        _wirdChannel.name,
        channelDescription: _wirdChannel.description,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
        styleInformation: BigTextStyleInformation(body),
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      const int testId = 0x60000000;

      await _plugin.show(
        testId,
        notifTitle,
        body,
        NotificationDetails(android: androidDetails, iOS: darwinDetails),
        payload: 'wird_test',
      );
      Log.i('NotificationService', 'Wird test notification posted (id=$testId)');
      return WirdTestResult.ok;
    } catch (e, st) {
      Log.e('NotificationService', 'Wird test notification failed', e, st);
      return WirdTestResult.unknownError;
    }
  }

  /// Ensures the runtime permissions that wird reminders need are granted.
  ///
  /// Returns `true` iff `POST_NOTIFICATIONS` is granted at the end of the
  /// call (already-granted or granted during the prompt). Also opportunistically
  /// requests `SCHEDULE_EXACT_ALARM` so scheduled reminders can fire at the
  /// exact time — a denied exact-alarm permission doesn't affect the return
  /// value because [scheduleWirdOneShot] falls back to inexact scheduling
  /// gracefully, but we still prompt here so the user sees the system UI
  /// once, in-context.
  ///
  /// Callers:
  ///   * [sendWirdTestNotification] — a denied permission blocks the test;
  ///     the UI shows the "notifications aren't allowed" SnackBar.
  ///   * The Wird edit sheet's reminder toggle — flipping the switch ON
  ///     triggers this method; if it returns false the toggle is reverted
  ///     so the user doesn't end up with a reminder that will never fire.
  ///
  /// On iOS and Android <=12 this method is effectively a no-op that
  /// returns `true` (permissions were handled at app init time or don't
  /// exist as a separate runtime gate).
  static Future<bool> ensureWirdNotificationPermissions() async {
    await _ensureInitialized();
    await _ensureWirdChannel();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true; // iOS: handled by init

    // Android 13+: POST_NOTIFICATIONS is a runtime permission. If the user
    // declined at cold start (or the OS suppressed the prompt), surface
    // the request again now. On Android <=12 this reports enabled=true
    // based on the manifest declaration, so the request is skipped.
    final enabled = await androidPlugin.areNotificationsEnabled() ?? false;
    if (!enabled) {
      final granted =
          await androidPlugin.requestNotificationsPermission() ?? false;
      if (!granted) return false;
    }

    // Best-effort exact-alarm prompt. On Android 12-13 this shows an
    // in-app dialog; on Android 14+ it redirects to the system
    // "Alarms & reminders" settings page. Either way, the return value
    // is `null` (the async user-flow result isn't surfaced by the
    // plugin), so the caller must re-probe via [canScheduleExactWirdReminders]
    // to know the actual state.
    try {
      await androidPlugin.requestExactAlarmsPermission();
    } catch (e) {
      Log.d('NotificationService',
          'requestExactAlarmsPermission threw: $e');
    }
    return true;
  }

  /// Probes whether `SCHEDULE_EXACT_ALARM` is currently granted on this
  /// device.
  ///
  /// Used by the wird edit sheet AFTER a toggle-on + permission prompt
  /// to decide whether to warn the user that their reminders will fire
  /// inexactly (Doze-delayed) because exact alarms are denied.
  ///
  /// Returns:
  ///   * `true` — exact scheduling is permitted. Reminders fire on time.
  ///   * `false` — Android 13+ user has denied `SCHEDULE_EXACT_ALARM`.
  ///     Reminders fall back to inexact, which Android batches into
  ///     maintenance windows (can defer by 15+ min in Doze).
  ///   * `null` — the plugin can't tell (iOS, Android <12, or unknown
  ///     platform). Callers should treat this as "don't warn".
  static Future<bool?> canScheduleExactWirdReminders() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return null;
    try {
      return await androidPlugin.canScheduleExactNotifications();
    } catch (e, st) {
      Log.w('NotificationService',
          'canScheduleExactNotifications probe failed', e, st);
      return null;
    }
  }

  /// Schedules a wird notification at [when] using `exactAllowWhileIdle`
  /// so it fires AT the scheduled time even when the device is in Doze or
  /// the app has been force-killed.
  ///
  /// Why exact instead of inexact:
  ///   Inexact alarms on modern Android (12+) can be deferred by minutes
  ///   to hours during deep Doze. For a prayer-time-adjacent reminder,
  ///   that silent drift is the worst failure mode — the user sees the
  ///   reminder long after the window has closed. Exact alarms are the
  ///   correct Android idiom here.
  ///
  /// Graceful fallback:
  ///   `SCHEDULE_EXACT_ALARM` is runtime-grantable on Android 13+ and can
  ///   be revoked at any time from system settings. If the user has
  ///   denied it, `zonedSchedule` throws `PlatformException(code:
  ///   "exact_alarms_not_permitted")`. Rather than drop the reminder
  ///   entirely, we retry with inexact scheduling so the user still gets
  ///   a (possibly delayed) reminder, and log once so the behaviour is
  ///   discoverable in logs.
  static Future<void> _scheduleWirdZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null, // one-shot; see class docstring
        payload: payload,
      );
      Log.i('NotificationService',
          'Scheduled wird id=$id at ${when.toIso8601String()} (exact)');
    } on PlatformException catch (e, st) {
      // `exact_alarms_not_permitted` is the well-known Android 13+ case
      // where the user (or Google Play) hasn't granted SCHEDULE_EXACT_ALARM.
      // Other errors (unknown plugin/OEM failure modes) used to rethrow,
      // but we've seen cases in the wild where non-permission exceptions
      // silently drop the reminder because the caller's future was
      // `unawaited`. Broaden the fallback: try inexact for *any*
      // PlatformException, log the original cause so it stays diagnosable,
      // and only give up if inexact also fails.
      if (e.code == 'exact_alarms_not_permitted') {
        Log.w(
          'NotificationService',
          'Exact alarm denied for wird id=$id; falling back to inexact. '
              'Ask the user to grant SCHEDULE_EXACT_ALARM for on-time delivery.',
        );
      } else {
        Log.w(
          'NotificationService',
          'Exact scheduling failed for wird id=$id with ${e.code}; '
              'falling back to inexact.',
          e,
          st,
        );
      }
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: null,
          payload: payload,
        );
        Log.i('NotificationService',
            'Scheduled wird id=$id at ${when.toIso8601String()} (inexact)');
      } catch (e2, st2) {
        // Last-resort log — both scheduling paths failed. Don't rethrow:
        // the caller (`WirdService._rescheduleOne` inside
        // `ensureReadyAndReschedule`) is fire-and-forget, so a rethrow
        // would land in an unawaited zone-error handler and be invisible.
        // Logging here is the only way this bug surfaces post-incident.
        Log.e('NotificationService',
            'Both exact and inexact scheduling failed for wird id=$id',
            e2, st2);
      }
    } catch (e, st) {
      // Catch anything non-PlatformException too, for the same reason.
      Log.e('NotificationService',
          'Unexpected error scheduling wird id=$id', e, st);
    }
  }

  /// One-time (idempotent) wird channel registration. Called from every
  /// `scheduleWirdOneShot` because `createNotificationChannel` is a cheap
  /// no-op for channels that already exist, and lazy creation avoids an
  /// extra channel on installs that never use this feature.
  ///
  /// Also handles the v1 → v2 migration: once the old sound-enabled
  /// channel has been deleted it won't come back, so subsequent launches
  /// short-circuit via the `_wirdChannelReady` flag. `deleteNotificationChannel`
  /// on an id that was never registered (fresh installs) is a safe no-op.
  static bool _wirdChannelReady = false;
  static Future<void> _ensureWirdChannel() async {
    if (_wirdChannelReady) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Remove the legacy sound-enabled channel. Android locks a channel's
    // sound/vibration/importance after creation, so silencing the old
    // channel in place is impossible — the only path is to delete it and
    // replace it with the new `_wirdChannel` (id v2).
    await androidPlugin
        ?.deleteNotificationChannel('wird_reminders_v1');
    await androidPlugin?.createNotificationChannel(_wirdChannel);
    _wirdChannelReady = true;
  }

  static int _wirdNotifId({
    required String wirdId,
    required DateTime occurrence,
  }) =>
      _wirdNotifIdRaw(wirdId: wirdId, weekday: occurrence.weekday);

  /// See the namespace comment above for the bit layout.
  static int _wirdNotifIdRaw({
    required String wirdId,
    required int weekday,
  }) {
    const int fnvOffset = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffset;
    for (final codeUnit in wirdId.codeUnits) {
      hash = (hash ^ codeUnit) & 0xffffffff;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    // Keep 25 bits of the hash, shift left by 3 to make room for weekday.
    final wirdBits = (hash & 0x01ffffff) << 3;
    final weekdayBits = weekday & 0x07;
    return 0x60000000 | wirdBits | weekdayBits;
  }
}


