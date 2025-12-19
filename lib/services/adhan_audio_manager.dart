import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'preferences_service.dart';

class AdhanAudioManager {
  static final AudioPlayer _foregroundPlayer = AudioPlayer();
  static const MethodChannel _nativeChannel = MethodChannel('qurani/adhan');
  static final Set<AudioPlayer> _backgroundPlayers = {};

  static Future<void> playForegroundAdhan(String prayerId) async {
    final enabled = PreferencesService.getBool('adhan_$prayerId') ?? false;
    if (!enabled) return;

    final soundKey = PreferencesService.getAdhanSound();
    final isFajr = prayerId == 'fajr';
    final asset =
        isFajr ? 'assets/audio/$soundKey-fajr.mp3' : 'assets/audio/$soundKey.mp3';
    final volume = PreferencesService.getAdhanVolume().clamp(0.0, 1.0);

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

    try {
      await _foregroundPlayer.stop();
      await _foregroundPlayer.setAudioSource(AudioSource.asset(asset));
      await _foregroundPlayer.setVolume(volume);
      await _foregroundPlayer.play();
    } catch (_) {}
  }

  static Future<void> stopForegroundAdhan() async {
    try {
      await _foregroundPlayer.stop();
    } catch (_) {}
  }

  static Future<bool> tryPlayNativeFile(
    String filePath, {
    double? volumeOverride,
  }) async {
    try {
      final volume =
          (volumeOverride ?? PreferencesService.getAdhanVolume()).clamp(0.0, 1.0);
      await _nativeChannel
          .invokeMethod('playAdhan', {'filePath': filePath, 'volume': volume});
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopNativeAdhan() async {
    try {
      await _nativeChannel.invokeMethod('stopAdhan');
    } catch (_) {}
  }

  static Future<void> stopAllAdhanPlayback() async {
    await stopForegroundAdhan();
    await stopNativeAdhan();
    for (final player in _backgroundPlayers.toList()) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
      _backgroundPlayers.remove(player);
    }
  }

  static void registerBackgroundPlayer(AudioPlayer player) {
    _backgroundPlayers.add(player);
    player.playerStateStream
        .firstWhere((s) => s.processingState == ProcessingState.completed)
        .then((_) async {
      _backgroundPlayers.remove(player);
      try {
        await player.dispose();
      } catch (_) {}
    }).catchError((_) {
      _backgroundPlayers.remove(player);
    });
  }
}

