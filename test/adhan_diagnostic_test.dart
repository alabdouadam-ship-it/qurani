import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/adhan_diagnostic_service.dart';

void main() {
  test('next expected adhan ignores disabled, elapsed and non-prayer times',
      () {
    final now = DateTime(2026, 11, 4, 12);
    final next = nextEnabledAdhan([
      {
        'fajr': DateTime(2026, 11, 4, 6),
        'sunrise': DateTime(2026, 11, 4, 13),
        'asr': DateTime(2026, 11, 4, 15),
        'maghrib': DateTime(2026, 11, 4, 18)
      },
      {'fajr': DateTime(2026, 11, 5, 6)}
    ], {
      'fajr': true,
      'sunrise': true,
      'asr': false,
      'maghrib': true
    }, now);
    expect(next!.key, 'maghrib');
    expect(next.value, DateTime(2026, 11, 4, 18));
  });
  test('missing cache or all disabled produces no proposed trigger', () {
    expect(nextEnabledAdhan([], {}, DateTime.now()), isNull);
    expect(
        nextEnabledAdhan([
          {'fajr': DateTime(2027)}
        ], {
          'fajr': false
        }, DateTime(2026)),
        isNull);
  });
  test('next day remains available after last prayer', () {
    expect(
        nextEnabledAdhan([
          {'isha': DateTime(2026, 11, 4, 20)},
          {'fajr': DateTime(2026, 11, 5, 6)}
        ], {
          'isha': true,
          'fajr': true
        }, DateTime(2026, 11, 4, 22))!
            .key,
        'fajr');
  });
}
