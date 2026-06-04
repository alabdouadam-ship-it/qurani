import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/quran_edition.dart';

void main() {
  group('QuranEditions.byId', () {
    test('resolves canonical ids to the same instance', () {
      expect(QuranEditions.byId('simple'), QuranEditions.simple);
      expect(QuranEditions.byId('ar.jalalayn'), QuranEditions.tafsirJalalayn);
      expect(QuranEditions.byId('tr.vakfi'), QuranEditions.turkish);
    });

    test('applies the legacy "tafsir" -> muyassar alias', () {
      expect(QuranEditions.byId('tafsir'), QuranEditions.tafsirMuyassar);
    });

    test('falls back to simple for null/empty/unknown', () {
      expect(QuranEditions.byId(null), QuranEditions.simple);
      expect(QuranEditions.byId(''), QuranEditions.simple);
      expect(QuranEditions.byId('no-such-edition'), QuranEditions.simple);
    });

    test('round-trips an edition id through byId', () {
      for (final e in QuranEditions.values) {
        expect(QuranEditions.byId(e.id), e);
      }
    });
  });

  group('category grouping', () {
    test('arabicScripts contains the four scripts', () {
      expect(
        QuranEditions.arabicScripts.map((e) => e.id),
        containsAll(<String>['simple', 'uthmani', 'tajweed', 'irab']),
      );
    });

    test('translations include english, french, turkish, german', () {
      expect(
        QuranEditions.translations.map((e) => e.id),
        containsAll(<String>['english', 'french', 'tr.vakfi', 'de.bubenheim']),
      );
    });

    test('tafsirs include muyassar + the five added books', () {
      expect(
        QuranEditions.tafsirs.map((e) => e.id),
        containsAll(<String>[
          'ar.muyassar',
          'ar.jalalayn',
          'ar.qurtubi',
          'ar.miqbas',
          'ar.waseet',
          'ar.baghawi',
        ]),
      );
    });

    test('every edition belongs to exactly one of the three groups', () {
      final grouped = {
        ...QuranEditions.arabicScripts,
        ...QuranEditions.translations,
        ...QuranEditions.tafsirs,
      };
      expect(grouped.length, QuranEditions.values.length);
    });
  });

  group('edition invariants', () {
    test('every edition has a non-empty dbColumn', () {
      for (final e in QuranEditions.values) {
        expect(e.dbColumn, isNotNull, reason: '${e.id} missing dbColumn');
        expect(e.column.isNotEmpty, isTrue);
      }
    });

    test('translations are LTR and carry a language code', () {
      for (final e in QuranEditions.translations) {
        expect(e.isRtl, isFalse, reason: '${e.id} should be LTR');
        expect(e.languageCode, isNotNull);
      }
    });

    test('tafsir editions are RTL', () {
      for (final e in QuranEditions.tafsirs) {
        expect(e.isRtl, isTrue, reason: '${e.id} should be RTL');
      }
    });

    test('editions without audio fall back (null reciter key)', () {
      // Turkish/German + the new tafsirs have no associated recitation yet.
      expect(QuranEditions.turkish.audioReciterKey, isNull);
      expect(QuranEditions.german.audioReciterKey, isNull);
      expect(QuranEditions.tafsirJalalayn.audioReciterKey, isNull);
      // The ones that DO have audio keep their reciter.
      expect(QuranEditions.english.audioReciterKey, 'arabic_english');
      expect(QuranEditions.tafsirMuyassar.audioReciterKey, 'muyassar');
    });
  });
}
