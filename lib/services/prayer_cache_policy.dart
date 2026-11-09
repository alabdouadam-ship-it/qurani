import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerCacheMetadata {
  const PrayerCacheMetadata(
      this.latitude, this.longitude, this.method, this.fetchedAt);
  final double latitude;
  final double longitude;
  final int method;
  final DateTime fetchedAt;

  bool matches(Position position, int selectedMethod) =>
      method == selectedMethod &&
      Geolocator.distanceBetween(
              latitude, longitude, position.latitude, position.longitude) <
          2000;

  bool isFresh(DateTime now) =>
      !fetchedAt.isAfter(now) &&
      now.difference(fetchedAt) < const Duration(days: 10);

  Position get position => Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: fetchedAt,
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  Map<String, Object> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'method': method,
        'fetched_at': fetchedAt.millisecondsSinceEpoch
      };

  static PrayerCacheMetadata? fromJson(Map data) {
    if (data['lat'] is! num ||
        data['lng'] is! num ||
        data['method'] is! int ||
        data['fetched_at'] is! int) {
      return null;
    }
    return PrayerCacheMetadata(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
        data['method'] as int,
        DateTime.fromMillisecondsSinceEpoch(data['fetched_at'] as int));
  }
}

/// Shared native/Web cache rules. A check never changes the download timestamp.
class PrayerCachePolicy {
  static int revision = 0;
  static const _contextKey = 'prayer_active_location_v1';

  static Future<PrayerCacheMetadata?> active() async {
    final prefs = await SharedPreferences.getInstance();
    // The alarm isolate must see location changes made by the UI isolate.
    await prefs.reload();
    final raw = prefs.getString(_contextKey);
    if (raw == null) return null;
    try {
      return PrayerCacheMetadata.fromJson(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> observe(Position position, int method) async {
    final previous = await active();
    if (previous != null && previous.matches(position, method)) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _contextKey,
        jsonEncode(PrayerCacheMetadata(
                position.latitude, position.longitude, method, DateTime.now())
            .toJson()));
    revision++;
    return true;
  }

  static Future<bool> usable(PrayerCacheMetadata? metadata) async {
    final context = await active();
    return metadata != null &&
        context != null &&
        metadata.matches(context.position, context.method);
  }

  static Future<bool> refresh({
    required DateTime date,
    required Position position,
    required int method,
    required Future<PrayerCacheMetadata?> Function(int, int) read,
    required Future<void> Function(int, int) fetch,
    DateTime? now,
  }) async {
    var changed = false;
    for (final offset in [-1, 0, 1]) {
      final month = DateTime(date.year, date.month + offset);
      final metadata = await read(month.year, month.month);
      if (metadata != null &&
          metadata.matches(position, method) &&
          metadata.isFresh(now ?? DateTime.now())) {
        continue;
      }
      await fetch(month.year, month.month);
      changed = true;
    }
    return changed;
  }
}
