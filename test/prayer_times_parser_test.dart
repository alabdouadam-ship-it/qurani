import 'package:qurani/services/prayer_cache_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/prayer_times_parser.dart';
import 'package:qurani/services/prayer_times_service_web.dart' as web;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, Object?> timings() => {
        'Fajr': '05:12 (CET)',
        'Sunrise': '06:30',
        'Dhuhr': '12:00',
        'Asr': '15:00',
        'Maghrib': '18:00',
        'Isha': '19:30',
      };
  Map<String, DateTime>? parse(Map<String, Object?> times) => parsePrayerTimes({
        'data': [
          {'timings': times}
        ]
      }, year: 2026, month: 11, day: 1);

  test('accepts API timezone suffix and optional Imsak', () {
    final result = parse(timings());
    expect(result!['fajr'], DateTime(2026, 11, 1, 5, 12));
    expect(result.containsKey('imsak'), isFalse);
    expect(parse(timings()..['Imsak'] = '04:50')!['imsak'],
        DateTime(2026, 11, 1, 4, 50));
  });
  for (final bad in <Object?>[
    null,
    '',
    'xx:yy',
    '24:00',
    '12:60',
    '-1:30',
    512,
    '5',
    '05:12 garbage'
  ]) {
    test('rejects invalid mandatory time $bad', () {
      expect(() => parse(timings()..['Fajr'] = bad), throwsFormatException);
    });
  }
  test('rejects malformed and incomplete structures', () {
    for (final data in [
      null,
      {},
      {'data': 'bad'},
      {
        'data': [null]
      },
      {
        'data': [
          {'timings': {}}
        ]
      }
    ]) {
      expect(() => parsePrayerTimes(data, year: 2026, month: 11, day: 1),
          throwsFormatException);
    }
  });
  test('real midnight remains valid; missing day is unavailable', () {
    expect(
        parse(timings()..['Fajr'] = '00:00')!['fajr'], DateTime(2026, 11, 1));
    expect(
        parsePrayerTimes({'data': []}, year: 2026, month: 11, day: 1), isNull);
  });
  test('rejects invalid network calendar before caching any day', () {
    expect(() => validatePrayerCalendar({'data': []}, year: 2026, month: 11),
        throwsFormatException);
    expect(
        () => validatePrayerCalendar({
              'data': [
                {'timings': timings()},
                {'timings': timings()..remove('Isha')},
              ]
            }, year: 2026, month: 11),
        throwsFormatException);
  });
  test('cached Web service uses strict shared parsing', () async {
    final metadata =
        PrayerCacheMetadata(48.8566, 2.3522, 12, DateTime(2026, 11, 1));
    SharedPreferences.setMockInitialValues({
      'prayer_month_2026_11': jsonEncode({
        'metadata': metadata.toJson(),
        'calendar': {
          'data': [
            {'timings': timings()..['Fajr'] = 'xx:yy'}
          ]
        },
      }),
    });
    await PrayerCachePolicy.observe(metadata.position, metadata.method);
    await expectLater(
        web.PrayerTimesService.getTimesForDate(year: 2026, month: 11, day: 1),
        throwsFormatException);
  });
}
