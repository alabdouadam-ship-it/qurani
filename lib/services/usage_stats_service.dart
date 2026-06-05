import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net_utils.dart';
import 'preferences_service.dart';
import 'supabase_config.dart';

/// Anonymous, opt-out-able usage statistics sent to Supabase via the
/// locked-down RPCs in `supabase/migrations/..._app_stats.sql`.
///
/// ### Privacy contract (must stay true)
/// - Identity is the app's RANDOM installation UUID — never a hardware id,
///   advertising id, or any PII.
/// - Only coarse, non-identifying data is sent (platform/OS/model, app
///   version, language, coarse country from locale, timezone, anonymous
///   product preferences, and usage counters).
/// - NOTHING is sent when the user opted out, Supabase isn't configured, or
///   we're offline.
///
/// ### Performance contract (the priority for this app)
/// - **The hot path ([logFeature]) is pure in-memory** — a single list
///   `add()`, no disk I/O, no JSON, no `await`. Tapping features never pays an
///   analytics cost.
/// - **Disk is touched only on lifecycle edges** (background/opt-out), never
///   per interaction. SharedPreferences writes therefore happen at most ~once
///   per session, off the interaction path.
/// - **All network calls are fire-and-forget and connectivity-gated**, run via
///   `unawaited`, so they never block a frame or the offline experience.
/// - When disabled (opted out / unconfigured) every entry point returns on the
///   first line — the feature is a true no-op with zero allocation.
///
/// ### Offline durability (without hot-path cost)
/// The in-memory buffer is persisted to disk on the background transition (the
/// normal way an app is closed) and reloaded on next launch, so offline
/// sessions don't lose data. The only loss window is a *hard crash* mid-session
/// before any background event — acceptable for best-effort telemetry.
class UsageStatsService {
  UsageStatsService._();
  static final UsageStatsService instance = UsageStatsService._();

  // ── Persisted keys ─────────────────────────────────────────────────────
  static const String _keyOptOut = 'analytics_opt_out';
  static const String _keyEventQueue = 'analytics_event_queue_v1';
  static const String _keySessionStart = 'analytics_session_start_ms_v1';
  static const String _keySessionVersion = 'analytics_session_version_v1';
  static const String _keyLastHeartbeatDay = 'analytics_last_heartbeat_day_v1';

  /// Hard cap on buffered events so a long offline streak can't grow memory or
  /// the persisted blob unbounded. Oldest are dropped (telemetry is
  /// best-effort, not a ledger).
  static const int _maxQueued = 500;

  /// Flush mid-session once this many events accumulate (network only — no
  /// disk write on this path).
  static const int _flushThreshold = 20;

  /// Clamp for a recovered (crash) session so a phone that slept for days
  /// doesn't report an absurd duration.
  static const int _maxSessionSeconds = 6 * 60 * 60; // 6h

  static bool get isOptedOut =>
      PreferencesService.getBool(_keyOptOut) ?? false;

  static Future<void> setOptedOut(bool value) async {
    await PreferencesService.setBool(_keyOptOut, value);
    if (value) {
      // Honor opt-out immediately: drop in-memory + persisted data.
      instance._buffer.clear();
      await instance._clearPersisted();
    }
  }

  bool get _enabled => SupabaseConfig.isReady && !isOptedOut;

  /// In-memory working set. The hot path only touches this.
  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];

  String? _appVersion;
  String? _appBuild;
  bool _flushing = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Called once at startup (after Supabase init + device-info collection).
  /// Fire-and-forget from `main()`, so none of this blocks the first frame.
  Future<void> init() async {
    if (!_enabled) return;
    _hydrateAppVersionFromDeviceInfo();

    // Pull any events a previous (offline/killed) session left on disk into
    // memory, and clear the disk copy — memory is now the working set.
    await _loadPersistedIntoBuffer();

    // Recover a session cut off by an app kill last time.
    await _recoverInterruptedSession();

    // One connectivity probe gates ALL network work below (avoids redundant
    // DNS lookups on launch). If offline, everything stays buffered for later.
    if (await NetUtils.hasInternet()) {
      unawaited(_flushOverNetwork());
      unawaited(_dailyHeartbeat());
    }

    await _startSession();
  }

  /// Records a feature open/use. HOT PATH — intentionally synchronous and
  /// in-memory only (no disk, no JSON, no await).
  void logFeature(String feature, {String action = 'open'}) {
    if (!_enabled) return;
    _buffer.add({
      'feature': feature,
      'action': action,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_buffer.length > _maxQueued) {
      _buffer.removeRange(0, _buffer.length - _maxQueued);
    }
    // Network-only flush at the threshold; still no disk write here.
    if (_buffer.length >= _flushThreshold && !_flushing) {
      unawaited(flushEvents());
    }
  }

  /// Records how long a screen was visible (a timed 'view' event). Same
  /// in-memory hot-path treatment as [logFeature]. Sub-second views are
  /// dropped (transient pushes), and an absurd duration is clamped.
  void logScreenTime(String feature, int seconds) {
    if (!_enabled) return;
    if (seconds <= 0) return;
    if (seconds > _maxSessionSeconds) seconds = _maxSessionSeconds;
    _buffer.add({
      'feature': feature,
      'action': 'view',
      'duration_seconds': seconds,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_buffer.length > _maxQueued) {
      _buffer.removeRange(0, _buffer.length - _maxQueued);
    }
    if (_buffer.length >= _flushThreshold && !_flushing) {
      unawaited(flushEvents());
    }
  }

  /// Called when the app is backgrounded/closed. This is where we pay the
  /// (single) disk write for durability, then attempt a send. Safe to call
  /// repeatedly.
  Future<void> endSession() async {
    if (!_enabled) return;
    // Durability: persist the buffer once, so a kill after this can't lose it.
    await _persistBuffer();
    // Record the finished session's duration.
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_keySessionStart);
    await prefs.remove(_keySessionStart);

    if (!await NetUtils.hasInternet()) {
      // Offline: keep everything on disk; record session on a later launch
      // only if it matters — here we simply drop the (already-persisted)
      // attempt to avoid a hanging request.
      return;
    }
    await flushEvents();
    if (startMs != null) {
      final start = DateTime.fromMillisecondsSinceEpoch(startMs);
      final seconds = DateTime.now().difference(start).inSeconds;
      if (seconds > 0) {
        unawaited(_recordSession(start, seconds.clamp(0, _maxSessionSeconds)));
      }
    }
  }

  /// Sends buffered events in a single RPC, clearing them (memory + disk) only
  /// on success. Connectivity-gated and re-entrancy-guarded.
  Future<void> flushEvents() async {
    if (!_enabled || _flushing || _buffer.isEmpty) return;
    if (!await NetUtils.hasInternet()) return;
    await _flushOverNetwork();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Assumes caller already confirmed connectivity (or accepts a failed RPC).
  Future<void> _flushOverNetwork() async {
    if (_flushing || _buffer.isEmpty) return;
    _flushing = true;
    final sending = List<Map<String, dynamic>>.from(_buffer);
    try {
      await SupabaseConfig.client.rpc('record_feature_events', params: {
        'p_installation_id': PreferencesService.getInstallationId(),
        'p_events': sending,
        'p_app_version': _appVersion,
      });
      // Remove exactly what we sent (events logged meanwhile are kept).
      _buffer.removeRange(0, sending.length);
      await _clearPersisted(); // disk copy is now stale
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageStats] flush failed: $e');
      // Keep the buffer for a later attempt.
    } finally {
      _flushing = false;
    }
  }

  Future<void> _dailyHeartbeat() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(DateTime.now());
    if (prefs.getInt(_keyLastHeartbeatDay) == todayKey) return; // done today

    final info = _deviceInfo();
    final platform = (info?['platform'] as Map?)?.cast<String, dynamic>() ?? {};
    final locale = (info?['locale'] as Map?)?.cast<String, dynamic>() ?? {};
    final tz = (info?['timezone'] as Map?)?.cast<String, dynamic>() ?? {};
    try {
      await SupabaseConfig.client.rpc('record_installation', params: {
        'p_installation_id': PreferencesService.getInstallationId(),
        'p_platform': platform['os'],
        'p_os_version': platform['version'] ?? platform['systemVersion'],
        'p_device_model': platform['model'],
        'p_manufacturer': platform['manufacturer'],
        'p_is_physical_device': platform['isPhysicalDevice'],
        'p_app_version': _appVersion,
        'p_app_build': _appBuild,
        'p_app_language': PreferencesService.getLanguage(),
        'p_locale_language': locale['languageCode'],
        'p_country_code': locale['countryCode'],
        'p_timezone': tz['name'],
        'p_tz_offset_minutes': tz['offsetMinutes'],
        'p_theme_id': PreferencesService.getTheme(),
        'p_reciter_code': PreferencesService.getReciter(),
        'p_notifications_enabled': _anyAdhanEnabled(),
      });
      await prefs.setInt(_keyLastHeartbeatDay, todayKey);
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageStats] heartbeat failed: $e');
    }
  }

  /// Persist the session start (crash-safe). Disk write on resume only — not a
  /// hot path.
  Future<void> _startSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySessionStart, DateTime.now().millisecondsSinceEpoch);
    if (_appVersion != null) {
      await prefs.setString(_keySessionVersion, _appVersion!);
    }
  }

  /// Re-open a session on resume (called from the app lifecycle observer).
  void startSession() {
    if (!_enabled) return;
    unawaited(_startSession());
  }

  /// If a session start was left on disk (app killed without a clean
  /// background event), record an approximate duration up to the last buffered
  /// event, then clear it.
  Future<void> _recoverInterruptedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_keySessionStart);
    if (startMs == null) return;
    await prefs.remove(_keySessionStart);
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final version = prefs.getString(_keySessionVersion);

    DateTime end = start.add(const Duration(seconds: 1));
    for (final e in _buffer) {
      final t = DateTime.tryParse(e['occurred_at'] as String? ?? '');
      if (t != null && t.isAfter(end)) end = t;
    }
    final seconds = end.difference(start).inSeconds.clamp(0, _maxSessionSeconds);
    if (seconds <= 0) return;
    if (!await NetUtils.hasInternet()) return;
    unawaited(_recordSession(start, seconds, appVersionOverride: version));
  }

  Future<void> _recordSession(DateTime start, int seconds,
      {String? appVersionOverride}) async {
    try {
      await SupabaseConfig.client.rpc('record_session', params: {
        'p_installation_id': PreferencesService.getInstallationId(),
        'p_started_at': start.toUtc().toIso8601String(),
        'p_duration_seconds': seconds,
        'p_app_version': appVersionOverride ?? _appVersion,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageStats] recordSession failed: $e');
    }
  }

  // ── disk persistence (called only on edges) ────────────────────────────

  Future<void> _persistBuffer() async {
    final prefs = await SharedPreferences.getInstance();
    if (_buffer.isEmpty) {
      await prefs.remove(_keyEventQueue);
      return;
    }
    final encoded = _buffer.map(jsonEncode).toList(growable: false);
    await prefs.setStringList(_keyEventQueue, encoded);
  }

  Future<void> _loadPersistedIntoBuffer() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_keyEventQueue);
    if (stored == null || stored.isEmpty) return;
    for (final s in stored) {
      try {
        _buffer.add(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {/* skip malformed */}
    }
    if (_buffer.length > _maxQueued) {
      _buffer.removeRange(0, _buffer.length - _maxQueued);
    }
    await prefs.remove(_keyEventQueue); // memory is now the working set
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEventQueue);
  }

  // ── small helpers ──────────────────────────────────────────────────────

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  Map<String, dynamic>? _deviceInfo() {
    final raw = PreferencesService.getDeviceInfoJson();
    if (raw == null || raw.isEmpty) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _hydrateAppVersionFromDeviceInfo() {
    final app = (_deviceInfo()?['app'] as Map?)?.cast<String, dynamic>();
    _appVersion = app?['version'] as String?;
    _appBuild = app?['buildNumber'] as String?;
  }

  bool _anyAdhanEnabled() {
    const ids = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (final id in ids) {
      if (PreferencesService.getBool('adhan_$id') ?? false) return true;
    }
    return false;
  }
}
