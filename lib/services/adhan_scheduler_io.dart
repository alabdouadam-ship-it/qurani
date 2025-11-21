import 'dart:async';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'adhan_audio_manager.dart';
import 'notification_service.dart';
import 'preferences_service.dart';

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
  return isFajr ? 'assets/audio/${soundKey}-fajr.mp3' : 'assets/audio/$soundKey.mp3';
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
    return true;
  } catch (e) {
    debugPrint('[AdhanScheduler] ✗ Failed to cache $soundKey (fajr: $isFajr): $e');
    return false;
  }
}

@pragma('vm:entry-point')
Future<void> _playAdhanCallback(int id) async {
  print('[AdhanScheduler.Callback] ===== ADHAN CALLBACK TRIGGERED (ID: $id) =====');
  print('[AdhanScheduler.Callback] Step 0: Initializing Flutter bindings...');
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('[AdhanScheduler.Callback] ✓ WidgetsFlutterBinding initialized');
  } catch (e) {
    print('[AdhanScheduler.Callback] ✗ WidgetsFlutterBinding error: $e');
  }
  
  // DartPluginRegistrant is handled automatically by the platform
  
  try {
    print('[AdhanScheduler.Callback] Step 1: Getting preferences...');
    final prefs = await SharedPreferences.getInstance();
    print('[AdhanScheduler.Callback] ✓ SharedPreferences obtained');
    
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
    final fileName = isFajr ? '${soundKey}-fajr.mp3' : '$soundKey.mp3';
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
      await NotificationService.showActiveAdhanNotification(prayerId);
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
      await player.play();
      debugPrint('[AdhanScheduler.Callback] ✓ Playback started');
      await NotificationService.showActiveAdhanNotification(prayerId);
      AdhanAudioManager.registerBackgroundPlayer(player);
      
      // Keep player alive and don't dispose immediately
      // Let it play in background
      debugPrint('[AdhanScheduler.Callback] Adhan is playing, keeping player alive...');
      
      // Wait for completion but don't block
      player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .timeout(const Duration(seconds: 300))
          .then((_) async {
        debugPrint('[AdhanScheduler.Callback] ✓ Playback completed');
        await NotificationService.cancelActiveAdhanNotification();
        player.dispose().catchError((e) {
          debugPrint('[AdhanScheduler.Callback] ⊘ Dispose error: $e');
        });
      }).catchError((e) {
        debugPrint('[AdhanScheduler.Callback] ⊘ Playback monitoring error: $e');
        Future.delayed(const Duration(seconds: 5), () async {
          await NotificationService.cancelActiveAdhanNotification();
          player.dispose().catchError((err) {
            debugPrint('[AdhanScheduler.Callback] ⊘ Final dispose error: $err');
          });
        });
      });
      
      // Don't wait - return immediately to let it play
      debugPrint('[AdhanScheduler.Callback] ✓ Adhan playback initiated successfully');
    } catch (e) {
      debugPrint('[AdhanScheduler.Callback] ✗ Playback error: $e');
      await NotificationService.cancelActiveAdhanNotification();
      try {
        await player.dispose();
      } catch (_) {}
    }
    
    debugPrint('[AdhanScheduler.Callback] ===== CALLBACK COMPLETE =====');
  } catch (e, st) {
    debugPrint('[AdhanScheduler.Callback] ✗✗✗ FATAL ERROR: $e');
    debugPrint('[AdhanScheduler.Callback] Stack: $st');
  }
}

class AdhanScheduler {
  static Future<void> init() async {
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
    debugPrint('[AdhanScheduler] Scheduling Adhan alarms...');
    final now = DateTime.now();
    
    // Pre-cache the sound files we'll need
    for (final prayerId in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if (toggles[prayerId] ?? false) {
        await _ensureAdhanFileExists(soundKey, prayerId == 'fajr');
      }
    }
    
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


  static Future<void> testAdhanPlaybackAfterSeconds(int seconds, String soundKey) async {
    debugPrint('[AdhanScheduler] TEST: Scheduling test Adhan playback after $seconds seconds with sound: $soundKey');
    final triggerTime = DateTime.now().add(Duration(seconds: seconds));
    
    // Pre-cache the test adhan file
    await _ensureAdhanFileExists(soundKey, false);
    await _ensureAdhanFileExists(soundKey, true);
    
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


