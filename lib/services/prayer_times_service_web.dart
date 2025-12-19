import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/services/preferences_service.dart';

class PrayerTimesService {
  static final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)));

  static String _monthKey(int year, int month) => 'prayer_month_${year}_$month';

  static Future<void> _saveMonth({
    required int year,
    required int month,
    required int method,
    required double lat,
    required double lng,
    required String jsonString,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_monthKey(year, month), jsonString);
    await prefs.setString('prayer_last_latlng', '$lat,$lng');
    await prefs.setInt('prayer_last_success', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> getMonthData(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_monthKey(year, month));
    if (jsonStr == null || jsonStr.isEmpty) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  static Future<void> cleanupKeepPrevCurrentNext(DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    final prev = DateTime(today.year, today.month - 1, 1);
    final curr = DateTime(today.year, today.month, 1);
    final next = DateTime(today.year, today.month + 1, 1);
    final keep = <String>{
      _monthKey(prev.year, prev.month),
      _monthKey(curr.year, curr.month),
      _monthKey(next.year, next.month),
    };
    final allKeys = prefs.getKeys().where((k) => k.startsWith('prayer_month_')).toList();
    for (final k in allKeys) {
      if (!keep.contains(k)) {
        await prefs.remove(k);
      }
    }
  }

  static Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location disabled');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }
    // Try using LocationSettings if available, fallback to desiredAccuracy for older geolocator versions
    try {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (_) {
      // Fallback for older geolocator versions
      // ignore: deprecated_member_use
      return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
    }
  }

  static Future<void> fetchAndCacheMonth({
    required int year,
    required int month,
    required double latitude,
    required double longitude,
    required int method,
  }) async {
    final url = 'https://api.aladhan.com/v1/calendar/$year/$month';
    final resp = await _dio.get(url, queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      'method': method,
    });
    if (resp.statusCode == 200 && resp.data != null) {
      final jsonString = json.encode(resp.data);
      await _saveMonth(
        year: year,
        month: month,
        method: method,
        lat: latitude,
        lng: longitude,
        jsonString: jsonString,
      );
    } else {
      throw Exception('Failed to fetch month $year-$month');
    }
  }

  static Future<Map<String, DateTime>?> getTimesForDate({
    required int year,
    required int month,
    required int day,
  }) async {
    final data = await getMonthData(year, month);
    if (data == null) return null;
    final list = data['data'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    if (day < 1 || day > list.length) return null;
    final timings = (list[day - 1]['timings'] as Map).cast<String, dynamic>();
    DateTime? parse(String key) {
      final raw = timings[key] as String?;
      if (raw == null) return null;
      final hhmm = raw.split(' ').first;
      final parts = hhmm.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return DateTime(year, month, day, h, m);
    }
    final result = <String, DateTime>{
      'fajr': parse('Fajr')!,
      'sunrise': parse('Sunrise')!,
      'dhuhr': parse('Dhuhr')!,
      'asr': parse('Asr')!,
      'maghrib': parse('Maghrib')!,
      'isha': parse('Isha')!,
    };
    final imsak = parse('Imsak');
    if (imsak != null) {
      result['imsak'] = imsak;
    }
    
    // Apply debug mode adjustments if any
    final adjustments = PreferencesService.getAllPrayerTimeAdjustments();
    for (final entry in adjustments.entries) {
      final prayerId = entry.key;
      final offsetMinutes = entry.value;
      if (result.containsKey(prayerId) && offsetMinutes != 0) {
        result[prayerId] = result[prayerId]!.add(Duration(minutes: offsetMinutes));
      }
    }
    
    return result;
  }

  static Future<Map<String, String>?> getHijriForDate({
    required int year,
    required int month,
    required int day,
  }) async {
    final data = await getMonthData(year, month);
    if (data == null) return null;
    final list = data['data'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    if (day < 1 || day > list.length) return null;
    final hijri = ((list[day - 1]['date'] as Map)['hijri'] as Map).cast<String, dynamic>();
    final monthMap = (hijri['month'] as Map).cast<String, dynamic>();
    final monthAr = (monthMap['ar'] as String?) ?? '';
    final monthEn = (monthMap['en'] as String?) ?? '';
    return {
      'day': hijri['day'] as String? ?? '',
      'monthAr': monthAr,
      'monthEn': monthEn,
      'year': hijri['year'] as String? ?? '',
    };
  }

  static Future<bool> hasMonth(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_monthKey(year, month));
  }

  static Future<String?> getCountryFromCoordinates(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        return placemarks.first.country;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> getCityFromCoordinates(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      return (p.locality?.isNotEmpty == true)
          ? p.locality
          : (p.subAdministrativeArea?.isNotEmpty == true)
              ? p.subAdministrativeArea
              : (p.administrativeArea?.isNotEmpty == true)
                  ? p.administrativeArea
                  : p.country;
    } catch (_) {
      return null;
    }
  }

  static const Map<String, int> _prayerMethodByCountryName = {
    'saudi arabia': 4,
    'france': 12,
    'germany': 12,
    'belgium': 12,
    'netherlands': 12,
    'luxembourg': 12,
    'switzerland': 12,
    'spain': 12,
    'italy': 12,
    'portugal': 22,
    'united kingdom': 12,
    'ireland': 12,
    'austria': 12,
    'denmark': 12,
    'sweden': 12,
    'norway': 12,
    'finland': 12,
    'iceland': 12,
    'monaco': 12,
    'liechtenstein': 12,
    'andorra': 12,
    'turkey': 13,
    'egypt': 5,
    'jordan': 23,
    'syria': 23,
    'palestine': 23,
    'lebanon': 23,
    'pakistan': 1,
    'india': 1,
    'bangladesh': 1,
    'iran': 7,
    'iraq': 1,
    'kuwait': 9,
    'qatar': 10,
    'united arab emirates': 16,
    'oman': 8,
    'bahrain': 8,
    'malaysia': 17,
    'singapore': 11,
    'indonesia': 20,
    'morocco': 21,
    'algeria': 19,
    'tunisia': 18,
    'russia': 14,
    'united states': 2,
    'canada': 2,
    'rest of europe / africa / americas': 3,
  };

  static Future<int> resolveMethodForRegionFromPosition(Position pos) async {
    final country = await getCountryFromCoordinates(pos);
    if (country == null || country.isEmpty) return 3;
    final key = country.toLowerCase().trim();
    return _prayerMethodByCountryName[key] ?? 3;
  }

  static Future<int> resolveMethodFromLastKnownPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return 3;
      return await resolveMethodForRegionFromPosition(pos);
    } catch (_) {
      return 3;
    }
  }

  static Future<void> maybeRefreshCacheOnLaunch() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final lastSuccessMs = prefs.getInt('prayer_last_success') ?? 0;
    final lastAttemptDay = prefs.getInt('prayer_last_attempt_day') ?? -1;
    final lastSuccess = DateTime.fromMillisecondsSinceEpoch(lastSuccessMs, isUtc: false);
    final daysSince = now.difference(lastSuccess).inDays;
    if (daysSince < 10 && lastSuccessMs != 0) return;
    final todayKey = now.year * 10000 + now.month * 100 + now.day;
    if (lastAttemptDay == todayKey) return;
    await prefs.setInt('prayer_last_attempt_day', todayKey);
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return;
      final method = await resolveMethodForRegionFromPosition(pos);
      final curr = DateTime(now.year, now.month, 1);
      final next = DateTime(now.year, now.month + 1, 1);
      await fetchAndCacheMonth(year: curr.year, month: curr.month, latitude: pos.latitude, longitude: pos.longitude, method: method);
      await fetchAndCacheMonth(year: next.year, month: next.month, latitude: pos.latitude, longitude: pos.longitude, method: method);
      await cleanupKeepPrevCurrentNext(now);
      await prefs.setInt('prayer_last_success', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('prayer_last_latlng', '${pos.latitude},${pos.longitude}');
    } catch (_) {}
  }
}


