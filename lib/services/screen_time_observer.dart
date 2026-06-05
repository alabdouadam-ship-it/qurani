import 'package:flutter/widgets.dart';

import 'usage_stats_service.dart';

/// A single [NavigatorObserver] that measures how long each named screen is
/// visible and reports it as a timed 'view' event via [UsageStatsService].
///
/// ### Why an observer (not per-screen timers)
/// Wiring enter/exit timers into ~14 screens would be invasive and easy to get
/// wrong (initState/dispose, lifecycle, back-button, etc.). One observer on the
/// root navigator captures the same data with zero per-screen state — screens
/// only need a `RouteSettings(name: ...)` at their push site to opt in.
///
/// ### How timing works
/// We track the top-of-stack named route and the moment it became visible.
/// When the stack changes (push / pop / replace / remove), the route that was
/// on top has just been covered or removed, so we emit its elapsed view time
/// and start the clock for whatever is now on top.
///
/// ### Cost / safety
/// - All work is a couple of timestamp comparisons + an in-memory log call
///   ([UsageStatsService.logScreenTime] is buffer-only). No disk/network on the
///   navigation path.
/// - No-op when analytics is disabled (logScreenTime returns immediately).
/// - Unnamed routes (dialogs, bottom sheets, anonymous MaterialPageRoutes) are
///   ignored, so we only measure real screens we chose to name.
class ScreenTimeObserver extends NavigatorObserver {
  String? _currentName;
  DateTime? _enteredAt;

  void _flushCurrent() {
    final name = _currentName;
    final enteredAt = _enteredAt;
    _currentName = null;
    _enteredAt = null;
    if (name == null || enteredAt == null) return;
    final seconds = DateTime.now().difference(enteredAt).inSeconds;
    UsageStatsService.instance.logScreenTime(name, seconds);
  }

  void _enter(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) {
      // Whatever is now on top isn't a named screen we track.
      _currentName = null;
      _enteredAt = null;
      return;
    }
    _currentName = name;
    _enteredAt = DateTime.now();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The previous top (if any) is now covered — record its time, then start
    // timing the newly-pushed route.
    _flushCurrent();
    _enter(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The popped route was on top — record its time, then resume timing the
    // route revealed underneath.
    _flushCurrent();
    _enter(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _flushCurrent();
    _enter(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // A route was removed from the stack (not via pop). If it was the one we
    // were timing, flush and resume on whatever is now relevant.
    if (route.settings.name == _currentName) {
      _flushCurrent();
      _enter(previousRoute);
    }
  }

  /// Called when the app is backgrounded: record the in-progress screen's time
  /// so far (but keep tracking it, since it's still on top of the stack).
  void onAppPaused() {
    final name = _currentName;
    final enteredAt = _enteredAt;
    if (name == null || enteredAt == null) return;
    final seconds = DateTime.now().difference(enteredAt).inSeconds;
    UsageStatsService.instance.logScreenTime(name, seconds);
    _enteredAt = null; // stop accruing while backgrounded
  }

  /// Called when the app returns to foreground: restart the clock for the
  /// screen that's still on top (we kept its name; just reset the start time).
  void onAppResumed() {
    if (_currentName != null) {
      _enteredAt = DateTime.now();
    }
  }
}
