import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/services/reciter_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ReciterConfigService.resetMemoryCache);
  tearDown(ReciterConfigService.resetMemoryCache);
  test(
      'cached server catalogue excludes bundled-only reciters from all pickers',
      () async {
    SharedPreferences.setMockInitialValues({
      'reciters_version': 6,
      'reciters_cache': jsonEncode({
        'reciters': [
          {
            'code': 'only-enabled',
            'nameAr': 'قارئ',
            'nameLatin': 'Enabled',
            'ayahsPath': 'https://example.test/ayah',
            'surahsPath': 'https://example.test/surah',
          }
        ]
      }),
    });
    expect((await ReciterConfigService.getReciters()).map((r) => r.code),
        ['only-enabled']);
    expect(
        (await ReciterConfigService.getRecitersWithFullSurahs())
            .map((r) => r.code),
        ['only-enabled']);
    expect(
        (await ReciterConfigService.getRecitersForVerseByVerse())
            .map((r) => r.code),
        ['only-enabled']);
    // Previous saved selections can still resolve without reappearing in pickers.
    expect(ReciterConfigService.reciterMap!.length, greaterThan(1));
    await ReciterConfigService
        .forceRefresh(); // Offline refresh preserves snapshot.
    expect((await ReciterConfigService.getReciters()).length, 1);
  });
  test(
      'authoritative empty catalogue remains empty after restart and offline refresh',
      () async {
    SharedPreferences.setMockInitialValues({
      'reciters_version': 6,
      'reciters_cache': jsonEncode({'reciters': []})
    });
    expect(await ReciterConfigService.getReciters(), isEmpty);
    ReciterConfigService.resetMemoryCache();
    await ReciterConfigService.forceRefresh();
    expect(await ReciterConfigService.getReciters(), isEmpty);
  });
  test('first launch offline still uses bundled catalogue', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ReciterConfigService.getReciters(), isNotEmpty);
  });
}
