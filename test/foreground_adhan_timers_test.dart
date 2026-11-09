import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/foreground_adhan_timers.dart';
import 'package:qurani/services/adhan_schedule_logic.dart';

void main() {
  testWidgets('scheduling future days preserves today timer', (tester) async {
    var now = DateTime(2026, 11, 4, 6);
    final fired = <int>[];
    final timers = ForegroundAdhanTimers(clock: () => now, fire: fired.add);
    final prayer = now.add(const Duration(seconds: 10));
    timers.schedule({'fajr': prayer}, {'fajr': true});
    for (var day = 1; day <= 7; day++) {
      timers.schedule(
          {'fajr': DateTime(2026, 11, 4 + day, 6, 1)}, {'fajr': true});
    }
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(fired, [AdhanScheduleLogic.dailyId(prayerId: 'fajr', date: prayer)]);
    timers.dispose();
  });

  testWidgets('replacement is unique and disabled slot is cancelled',
      (tester) async {
    var now = DateTime(2026, 11, 4, 6);
    final fired = <int>[];
    final timers = ForegroundAdhanTimers(clock: () => now, fire: fired.add);
    timers.schedule({
      'fajr': now.add(const Duration(seconds: 5)),
      'dhuhr': now.add(const Duration(seconds: 6))
    }, {
      'fajr': true,
      'dhuhr': true
    });
    timers.schedule({
      'fajr': now.add(const Duration(seconds: 10)),
      'dhuhr': now.add(const Duration(seconds: 6))
    }, {
      'fajr': true,
      'dhuhr': false
    });
    now = now.add(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 7));
    expect(fired, isEmpty);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(fired.length, 1);
    timers.dispose();
  });
  testWidgets('a timer delayed by app suspension does not play an old prayer', (tester) async {
    var now = DateTime(2026, 11, 4, 6);
    final fired = <int>[];
    final timers = ForegroundAdhanTimers(clock: () => now, fire: fired.add);
    timers.schedule({'fajr': now.add(const Duration(seconds: 10))}, {'fajr': true});
    now = now.add(const Duration(hours: 3));
    await tester.pump(const Duration(hours: 3));
    expect(fired, isEmpty);
    timers.dispose();
  });
}
