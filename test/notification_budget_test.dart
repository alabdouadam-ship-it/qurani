import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/notification_budget.dart';

void main() {
  group('NotificationBudget.adhanPendingFor', () {
    test('is (today + 7 days) x prayers = 8 x n', () {
      expect(NotificationBudget.adhanPendingFor(0), 0);
      expect(NotificationBudget.adhanPendingFor(5), 40);
      expect(NotificationBudget.adhanPendingFor(3), 24);
    });

    test('clamps negative prayer counts to zero', () {
      expect(NotificationBudget.adhanPendingFor(-1), 0);
    });
  });

  group('NotificationBudget.wirdDayHorizon', () {
    test('no reminder wirds -> full 7-day window', () {
      expect(
        NotificationBudget.wirdDayHorizon(
          enabledPrayerCount: 5,
          reminderWirdCount: 0,
          usable: NotificationBudget.iosUsable,
        ),
        7,
      );
    });

    test('unlimited budget (Android/web) -> always 7', () {
      expect(
        NotificationBudget.wirdDayHorizon(
          enabledPrayerCount: 5,
          reminderWirdCount: 10,
          usable: NotificationBudget.unlimited,
        ),
        7,
      );
    });

    test('light load stays at full 7 days on iOS', () {
      // 5 prayers (40) + 1 wird * 7 = 47 <= 60. No shrink.
      expect(
        NotificationBudget.wirdDayHorizon(
          enabledPrayerCount: 5,
          reminderWirdCount: 1,
          usable: NotificationBudget.iosUsable,
        ),
        7,
      );
    });

    test('heavy load shrinks the per-wird horizon to fit iOS budget', () {
      // 5 prayers (40) + 5 wirds. Remaining = 60 - 40 = 20; 20 ~/ 5 = 4.
      final horizon = NotificationBudget.wirdDayHorizon(
        enabledPrayerCount: 5,
        reminderWirdCount: 5,
        usable: NotificationBudget.iosUsable,
      );
      expect(horizon, 4);
      // Verify the resulting total stays under the hard cap.
      final total = NotificationBudget.adhanPendingFor(5) + 5 * horizon;
      expect(total, lessThanOrEqualTo(NotificationBudget.iosPendingCap));
    });

    test('never drops below 1 even when Adhan saturates the budget', () {
      // Contrived: a huge prayer count would exhaust the budget; each wird
      // must still keep its nearest occurrence.
      expect(
        NotificationBudget.wirdDayHorizon(
          enabledPrayerCount: 100,
          reminderWirdCount: 5,
          usable: NotificationBudget.iosUsable,
        ),
        1,
      );
    });

    test('result is capped at 7 even with tiny load', () {
      expect(
        NotificationBudget.wirdDayHorizon(
          enabledPrayerCount: 0,
          reminderWirdCount: 1,
          usable: NotificationBudget.iosUsable,
        ),
        7,
      );
    });

    test('realistic engaged user stays under the cap after shrink', () {
      // 5 prayers + 4 all-day wirds would be 40 + 28 = 68 > 64 at full window.
      final horizon = NotificationBudget.wirdDayHorizon(
        enabledPrayerCount: 5,
        reminderWirdCount: 4,
        usable: NotificationBudget.iosUsable,
      );
      // Remaining 20 ~/ 4 = 5.
      expect(horizon, 5);
      final total = NotificationBudget.adhanPendingFor(5) + 4 * horizon;
      expect(total, lessThanOrEqualTo(NotificationBudget.iosPendingCap));
    });
  });
}
