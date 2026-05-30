import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/wird_schedule_logic.dart';

void main() {
  group('notificationId', () {
    test('is deterministic for the same wird+weekday', () {
      final a = WirdScheduleLogic.notificationId(wirdId: 'abc', weekday: 3);
      final b = WirdScheduleLogic.notificationId(wirdId: 'abc', weekday: 3);
      expect(a, b);
    });

    test('lives in the 0x60000000 wird namespace and is positive', () {
      final id = WirdScheduleLogic.notificationId(wirdId: 'abc', weekday: 5);
      expect(id & 0x70000000, 0x60000000);
      expect(id, greaterThan(0));
    });

    test('encodes the weekday in the low 3 bits', () {
      for (int wd = 1; wd <= 7; wd++) {
        final id = WirdScheduleLogic.notificationId(wirdId: 'abc', weekday: wd);
        expect(id & 0x07, wd);
      }
    });

    test('different wirds on the same weekday rarely collide', () {
      final a = WirdScheduleLogic.notificationId(wirdId: 'wird-one', weekday: 2);
      final b = WirdScheduleLogic.notificationId(wirdId: 'wird-two', weekday: 2);
      expect(a, isNot(b));
    });

    test('same wird, different weekdays produce distinct ids', () {
      final mon = WirdScheduleLogic.notificationId(wirdId: 'x', weekday: 1);
      final tue = WirdScheduleLogic.notificationId(wirdId: 'x', weekday: 2);
      expect(mon, isNot(tue));
    });

    test('test id has weekday 0 so it never collides with real reminders', () {
      expect(WirdScheduleLogic.testNotificationId & 0x07, 0);
      for (int wd = 1; wd <= 7; wd++) {
        expect(
          WirdScheduleLogic.notificationId(wirdId: 'x', weekday: wd),
          isNot(WirdScheduleLogic.testNotificationId),
        );
      }
    });
  });

  group('windowTriggers', () {
    test('schedules one trigger per active weekday within the horizon', () {
      // Wed 2025-11-26 09:00; wird active Mon/Wed/Fri at 14:00.
      final now = DateTime(2025, 11, 26, 9);
      final triggers = WirdScheduleLogic.windowTriggers(
        now: now,
        daysOfWeek: const [1, 3, 5], // Mon, Wed, Fri
        hour: 14,
        minute: 0,
        alreadyDoneToday: false,
        horizon: 7,
      );
      // Next 7 days from Wed: Wed(26), Fri(28), Mon(Dec1) — 3 occurrences.
      expect(triggers.length, 3);
      expect(triggers[0], DateTime(2025, 11, 26, 14));
      expect(triggers[1], DateTime(2025, 11, 28, 14));
      expect(triggers[2], DateTime(2025, 12, 1, 14));
    });

    test('skips today when the time has already passed', () {
      final now = DateTime(2025, 11, 26, 15); // already past 14:00
      final triggers = WirdScheduleLogic.windowTriggers(
        now: now,
        daysOfWeek: const [3], // Wed only
        hour: 14,
        minute: 0,
        alreadyDoneToday: false,
        horizon: 7,
      );
      // Today's 14:00 passed; next Wed is outside a 7-day horizon from Wed
      // (offsets 0..6 reach Tue Dec 2), so nothing is queued.
      expect(triggers, isEmpty);
    });

    test('skips today when already done, keeps future days', () {
      final now = DateTime(2025, 11, 26, 9);
      final triggers = WirdScheduleLogic.windowTriggers(
        now: now,
        daysOfWeek: const [3, 5], // Wed, Fri
        hour: 14,
        minute: 0,
        alreadyDoneToday: true,
        horizon: 7,
      );
      // Wed (today) skipped; Fri kept.
      expect(triggers.length, 1);
      expect(triggers.single, DateTime(2025, 11, 28, 14));
    });

    test('keeps only the nearest occurrence of each weekday', () {
      final now = DateTime(2025, 11, 24, 7); // Monday 07:00, before 08:00
      final triggers = WirdScheduleLogic.windowTriggers(
        now: now,
        daysOfWeek: const [1], // Monday only
        hour: 8,
        minute: 0,
        alreadyDoneToday: false,
        horizon: 14, // would include next Monday too, but it's deduped
      );
      expect(triggers.length, 1);
      expect(triggers.single, DateTime(2025, 11, 24, 8));
    });

    test('a shrunk horizon limits how far ahead we schedule', () {
      final now = DateTime(2025, 11, 26, 9); // Wed
      final triggers = WirdScheduleLogic.windowTriggers(
        now: now,
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7], // every day
        hour: 14,
        minute: 0,
        alreadyDoneToday: false,
        horizon: 3, // only today + 2
      );
      expect(triggers.length, 3);
      expect(triggers.first, DateTime(2025, 11, 26, 14));
      expect(triggers.last, DateTime(2025, 11, 28, 14));
    });
  });

  group('isDueForDailyReset', () {
    final today = DateTime(2025, 11, 26); // Wednesday (weekday 3)

    test('due when last update predates today and today is scheduled', () {
      expect(
        WirdScheduleLogic.isDueForDailyReset(
          today: today,
          lastUpdatedDate: DateTime(2025, 11, 25),
          daysOfWeek: const [3],
        ),
        isTrue,
      );
    });

    test('due when never updated and today is scheduled', () {
      expect(
        WirdScheduleLogic.isDueForDailyReset(
          today: today,
          lastUpdatedDate: null,
          daysOfWeek: const [3],
        ),
        isTrue,
      );
    });

    test('not due when today is not in the schedule', () {
      expect(
        WirdScheduleLogic.isDueForDailyReset(
          today: today,
          lastUpdatedDate: DateTime(2025, 11, 25),
          daysOfWeek: const [1, 5], // Mon, Fri — not Wed
        ),
        isFalse,
      );
    });

    test('not due when already updated today', () {
      expect(
        WirdScheduleLogic.isDueForDailyReset(
          today: today,
          lastUpdatedDate: DateTime(2025, 11, 26),
          daysOfWeek: const [3],
        ),
        isFalse,
      );
    });

    test('ignores time-of-day on lastUpdatedDate', () {
      expect(
        WirdScheduleLogic.isDueForDailyReset(
          today: DateTime(2025, 11, 26, 8),
          lastUpdatedDate: DateTime(2025, 11, 25, 23, 59),
          daysOfWeek: const [3],
        ),
        isTrue,
      );
    });
  });
}
