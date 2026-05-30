import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/adhan_schedule_logic.dart';

void main() {
  group('codeForPrayer / dailyId', () {
    test('maps the five prayers to stable codes', () {
      expect(AdhanScheduleLogic.codeForPrayer('fajr'), 1);
      expect(AdhanScheduleLogic.codeForPrayer('dhuhr'), 3);
      expect(AdhanScheduleLogic.codeForPrayer('asr'), 4);
      expect(AdhanScheduleLogic.codeForPrayer('maghrib'), 5);
      expect(AdhanScheduleLogic.codeForPrayer('isha'), 6);
      expect(AdhanScheduleLogic.codeForPrayer('sunrise'), 2);
      expect(AdhanScheduleLogic.codeForPrayer('unknown'), 0);
    });

    test('dailyId embeds the date and prayer code', () {
      final id = AdhanScheduleLogic.dailyId(
        prayerId: 'fajr',
        date: DateTime(2025, 11, 25, 5, 30),
      );
      expect(id, 20251125 * 10 + 1);
    });

    test('dailyId differs per day and per prayer, same day same prayer stable', () {
      final a = AdhanScheduleLogic.dailyId(
          prayerId: 'isha', date: DateTime(2025, 11, 25, 19));
      final b = AdhanScheduleLogic.dailyId(
          prayerId: 'isha', date: DateTime(2025, 11, 25, 20));
      final c = AdhanScheduleLogic.dailyId(
          prayerId: 'isha', date: DateTime(2025, 11, 26, 19));
      final d = AdhanScheduleLogic.dailyId(
          prayerId: 'fajr', date: DateTime(2025, 11, 25, 5));
      expect(a, b); // time-of-day doesn't change the id
      expect(a, isNot(c)); // different day
      expect(a, isNot(d)); // different prayer
    });
  });

  group('dayKey', () {
    test('is a compact yyyymmdd integer ignoring time', () {
      expect(AdhanScheduleLogic.dayKey(DateTime(2025, 3, 9, 23, 59)), 20250309);
      expect(AdhanScheduleLogic.dayKey(DateTime(2025, 12, 31)), 20251231);
    });
  });

  group('togglesFingerprint', () {
    test('is order-independent', () {
      final a = AdhanScheduleLogic.togglesFingerprint(
          {'fajr': true, 'isha': false});
      final b = AdhanScheduleLogic.togglesFingerprint(
          {'isha': false, 'fajr': true});
      expect(a, b);
    });

    test('changes when a toggle flips', () {
      final a = AdhanScheduleLogic.togglesFingerprint({'fajr': true});
      final b = AdhanScheduleLogic.togglesFingerprint({'fajr': false});
      expect(a, isNot(b));
    });
  });

  group('shouldSchedule', () {
    final now = DateTime(2025, 11, 25, 8);
    final toggles = {'fajr': true, 'dhuhr': true};
    String fp() => AdhanScheduleLogic.togglesFingerprint(toggles);

    test('reschedules when sound changed', () {
      expect(
        AdhanScheduleLogic.shouldSchedule(
          now: now,
          soundKey: 'afs',
          toggles: toggles,
          lastScheduledThrough: AdhanScheduleLogic.dayKey(
              DateTime(2025, 12, 5)),
          lastSoundHash: 'basit', // different sound
          lastTogglesHash: fp(),
        ),
        isTrue,
      );
    });

    test('reschedules when toggles changed', () {
      expect(
        AdhanScheduleLogic.shouldSchedule(
          now: now,
          soundKey: 'afs',
          toggles: toggles,
          lastScheduledThrough:
              AdhanScheduleLogic.dayKey(DateTime(2025, 12, 5)),
          lastSoundHash: 'afs',
          lastTogglesHash: 'fajr=1', // stale fingerprint
        ),
        isTrue,
      );
    });

    test('skips when sound+toggles match and horizon already covered', () {
      // Covered through 2025-12-05, target is now+7 = 2025-12-02 <= covered.
      expect(
        AdhanScheduleLogic.shouldSchedule(
          now: now,
          soundKey: 'afs',
          toggles: toggles,
          lastScheduledThrough:
              AdhanScheduleLogic.dayKey(DateTime(2025, 12, 5)),
          lastSoundHash: 'afs',
          lastTogglesHash: fp(),
        ),
        isFalse,
      );
    });

    test('reschedules when the persisted horizon is in the past', () {
      expect(
        AdhanScheduleLogic.shouldSchedule(
          now: now,
          soundKey: 'afs',
          toggles: toggles,
          lastScheduledThrough:
              AdhanScheduleLogic.dayKey(DateTime(2025, 11, 20)),
          lastSoundHash: 'afs',
          lastTogglesHash: fp(),
        ),
        isTrue,
      );
    });
  });

  group('scheduleDayCursors (DST-safe)', () {
    test('returns daysAhead consecutive calendar dates from today', () {
      final cursors =
          AdhanScheduleLogic.scheduleDayCursors(DateTime(2025, 1, 30), daysAhead: 3);
      expect(cursors, [
        DateTime(2025, 1, 30),
        DateTime(2025, 1, 31),
        DateTime(2025, 2, 1), // rolls into February correctly
      ]);
    });

    test('advances across a spring-forward DST boundary without drift', () {
      // US DST 2025 begins Sun Mar 9. add(Duration(days:1)) would drift by an
      // hour; the calendar constructor keeps wall-clock midnight each day.
      final cursors =
          AdhanScheduleLogic.scheduleDayCursors(DateTime(2025, 3, 8), daysAhead: 3);
      expect(cursors, [
        DateTime(2025, 3, 8),
        DateTime(2025, 3, 9),
        DateTime(2025, 3, 10),
      ]);
      for (final c in cursors) {
        expect(c.hour, 0);
      }
    });
  });

  group('isPlayingFlagStale', () {
    test('zero start time is always stale', () {
      expect(
        AdhanScheduleLogic.isPlayingFlagStale(startMs: 0, nowMs: 1000),
        isTrue,
      );
    });

    test('within max duration is fresh', () {
      final now = DateTime(2025, 1, 1, 12).millisecondsSinceEpoch;
      final start = DateTime(2025, 1, 1, 11, 58).millisecondsSinceEpoch; // 2m
      expect(
        AdhanScheduleLogic.isPlayingFlagStale(startMs: start, nowMs: now),
        isFalse,
      );
    });

    test('older than max duration is stale', () {
      final now = DateTime(2025, 1, 1, 12).millisecondsSinceEpoch;
      final start = DateTime(2025, 1, 1, 11, 50).millisecondsSinceEpoch; // 10m
      expect(
        AdhanScheduleLogic.isPlayingFlagStale(startMs: start, nowMs: now),
        isTrue,
      );
    });
  });
}
