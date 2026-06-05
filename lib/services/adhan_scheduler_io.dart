import 'dart:async';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'adhan_audio_manager.dart';
import 'adhan_schedule_logic.dart';
import 'logger.dart';
import 'preferences_service.dart';
import 'notification_service_io.dart';

// Sound keys whose MP3 files are bundled under assets/audio/.
// ONLY list keys that have actual files — the scheduler tries to pre-cache
// every entry at startup and logs errors for missing ones.
// Bundled: basit, afs, mecca, medina, ibrahim-jabr-masr (5 keys × 2 variants).
// Others (sds, frs_a, husr, minsh, suwaid, muyassar) are downloaded on demand
// and must NOT be listed here.
const List<String> _defaultSoundKeys = [
  'basit',
  'afs',
  'mecca',
  'medina',
  'ibrahim-jabr-masr',
];

// We reuse the same id scheme as notifications: yyyymmdd*10 + code.
// The id derivation now lives in the pure, testable AdhanScheduleLogic.
int _dailyId({required String prayerId, required DateTime date}) =>
    AdhanScheduleLogic.dailyId(prayerId: prayerId, date: date);

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

/// Re-initialises everything Adhan playback depends on, so it works in BOTH
/// the AndroidAlarmManager background isolate (which never runs `main()` and
/// therefore starts with none of the app's singletons initialised) and any
/// foreground caller.
///
/// **The invariant this protects:** anything Adhan playback needs at fire time
/// must be initialised here. The background alarm isolate is a fresh Dart VM —
/// `PreferencesService._prefs` is null, `NotificationService` is uninitialised,
/// etc. Code that "works" in the foreground will silently no-op in the isolate
/// if its dependency was only set up in `main()`. Adding a new dependency to
/// Adhan playback? Initialise it HERE, not just in `main()`.
///
/// Idempotent: `PreferencesService.ensureInitialized` and
/// `NotificationService.init` both guard against repeat work, so calling this
/// from a warm foreground path is cheap.
@pragma('vm:entry-point')
Future<void> ensureAdhanRuntimeReady() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (_) {}

  // Hydrate SharedPreferences in this isolate so [AdhanAudioManager.playAdhan]
  // can read the toggle/sound/volume keys reliably.
  await PreferencesService.ensureInitialized();

  // Lazily init the notification plugin so any stop/cancel calls from
  // AdhanAudioManager work correctly in this background isolate.
  // NotificationService.init() is idempotent (guarded by _initialized).
  try {
    await NotificationService.init();
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<void> _playAdhanCallback(int id) async {
  // Single bootstrap point shared with the foreground path. See
  // [ensureAdhanRuntimeReady] for the "initialise dependencies here, not just
  // in main()" invariant this enforces.
  await ensureAdhanRuntimeReady();

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
  AdhanAudioManager.trace('fired', fields: {
    'prayer': prayerId,
    'id': id,
    'isolate': 'background-alarm',
  });

  // Read (don't act on) the cross-isolate foreground flag. This is the
  // designated reader for `is_app_in_foreground`: it makes the flag's value
  // observable in logs at the moment an alarm fires in the background isolate,
  // which is invaluable for diagnosing "did the UI isolate think it was alive
  // when this alarm ran?" incidents. We deliberately do NOT use it to suppress
  // the stop-notification — the notification's Stop action is the only way to
  // stop a playing Adhan, so it must always show, foreground or not.
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final appForeground = prefs.getBool('is_app_in_foreground') ?? false;
    Log.d('AdhanCallback',
        'Alarm fired with is_app_in_foreground=$appForeground');
  } catch (_) {}

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
  //
  // The "Adhan playing — [Stop]" notification is now surfaced automatically
  // by AdhanAudioManager's onAdhanStarted hook (wired in
  // NotificationService.init), so every playback path — this background
  // callback AND the foreground GlobalAdhanService loop — gets the Stop
  // button. No explicit _showStopNotification call is needed here anymore.
  final started = await AdhanAudioManager.playAdhan(isTest ? 'test' : prayerId);
  if (!started) {
    Log.w('AdhanCallback', 'No engine started playback for $prayerId');
    return;
  }

  // AndroidAlarmManager tears down this isolate once the callback returns,
  // which would kill just_audio playback mid-Adhan. Block here until the
  // manager's session completes (or a safety timeout fires).
  await AdhanAudioManager.awaitCurrentSession(
    timeout: const Duration(minutes: 6),
  );
  Log.i('AdhanCallback', 'Session completed for $prayerId');
  // The stop-notification is cleared by AdhanAudioManager's onAdhanStopped
  // hook when the session ends, so no explicit cancel is needed here.
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
  static String _togglesFingerprint(Map<String, bool> toggles) =>
      AdhanScheduleLogic.togglesFingerprint(toggles);

  static int _dayKey(DateTime d) => AdhanScheduleLogic.dayKey(d);

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
      return AdhanScheduleLogic.shouldSchedule(
        now: DateTime.now(),
        soundKey: soundKey,
        toggles: toggles,
        lastScheduledThrough: prefs.getInt(_keyLastScheduledThrough) ?? 0,
        lastSoundHash: prefs.getString(_keyLastScheduledSoundHash),
        lastTogglesHash: prefs.getString(_keyLastScheduledTogglesHash),
        daysAhead: daysAhead,
      );
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

  /// Atomically persists the enabled state of [prayerId] AND invalidates the
  /// scheduling-dedup cache.
  ///
  /// This is the ONLY sanctioned way to change a prayer's Adhan toggle. By
  /// fusing the write to `adhan_<prayerId>` with [invalidateScheduling], it
  /// becomes structurally impossible to change a toggle without the next
  /// scheduling pass actually running — previously a caller had to remember
  /// to invalidate, and forgetting meant `shouldScheduleThroughDay`
  /// short-circuited and the change silently never took effect. Callers
  /// should still follow with a reschedule pass to (re)arm alarms now.
  static Future<void> setPrayerEnabled(String prayerId, bool enabled) async {
    await PreferencesService.setBool('adhan_$prayerId', enabled);
    await invalidateScheduling();
  }

  /// Atomically persists the selected Adhan [soundKey] AND invalidates the
  /// scheduling-dedup cache, for the same reason as [setPrayerEnabled]: the
  /// sound is part of the dedup fingerprint, so changing it without
  /// invalidating would leave the next pass thinking it had nothing to do.
  static Future<void> setSound(String soundKey) async {
    await PreferencesService.saveAdhanSound(soundKey);
    await invalidateScheduling();
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
    // Schedule alarms for enabled prayers; cancel alarms (and their paired
    // notifications) for prayers that are toggled OFF or whose time has
    // already passed. This is what makes "turn a prayer off" actually stop a
    // future Adhan: scheduling-only would leave a previously-armed alarm in
    // AndroidAlarmManager's queue, so the Adhan would still fire tomorrow.
    // Cancelling here, on every (re)schedule pass, keeps the armed set exactly
    // in sync with the current toggles without a separate code path.
    for (final entry in times.entries) {
      final prayerId = entry.key;
      final time = entry.value;

      if (prayerId == 'sunrise' || prayerId == 'imsak') continue;

      final id = _dailyId(prayerId: prayerId, date: time);
      final enabled = toggles[prayerId] ?? false;

      if (!enabled || time.isBefore(now)) {
        // Cancel any previously-armed alarm for this slot. (The paired
        // notification is cancelled centrally in
        // NotificationService.scheduleRemainingAdhans, which runs on both
        // platforms.)
        try {
          await AndroidAlarmManager.cancel(id);
        } catch (e, st) {
          Log.w('AdhanScheduler', 'Failed to cancel alarm $id', e, st);
        }
        continue;
      }

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
        AdhanAudioManager.trace('scheduled', fields: {
          'prayer': prayerId,
          'id': id,
          'at': time.toIso8601String(),
        });
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


