import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Log severity levels, ordered from most to least verbose.
enum LogLevel { debug, info, warn, error }

/// A single emitted log record. Exposed so [Log.onRecord] sinks (e.g.
/// crash-reporting forwarders) can consume structured data instead of a
/// pre-formatted string.
class LogRecord {
  LogRecord({
    required this.level,
    required this.tag,
    required this.message,
    required this.time,
    this.error,
    this.stackTrace,
  });
  final LogLevel level;
  final String tag;
  final String message;
  final DateTime time;
  final Object? error;
  final StackTrace? stackTrace;
}

/// Central structured logger.
///
/// Why this instead of `debugPrint`:
/// * `debugPrint` is a no-op in release builds, so errors happening on real
///   user devices leave no trace. `dart:developer.log` continues to emit in
///   release mode and is visible in DevTools if attached — and can be
///   forwarded to a crash reporter (Sentry / Crashlytics / etc.) via
///   [onRecord] without touching every call site.
/// * Level-based filtering lets us raise the bar in release ([minLevel] =
///   info) while keeping noisy debug logs during development.
/// * Tags give each call site a searchable identity (previously we relied
///   on inline `[AdhanScheduler]` string prefixes).
///
/// Usage:
/// ```dart
/// Log.i('AdhanScheduler', 'Scheduled fajr at $time');
/// Log.e('AdhanScheduler', 'Alarm failed', error, stackTrace);
/// ```
class Log {
  Log._();

  /// Minimum level to emit. Raise this in release builds to suppress noisy
  /// debug traces while keeping warnings and errors. Tests may override.
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Optional sink invoked for every emitted record. Useful for forwarding
  /// to a crash reporter or persistent log store without changing call
  /// sites. Exceptions thrown by the sink are swallowed to prevent
  /// recursive failures from taking down the logger itself.
  static void Function(LogRecord record)? onRecord;

  static void d(String tag, String message) =>
      _log(LogLevel.debug, tag, message);

  static void i(String tag, String message) =>
      _log(LogLevel.info, tag, message);

  static void w(String tag, String message,
          [Object? error, StackTrace? stack]) =>
      _log(LogLevel.warn, tag, message, error, stack);

  static void e(String tag, String message,
          [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, tag, message, error, stack);

  static void _log(LogLevel level, String tag, String message,
      [Object? error, StackTrace? stack]) {
    if (level.index < minLevel.index) return;
    final now = DateTime.now();
    final record = LogRecord(
      level: level,
      tag: tag,
      message: message,
      time: now,
      error: error,
      stackTrace: stack,
    );

    // Primary emission: `dart:developer.log` survives release builds and is
    // visible in DevTools' Logging view. Numeric level follows java.util.logging:
    // FINE=500, INFO=800, WARNING=900, SEVERE=1000 — DevTools uses this to
    // colour-code entries.
    developer.log(
      message,
      time: now,
      level: _dartLevel(level),
      name: tag,
      error: error,
      stackTrace: stack,
    );

    // Debug-only: also echo to the Flutter console so `flutter run` output
    // is immediately readable without DevTools.
    if (kDebugMode) {
      final prefix = _levelGlyph(level);
      debugPrint('$prefix [$tag] $message'
          '${error != null ? ' error=$error' : ''}');
      if (stack != null) debugPrint(stack.toString());
    }

    final sink = onRecord;
    if (sink != null) {
      try {
        sink(record);
      } catch (_) {
        // Sinks must never crash the app's logging path.
      }
    }
  }

  static int _dartLevel(LogLevel l) {
    switch (l) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warn:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  static String _levelGlyph(LogLevel l) {
    switch (l) {
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warn:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }
}
