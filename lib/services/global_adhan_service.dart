import 'foreground_adhan_monitor.dart';
import 'prayer_cache_policy.dart';
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
  static void Function()? onDayChanged;
  late final _monitor = ForegroundAdhanMonitor(
    loadTimes: (day) => PrayerTimesService.getTimesForDate(
      year: day.year, month: day.month, day: day.day),
    play: (prayer) async { await AdhanAudioManager.playAdhan(prayer); },
    isPlaying: () => AdhanAudioManager.isPlayingListenable.value,
    isEnabled: (prayer) => PreferencesService.getBool('adhan_$prayer') ?? false,
    onDayChanged: () => onDayChanged?.call(),
    cacheRevision: () => PrayerCachePolicy.revision,
  );

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

  /// Pause the 30s foreground monitoring timer. Called when the app is
  /// backgrounded: the AndroidAlarmManager background isolate owns Adhan
  /// playback while we're not in the foreground, so a foreground polling
  /// timer running in parallel would be redundant work that also widens the
  /// race window where both paths could try to play near prayer time. Pausing
  /// it on background partitions responsibility cleanly (alarm = background,
  /// timer = foreground) and saves battery.
  static void pause() {
    _instance._stop();
  }

  /// Resume foreground monitoring. Reloads today's times and re-syncs the
  /// playing flag before restarting the timer, so state is fresh after a
  /// possibly-long background period. Safe to call repeatedly — `_start`
  /// cancels any existing timer first.
  static Future<void> resume() async {
    await _instance._start();
  }

  /// Check if Adhan is currently playing.
  static bool get isAdhanPlaying => AdhanAudioManager.isPlayingListenable.value;

  /// Stop any currently playing Adhan.
  static Future<void> stopAdhan() async {
    await AdhanAudioManager.stopAllAdhanPlayback();
  }

  int _lifecycleGeneration = 0;

  Future<void> _start() async {
    _stop();
    final generation = _lifecycleGeneration;
    await AdhanAudioManager.syncPlayingStateFromPrefs();
    if (generation != _lifecycleGeneration) return;
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_checkAndPlayAdhan());
    });
    await _checkAndPlayAdhan();
  }

  void _stop() {
    _lifecycleGeneration++;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _monitor.invalidate();
  }

  Future<void> _checkAndPlayAdhan() async {
    try {
      if (_cacheRevision != PrayerCachePolicy.revision) {
        _cacheRevision = PrayerCachePolicy.revision;
        _monitor.invalidate();
      }
      await _monitor.check();
    } catch (e, st) {
      Log.w('GlobalAdhanService', 'Error monitoring prayer times', e, st);
    }
  }
  int _cacheRevision = -1;
}
