/// Reject invalid network responses before replacing a usable cache.
void validatePrayerCalendar(Object? calendar,
    {required int year, required int month}) {
  if (calendar is! Map ||
      calendar['data'] is! List ||
      (calendar['data'] as List).isEmpty) {
    throw const FormatException('Empty or invalid prayer calendar');
  }
  for (var day = 1; day <= (calendar['data'] as List).length; day++) {
    parsePrayerTimes(calendar, year: year, month: month, day: day);
  }
}

/// Validates API/cache data before it can become a prayer alarm.
/// Missing calendar days return null; malformed days throw FormatException.
Map<String, DateTime>? parsePrayerTimes(
  Object? calendar, {
  required int year,
  required int month,
  required int day,
}) {
  if (calendar is! Map || calendar['data'] is! List) {
    throw const FormatException('Invalid prayer calendar');
  }
  final days = calendar['data'] as List;
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime(year, month + 1, 0).day) {
    throw const FormatException('Invalid prayer date');
  }
  if (day > days.length) return null;
  final entry = days[day - 1];
  if (entry is! Map || entry['timings'] is! Map) {
    throw const FormatException('Missing prayer timings');
  }
  final timings = entry['timings'] as Map;
  DateTime parse(String key) {
    final raw = timings[key];
    final match = raw is String
        ? RegExp(r'^(\d{1,2}):(\d{2})(?:\s+\([^)]+\))?$').firstMatch(raw.trim())
        : null;
    if (match == null) throw FormatException('Invalid prayer time: $key');
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw FormatException('Out-of-range prayer time: $key');
    }
    return DateTime(year, month, day, hour, minute);
  }

  final result = <String, DateTime>{};
  for (final key in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
    result[key.toLowerCase()] = parse(key);
  }
  if (timings['Imsak'] != null) result['imsak'] = parse('Imsak');
  return result;
}
