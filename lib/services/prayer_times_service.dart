import 'package:geolocator/geolocator.dart';

enum PrayerCalcMethod { mwl, ummAlQura, egyptian }

class PrayerTimesService {
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
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  }

  // Temporary local estimation until remote API is available or precise methods are added.
  // Provides reasonable placeholder times that can be adjusted by user offsets.
  static Future<Map<String, DateTime>> computeTodayTimes({
    required double latitude,
    required double longitude,
    required PrayerCalcMethod method,
  }) async {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    return {
      'fajr': at(5, 0),
      'sunrise': at(6, 15),
      'dhuhr': at(12, 30),
      'asr': at(15, 45),
      'maghrib': at(18, 10),
      'isha': at(19, 30),
    };
  }
}


