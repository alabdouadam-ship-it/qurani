import 'dart:async';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'adhan_audio_manager.dart';
import 'logger.dart';
import 'preferences_service.dart';
import 'notification_service_io.dart';

const List<String> _defaultSoundKeys = [
  'basit',
  'afs',
  'sds',
  'frs_a',
  'husr',
  'minsh',
  'suwaid',
  'muyassar',
  'mecca',
  'medina', 
  'ibrahim-jabr-masr',
];

// We reuse the same id scheme as notifications: yyyymmdd*10 + code
int _codeForPrayer(String id) {
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

int _dailyId({required String prayerId, required DateTime date}) {
  final ymd = date.year * 10000 + date.month * 100 + date.day;
  return ymd * 10 + _codeForPrayer(prayerId);
}

String _assetFor(String soundKey, bool isFajr) {
  return isFajr ? 'assets/audio/$soundKey-fajr.mp3' : 'assets/audio/$soundKey.mp3';
}

Future<bool> _ensureAdhanFileExists(String soundKey, bool isFajr) async {
  try {
    final docDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${docDir.path}/adhan_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    // 1. Cache FULL audio for in-app playback (Android & iOS Foreground/Background)
    final assetPath = _assetFor(soundKey, isFajr);
    final fileName = assetPath.split('/').last;
    final file = File('${cacheDir.path}/$fileName');
    
    // Check if full audio exists in cache
    if (!await file.exists()) {
      try {
        final byteData = await rootBundle.load(assetPath);
        await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
        Log.i('AdhanScheduler', 'Cached full audio: $fileName');
      } catch (e, st) {
        Log.e('AdhanScheduler', 'Failed to load asset $assetPath', e, st);
        // If we can't load the full asset, we probably can't play it.
        // But we continue to try iOS notification sound setup.
      }
    }

    // 2. iOS Specific: Copy SHORT/IOS audio to Library/Sounds for Notifications
    if (Platform.isIOS) {
      try {
        final libDir = await getLibraryDirectory();
        final soundsDir = Directory('${libDir.path}/Sounds');
        if (!await soundsDir.exists()) {
          await soundsDir.create(recursive: true);
        }

        // `$soundKey-ios.mp3` is the short (~30s) file referenced by the
        // iOS `UNNotificationSound` — must live in `Library/Sounds/`.
        final iosFileName = '$soundKey-ios.mp3';
        final iosAssetPath = 'assets/audio/$iosFileName';
        final iosDestFile = File('${soundsDir.path}/$iosFileName');

        try {
          final iosByteData = await rootBundle.load(iosAssetPath);
          final expectedLen = iosByteData.lengthInBytes;

          // Skip the rewrite when the file already matches the bundled
          // asset byte-for-byte (size is sufficient — assets are immutable
          // per-build). This was previously a force-copy on every launch,
          // multiplied across 11 sound keys, which was measurable cold-start
          // cost on iOS.
          if (await iosDestFile.exists() &&
              await iosDestFile.length() == expectedLen) {
            // Already installed, nothing to do.
          } else {
            if (await iosDestFile.exists()) {
              await iosDestFile.delete();
            }
            await iosDestFile.writeAsBytes(
                iosByteData.buffer.asUint8List(),
                flush: true);
            Log.i('AdhanScheduler',
                'Copied to Library/Sounds: $iosFileName');
          }
        } catch (e, st) {
          Log.w('AdhanScheduler',
              'Could not find/copy iOS specific asset $iosAssetPath', e, st);
          // Fail silently — the scheduling side validates the file and will
          // fall back to the system default sound if this asset is missing.
        }
      } catch (e, st) {
        Log.e('AdhanScheduler', 'Failed to handle iOS Library/Sounds', e, st);
      }
    }

    return await file.exists();
  } catch (e, st) {
    Log.e('AdhanScheduler', 'Failed to cache $soundKey (fajr: $isFajr)', e, st);
    return false;
  }
}

Future<void> _showStopNotification(String prayerId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(PreferencesService.keyLanguage) ?? 'ar';
    
    // Get localized prayer name
    String prayerName;
    if (prayerId == 'test' || prayerId == 'fajr' && prefs.getBool('test_mode') == true) {
      prayerName = lang == 'ar' ? 'اختبار' : (lang == 'fr' ? 'Test' : 'Test');
    } else {
      switch (prayerId) {
        case 'fajr':
          prayerName = lang == 'ar' ? 'الفجر' : (lang == 'fr' ? 'Fajr' : 'Fajr');
          break;
        case 'dhuhr':
          prayerName = lang == 'ar' ? 'الظهر' : (lang == 'fr' ? 'Dohr' : 'Dhuhr');
          break;
        case 'asr':
          prayerName = lang == 'ar' ? 'العصر' : (lang == 'fr' ? 'Asr' : 'Asr');
          break;
        case 'maghrib':
          prayerName = lang == 'ar' ? 'المغرب' : (lang == 'fr' ? 'Maghreb' : 'Maghrib');
          break;
        case 'isha':
          prayerName = lang == 'ar' ? 'العشاء' : (lang == 'fr' ? 'Icha' : 'Isha');
          break;
        default:
          prayerName = lang == 'ar' ? 'اختبار' : (lang == 'fr' ? 'Test' : 'Test');
      }
    }
    
    String title, body, stopLabel;
    switch (lang) {
      case 'en':
        title = 'Adhan - $prayerName';
        body = 'Tap to open app';
        stopLabel = 'Stop';
        break;
      case 'fr':
        title = 'Adhan - $prayerName';
        body = 'Touchez pour ouvrir';
        stopLabel = 'Arrêter';
        break;
      default:
        title = 'أذان $prayerName';
        body = 'اضغط لفتح التطبيق';
        stopLabel = 'إيقاف';
    }
    
    // Ensure NotificationService is initialized properly to preserve callbacks
    await NotificationService.init();

    final androidDetails = AndroidNotificationDetails(
      'prayer_adhans_default_v2', // Use the main adhan channel
      'Prayer Adhan',
      channelDescription: 'Adhan at prayer time',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false, // The audio is already playing via AdhanAudioManager
      enableVibration: false,
      ongoing: true, // Keep it active while audio is playing
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
    
    Log.d('AdhanStopNotif', 'Showing notification: $title');
    await NotificationService.plugin.show(
      9999999, // Specific ID for the active playback notification
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: 'stop_adhan',
    );
    Log.i('AdhanStopNotif', 'Stop-notification shown for $prayerId');
  } catch (e, stackTrace) {
    Log.e('AdhanStopNotif', 'Failed to show stop-notification', e, stackTrace);
  }
}

@pragma('vm:entry-point')
Future<void> _playAdhanCallback(int id) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (_) {}

  // Ensure PreferencesService is hydrated in this isolate so that the
  // unified [AdhanAudioManager.playAdhan] can read the toggle/sound/volume
  // keys reliably.
  await PreferencesService.ensureInitialized();

  // Lazily init the notification plugin so any stop/cancel calls from
  // AdhanAudioManager work correctly in this background isolate.
  // NotificationService.init() is idempotent (guarded by _initialized).
  try { await NotificationService.init(); } catch (_) {}

  // Decode prayer from alarm id.
  final code = id % 10;
  String? prayerId;
  switch (code) {
    case 1: prayerId = 'fajr'; break;
    case 3: prayerId = 'dhuhr'; break;
    case 4: prayerId = 'asr'; break;
    case 5: prayerId = 'maghrib'; break;
    case 6: prayerId = 'isha'; break;
  }

  // Test IDs always play fajr and bypass the enable gate.
  final isTest = id == 999991;
  if (isTest) {
    prayerId = 'fajr';
    Log.i('AdhanCallback', 'TEST MODE — forcing fajr');
  }
  if (prayerId == null) {
    Log.w('AdhanCallback', 'Invalid prayer code: $code');
    return;
  }

  Log.i('AdhanCallback', 'Firing for $prayerId');

  // Respect the enable toggle (test bypasses).
  if (!isTest) {
    final enabled =
        PreferencesService.getBool('adhan_$prayerId') ?? false;
    if (!enabled) {
      Log.d('AdhanCallback', '$prayerId disabled, skipping');
      return;
    }
  }

  // Make sure the cached audio file exists so the native MediaPlayer path
  // has something to play. just_audio asset fallback works without a file,
  // but native MediaPlayer requires a filesystem path. This is the only
  // reason the callback still does pre-caching work before delegating.
  final soundKey = PreferencesService.getAdhanSound();
  final isFajr = prayerId == 'fajr';
  if (!File(
          '${(await getApplicationDocumentsDirectory()).path}/adhan_cache/'
          '${isFajr ? '$soundKey-fajr.mp3' : '$soundKey.mp3'}')
      .existsSync()) {
    Log.d('AdhanCallback', 'Pre-caching adhan file...');
    await _ensureAdhanFileExists(soundKey, isFajr);
  }

  // Delegate engine selection, state tracking, and completion hookup to
  // the single authoritative manager. For tests we pass 'test' so the
  // manager bypasses its own enable-gate (we already bypassed ours above).
  final started = await AdhanAudioManager.playAdhan(isTest ? 'test' : prayerId);
  if (!started) {
    Log.w('AdhanCallback', 'No engine started playback for $prayerId');
    return;
  }

  // Surface the tappable stop-notification *after* playback has begun, so
  // the user sees it only when Adhan is actually audible.
  await _showStopNotification(prayerId);

  // AndroidAlarmManager tears down this isolate once the callback returns,
  // which would kill just_audio playback mid-Adhan. Block here until the
  // manager's session completes (or a safety timeout fires).
  await AdhanAudioManager.awaitCurrentSession(
    timeout: const Duration(minutes: 6),
  );
  Log.i('AdhanCallback', 'Session completed for $prayerId');
  
  // Clean up the stop-notification once playback naturally finishes
  try {
    await NotificationService.plugin.cancel(9999999);
  } catch (_) {}
}

class AdhanScheduler {
  static bool _initialized = false;

  // Keys used to remember how far into the future we last scheduled alarms
  // and with which settings, so we can skip redundant Android alarm-manager
  // round-trips on every cold start / screen rebuild.
  static const String _keyLastScheduledThrough =
      'adhan_last_scheduled_through_day';
  static const String _keyLastScheduledSoundHash =
      'adhan_last_scheduled_sound_hash';
  static const String _keyLastScheduledTogglesHash =
      'adhan_last_scheduled_toggles_hash';

  /// Returns a stable, order-independent fingerprint of a toggles map so we
  /// can detect whether the user changed their Adhan prayer selection since
  /// the last scheduling pass.
  static String _togglesFingerprint(Map<String, bool> toggles) {
    final keys = toggles.keys.toList()..sort();
    return keys.map((k) => '$k=${toggles[k] == true ? 1 : 0}').join(',');
  }

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Returns `true` if we have *not* already scheduled alarms for every day
  /// from today through (today + [daysAhead]) with the given [soundKey] and
  /// [toggles]. Call this before running the 7-day scheduling loop to avoid
  /// queuing duplicate Android alarm-manager entries on every launch.
  static Future<bool> shouldScheduleThroughDay({
    required String soundKey,
    required Map<String, bool> toggles,
    int daysAhead = 7,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = _dayKey(now);
      final target =
          _dayKey(DateTime(now.year, now.month, now.day + daysAhead));
      final lastThrough = prefs.getInt(_keyLastScheduledThrough) ?? 0;
      final lastSound = prefs.getString(_keyLastScheduledSoundHash);
      final lastToggles = prefs.getString(_keyLastScheduledTogglesHash);
      final togglesHash = _togglesFingerprint(toggles);
      if (lastSound != soundKey || lastToggles != togglesHash) {
        return true; // settings changed -> must re-schedule
      }
      // Already scheduled today AND covered the full horizon: skip.
      return lastThrough < target || lastThrough < today;
    } catch (_) {
      return true; // on any pref error, err on the side of scheduling
    }
  }

  /// Persist the fact that we just finished scheduling through (today +
  /// [daysAhead]) with [soundKey] and [toggles]. Must be called after a
  /// successful scheduling pass that was gated by [shouldScheduleThroughDay].
  static Future<void> markScheduledThroughDay({
    required String soundKey,
    required Map<String, bool> toggles,
    int daysAhead = 7,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final target =
          _dayKey(DateTime(now.year, now.month, now.day + daysAhead));
      await prefs.setInt(_keyLastScheduledThrough, target);
      await prefs.setString(_keyLastScheduledSoundHash, soundKey);
      await prefs.setString(
          _keyLastScheduledTogglesHash, _togglesFingerprint(toggles));
    } catch (_) {}
  }

  /// Forget the "already scheduled through" state. Call this whenever the
  /// user changes their Adhan sound or toggles a prayer on/off, so the next
  /// scheduling pass is guaranteed to run.
  static Future<void> invalidateScheduling() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastScheduledThrough);
      await prefs.remove(_keyLastScheduledSoundHash);
      await prefs.remove(_keyLastScheduledTogglesHash);
    } catch (_) {}
  }

  /// Initialises the Adhan scheduler exactly once per app process. Repeated
  /// calls (e.g. hot reload during dev, or duplicate entry-points) are no-ops.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      // Only initialise AndroidAlarmManager on Android; it's a no-op elsewhere.
      if (Platform.isAndroid) {
        final success = await AndroidAlarmManager.initialize();
        Log.i('AdhanScheduler',
            'AndroidAlarmManager.initialize() returned: $success');
      }
      await _cacheAdhanAudio();
      _initialized = true;
    } catch (e, st) {
      Log.e('AdhanScheduler', 'Critical init error', e, st);
    }
  }

  static Future<void> _cacheAdhanAudio() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/adhan_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      Log.d('AdhanScheduler', 'Adhan cache directory: ${cacheDir.path}');

      final prefs = await SharedPreferences.getInstance();
      final selected = prefs.getString(PreferencesService.keyAdhanSound) ?? 'afs';
      final soundKeys = {..._defaultSoundKeys, selected};
      int cachedCount = 0;
      for (final soundKey in soundKeys) {
        for (final isFajr in [true, false]) {
          final cached = await _ensureAdhanFileExists(soundKey, isFajr);
          if (cached) {
            cachedCount++;
          }
        }
      }
      Log.i('AdhanScheduler', 'Caching complete. Total new files: $cachedCount');
    } catch (e, st) {
      Log.e('AdhanScheduler', 'Error during caching', e, st);
    }
  }

  static Future<void> scheduleForTimes({
    required Map<String, DateTime> times,
    required Map<String, bool> toggles,
    required String soundKey,
  }) async {
    Log.d('AdhanScheduler',
        'Scheduling Adhan alarms (Platform: ${Platform.operatingSystem})...');
    
    // CRITICAL: Ensure files are cached/copied BEFORE scheduling
    final now = DateTime.now();
    for (final prayerId in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if (toggles[prayerId] ?? false) {
        await _ensureAdhanFileExists(soundKey, prayerId == 'fajr');
      }
    }
    
    // Convert times to Map<String, DateTime> for NotificationService
    if (Platform.isIOS) {
      await NotificationService.scheduleRemainingAdhans(times: times, toggles: toggles, soundKey: soundKey);
      _scheduleForegroundTimers(times, toggles);
      return;
    }

    if (!Platform.isAndroid) return;

    Log.d('AdhanScheduler', 'Scheduling Adhan alarms for Android...');
    // Schedule alarms for enabled prayers
    for (final entry in times.entries) {
      final prayerId = entry.key;
      final time = entry.value;
      
      if (prayerId == 'sunrise' || prayerId == 'imsak') continue;
      if (!(toggles[prayerId] ?? false)) continue;
      if (time.isBefore(now)) continue;
      
      final id = _dailyId(prayerId: prayerId, date: time);
      
      try {
        await AndroidAlarmManager.oneShotAt(
          time,
          id,
          _playAdhanCallback,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
        );
        Log.i('AdhanScheduler', 'Scheduled $prayerId at $time (id: $id)');
      } catch (e, st) {
        Log.e('AdhanScheduler', 'Failed to schedule $prayerId', e, st);
      }
    }
  }


  static final List<Timer> _foregroundTimers = [];

  static void _scheduleForegroundTimers(Map<String, DateTime> times, Map<String, bool> toggles) {
    // Cancel existing timers
    for (var t in _foregroundTimers) {
      t.cancel();
    }
    _foregroundTimers.clear();

    final now = DateTime.now();
    for (final entry in times.entries) {
      final prayerId = entry.key;
      final time = entry.value;
      
      if (prayerId == 'sunrise' || prayerId == 'imsak') continue;
      if (!(toggles[prayerId] ?? false)) continue;
      
      if (time.isAfter(now)) {
        final duration = time.difference(now);
        if (duration.inHours > 24) continue; // Safety check
        
        Log.d('AdhanScheduler',
            'Scheduling foreground timer for $prayerId in $duration');
        final id = _dailyId(prayerId: prayerId, date: time);

        final timer = Timer(duration, () {
          Log.i('AdhanScheduler', 'Foreground timer firing for $prayerId');
          _playAdhanCallback(id);
        });
        _foregroundTimers.add(timer);
      }
    }
  }

  static Future<void> testAdhanPlaybackAfterSeconds(int seconds, String soundKey) async {
    Log.i('AdhanScheduler',
        'TEST: Scheduling test Adhan in ${seconds}s with sound "$soundKey"');
    final triggerTime = DateTime.now().add(Duration(seconds: seconds));
    
    // Pre-cache the test adhan file
    await _ensureAdhanFileExists(soundKey, false);
    await _ensureAdhanFileExists(soundKey, true);

    if (Platform.isIOS) {
        // For iOS test, trigger timer immediately after delay
        Timer(Duration(seconds: seconds), () {
          Log.i('AdhanScheduler', 'TEST: Triggering iOS foreground callback');
          _playAdhanCallback(999991);
        });
        // Also schedule a notification
        await NotificationService.scheduleAdhanNotification(
          id: 999991, 
          triggerTimeLocal: triggerTime, 
          title: 'Test Adhan', 
          body: 'Testing Adhan Sound', 
          soundKey: soundKey,
          isFajr: true,
        );
        return;
    }

    if (!Platform.isAndroid) return; // Android-only
    
    // Schedule test with a unique ID that will trigger fajr
    await AndroidAlarmManager.oneShotAt(
      triggerTime,
      999991, // ID ending with 1 = fajr
      _playAdhanCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
    );
    
    Log.i('AdhanScheduler', 'TEST: Alarm scheduled for $triggerTime');
  }

  static Future<void> testAdhanPlaybackImmediate() async {
    if (!Platform.isAndroid) return; // Android-only

    Log.i('AdhanScheduler', 'TEST: Triggering Adhan callback IMMEDIATELY');
    try {
      await _playAdhanCallback(202511251); // fajr code
      Log.i('AdhanScheduler', 'TEST: Direct callback completed');
    } catch (e, st) {
      Log.e('AdhanScheduler', 'TEST: Direct callback error', e, st);
    }
  }
}


