import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adhan_scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:qurani/services/notification_service.dart';
import 'package:qurani/services/preferences_service.dart';

class PrayerTimesService {
  static Database? _db;
  static final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)));

  static Future<void> _ensureDb() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'qurani_prayer_times.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS prayer_times_months (
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            method INTEGER NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            json TEXT NOT NULL,
            fetched_at INTEGER NOT NULL,
            PRIMARY KEY(year, month)
          )
        ''');
      },
    );
  }

  static Future<void> _saveMonth({
    required int year,
    required int month,
    required int method,
    required double lat,
    required double lng,
    required String jsonString,
  }) async {
    await _ensureDb();
    await _db!.insert(
      'prayer_times_months',
      {
        'year': year,
        'month': month,
        'method': method,
        'lat': lat,
        'lng': lng,
        'json': jsonString,
        'fetched_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, Object?>?> _getMonthRow(int year, int month) async {
    await _ensureDb();
    final rows = await _db!.query('prayer_times_months', where: 'year=? AND month=?', whereArgs: [year, month], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<Map<String, dynamic>?> getMonthData(int year, int month) async {
    final row = await _getMonthRow(year, month);
    if (row == null) return null;
    final jsonStr = row['json'] as String?;
    if (jsonStr == null || jsonStr.isEmpty) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  static Future<void> cleanupKeepPrevCurrentNext(DateTime today) async {
    await _ensureDb();
    final prev = DateTime(today.year, today.month - 1, 1);
    final curr = DateTime(today.year, today.month, 1);
    final next = DateTime(today.year, today.month + 1, 1);
    final keep = <String>{
      '${prev.year}-${prev.month}',
      '${curr.year}-${curr.month}',
      '${next.year}-${next.month}',
    };
    final rows = await _db!.query('prayer_times_months', columns: ['year','month']);
    for (final r in rows) {
      final key = '${r['year']}-${r['month']}';
      if (!keep.contains(key)) {
        await _db!.delete('prayer_times_months', where: 'year=? AND month=?', whereArgs: [r['year'], r['month']]);
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
    final row = await _getMonthRow(year, month);
    return row != null;
  }

  static Future<String?> getCountryFromCoordinates(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        return placemarks.first.country;
      }
    } catch (e) {
      // Intentionally ignoring geocoding errors, will return null
    }
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
    'kingdom of saudi arabia': 4,
    'السعودية': 4,
    'المملكة العربية السعودية': 4,
    'france': 4,
    'فرنسا': 4,
    'egypt': 5,
    'مصر': 5,
    'united arab emirates': 16,
    'الإمارات': 16,
    'germany': 12,
    'ألمانيا': 12,

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
    // 'egypt': 5, // Removed duplicate
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
    // 'united arab emirates': 16, // Removed duplicate
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
    'afghanistan': 1,
    'nepal': 1,
    'sri lanka': 1,
    'nigeria': 5,
    'sudan': 5,
    'yemen': 4,
    'libya': 5,
    'ethiopia': 5,
    'kenya': 5,
    'somalia': 8,
    'brunei': 17,
    'cyprus (north)': 13,
    'rest of europe / africa / americas': 3,
  };

  static const Map<String, int> _prayerMethodByIsoCode = {
    'SA': 4, // Saudi Arabia
    'FR': 4, // France
    'US': 2, // USA
    'CA': 2, // Canada
    'GB': 12, // UK
    'TR': 13, // Turkey
    'EG': 5, // Egypt
    'AE': 16, // UAE
    'KW': 9, // Kuwait
    'QA': 10, // Qatar
    'BH': 8, // Bahrain
    'OM': 8, // Oman
    'LB': 23, // Lebanon
    'PS': 23, // Palestine
    'JO': 23, // Jordan
    'SY': 23, // Syria
    'IQ': 1, // Iraq
    'IR': 7, // Iran
    'PK': 1, // Pakistan
    'IN': 1, // India
    'BD': 1, // Bangladesh
    'ID': 20, // Indonesia
    'MY': 17, // Malaysia
    'SG': 11, // Singapore
    'MA': 21, // Morocco
    'DZ': 19, // Algeria
    'TN': 18, // Tunisia
    'DE': 12, // Germany
    'BE': 12, // Belgium
    'NL': 12, // Netherlands
    'LU': 12, // Luxembourg
    'CH': 12, // Switzerland
    'ES': 12, // Spain
    'IT': 12, // Italy
    'PT': 22, // Portugal
    'IE': 12, // Ireland
    'AT': 12, // Austria
    'DK': 12, // Denmark
    'SE': 12, // Sweden
    'NO': 12, // Norway
    'FI': 12, // Finland
    'IS': 12, // Iceland
  };

  static Future<int> resolveMethodForRegionFromPosition(Position pos) async {
    // Check if user has set a preferred method
    final userMethod = PreferencesService.getPrayerMethod();
    if (userMethod != null) {
      return userMethod;
    }
    
    // Otherwise, auto-detect based on location
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
         final p = placemarks.first;
         
         // 1. Try ISO Country Code (Most reliable)
         if (p.isoCountryCode != null && p.isoCountryCode!.isNotEmpty) {
            final code = p.isoCountryCode!.toUpperCase();
            if (_prayerMethodByIsoCode.containsKey(code)) {
               return _prayerMethodByIsoCode[code]!;
            }
         }
         
         // 2. Try Country Name
         if (p.country != null && p.country!.isNotEmpty) {
             final name = p.country!.toLowerCase().trim();
             if (_prayerMethodByCountryName.containsKey(name)) {
                return _prayerMethodByCountryName[name]!;
             }
         }
      }
    } catch (_) {}

    return 3; // Default
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

      try {
        final soundKey = prefs.getString('adhan_sound') ?? 'afs';
        final toggles = <String, bool>{
          'fajr': prefs.getBool('adhan_fajr') ?? false,
          'dhuhr': prefs.getBool('adhan_dhuhr') ?? false,
          'asr': prefs.getBool('adhan_asr') ?? false,
          'maghrib': prefs.getBool('adhan_maghrib') ?? false,
          'isha': prefs.getBool('adhan_isha') ?? false,
        };

        // Schedule for the remainder of today
        final timesToday = await getTimesForDate(year: now.year, month: now.month, day: now.day);
        if (timesToday != null) {
          await NotificationService.scheduleRemainingAdhans(
            times: timesToday,
            soundKey: soundKey,
            toggles: toggles,
          );
          // Background full Adhan playback
          await AdhanScheduler.scheduleForTimes(
            times: timesToday,
            toggles: toggles,
            soundKey: soundKey,
          );
        }

        // Additionally schedule for the next 7 days using cached month data
        DateTime cursor = now.add(const Duration(days: 1));
        for (int i = 0; i < 7; i++) {
          final times = await getTimesForDate(year: cursor.year, month: cursor.month, day: cursor.day);
          if (times != null) {
            await NotificationService.scheduleRemainingAdhans(
              times: times,
              soundKey: soundKey,
              toggles: toggles,
            );
            await AdhanScheduler.scheduleForTimes(
              times: times,
              toggles: toggles,
              soundKey: soundKey,
            );
          }
          cursor = cursor.add(const Duration(days: 1));
        }
      } catch (_) {}
    } catch (_) {}
  }
}


