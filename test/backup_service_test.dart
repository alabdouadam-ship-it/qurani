import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/services/backup_service.dart';
import 'package:qurani/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic>? tables;
  late BackupService service;
  Map<String, dynamic> emptyTables() =>
      {'tasbeeh_groups': [], 'tasbeeh_items': [], 'wirds': []};
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tables = emptyTables();
    service = BackupService(
        readTables: () async => tables,
        writeTables: (value) async {
          tables = value;
        });
  });
  test(
      'portable backup includes user data but excludes device state, GPS, tokens and download claims',
      () async {
    SharedPreferences.setMockInitialValues({
      'language': 'fr',
      'highlighted_pdf_pages': ['2'],
      'memorization_total_tests': 5,
      'installation_id_v1': 'secret-device',
      'prayer_last_latlng': '1,2',
      'download_full': true,
      'reciters_cache': 'cache',
      'sb-auth-token': 'secret'
    });
    final data = await service.capture();
    expect(
        data.preferences.keys,
        unorderedEquals(
            ['language', 'highlighted_pdf_pages', 'memorization_total_tests']));
    final roundtrip = BackupService.parse(jsonEncode(data.toJson()));
    expect(roundtrip.preferences, data.preferences);
  });
  test(
      'restore replaces backed-up data, keeps device state and hydrates numeric settings safely',
      () async {
    SharedPreferences.setMockInitialValues({
      'language': 'ar',
      'memorization_total_tests': 10,
      'installation_id_v1': 'keep'
    });
    await service.restore(BackupData(
        {'language': 'fr', 'font_size': 20, 'adhan_volume': 1},
        emptyTables(),
        DateTime(2026)));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'fr');
    expect(prefs.containsKey('memorization_total_tests'), isFalse);
    expect(prefs.getString('installation_id_v1'), 'keep');
    expect(prefs.getDouble('font_size'), 20.0);
    await PreferencesService.init();
    expect(PreferencesService.getAdhanVolume(), 1.0);
    expect(prefs.containsKey(BackupService.journalKey), isFalse);
  });
  test('unknown or malformed preference fails before any write', () async {
    for (final bad in [
      {'language': null},
      {'installation_id_v1': 'injected'},
      {
        'repetition_passage_v1': ['1', '8', '1', '9']
      },
      {'reciter': '../escape'},
      {'audio_bookmarks_list_v1': '[{}]'},
      {'highlighted_ayahs_colors': '{"bad":1}'},
      {'memorization_test_history': '[1]'},
      {'memorization_surah_agg': '{"1":null}'}
    ]) {
      await expectLater(
          service.restore(BackupData(bad, emptyTables(), DateTime(2026))),
          throwsA(anything));
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    }
  });
  test('rejects newer versions and invalid tables/references', () {
    final data = BackupData({}, emptyTables(), DateTime(2026)).toJson();
    expect(() => BackupService.parse(jsonEncode({...data, 'version': 2})),
        throwsFormatException);
    final bad = emptyTables();
    bad['tasbeeh_items'] = [
      {
        'id': 'item',
        'group_id': 'missing',
        'text': 'text',
        'count': 0,
        'position': 0
      }
    ];
    expect(() => BackupService.validateTables(bad), throwsFormatException);
    expect(() => BackupService.validateTables({'anything': []}),
        throwsFormatException);
  });
  test('failed database write rolls back and removes the recovery journal',
      () async {
    SharedPreferences.setMockInitialValues({'language': 'ar'});
    var writes = 0;
    service = BackupService(
        readTables: () async => tables,
        writeTables: (value) async {
          if (++writes == 1) throw StateError('disk error');
          tables = value;
        });
    await expectLater(
        service.restore(
            BackupData({'language': 'fr'}, emptyTables(), DateTime(2026))),
        throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'ar');
    expect(prefs.containsKey(BackupService.journalKey), isFalse);
    expect(writes, 2);
  });
  test('startup recovery repairs a restore interrupted between stores',
      () async {
    final before = BackupData({'language': 'en', 'memorization_total_tests': 7},
        emptyTables(), DateTime(2026));
    SharedPreferences.setMockInitialValues({
      'language': 'fr',
      'font_size': 24.0,
      BackupService.journalKey: jsonEncode(before.toJson())
    });
    await service.recoverInterruptedRestore();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'en');
    expect(prefs.getInt('memorization_total_tests'), 7);
    expect(prefs.containsKey('font_size'), isFalse);
    expect(prefs.containsKey(BackupService.journalKey), isFalse);
  });
  test('review schedule roundtrips with all endpoints and dates', () async {
    final review = {
      'startSurah': 1,
      'startVerse': 1,
      'endSurah': 2,
      'endVerse': 4,
      'due': '2026-11-06',
      'lastReviewed': '2026-11-03',
      'intervalDays': 3,
      'reviews': 1
    };
    SharedPreferences.setMockInitialValues({
      'spaced_reviews_v1': jsonEncode([review])
    });
    final backup = await service.capture();
    await (await SharedPreferences.getInstance()).remove('spaced_reviews_v1');
    await service.restore(backup);
    expect(
        jsonDecode((await SharedPreferences.getInstance())
            .getString('spaced_reviews_v1')!),
        [review]);
  });
}
