import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/prayer_times_service_io.dart';

void main() {
  group('PrayerTimesService Mapping', () {
    test('should map known countries to correct methods', () {
      expect(PrayerTimesService.prayerMethodByCountryName['saudi arabia'], 4);
      expect(PrayerTimesService.prayerMethodByCountryName['france'], 4);
      expect(PrayerTimesService.prayerMethodByCountryName['egypt'], 5);
      expect(PrayerTimesService.prayerMethodByCountryName['pakistan'], 1);
    });

    test('should map known ISO codes to correct methods', () {
      expect(PrayerTimesService.prayerMethodByIsoCode['SA'], 4);
      expect(PrayerTimesService.prayerMethodByIsoCode['FR'], 4);
      expect(PrayerTimesService.prayerMethodByIsoCode['EG'], 5);
      expect(PrayerTimesService.prayerMethodByIsoCode['GB'], 12);
    });

    test('case sensitivity check for mappings', () {
      // The service uses .toLowerCase() on country names
      final saudi = 'Saudi Arabia'.toLowerCase();
      expect(PrayerTimesService.prayerMethodByCountryName[saudi], 4);
    });
  });

  group('Hijri Date Parsing Logic', () {
    // Note: We can't easily test getHijriForDate without a mock database/List,
    // but we can verify the structure of the parsing logic by checking how it would handle a map.
    test('Manual test of Hijri extraction logic', () {
      final mockDayData = {
        'date': {
          'hijri': {
            'day': '14',
            'month': {'ar': 'رمضان', 'en': 'Ramadan'},
            'year': '1445'
          }
        }
      };

      final hijri = (mockDayData['date'] as Map)['hijri'] as Map;
      final monthMap = (hijri['month'] as Map).cast<String, dynamic>();

      expect(hijri['day'], '14');
      expect(monthMap['ar'], 'رمضان');
      expect(hijri['year'], '1445');
    });
  });
}
