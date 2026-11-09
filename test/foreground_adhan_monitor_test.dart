import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/foreground_adhan_monitor.dart';

void main() {
  test('location revision during loading discards the old calendar', () async {
    final now = DateTime(2026, 11, 4, 6);
    var revision = 0;
    final gate = Completer<Map<String, DateTime>?>();
    final monitor = ForegroundAdhanMonitor(
        clock: () => now,
        cacheRevision: () => revision,
        loadTimes: (_) => gate.future,
        play: (_) async {
          fail('old location played');
        },
        isPlaying: () => false,
        isEnabled: (_) => true);
    final check = monitor.check();
    revision++;
    gate.complete({'fajr': now});
    await check;
  });
  test('reloads after midnight and resets played prayers across year boundary',
      () async {
    var now = DateTime(2026, 12, 31, 6);
    final loaded = <DateTime>[];
    final played = <String>[];
    var renewals = 0;
    final monitor = ForegroundAdhanMonitor(
      clock: () => now,
      loadTimes: (day) async {
        loaded.add(day);
        return {'fajr': DateTime(day.year, day.month, day.day, 6)};
      },
      play: (id) async {
        played.add(id);
      },
      isPlaying: () => false,
      isEnabled: (_) => true,
      onDayChanged: () {
        renewals++;
      },
    );
    await monitor.check();
    await monitor.check();
    now = DateTime(2027, 1, 1, 6);
    await monitor.check();
    expect(loaded, [DateTime(2026, 12, 31), DateTime(2027, 1, 1)]);
    expect(played, ['fajr', 'fajr']);
    expect(renewals, 1);
  });

  test('failed new-day load is retried without yesterday data', () async {
    var now = DateTime(2026, 11, 4, 23);
    var fail = false;
    var loads = 0;
    final played = <String>[];
    final monitor = ForegroundAdhanMonitor(
        clock: () => now,
        loadTimes: (day) async {
          loads++;
          if (fail) throw StateError('offline');
          return {'fajr': DateTime(day.year, day.month, day.day, 6)};
        },
        play: (id) async {
          played.add(id);
        },
        isPlaying: () => false,
        isEnabled: (_) => true);
    await monitor.check();
    now = DateTime(2026, 11, 5, 6);
    fail = true;
    await expectLater(monitor.check(), throwsStateError);
    fail = false;
    await monitor.check();
    expect(loads, 3);
    expect(played, ['fajr']);
  });

  test('crossing midnight during a load discards that result', () async {
    var now = DateTime(2026, 11, 4, 23, 59, 59);
    final gate = Completer<Map<String, DateTime>?>();
    final monitor = ForegroundAdhanMonitor(
        clock: () => now,
        loadTimes: (_) => gate.future,
        play: (_) async {
          fail('stale prayer');
        },
        isPlaying: () => false,
        isEnabled: (_) => true);
    final check = monitor.check();
    now = DateTime(2026, 11, 5);
    gate.complete({'isha': now});
    await check;
  });

  test('pause invalidates an in-flight load and concurrent checks coalesce',
      () async {
    final gate = Completer<Map<String, DateTime>?>();
    final now = DateTime(2026, 11, 4, 6);
    var loads = 0;
    final monitor = ForegroundAdhanMonitor(
        clock: () => now,
        loadTimes: (_) {
          loads++;
          return gate.future;
        },
        play: (_) async {
          fail('paused prayer');
        },
        isPlaying: () => false,
        isEnabled: (_) => true);
    final pending = monitor.check();
    await monitor.check();
    monitor.invalidate();
    gate.complete({'fajr': now});
    await pending;
    expect(loads, 1);
  });

  test('does not play before prayer time or repeat within the window',
      () async {
    final time = DateTime(2026, 11, 4, 6);
    var now = time.subtract(const Duration(seconds: 20));
    var plays = 0;
    final monitor = ForegroundAdhanMonitor(
        clock: () => now,
        loadTimes: (_) async => {'fajr': time},
        play: (_) async {
          plays++;
        },
        isPlaying: () => false,
        isEnabled: (_) => true);
    await monitor.check();
    expect(plays, 0);
    now = time;
    await monitor.check();
    await monitor.check();
    expect(plays, 1);
  });
}
