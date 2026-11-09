import 'prayer_cache_policy.dart';
import 'prayer_times_parser.dart';
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

  static Future<PrayerCacheMetadata?> getCacheMetadata(int year, int month) async {
    final row = await _getMonthRow(year, month);
    return row == null ? null : PrayerCacheMetadata.fromJson(row);
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
  static Future<Position?> getPositionForCacheCheck() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          return await Geolocator.getCurrentPosition(locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 8)));
        }
      } catch (_) {}
      return await Geolocator.getLastKnownPosition();
    } catch (_) { return null; }
  }

  static Future<void> observePosition(Position position, int method) async {
    if (await PrayerCachePolicy.observe(position, method)) {
      await AdhanScheduler.cancelScheduledWindow();
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
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (_) {
      // Fallback for older geolocator versions
      // ignore: deprecated_member_use
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
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
      validatePrayerCalendar(resp.data, year: year, month: month);
      final context = await PrayerCachePolicy.active();
      final requested = PrayerCacheMetadata(latitude, longitude, method, DateTime.now());
      if (context != null && !requested.matches(context.position, context.method)) {
        throw StateError('Obsolete prayer location response');
      }
      final jsonString = json.encode(resp.data);
      await _saveMonth(
        year: year,
        month: month,
        method: method,
        lat: latitude,
        lng: longitude,
        jsonString: jsonString,
      );
      PrayerCachePolicy.revision++;
      await AdhanScheduler.invalidateScheduling();
    } else {
      throw Exception('Failed to fetch month $year-$month');
    }
  }

  static Future<Map<String, DateTime>?> getTimesForDate({
    required int year,
    required int month,
    required int day,
  }) async {
    if (!await PrayerCachePolicy.usable(await getCacheMetadata(year, month))) return null;
    final data = await getMonthData(year, month);
    if (data == null) return null;
    final result = parsePrayerTimes(data, year: year, month: month, day: day);
    if (result == null) return null;

    // Apply user per-prayer time adjustments (±minutes) if any
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

  // Default location used purely to seed the current month's calendar so the
  // home Hijri-date card can render before the user grants location. Makkah
  // (Kaaba) + method 4 (Umm al-Qura) gives the authoritative Hijri date.
  static const double _defaultSeedLat = 21.4225;
  static const double _defaultSeedLng = 39.8262;
  static const int _defaultSeedMethod = 4;

  /// Ensures the CURRENT month's calendar is cached so the Hijri date is
  /// available app-wide (notably the home hub card) without first opening
  /// Prayer Times or granting GPS.
  ///
  /// Hijri is a calendar conversion — Aladhan returns the same Hijri date for
  /// a given Gregorian day regardless of coordinates — so seeding with a
  /// default (Makkah/KSA) location is safe and won't disagree with the value
  /// the Prayer Times screen shows once real coordinates are fetched.
  ///
  /// Safety: this seeds ONLY the current month. The Prayer Times screen still
  /// requires prev+curr+next to be cached before it skips its GPS fetch, so a
  /// KSA-seeded current month never causes KSA prayer *times* to be displayed
  /// there — only the (location-independent) Hijri date is consumed early.
  ///
  /// No-ops when the current month is already cached (real fetch or prior
  /// seed) or when offline (the card simply stays hidden, as before).
  static Future<void> ensureHijriSeed() async {
    final now = DateTime.now();
    if (await hasMonth(now.year, now.month)) return;

    double lat = _defaultSeedLat;
    double lng = _defaultSeedLng;
    int method = _defaultSeedMethod;
    // Prefer the user's last-known position if we have one (more accurate
    // method, and the seed will match their region) — otherwise fall back to
    // the KSA default.
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        method = await resolveMethodForRegionFromPosition(pos);
      }
    } catch (_) {}

    try {
      await fetchAndCacheMonth(
        year: now.year,
        month: now.month,
        latitude: lat,
        longitude: lng,
        method: method,
      );
    } catch (_) {
      // Offline / fetch failed — nothing to do; the card stays hidden.
    }
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

  static const Map<String, int> prayerMethodByCountryName = {
    'saudi arabia': 4,
    'kingdom of saudi arabia': 4,
    'السعودية': 4,
    'المملكة العربية السعودية': 4,
    'france': 12,
    'فرنسا': 12,
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

  static const Map<String, int> prayerMethodByIsoCode = {
    'SA': 4, // Saudi Arabia
    'FR': 12, // France (UOIF)
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
    // Reverse-geocode once. We use the result both to persist the user's
    // PHYSICAL country (for news targeting — see PreferencesService
    // .saveLocationCountryCode) and to auto-detect the prayer method. We do
    // this even when the user has a manually-chosen method so the country is
    // still kept fresh for news.
    int? detectedMethod;
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
         final p = placemarks.first;

         // Persist the physical country (ISO alpha-2) for news targeting.
         if (p.isoCountryCode != null && p.isoCountryCode!.isNotEmpty) {
            final code = p.isoCountryCode!.toUpperCase();
            await PreferencesService.saveLocationCountryCode(code);
            if (prayerMethodByIsoCode.containsKey(code)) {
               detectedMethod = prayerMethodByIsoCode[code]!;
            }
         }

         // Persist the coarse town/city for stats geography (locality name
         // only — never coordinates). Mirrors getCityFromCoordinates' field
         // preference so it matches what prayer times shows.
         final city = (p.locality?.isNotEmpty == true)
             ? p.locality!
             : (p.subAdministrativeArea?.isNotEmpty == true)
                 ? p.subAdministrativeArea!
                 : (p.administrativeArea?.isNotEmpty == true)
                     ? p.administrativeArea!
                     : '';
         if (city.isNotEmpty) {
            await PreferencesService.saveLocationCity(city);
         }

         // 2. Try Country Name (only if ISO code didn't resolve a method)
         if (detectedMethod == null &&
             p.country != null && p.country!.isNotEmpty) {
             final name = p.country!.toLowerCase().trim();
             if (prayerMethodByCountryName.containsKey(name)) {
                detectedMethod = prayerMethodByCountryName[name]!;
             }
         }
      }
    } catch (_) {}

    // A user-chosen method overrides auto-detection (but we still saved the
    // country above).
    final userMethod = PreferencesService.getPrayerMethod();
    if (userMethod != null) {
      return userMethod;
    }

    if (detectedMethod != null) return detectedMethod;
    // A failed reverse-geocode must not change methods for the same place.
    final now = DateTime.now();
    final previous = await PrayerCachePolicy.active() ??
        await getCacheMetadata(now.year, now.month);
    if (previous != null && previous.matches(pos, previous.method)) {
      return previous.method;
    }
    return 3; // Default only when no matching location is known.
  }

  static Future<void>? _refreshInFlight;
  static Future<void> maybeRefreshCacheOnLaunch() =>
      _refreshInFlight ??= _refreshCache().whenComplete(() { _refreshInFlight = null; });

  static Future<void> _refreshCache() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    try {
      final pos = await getPositionForCacheCheck();
      if (pos == null) return;
      final method = await resolveMethodForRegionFromPosition(pos);
      await observePosition(pos, method);
      final changed = await PrayerCachePolicy.refresh(
        date: now, position: pos, method: method, read: getCacheMetadata,
        fetch: (year, month) => fetchAndCacheMonth(year: year, month: month,
          latitude: pos.latitude, longitude: pos.longitude, method: method));
      if (!changed) return;
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

        // Skip the 7-day scheduling if we already did it today with the same
        // settings. Without this guard, every 10-day cache refresh re-queues
        // dozens of Android alarms that the OS silently coalesces but counts
        // against alarm-scheduling budgets.
        final shouldSchedule = await AdhanScheduler.shouldScheduleThroughDay(
          soundKey: soundKey,
          toggles: toggles,
          daysAhead: 7,
        );
        if (shouldSchedule) {
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

          // Additionally schedule for the next 7 days using cached month data.
          //
          // IMPORTANT — DST safety: we iterate via the calendar-aware
          // `DateTime(y, m, d + 1)` constructor rather than
          // `cursor.add(Duration(days: 1))`. The latter adds exactly 86400
          // seconds of absolute time, so on DST transition days the
          // cursor's wall-clock drifts by ±1 hour and can skip or repeat
          // a calendar day depending on time-of-day. `DateTime(y, m, d+1)`
          // always advances to the same wall-clock moment on the next
          // calendar date, which is what we want for "tomorrow's times".
          bool complete = timesToday != null;
          DateTime cursor = DateTime(now.year, now.month, now.day + 1);
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
            if (times == null) complete = false;
            cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
          }
          if (!complete) return;
          await AdhanScheduler.markScheduledThroughDay(
            soundKey: soundKey,
            toggles: toggles,
            daysAhead: 7,
          );
        }
      } catch (_) {}
    } catch (_) {}
  }
}

