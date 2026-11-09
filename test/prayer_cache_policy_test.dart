import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/services/prayer_cache_policy.dart';
import 'package:qurani/services/prayer_times_service_web.dart' as web;
import 'package:qurani/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final downloaded = DateTime(2026, 11, 1);
  final paris = PrayerCacheMetadata(48.8566, 2.3522, 12, downloaded);
  final lyon = PrayerCacheMetadata(45.764, 4.8357, 12, downloaded);
  Map<String, PrayerCacheMetadata> months() => {
        '2026-10': paris,
        '2026-11': paris,
        '2026-12': paris,
      };
  Future<List<String>> refresh(Map<String, PrayerCacheMetadata> cache,
      {Position? position,
      int method = 12,
      DateTime? now,
      DateTime? date}) async {
    final calls = <String>[];
    await PrayerCachePolicy.refresh(
        date: date ?? DateTime(2026, 11, 4),
        now: now ?? DateTime(2026, 11, 4),
        position: position ?? paris.position,
        method: method,
        read: (y, m) async => cache['$y-$m'],
        fetch: (y, m) async {
          calls.add('$y-$m');
        });
    return calls;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('real launch check at unchanged position leaves success date untouched',
      () async {
    final platform = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FixedPosition(paris.position);
    addTearDown(() {
      GeolocatorPlatform.instance = platform;
    });
    await PreferencesService.init();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final fetched = now.subtract(const Duration(days: 2));
    final metadata =
        PrayerCacheMetadata(paris.latitude, paris.longitude, 12, fetched);
    await PrayerCachePolicy.observe(metadata.position, 12);
    await prefs.setInt('prayer_last_success', fetched.millisecondsSinceEpoch);
    for (final offset in [-1, 0, 1]) {
      final month = DateTime(now.year, now.month + offset);
      await prefs.setString(
          'prayer_month_${month.year}_${month.month}',
          jsonEncode({
            'metadata': metadata.toJson(),
            'calendar': {'data': []},
          }));
    }
    await web.PrayerTimesService.maybeRefreshCacheOnLaunch();
    await web.PrayerTimesService.maybeRefreshCacheOnLaunch();
    expect(prefs.getInt('prayer_last_success'), fetched.millisecondsSinceEpoch);
    expect(
        (await web.PrayerTimesService.getCacheMetadata(now.year, now.month))!
            .fetchedAt
            .millisecondsSinceEpoch,
        fetched.millisecondsSinceEpoch);
  });

  test('stationary checks preserve actual download timestamps', () async {
    final cache = months();
    expect(await refresh(cache), isEmpty);
    expect(await refresh(cache, now: DateTime(2026, 11, 10)), isEmpty);
    expect(cache.values.every((m) => m.fetchedAt == downloaded), isTrue);
    expect(await refresh(cache, now: DateTime(2026, 11, 11)), hasLength(3));
  });
  test('travel invalidates even a recent calendar on the same day', () async {
    expect(await refresh(months(), position: lyon.position), hasLength(3));
  });
  test('small GPS variation retains matching calendar', () async {
    final nearby = PrayerCacheMetadata(48.857, 2.352, 12, downloaded);
    expect(await refresh(months(), position: nearby.position), isEmpty);
  });
  test('method change invalidates cached months', () async {
    expect(await refresh(months(), method: 3), hasLength(3));
  });
  test('missing next month is fetched despite recent cache', () async {
    expect(await refresh(months()..remove('2026-12')), ['2026-12']);
  });
  test('year rollover checks the new month coverage', () async {
    final now = DateTime(2026, 12, 31);
    final metadata = PrayerCacheMetadata(48.8566, 2.3522, 12, now);
    expect(
        await refresh({'2026-12': metadata, '2027-1': metadata},
            date: DateTime(2027, 1, 1), now: DateTime(2027, 1, 1)),
        ['2027-2']);
  });
  test('observing a location never marks a download successful', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'prayer_last_success', downloaded.millisecondsSinceEpoch);
    expect(await PrayerCachePolicy.observe(paris.position, 12), isTrue);
    expect(await PrayerCachePolicy.observe(paris.position, 12), isFalse);
    expect(
        prefs.getInt('prayer_last_success'), downloaded.millisecondsSinceEpoch);
    expect(await PrayerCachePolicy.usable(paris), isTrue);
    await PrayerCachePolicy.observe(lyon.position, 12);
    expect(await PrayerCachePolicy.usable(paris), isFalse);
  });
  test('failed download does not change successful-download timestamp',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'prayer_last_success', downloaded.millisecondsSinceEpoch);
    await expectLater(
        PrayerCachePolicy.refresh(
            date: downloaded,
            position: paris.position,
            method: 12,
            read: (_, __) async => null,
            fetch: (_, __) async {
              throw StateError('offline');
            }),
        throwsStateError);
    expect(
        prefs.getInt('prayer_last_success'), downloaded.millisecondsSinceEpoch);
  });
  test('Web calendar cannot be read as prayer times for another city',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final calendar = {
      'data': [
        {
          'timings': {
            'Fajr': '05:00',
            'Sunrise': '06:30',
            'Dhuhr': '12:00',
            'Asr': '15:00',
            'Maghrib': '18:00',
            'Isha': '19:30',
          }
        }
      ]
    };
    await prefs.setString(
        'prayer_month_2026_11',
        jsonEncode({
          'calendar': calendar,
          'metadata': paris.toJson(),
        }));
    await PrayerCachePolicy.observe(paris.position, 12);
    expect(
        await web.PrayerTimesService.getTimesForDate(
            year: 2026, month: 11, day: 1),
        isNotNull);
    await PrayerCachePolicy.observe(lyon.position, 12);
    expect(
        await web.PrayerTimesService.getTimesForDate(
            year: 2026, month: 11, day: 1),
        isNull);
    // Hijri/legacy data remains readable, but unverified provenance is not an alarm source.
    await prefs.setString('prayer_month_2026_11', jsonEncode(calendar));
    expect(await web.PrayerTimesService.getMonthData(2026, 11), calendar);
    expect(
        await web.PrayerTimesService.getTimesForDate(
            year: 2026, month: 11, day: 1),
        isNull);
  });
}

class _FixedPosition extends GeolocatorPlatform {
  _FixedPosition(this.position);
  final Position position;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      position;
}
