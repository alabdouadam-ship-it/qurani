import 'dart:async';
import 'package:flutter/material.dart';
import 'prayer_times_service.dart';
import 'adhan_audio_manager.dart';
import 'preferences_service.dart';
/// Global service that monitors prayer times and plays Adhan across all screens
class GlobalAdhanService {
  static final GlobalAdhanService _instance = GlobalAdhanService._internal();
  factory GlobalAdhanService() => _instance;
  GlobalAdhanService._internal();

  Timer? _monitorTimer;
  DateTime? _lastCheckedDay;
  Map<String, DateTime>? _todayTimes;
  final Set<String> _playedToday = {};
  static bool _isPlaying = false;

  /// Initialize the global Adhan monitoring service
  static Future<void> init() async {
    await _instance._start();
  }

  /// Stop the monitoring service
  static void dispose() {
    _instance._stop();
  }

  /// Check if Adhan is currently playing
  static bool get isAdhanPlaying => _isPlaying;

  /// Stop any currently playing Adhan
  static Future<void> stopAdhan() async {
    _isPlaying = false;
    await AdhanAudioManager.stopAllAdhanPlayback();
    // Notification stop is handled by the scheduled notification's action button
  }

  Future<void> _start() async {
    await _loadTodayTimes();
    
    // Check every 30 seconds for prayer times
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
    } catch (e) {
      debugPrint('[GlobalAdhanService] Error loading prayer times: $e');
    }
  }

  Future<void> _checkAndPlayAdhan() async {
    if (_isPlaying) return; // Don't play if already playing
    if (_todayTimes == null) {
      await _loadTodayTimes();
      if (_todayTimes == null) return;
    }

    final now = DateTime.now();
    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    
    for (final prayerId in prayers) {
      final prayerTime = _todayTimes![prayerId];
      if (prayerTime == null) continue;
      
      // Check if it's time for this prayer (within 1 minute window)
      final diff = now.difference(prayerTime).inSeconds.abs();
      if (diff <= 30) { // Within 30 seconds of prayer time
        // Check if enabled and not already played today
        final enabled = PreferencesService.getBool('adhan_$prayerId') ?? false;
        if (enabled && !_playedToday.contains(prayerId)) {
          _playedToday.add(prayerId);
          await _playAdhan(prayerId);
          break; // Only play one at a time
        }
      }
    }
  }

  Future<void> _playAdhan(String prayerId) async {
    try {
      _isPlaying = true;
      debugPrint('[GlobalAdhanService] Playing Adhan for $prayerId');
      
      // Stop button is now part of the scheduled Adhan notification
      
      // Play Adhan using the audio manager
      await AdhanAudioManager.playForegroundAdhan(prayerId);
      
      // Monitor completion (approximate duration - most adhans are 2-3 minutes)
      // We use a longer timeout to ensure we don't cut off long adhans
      Future.delayed(const Duration(minutes: 5), () {
        if (_isPlaying) {
          _isPlaying = false;
        }
      });
    } catch (e) {
      debugPrint('[GlobalAdhanService] Error playing Adhan: $e');
      _isPlaying = false;
    }
  }
}
