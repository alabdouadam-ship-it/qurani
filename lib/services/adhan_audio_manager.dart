import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';
import 'preferences_service.dart';

/// Single authoritative Adhan playback engine.
///
/// Responsibilities:
/// * Own the one-and-only `AudioPlayer` and native MethodChannel used for
///   Adhan playback, so foreground UI, the 30s-periodic `GlobalAdhanService`
///   loop, and the AndroidAlarmManager background isolate all go through the
///   same code path.
/// * Expose `isPlayingListenable` — the single source of truth in the main
///   isolate. UI that wants to show a stop-button subscribes to this via
///   `ValueListenableBuilder`.
/// * Persist playing-state to `SharedPreferences` so that playback started
///   in the background alarm isolate is observable from the main isolate on
///   `AppLifecycleState.resumed` via [syncPlayingStateFromPrefs].
/// * Receive `adhanPlaybackEnded` callbacks from the native Kotlin side so
///   completion of native `MediaPlayer` playback promptly clears the flag.
class AdhanAudioManager {
  // --- Engines ------------------------------------------------------------
  static final AudioPlayer _foregroundPlayer = AudioPlayer();
  static const MethodChannel _nativeChannel = MethodChannel('qurani/adhan');
  static final Set<AudioPlayer> _backgroundPlayers = {};

  // --- Session state (local to current isolate) --------------------------
  static StreamSubscription<PlayerState>? _foregroundSub;
  static Completer<void>? _sessionCompleter;
  static Timer? _safetyTimeout;
  static bool _nativeHandlerInstalled = false;

  // --- Cross-isolate flags (shared prefs) --------------------------------
  static const String _kIsPlaying = 'adhan_is_playing';
  static const String _kPlayingStartMs = 'adhan_playing_start_ms';
  static const String _kPlayingPrayerId = 'adhan_playing_prayer_id';

  /// Hard ceiling after which we consider any "still playing" flag stale.
  /// Longest Adhan recordings are ~4 minutes; 6 minutes gives safe slack.
  static const Duration _maxAdhanDuration = Duration(minutes: 6);

  /// Authoritative "Adhan currently playing" flag for the main isolate.
  ///
  /// * Flips to `true` synchronously when `playAdhan` starts any engine.
  /// * Flips to `false` when the foreground player's `playerStateStream`
  ///   reports completion, when `stopAllAdhanPlayback` is invoked, when the
  ///   native side calls back `adhanPlaybackEnded`, or when the safety
  ///   timeout fires.
  /// * Reconciled with the cross-isolate pref on app resume via
  ///   [syncPlayingStateFromPrefs] so UI correctly reflects playback that
  ///   began in the alarm background isolate.
  static final ValueNotifier<bool> isPlayingListenable =
      ValueNotifier<bool>(false);

  // --- Public API --------------------------------------------------------

  /// Unified entry point for starting Adhan playback.
  ///
  /// Honors the `adhan_<prayerId>` toggle and silently returns `false` if
  /// disabled (except for the synthetic `prayerId == 'test'` which always
  /// plays). Attempts engines in order:
  ///
  ///   1. Native Android `MediaPlayer` via `qurani/adhan` MethodChannel —
  ///      only succeeds when a `MainActivity` is alive, i.e. when the app
  ///      is in warm foreground. Gives best alarm-category behavior.
  ///   2. `just_audio` playing the cached file under
  ///      `<docs>/adhan_cache/<soundKey>[-fajr].mp3`.
  ///   3. `just_audio` playing the bundled asset fallback.
  ///
  /// Returns `true` iff any engine started playback.
  static Future<bool> playAdhan(String prayerId) async {
    // The AndroidAlarmManager background isolate does not run `main()` and
    // therefore never calls `PreferencesService.init()` — so every getter on
    // the service returns its default (usually null). Hydrate lazily so the
    // toggle/volume/sound reads below resolve correctly in both isolates.
    await PreferencesService.ensureInitialized();

    // Gate on the per-prayer toggle (test bypasses).
    if (prayerId != 'test') {
      final enabled = PreferencesService.getBool('adhan_$prayerId') ?? false;
      if (!enabled) return false;
    }

    // If something else is already playing, stop it first so we never stack
    // two adhans over each other.
    if (isPlayingListenable.value) {
      await stopAllAdhanPlayback();
    }

    final soundKey = PreferencesService.getAdhanSound();
    final isFajr = prayerId == 'fajr';
    final volume = PreferencesService.getAdhanVolume().clamp(0.0, 1.0);

    await _configureAudioSession();
    _ensureNativeCallbackHandler();

    // Mark playing *before* actually starting so a crash mid-start still
    // leaves a well-defined state that the safety timeout will clear.
    await _markPlaying(prayerId);

    final filePath = await _resolveCachedFilePath(soundKey, isFajr);

    // --- 1) Native -------------------------------------------------------
    if (filePath != null) {
      if (await _tryNative(filePath, volume)) {
        Log.i('AdhanAudioManager',
            'Native MediaPlayer started for $prayerId '
            '($soundKey${isFajr ? "-fajr" : ""})');
        // Native playback reports completion via MethodChannel callback; no
        // safety timer needed beyond the max-duration watchdog that
        // `_markPlaying` already armed.
        return true;
      }
    }

    // --- 2) just_audio from cached file ---------------------------------
    if (filePath != null) {
      try {
        await _foregroundPlayer.stop();
        await _foregroundPlayer.setAudioSource(AudioSource.file(filePath));
        await _foregroundPlayer.setVolume(volume);
        _attachForegroundCompletionListener();
        await _foregroundPlayer.play();
        Log.i('AdhanAudioManager', 'just_audio(file) started for $prayerId');
        return true;
      } catch (e, st) {
        Log.w('AdhanAudioManager', 'just_audio(file) failed', e, st);
      }
    }

    // --- 3) just_audio from bundled asset -------------------------------
    final asset = isFajr
        ? 'assets/audio/$soundKey-fajr.mp3'
        : 'assets/audio/$soundKey.mp3';
    try {
      await _foregroundPlayer.stop();
      await _foregroundPlayer.setAudioSource(AudioSource.asset(asset));
      await _foregroundPlayer.setVolume(volume);
      _attachForegroundCompletionListener();
      await _foregroundPlayer.play();
      Log.i('AdhanAudioManager', 'just_audio(asset) started for $prayerId');
      return true;
    } catch (e, st) {
      Log.w('AdhanAudioManager', 'just_audio(asset) failed', e, st);
    }

    // No engine started — clear the flag we set optimistically.
    await _markStopped();
    return false;
  }

  /// Resolves when the current playback session ends (completion, stop,
  /// error, or safety timeout). Returns immediately if nothing is playing.
  ///
  /// Primarily used by the AndroidAlarmManager background isolate, which
  /// must keep the Dart VM alive until playback finishes.
  static Future<void> awaitCurrentSession({Duration? timeout}) async {
    final completer = _sessionCompleter;
    if (completer == null || completer.isCompleted) return;
    if (timeout != null) {
      try {
        await completer.future.timeout(timeout);
      } on TimeoutException {
        Log.w('AdhanAudioManager', 'awaitCurrentSession timed out');
      }
    } else {
      await completer.future;
    }
  }

  /// Stop all engines. Safe to call from either isolate and from the
  /// notification-tap handler.
  static Future<void> stopAllAdhanPlayback() async {
    // Stop just_audio foreground + any registered background players.
    try {
      await _foregroundPlayer.stop();
    } catch (_) {}
    for (final player in _backgroundPlayers.toList()) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
      _backgroundPlayers.remove(player);
    }
    // Stop native MediaPlayer.
    try {
      await _nativeChannel.invokeMethod('stopAdhan');
    } catch (_) {}
    await _markStopped();
  }

  /// Reconcile [isPlayingListenable] with the cross-isolate pref so that
  /// playback started in the background alarm isolate is reflected in the
  /// main-isolate UI once the user resumes the app. Also clears a stale
  /// "playing" flag whose start-timestamp is older than `_maxAdhanDuration`.
  static Future<void> syncPlayingStateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final flag = prefs.getBool(_kIsPlaying) ?? false;
      final startMs = prefs.getInt(_kPlayingStartMs) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final stale =
          startMs == 0 || (now - startMs) > _maxAdhanDuration.inMilliseconds;
      if (flag && stale) {
        // Stale flag from a crashed/terminated isolate — clear it.
        await _markStopped();
        return;
      }
      // Double-check: if the flag says playing but no engine is actually
      // active in THIS isolate, and the pref is older than 30 seconds,
      // treat it as orphaned from a dead background isolate. This catches
      // the case where OEM ROMs serve a stale SharedPreferences disk cache
      // despite the reload() above.
      if (flag && !_foregroundPlayer.playing && _backgroundPlayers.isEmpty) {
        final age = now - startMs;
        if (age > 30000) {
          Log.w('AdhanAudioManager',
              'Playing flag set but no engine active and age=${age}ms; '
              'clearing orphaned state');
          await _markStopped();
          return;
        }
      }
      if (isPlayingListenable.value != flag) {
        isPlayingListenable.value = flag;
      }
    } catch (e, st) {
      Log.w('AdhanAudioManager', 'syncPlayingStateFromPrefs failed', e, st);
    }
  }

  // --- Backward-compatible shims ----------------------------------------

  /// Legacy entry point. Prefer [playAdhan].
  static Future<void> playForegroundAdhan(String prayerId) async {
    await playAdhan(prayerId);
  }

  /// Legacy entry point. Prefer [stopAllAdhanPlayback].
  static Future<void> stopForegroundAdhan() async {
    try {
      await _foregroundPlayer.stop();
    } catch (_) {}
    // Don't clear the flag here unilaterally — native or background players
    // may still be running. `stopAllAdhanPlayback` is the safe version.
  }

  /// Legacy entry point. Prefer [playAdhan] — this now also tracks state.
  static Future<bool> tryPlayNativeFile(
    String filePath, {
    double? volumeOverride,
  }) async {
    _ensureNativeCallbackHandler();
    final volume =
        (volumeOverride ?? PreferencesService.getAdhanVolume()).clamp(0.0, 1.0);
    return _tryNative(filePath, volume);
  }

  /// Legacy entry point. Prefer [stopAllAdhanPlayback].
  static Future<void> stopNativeAdhan() async {
    try {
      await _nativeChannel.invokeMethod('stopAdhan');
    } catch (_) {}
  }

  /// Legacy helper used by the background alarm isolate's fallback path.
  /// Registers [player] so [stopAllAdhanPlayback] can tear it down, and
  /// clears the playing flag when playback completes.
  static void registerBackgroundPlayer(AudioPlayer player) {
    _backgroundPlayers.add(player);
    player.playerStateStream
        .firstWhere((s) => s.processingState == ProcessingState.completed)
        .then((_) async {
      _backgroundPlayers.remove(player);
      try {
        await player.dispose();
      } catch (_) {}
      // Last player done → session ended.
      if (_backgroundPlayers.isEmpty) {
        await _markStopped();
      }
    }).catchError((_) {
      _backgroundPlayers.remove(player);
    });
  }

  // --- Privates ---------------------------------------------------------

  static Future<bool> _tryNative(String filePath, double volume) async {
    try {
      await _nativeChannel.invokeMethod(
        'playAdhan',
        {'filePath': filePath, 'volume': volume},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _configureAudioSession() async {
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
    } catch (_) {}
  }

  static Future<String?> _resolveCachedFilePath(
      String soundKey, bool isFajr) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = isFajr ? '$soundKey-fajr.mp3' : '$soundKey.mp3';
      final path = '${docDir.path}/adhan_cache/$fileName';
      if (File(path).existsSync()) return path;
      return null;
    } catch (_) {
      return null;
    }
  }

  static void _attachForegroundCompletionListener() {
    _foregroundSub?.cancel();
    _foregroundSub = _foregroundPlayer.playerStateStream.listen((s) async {
      if (s.processingState == ProcessingState.completed) {
        await _markStopped();
      }
    }, onError: (_) async {
      await _markStopped();
    });
  }

  /// Wires the MethodChannel to receive `adhanPlaybackEnded` from native.
  static void _ensureNativeCallbackHandler() {
    if (_nativeHandlerInstalled) return;
    _nativeHandlerInstalled = true;
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'adhanPlaybackEnded') {
        await _markStopped();
      }
      return null;
    });
  }

  static Future<void> _markPlaying(String prayerId) async {
    isPlayingListenable.value = true;
    // (Re)create the session completer so awaiters can block on it.
    if (_sessionCompleter == null || _sessionCompleter!.isCompleted) {
      _sessionCompleter = Completer<void>();
    }
    // Re-arm the safety timeout.
    _safetyTimeout?.cancel();
    _safetyTimeout = Timer(_maxAdhanDuration, () async {
      Log.w('AdhanAudioManager', 'Safety timeout fired — forcing stop');
      await stopAllAdhanPlayback();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      // Force fresh read before writing so we don't fight a stale disk
      // cache left by a dead isolate on OEM ROMs.
      await prefs.reload();
      await prefs.setBool(_kIsPlaying, true);
      await prefs.setInt(
          _kPlayingStartMs, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_kPlayingPrayerId, prayerId);
    } catch (_) {}
  }

  static Future<void> _markStopped() async {
    if (isPlayingListenable.value) {
      isPlayingListenable.value = false;
    }
    _safetyTimeout?.cancel();
    _safetyTimeout = null;
    final completer = _sessionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    try {
      _foregroundSub?.cancel();
      _foregroundSub = null;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsPlaying, false);
      await prefs.remove(_kPlayingStartMs);
      await prefs.remove(_kPlayingPrayerId);
    } catch (_) {}
  }
}

