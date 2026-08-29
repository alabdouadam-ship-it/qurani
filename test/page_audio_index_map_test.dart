// Tests for the source-index <-> ayah-index translation used by the reader's
// page audio.
//
// Why this matters: `buildPageAudioSourcesWithMapping` skips ayahs whose audio
// cannot be resolved, so the player's source indices and the page's ayah indices
// drift apart. Every ayah highlight, auto-scroll and previous-ayah seek depends
// on converting between them correctly. The conversion was previously written
// out four separate times inside read_quran_screen.dart, each with its own
// bounds check, and a mistake shows up as "the wrong ayah is highlighted while a
// different one is recited" — easy to miss in manual testing.

import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/read_quran/page_audio_index_map.dart';

void main() {
  group('identity mapping (no ayah skipped)', () {
    // A 5-ayah page where every ayah had audio.
    const map = PageAudioIndexMap(<int>[0, 1, 2, 3, 4]);

    test('is recognised as the identity', () {
      expect(map.isIdentity, isTrue);
      expect(map.length, 5);
      expect(map.isEmpty, isFalse);
    });

    test('converts both directions unchanged', () {
      for (var i = 0; i < 5; i++) {
        expect(map.ayahIndexOf(i), i);
        expect(map.sourceIndexOf(i), i);
      }
    });
  });

  group('sparse mapping (ayahs 1 and 3 had no audio)', () {
    // 5 ayahs, only 0, 2 and 4 resolved -> 3 sources.
    const map = PageAudioIndexMap(<int>[0, 2, 4]);

    test('is not the identity', () {
      expect(map.isIdentity, isFalse);
      expect(map.length, 3);
    });

    test('source index resolves to the ayah it actually plays', () {
      expect(map.ayahIndexOf(0), 0);
      expect(map.ayahIndexOf(1), 2);
      expect(map.ayahIndexOf(2), 4);
    });

    test('ayah index resolves to the source that plays it', () {
      expect(map.sourceIndexOf(0), 0);
      expect(map.sourceIndexOf(2), 1);
      expect(map.sourceIndexOf(4), 2);
    });

    test('skipped ayahs have no source', () {
      expect(map.sourceIndexOf(1), isNull);
      expect(map.sourceIndexOf(3), isNull);
    });

    test('skipped ayahs fall back to the first source when starting playback',
        () {
      // Matches the previous inline behaviour: tapping play on an ayah with no
      // audio starts the page from the beginning rather than doing nothing.
      expect(map.sourceIndexOrFirst(1), 0);
      expect(map.sourceIndexOrFirst(3), 0);
      expect(map.sourceIndexOrFirst(4), 2, reason: 'present ayahs unaffected');
    });

    test('stepping back moves one SOURCE, which can skip several ayahs', () {
      // Playing source 2 (ayah 4); previous source is 1, which is ayah 2 —
      // ayah 3 is correctly skipped because it has no audio.
      expect(map.previousSourceIndex(2), 1);
      expect(map.ayahIndexOf(map.previousSourceIndex(2)), 2);
    });

    test('stepping back from the first source stays put', () {
      expect(map.previousSourceIndex(0), 0);
    });
  });

  group('out-of-range handling', () {
    const map = PageAudioIndexMap(<int>[0, 2, 4]);

    test('ayahIndexOf returns null outside the mapping', () {
      expect(map.ayahIndexOf(3), isNull);
      expect(map.ayahIndexOf(99), isNull);
      expect(map.ayahIndexOf(-1), isNull);
    });

    test('ayahIndexOrIdentity degrades to the source index', () {
      // The stream listener relied on this: with no skipped ayahs the mapping is
      // the identity, so an unmapped index is still usually right.
      expect(map.ayahIndexOrIdentity(3), 3);
      expect(map.ayahIndexOrIdentity(0), 0, reason: 'mapped values still win');
      expect(map.ayahIndexOrIdentity(1), 2);
    });

    test('sourceIndexOf returns null for an ayah that is not mapped', () {
      expect(map.sourceIndexOf(99), isNull);
      expect(map.sourceIndexOf(-1), isNull);
    });
  });

  group('empty mapping (nothing prepared)', () {
    test('every lookup is null or the explicit fallback', () {
      expect(PageAudioIndexMap.empty.isEmpty, isTrue);
      expect(PageAudioIndexMap.empty.length, 0);
      expect(PageAudioIndexMap.empty.ayahIndexOf(0), isNull);
      expect(PageAudioIndexMap.empty.sourceIndexOf(0), isNull);
      expect(PageAudioIndexMap.empty.sourceIndexOrFirst(0), 0);
      expect(PageAudioIndexMap.empty.ayahIndexOrIdentity(7), 7);
      expect(PageAudioIndexMap.empty.isIdentity, isTrue,
          reason: 'vacuously true for an empty mapping');
    });
  });

  group('pageAudioNeedsReload', () {
    test('reloads when no source is prepared', () {
      expect(
        pageAudioNeedsReload(
          hasSource: false,
          preparedPageNumber: 5,
          preparedReciterCode: 'basit',
          pageNumber: 5,
          reciterCode: 'basit',
        ),
        isTrue,
      );
    });

    test('reloads when the reciter changed', () {
      expect(
        pageAudioNeedsReload(
          hasSource: true,
          preparedPageNumber: 5,
          preparedReciterCode: 'basit',
          pageNumber: 5,
          reciterCode: 'afs',
        ),
        isTrue,
      );
    });

    test('reloads when the page changed', () {
      expect(
        pageAudioNeedsReload(
          hasSource: true,
          preparedPageNumber: 5,
          preparedReciterCode: 'basit',
          pageNumber: 6,
          reciterCode: 'basit',
        ),
        isTrue,
      );
    });

    test('does NOT reload when page and reciter both match', () {
      // The point of the check: rebuilding costs one probe per ayah plus a
      // setAudioSource round trip, and resets playback position.
      expect(
        pageAudioNeedsReload(
          hasSource: true,
          preparedPageNumber: 5,
          preparedReciterCode: 'basit',
          pageNumber: 5,
          reciterCode: 'basit',
        ),
        isFalse,
      );
    });

    test('reloads when nothing was prepared before', () {
      expect(
        pageAudioNeedsReload(
          hasSource: false,
          preparedPageNumber: null,
          preparedReciterCode: null,
          pageNumber: 1,
          reciterCode: 'basit',
        ),
        isTrue,
      );
    });
  });
}
