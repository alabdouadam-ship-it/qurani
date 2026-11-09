import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/services/adhan_schedule_logic.dart';
import 'package:qurani/services/adhan_scheduler_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reboot never plays tomorrow or a long-overdue prayer', () {
    final now = DateTime(2026, 11, 4, 6);
    bool due(Duration offset) => AdhanScheduleLogic.isAlarmDue(
        now: now, scheduledAt: now.add(offset).millisecondsSinceEpoch);
    expect(due(Duration.zero), isTrue);
    expect(due(const Duration(seconds: -30)), isTrue);
    expect(due(const Duration(minutes: -2)), isTrue);
    expect(due(const Duration(minutes: -3)), isFalse);
    expect(due(const Duration(days: -1)), isFalse);
    expect(due(const Duration(seconds: 1)), isFalse);
  });
  test('old nonpersistent schedule marker forces migration on next launch',
      () async {
    SharedPreferences.setMockInitialValues({
      'adhan_last_scheduled_through_day': 20990101,
      'adhan_last_scheduled_sound_hash': 'afs',
      'adhan_last_scheduled_toggles_hash': 'fajr=1',
    });
    expect(
        await AdhanScheduler.shouldScheduleThroughDay(
            soundKey: 'afs', toggles: {'fajr': true}),
        isTrue);
  });
}
