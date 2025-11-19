import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  print('[AdhanScheduler.Callback] Step 0b: Initializing DartPluginRegistrant...');
  try {
    DartPluginRegistrant.ensureInitialized();
    print('[AdhanScheduler.Callback] ✓ DartPluginRegistrant initialized');
  } catch (e) {
    print('[AdhanScheduler.Callback] ✗ DartPluginRegistrant error: $e');
  }
  
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

    if (prayerId == null) {
      debugPrint('[AdhanScheduler.Callback] ✗ Invalid prayer code: $code');
      return;
    }
    
    debugPrint('[AdhanScheduler.Callback] Prayer ID: $prayerId');
    
    final enabled = prefs.getBool('adhan_$prayerId') ?? false;
    debugPrint('[AdhanScheduler.Callback] Enabled for $prayerId: $enabled');
    if (!enabled) return;

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
    final now = DateTime.now();
    debugPrint('[AdhanScheduler] ===== SCHEDULING ADHANS START =====');
    debugPrint('[AdhanScheduler] Current time: $now');
    debugPrint('[AdhanScheduler] Sound key: $soundKey');
    
    // Verify caches files exist
    await _verifyAdhanCacheFiles();
    
    for (final id in const ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if (!(toggles[id] ?? false)) {
        debugPrint('[AdhanScheduler] ⊘ $id disabled');
        continue;
      }
      final t = times[id];
      if (t == null) {
        debugPrint('[AdhanScheduler] ⊘ $id no time data');
        continue;
      }
      if (!t.isAfter(now)) {
        debugPrint('[AdhanScheduler] ⊘ $id time already passed ($t)');
        continue;
      }
      final alarmId = _dailyId(prayerId: id, date: t);
      try {
        debugPrint('[AdhanScheduler] ✓ Scheduling $id for $t (ID: $alarmId)');
        debugPrint('[AdhanScheduler]   Time until trigger: ${t.difference(now).inMinutes} minutes');
        
        // Cancel any existing alarm with the same ID first
        try {
          await AndroidAlarmManager.cancel(alarmId);
          debugPrint('[AdhanScheduler]   Cancelled any existing alarm with ID $alarmId');
        } catch (_) {
          // Ignore if alarm doesn't exist
        }
        
        final scheduled = await AndroidAlarmManager.oneShotAt(
          t,
          alarmId,
          _playAdhanCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          allowWhileIdle: true,
        );
        if (scheduled) {
          debugPrint('[AdhanScheduler]   ✓✓✓ $id SCHEDULED SUCCESSFULLY (ID: $alarmId, Time: $t)');
        } else {
          debugPrint('[AdhanScheduler]   ✗✗✗ $id scheduling returned FALSE - ALARM NOT SCHEDULED!');
        }
      } catch (e, stackTrace) {
        debugPrint('[AdhanScheduler]   ✗✗✗ Error scheduling $id: $e');
        debugPrint('[AdhanScheduler]   Stack trace: $stackTrace');
      }
    }
    debugPrint('[AdhanScheduler] ===== SCHEDULING ADHANS END =====');
  }

  static Future<void> _verifyAdhanCacheFiles() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/adhan_cache');
      debugPrint('[AdhanScheduler] Checking adhan cache at: ${cacheDir.path}');
      
      if (!await cacheDir.exists()) {
        debugPrint('[AdhanScheduler] ✗ Cache directory DOES NOT EXIST');
        return;
      }
      
      final files = cacheDir.listSync().whereType<File>().toList();
      debugPrint('[AdhanScheduler] ✓ Cache directory exists with ${files.length} files');
      for (final file in files) {
        debugPrint('[AdhanScheduler]   - ${file.path.split('/').last} (${file.lengthSync()} bytes)');
      }
    } catch (e) {
      debugPrint('[AdhanScheduler] Error verifying cache: $e');
    }
  }

  static Future<void> testAdhanPlaybackAfterSeconds(int seconds, String soundKey) async {
    debugPrint('[AdhanScheduler] TEST: Scheduling test Adhan playback after $seconds seconds with sound: $soundKey');
    final triggerTime = DateTime.now().add(Duration(seconds: seconds));
    
    await AndroidAlarmManager.oneShotAt(
      triggerTime,
      999999,
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


