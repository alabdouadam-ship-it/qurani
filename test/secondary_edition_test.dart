import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/read_quran/secondary_edition.dart';
import 'package:qurani/services/quran_repository.dart';

void main() {
  group('editionsShareText', () {
    test('an edition shares text with itself', () {
      expect(
        editionsShareText(QuranEditions.simple, QuranEditions.simple),
        isTrue,
      );
    });

    test('different scripts of the Arabic text do not share text', () {
      // Distinct columns: uthmani carries the full orthography, simple does not.
      expect(
        editionsShareText(QuranEditions.simple, QuranEditions.uthmani),
        isFalse,
      );
      expect(
        editionsShareText(QuranEditions.tajweed, QuranEditions.uthmani),
        isFalse,
      );
    });

    test('simple and irab share text despite being distinct editions', () {
      // irab reads text_simple and adds grammar from MASAQ.csv, so the words
      // are identical. This is the case an id comparison would miss.
      expect(
        editionsShareText(QuranEditions.simple, QuranEditions.irab),
        isTrue,
      );
      expect(
        editionsShareText(QuranEditions.irab, QuranEditions.simple),
        isTrue,
      );
    });

    test('unrelated editions do not share text', () {
      expect(
        editionsShareText(QuranEditions.english, QuranEditions.french),
        isFalse,
      );
      expect(
        editionsShareText(
            QuranEditions.tafsirMuyassar, QuranEditions.tafsirJalalayn),
        isFalse,
      );
    });
  });

  group('secondaryEditionOptions', () {
    test('offers every edition except irab', () {
      final options = secondaryEditionOptions();
      expect(options, isNot(contains(QuranEditions.irab)));
      expect(options.length, QuranEditions.values.length - 1);
    });

    test('still offers the plain Arabic text, tafsir and translations', () {
      final options = secondaryEditionOptions();
      expect(options, contains(QuranEditions.simple));
      expect(options, contains(QuranEditions.english));
      expect(options, contains(QuranEditions.tafsirMuyassar));
    });
  });

  group('secondaryFallbackOptions', () {
    test('excludes the preferred edition', () {
      final options = secondaryFallbackOptions(QuranEditions.tafsirMuyassar);
      expect(options, isNot(contains(QuranEditions.tafsirMuyassar)));
      expect(options, contains(QuranEditions.simple));
    });

    test('excludes editions sharing text with the preferred one', () {
      // irab is already excluded as a secondary; the meaningful case is that
      // choosing simple leaves nothing that duplicates simple.
      final options = secondaryFallbackOptions(QuranEditions.simple);
      expect(options, isNot(contains(QuranEditions.simple)));
      expect(options, isNot(contains(QuranEditions.irab)));
      expect(options, contains(QuranEditions.uthmani));
    });

    test('is never empty for any offerable preferred edition', () {
      for (final preferred in secondaryEditionOptions()) {
        expect(
          secondaryFallbackOptions(preferred),
          isNotEmpty,
          reason: 'no fallback available for ${preferred.id}',
        );
      }
    });
  });

  group('resolveSecondaryEdition', () {
    test('returns null when the feature is disabled', () {
      expect(
        resolveSecondaryEdition(
          enabled: false,
          primary: QuranEditions.tajweed,
          preferred: QuranEditions.tafsirMuyassar,
          fallback: QuranEditions.simple,
        ),
        isNull,
      );
    });

    test('returns the preferred edition when it differs from the primary', () {
      expect(
        resolveSecondaryEdition(
          enabled: true,
          primary: QuranEditions.tajweed,
          preferred: QuranEditions.tafsirMuyassar,
          fallback: QuranEditions.simple,
        ),
        QuranEditions.tafsirMuyassar,
      );
    });

    test('falls back when the preferred edition is the one being read', () {
      // The user's scenario: reading Tajweed with Tajweed also chosen as the
      // secondary. The panel must show something else.
      final resolved = resolveSecondaryEdition(
        enabled: true,
        primary: QuranEditions.tajweed,
        preferred: QuranEditions.tajweed,
        fallback: QuranEditions.tafsirMuyassar,
      );
      expect(resolved, QuranEditions.tafsirMuyassar);
      expect(resolved, isNot(QuranEditions.tajweed));
    });

    test('falls back when preferred merely shares text with the primary', () {
      // Reading irab, preferred is simple: different ids, same words.
      expect(
        resolveSecondaryEdition(
          enabled: true,
          primary: QuranEditions.irab,
          preferred: QuranEditions.simple,
          fallback: QuranEditions.english,
        ),
        QuranEditions.english,
      );
    });

    test('returns null when both configured editions collide with the primary',
        () {
      // Nothing distinct can be shown, so the arrow is hidden rather than
      // opening onto a copy of the ayah above it.
      expect(
        resolveSecondaryEdition(
          enabled: true,
          primary: QuranEditions.simple,
          preferred: QuranEditions.simple,
          fallback: QuranEditions.irab,
        ),
        isNull,
      );
    });

    test('never resolves to an edition sharing text with the primary', () {
      // Exhaustive sweep: whatever the configuration, the panel must never be
      // asked to render the same text as the ayah above it.
      for (final primary in QuranEditions.values) {
        for (final preferred in secondaryEditionOptions()) {
          for (final fallback in secondaryFallbackOptions(preferred)) {
            final resolved = resolveSecondaryEdition(
              enabled: true,
              primary: primary,
              preferred: preferred,
              fallback: fallback,
            );
            if (resolved == null) continue;
            expect(
              editionsShareText(resolved, primary),
              isFalse,
              reason: 'primary=${primary.id} preferred=${preferred.id} '
                  'fallback=${fallback.id} resolved=${resolved.id}',
            );
          }
        }
      }
    });

    test('resolves for every primary given the shipped defaults', () {
      // The defaults (tafsir al-Muyassar, falling back to simple) must produce
      // a usable panel for all 14 primaries, so the feature is never dead on
      // first enable.
      for (final primary in QuranEditions.values) {
        expect(
          resolveSecondaryEdition(
            enabled: true,
            primary: primary,
            preferred: QuranEditions.tafsirMuyassar,
            fallback: QuranEditions.simple,
          ),
          isNotNull,
          reason: 'defaults produce no secondary for ${primary.id}',
        );
      }
    });
  });
}
