import 'dart:async';
import 'package:flutter/material.dart';
import 'prayer_times_service.dart';
import 'adhan_audio_manager.dart';
import 'logger.dart';
import 'preferences_service.dart';

/// Monitors prayer times and triggers Adhan playback through the single
/// authoritative [AdhanAudioManager] engine.
///
/// All "is playing" state now lives on [AdhanAudioManager.isPlayingListenable].
/// The getters on this class forward to the manager for backward-compat with
/// any call sites still referencing `GlobalAdhanService.isPlayingListenable`.
class GlobalAdhanService {
  static final GlobalAdhanService _instance = GlobalAdhanService._internal();
  factory GlobalAdhanService() => _instance;
  GlobalAdhanService._internal();

  Timer? _monitorTimer;
  DateTime? _lastCheckedDay;
  Map<String, DateTime>? _todayTimes;
  final Set<String> _playedToday = {};

  /// Forwarder to [AdhanAudioManager.isPlayingListenable] — the single
  /// source of truth across the foreground UI and the background alarm
  /// isolate.
  static ValueNotifier<bool> get isPlayingListenable =>
      AdhanAudioManager.isPlayingListenable;

  /// Initialize the global Adhan monitoring service.
  ///
  /// Safe to call multiple times: `_start` cancels any pre-existing monitor
  /// timer before scheduling a new one, so repeated calls (hot reload, a
  /// defensive re-init from a lifecycle callback) cannot leak a timer.
  static Future<void> init() async {
    await _instance._start();
  }

  /// Stop the monitoring service.
  ///
  /// Not currently wired into the app lifecycle because the service is a
  /// process-scoped singleton that should live as long as the UI isolate
  /// itself; the Android OS tears the timer down when the process exits.
  /// Retained for tests and any future teardown path (e.g. a settings toggle
  /// that fully disables Adhan monitoring).
  static void dispose() {
    _instance._stop();
  }

  /// Check if Adhan is currently playing.
  static bool get isAdhanPlaying => AdhanAudioManager.isPlayingListenable.value;

  /// Stop any currently playing Adhan.
  static Future<void> stopAdhan() async {
    await AdhanAudioManager.stopAllAdhanPlayback();
  }

  Future<void> _start() async {
    await _loadTodayTimes();
    // Re-sync the in-memory notifier with prefs in case an alarm fired
    // while the main isolate was cold-starting.
    await AdhanAudioManager.syncPlayingStateFromPrefs();

    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndPlayAdhan();
    });

    // Also check immediately
    _checkAndPlayAdhan();
  }

  void _stop() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<void> _loadTodayTimes() async {
    final now = DateTime.now();

    // Reset if it's a new day
    if (_lastCheckedDay == null ||
        _lastCheckedDay!.day != now.day ||
        _lastCheckedDay!.month != now.month ||
        _lastCheckedDay!.year != now.year) {
      _playedToday.clear();
      _lastCheckedDay = now;
    }

    try {
      _todayTimes = await PrayerTimesService.getTimesForDate(
        year: now.year,
        month: now.month,
        day: now.day,
      );
    } catch (e, st) {
      Log.w('GlobalAdhanService', 'Error loading prayer times', e, st);
    }
  }

  Future<void> _checkAndPlayAdhan() async {
    // Don't play if the authoritative engine says something's already going.
    if (AdhanAudioManager.isPlayingListenable.value) return;
    if (_todayTimes == null) {
      await _loadTodayTimes();
      if (_todayTimes == null) return;
    }

    final now = DateTime.now();
    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    for (final prayerId in prayers) {
      final prayerTime = _todayTimes![prayerId];
      if (prayerTime == null) continue;

      // Within 30 seconds of prayer time
      final diff = now.difference(prayerTime).inSeconds.abs();
      if (diff <= 30) {
        final enabled = PreferencesService.getBool('adhan_$prayerId') ?? false;
        if (enabled && !_playedToday.contains(prayerId)) {
          _playedToday.add(prayerId);
          Log.i('GlobalAdhanService', 'Playing Adhan for $prayerId');
          // Delegate entirely to the unified engine. The manager handles:
          //  - picking the best engine (native → file → asset)
          //  - flipping `isPlayingListenable`
          //  - driving the completion listener so the flag clears at end
          //  - the 6-minute safety timeout
          await AdhanAudioManager.playAdhan(prayerId);
          break;
        }
      }
    }
  }
}
