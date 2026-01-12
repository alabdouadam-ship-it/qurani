import 'dart:async';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'adhan_audio_manager.dart';
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
    final assetPath = _assetFor(soundKey, isFajr);
    final fileName = assetPath.split('/').last;
    final file = File('${cacheDir.path}/$fileName');
    if (await file.exists()) {
      return true;
    }
    final byteData = await rootBundle.load(assetPath);
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    debugPrint('[AdhanScheduler] ✓ Cached: $fileName (${byteData.lengthInBytes} bytes)');
    
    // iOS specific: Copy to Library/Sounds for notification sound
    if (Platform.isIOS) {
      try {
        final libDir = await getLibraryDirectory();
        final soundsDir = Directory('${libDir.path}/Sounds');
        if (!await soundsDir.exists()) {
          await soundsDir.create(recursive: true);
        }
        final iosFile = File('${soundsDir.path}/$fileName');
        if (!await iosFile.exists()) {
          await file.copy(iosFile.path);
          debugPrint('[AdhanScheduler] ✓ Copied to Library/Sounds: $fileName');
        }
      } catch (e) {
        debugPrint('[AdhanScheduler] ✗ Failed to copy to Library/Sounds: $e');
      }
    }

    return true;
  } catch (e) {
    debugPrint('[AdhanScheduler] ✗ Failed to cache $soundKey (fajr: $isFajr): $e');
    return false;
  }
}

Future<void> _showStopNotification(String prayerId) async {
  try {
    debugPrint('[AdhanScheduler] ========== SHOWING STOP NOTIFICATION ==========');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check if app is in foreground using shared preferences
    // WidgetsBinding.instance.lifecycleState is not reliable in background isolate
    final isForeground = prefs.getBool('is_app_in_foreground') ?? false;
    if (isForeground) {
      debugPrint('[AdhanScheduler] App is in foreground (pref=true), skipping notification');
      return;
    }

    final lang = prefs.getString(PreferencesService.keyLanguage) ?? 'ar';
    debugPrint('[AdhanScheduler] Language: $lang');
    
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
    
    String title, body;
    switch (lang) {
      case 'en':
        title = 'Adhan - $prayerName';
        body = 'Tap to open app';
        break;
      case 'fr':
        title = 'Adhan - $prayerName';
        body = 'Touchez pour ouvrir';
        break;
      default:
        title = 'أذان $prayerName';
        body = 'اضغط لفتح التطبيق';
    }
    
    debugPrint('[AdhanScheduler] Creating notification plugin...');
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    
    debugPrint('[AdhanScheduler] Initializing notification plugin...');
    await plugin.initialize(initSettings);
    
    debugPrint('[AdhanScheduler] Creating notification details...');
    // Simple tappable notification without action buttons
    const androidDetails = AndroidNotificationDetails(
      'adhan_stop_silent',
      'Adhan Stop Control',
      channelDescription: 'Silent notification to stop Adhan',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      ongoing: false, // Allow dismissal
      autoCancel: true, // Auto-cancel when tapped
    );
    
    debugPrint('[AdhanScheduler] Showing notification with title: $title');
    await plugin.show(
      9999999,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'stop_adhan',
    );
    debugPrint('[AdhanScheduler] ✓✓✓ NOTIFICATION SHOWN SUCCESSFULLY ✓✓✓');
  } catch (e, stackTrace) {
    debugPrint('[AdhanScheduler] ✗✗✗ FAILED TO SHOW NOTIFICATION ✗✗✗');
    debugPrint('[AdhanScheduler] Error: $e');
    debugPrint('[AdhanScheduler] Stack trace: $stackTrace');
  }
}

@pragma('vm:entry-point')
Future<void> _playAdhanCallback(int id) async {
  //print('[AdhanScheduler.Callback] ===== ADHAN CALLBACK TRIGGERED (ID: $id) =====');
  //print('[AdhanScheduler.Callback] Step 0: Initializing Flutter bindings...');
  try {
    WidgetsFlutterBinding.ensureInitialized();
    //print('[AdhanScheduler.Callback] ✓ WidgetsFlutterBinding initialized');
  } catch (e) {
    //print('[AdhanScheduler.Callback] ✗ WidgetsFlutterBinding error: $e');
  }
  
  // DartPluginRegistrant is handled automatically by the platform
  
  //try {
    //print('[AdhanScheduler.Callback] Step 1: Getting preferences...');
    final prefs = await SharedPreferences.getInstance();
    //print('[AdhanScheduler.Callback] ✓ SharedPreferences obtained');
    
    // Decode prayer from id
    final code = id % 10;
    String? prayerId;
    switch (code) {
      case 1: prayerId = 'fajr'; break;
      case 3: prayerId = 'dhuhr'; break;
      case 4: prayerId = 'asr'; break;
      case 5: prayerId = 'maghrib'; break;
      case 6: prayerId = 'isha'; break;
      default: prayerId = null;
    }
    
    // For test IDs, always enable and use fajr
    if (id == 999991) {
      prayerId = 'fajr';
      debugPrint('[AdhanScheduler.Callback] TEST MODE: Forcing fajr prayer');
    }

    if (prayerId == null) {
      debugPrint('[AdhanScheduler.Callback] ✗ Invalid prayer code: $code');
      return;
    }
    
    debugPrint('[AdhanScheduler.Callback] Prayer ID: $prayerId');
    
    final enabled = prefs.getBool('adhan_$prayerId') ?? false;
    debugPrint('[AdhanScheduler.Callback] Enabled for $prayerId: $enabled');
    
    // For test mode, bypass the enable check
    if (id != 999991 && !enabled) {
      debugPrint('[AdhanScheduler.Callback] Adhan is disabled for $prayerId, skipping');
      return;
    }

    final soundKey = prefs.getString(PreferencesService.keyAdhanSound) ?? 'afs';
    final volume = (prefs.getDouble(PreferencesService.keyAdhanVolume) ?? 1.0)
        .clamp(0.0, 1.0);
    final isFajr = prayerId == 'fajr';
    debugPrint('[AdhanScheduler.Callback] Sound: $soundKey, Fajr: $isFajr');
    
    // Try to get file path
    final docDir = await getApplicationDocumentsDirectory();
    final fileName = isFajr ? '$soundKey-fajr.mp3' : '$soundKey.mp3';
    final filePath = '${docDir.path}/adhan_cache/$fileName';
    bool fileExists = File(filePath).existsSync();
    
    debugPrint('[AdhanScheduler.Callback] File path: $filePath');
    debugPrint('[AdhanScheduler.Callback] File exists: $fileExists');
    
    if (!fileExists) {
      debugPrint('[AdhanScheduler.Callback] ✗ File not found, attempting to cache...');
      final ensured = await _ensureAdhanFileExists(soundKey, isFajr);
      fileExists = ensured && File(filePath).existsSync();
      if (!fileExists) {
        debugPrint('[AdhanScheduler.Callback] ✗ File still missing after caching');
        return;
      }
    }

    debugPrint('[AdhanScheduler.Callback] Step 2: Configuring audio session...');
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await session.setActive(true);
      debugPrint('[AdhanScheduler.Callback] ✓ Audio session configured');
    } catch (e) {
      debugPrint('[AdhanScheduler.Callback] ✗ Audio session error: $e');
    }



    debugPrint('[AdhanScheduler.Callback] Step 3: Attempting native playback first...');
    final nativePlayed =
        await AdhanAudioManager.tryPlayNativeFile(filePath, volumeOverride: volume);
    if (nativePlayed) {
      debugPrint('[AdhanScheduler.Callback] ✓ Native MediaPlayer started successfully');
      debugPrint('[AdhanScheduler.Callback] >>>>>> ABOUT TO CALL _showStopNotification <<<<<<');
      await _showStopNotification(prayerId);
      debugPrint('[AdhanScheduler.Callback] >>>>>> RETURNED FROM _showStopNotification <<<<<<');
      return;
    }
    debugPrint('[AdhanScheduler.Callback] ⊘ Native playback failed, falling back to just_audio');

    debugPrint('[AdhanScheduler.Callback] Step 4: Creating audio player (fallback) ...');
    final player = AudioPlayer();
    try {
      await player.setVolume(volume);
      
      debugPrint('[AdhanScheduler.Callback] Loading: $filePath');
      await player.setAudioSource(AudioSource.file(filePath));
      debugPrint('[AdhanScheduler.Callback] ✓ Audio source set');
      
      
      debugPrint('[AdhanScheduler.Callback] Starting playback...');
      player.play(); // Don't await - start playback and continue immediately
      debugPrint('[AdhanScheduler.Callback] ✓ Playback started');
      debugPrint('[AdhanScheduler.Callback] >>>>>> CALLING NOTIFICATION NOW <<<<<<');
      await _showStopNotification(prayerId);
      debugPrint('[AdhanScheduler.Callback] >>>>>> NOTIFICATION CALL COMPLETED <<<<<<');
      AdhanAudioManager.registerBackgroundPlayer(player);


      
      // Wait for completion
      debugPrint('[AdhanScheduler.Callback] Adhan is playing, waiting for completion...');
      
      try {
        await player.playerStateStream
            .firstWhere((s) => s.processingState == ProcessingState.completed)
            .timeout(const Duration(minutes: 5)); // Safety timeout
        debugPrint('[AdhanScheduler.Callback] ✓ Playback completed normally');
      } catch (e) {
        debugPrint('[AdhanScheduler.Callback] ⊘ Playback timeout or error: $e');
      } finally {
        debugPrint('[AdhanScheduler.Callback] Disposing player...');
        await player.dispose();
      }
    } catch (e) {
      debugPrint('[AdhanScheduler.Callback] ✗ Playback error: $e');
      try {
        await player.dispose();
      } catch (_) {}
    }
    
    debugPrint('[AdhanScheduler.Callback] ===== CALLBACK COMPLETE =====');
  // } catch (e, st) {
  //   debugPrint('[AdhanScheduler.Callback] ✗✗✗ FATAL ERROR: $e');
  //   debugPrint('[AdhanScheduler.Callback] Stack: $st');
  // }
}

class AdhanScheduler {
  static Future<void> init() async {
    // Cache audio first (Platform agnostic logic inside)
    await _cacheAdhanAudio();

    if (Platform.isAndroid) {
       await AndroidAlarmManager.initialize();
    }
    
    try {
      debugPrint('[AdhanScheduler] INITIALIZING AndroidAlarmManager...');
      final success = await AndroidAlarmManager.initialize();
      debugPrint('[AdhanScheduler] AndroidAlarmManager.initialize() returned: $success');
      
      debugPrint('[AdhanScheduler] CACHING Adhan audio files...');
      await _cacheAdhanAudio();
      debugPrint('[AdhanScheduler] Adhan audio caching complete');
    } catch (e) {
      debugPrint('[AdhanScheduler] ✗ CRITICAL INIT ERROR: $e');
    }
  }

  static Future<void> _cacheAdhanAudio() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/adhan_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      debugPrint('[AdhanScheduler] Adhan cache directory: ${cacheDir.path}');

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
      debugPrint('[AdhanScheduler] Caching complete. Total new files: $cachedCount');
    } catch (e) {
      debugPrint('[AdhanScheduler] Error during caching: $e');
    }
  }

  static Future<void> scheduleForTimes({
    required Map<String, DateTime> times,
    required Map<String, bool> toggles,
    required String soundKey,
  }) async {
    debugPrint('[AdhanScheduler] Scheduling Adhan alarms (Platform: ${Platform.operatingSystem})...');
    
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
    
    debugPrint('[AdhanScheduler] Scheduling Adhan alarms for Android...');
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
        debugPrint('[AdhanScheduler] ✓ Scheduled $prayerId at $time (id: $id)');
      } catch (e) {
        debugPrint('[AdhanScheduler] ✗ Failed to schedule $prayerId: $e');
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
        
        debugPrint('[AdhanScheduler] Scheduling foreground timer for $prayerId in $duration');
        final id = _dailyId(prayerId: prayerId, date: time);
        
        final timer = Timer(duration, () {
          debugPrint('[AdhanScheduler] Triggering foreground timer for $prayerId');
          _playAdhanCallback(id);
        });
        _foregroundTimers.add(timer);
      }
    }
  }

  static Future<void> testAdhanPlaybackAfterSeconds(int seconds, String soundKey) async {
    debugPrint('[AdhanScheduler] TEST: Scheduling test Adhan playback after $seconds seconds with sound: $soundKey');
    final triggerTime = DateTime.now().add(Duration(seconds: seconds));
    
    // Pre-cache the test adhan file
    await _ensureAdhanFileExists(soundKey, false);
    await _ensureAdhanFileExists(soundKey, true);

    if (Platform.isIOS) {
        // For iOS test, trigger timer immediately after delay
        Timer(Duration(seconds: seconds), () {
          debugPrint('[AdhanScheduler] TEST: Triggering iOS foreground callback');
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
    
    debugPrint('[AdhanScheduler] TEST: Alarm scheduled for $triggerTime');
  }

  static Future<void> testAdhanPlaybackImmediate() async {
    if (!Platform.isAndroid) return; // Android-only
    
    debugPrint('[AdhanScheduler] TEST: Triggering Adhan callback IMMEDIATELY');
    debugPrint('[AdhanScheduler] TEST: Close app now and check logs!');
    
    // Call callback directly first to verify it works
    debugPrint('[AdhanScheduler] TEST: Calling callback directly...');
    try {
      await _playAdhanCallback(202511251); // fajr code
      debugPrint('[AdhanScheduler] TEST: Direct callback call completed');
    } catch (e) {
      debugPrint('[AdhanScheduler] TEST: Direct callback error: $e');
    }
  }
}


