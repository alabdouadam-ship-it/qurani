// Tests for the reader's page-audio bookkeeping.
//
// These five pieces of state have to stay mutually consistent. Before this was
// extracted they were reset in four separate places in read_quran_screen.dart,
// and a partial reset is a nasty class of bug: the player holds one page's audio
// while the screen believes it holds another, so the wrong ayahs play and the
// wrong ones are highlighted.

import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/read_quran/prepared_page_audio.dart';
import 'package:qurani/services/quran_repository.dart';

void main() {
  group('initial state', () {
    test('nothing loaded, nothing loading', () {
      final p = PreparedPageAudio();
      expect(p.hasSource, isFalse);
      expect(p.reciterCode, isNull);
      expect(p.pageNumber, isNull);
      expect(p.isLoading, isFalse);
      expect(p.inFlight, isNull);
      expect(p.indexMap.isEmpty, isTrue);
    });

    test('always needs a reload', () {
      final p = PreparedPageAudio();
      expect(p.needsReloadFor(pageNumber: 1, reciterCode: 'basit'), isTrue);
    });
  });

  group('markPrepared', () {
    PreparedPageAudio prepared() => PreparedPageAudio()
      ..markPrepared(
        reciterCode: 'basit',
        pageNumber: 42,
        indexMapping: const <int>[0, 2, 4],
      );

    test('records page, reciter and mapping', () {
      final p = prepared();
      expect(p.hasSource, isTrue);
      expect(p.reciterCode, 'basit');
      expect(p.pageNumber, 42);
      expect(p.indexMap.sourceToAyah, <int>[0, 2, 4]);
      expect(p.indexMap.ayahIndexOf(1), 2,
          reason: 'mapping must be usable straight away');
    });

    test('no reload needed for the same page and reciter', () {
      expect(prepared().needsReloadFor(pageNumber: 42, reciterCode: 'basit'),
          isFalse);
    });

    test('reload needed for a different page', () {
      expect(prepared().needsReloadFor(pageNumber: 43, reciterCode: 'basit'),
          isTrue);
    });

    test('reload needed for a different reciter', () {
      expect(prepared().needsReloadFor(pageNumber: 42, reciterCode: 'afs'),
          isTrue);
    });
  });

  group('preparation lifecycle', () {
    test('beginPreparation marks loading and exposes a joinable future',
        () async {
      final p = PreparedPageAudio();
      final completer = p.beginPreparation();

      expect(p.isLoading, isTrue);
      expect(p.inFlight, isNotNull);

      completer.complete(true);
      await expectLater(p.inFlight, completion(isTrue));
    });

    test('endPreparation clears loading and the in-flight marker', () {
      final p = PreparedPageAudio();
      p.beginPreparation().complete(true);
      p.endPreparation();
      expect(p.isLoading, isFalse);
      expect(p.inFlight, isNull);
    });

    test('endPreparation is idempotent', () {
      final p = PreparedPageAudio();
      p.beginPreparation().complete(true);
      p.endPreparation();
      expect(p.endPreparation, returnsNormally);
      expect(p.isLoading, isFalse);
    });

    test('discardFailedPreparation drops a poisoned future but keeps loading',
        () async {
      // Guards the real bug: re-awaiting a failed prepare only rethrows the same
      // stale error, so the next caller must be able to retry fresh.
      final p = PreparedPageAudio();
      final completer = p.beginPreparation();
      completer.completeError(Exception('network died'));
      await expectLater(p.inFlight, throwsException);

      p.discardFailedPreparation();
      expect(p.inFlight, isNull);
    });

    test('a second caller can start a fresh prepare after a failure', () async {
      final p = PreparedPageAudio();
      p.beginPreparation().completeError(Exception('boom'));
      await expectLater(p.inFlight, throwsException);
      p.discardFailedPreparation();

      final retry = p.beginPreparation();
      retry.complete(true);
      await expectLater(p.inFlight, completion(isTrue));
    });
  });

  group('invalidateIfReciterChanged', () {
    test('clears the reciter when the user picks a different one', () {
      final p = PreparedPageAudio()
        ..markPrepared(
            reciterCode: 'basit', pageNumber: 5, indexMapping: const [0]);
      p.invalidateIfReciterChanged('afs');
      expect(p.reciterCode, isNull);
      expect(p.needsReloadFor(pageNumber: 5, reciterCode: 'afs'), isTrue);
    });

    test('is a no-op when the pick matches, preserving playback position', () {
      final p = PreparedPageAudio()
        ..markPrepared(
            reciterCode: 'basit', pageNumber: 5, indexMapping: const [0]);
      p.invalidateIfReciterChanged('basit');
      expect(p.reciterCode, 'basit');
      expect(p.needsReloadFor(pageNumber: 5, reciterCode: 'basit'), isFalse);
    });
  });

  group('clear', () {
    test('resets every field together', () {
      final p = PreparedPageAudio()
        ..markPrepared(
            reciterCode: 'basit', pageNumber: 42, indexMapping: const [0, 1]);
      p.beginPreparation();

      p.clear();

      expect(p.hasSource, isFalse);
      expect(p.reciterCode, isNull);
      expect(p.pageNumber, isNull);
      expect(p.indexMap.isEmpty, isTrue);
      expect(p.inFlight, isNull);
      expect(p.isLoading, isFalse);
      expect(p.needsReloadFor(pageNumber: 42, reciterCode: 'basit'), isTrue,
          reason: 'a cleared state must never look valid');
    });
  });

  group('reciterCodeForEdition', () {
    test('uses the edition\'s own recitation when it has one', () {
      expect(reciterCodeForEdition(QuranEditions.english), 'arabic_english');
      expect(reciterCodeForEdition(QuranEditions.tafsirMuyassar), 'muyassar');
    });

    test('falls back to the selected Arabic reciter when it has none', () {
      // Turkish/German and the newer tafsirs carry no audioReciterKey, so the
      // reader hears the Arabic ayah while reading the translation.
      expect(QuranEditions.turkish.audioReciterKey, isNull);
      expect(QuranEditions.tafsirJalalayn.audioReciterKey, isNull);
      // Falls through to PreferencesService.getReciter(), which returns its
      // default when prefs are not initialised in a unit test.
      expect(reciterCodeForEdition(QuranEditions.turkish), isNotEmpty);
      expect(
        reciterCodeForEdition(QuranEditions.tafsirJalalayn),
        reciterCodeForEdition(QuranEditions.german),
        reason: 'both fall back to the same selected reciter',
      );
    });
  });
}
