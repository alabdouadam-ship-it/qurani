import 'dart:async';

import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_repository.dart';

import 'page_audio_index_map.dart';

/// Bookkeeping for what is currently loaded into the reader's page audio
/// player: which page and reciter it was built for, the source↔ayah index
/// mapping, whether a build is in flight, and whether one is loading.
///
/// Extracted from `read_quran_screen.dart`, where these five fields were reset
/// in four different places and had to stay mutually consistent — a partial
/// reset leaves the player holding one page's audio while the screen believes
/// it holds another, which plays the wrong ayahs.
///
/// Scope is deliberately narrow. This class does NOT own the [AudioPlayer], and
/// it shows no UI: the player calls, the dialogs and the snackbars stay on the
/// screen. It only answers "is what's loaded still valid, and is something
/// already loading?".
///
/// Note it stores no [AudioSource]. The screen's old `_currentPageAudioSource`
/// field was only ever null-checked, never read as an object, so a bool carries
/// the same information and keeps this class free of any just_audio dependency
/// (which is also what makes it testable without a platform channel).
class PreparedPageAudio {
  bool _hasSource = false;
  String? _reciterCode;
  int? _pageNumber;
  PageAudioIndexMap _indexMap = PageAudioIndexMap.empty;
  Future<bool>? _inFlight;
  bool _isLoading = false;

  /// True once a source has been successfully installed in the player.
  bool get hasSource => _hasSource;

  /// Reciter the loaded audio was built for, or null when nothing is loaded.
  /// Also surfaced in the share sheet as the recitation attribution.
  String? get reciterCode => _reciterCode;

  /// Quran page the loaded audio was built for.
  ///
  /// Tracked independently of the screen's current `PageData`, which is nulled
  /// during page transitions — comparing against that instead would make a
  /// mid-transition prepare look valid when it is not.
  int? get pageNumber => _pageNumber;

  /// Source index ↔ ayah index translation for the loaded audio.
  PageAudioIndexMap get indexMap => _indexMap;

  /// True while a prepare is running. Drives the play button's spinner and
  /// suppresses re-entrant play/pause taps.
  bool get isLoading => _isLoading;

  /// An in-flight prepare to join, or null if none is running.
  Future<bool>? get inFlight => _inFlight;

  /// Whether the loaded audio has to be rebuilt to play [pageNumber] with
  /// [reciterCode].
  bool needsReloadFor({
    required int pageNumber,
    required String reciterCode,
  }) =>
      pageAudioNeedsReload(
        hasSource: _hasSource,
        preparedPageNumber: _pageNumber,
        preparedReciterCode: _reciterCode,
        pageNumber: pageNumber,
        reciterCode: reciterCode,
      );

  /// Registers the start of a prepare and returns the completer whose future
  /// concurrent callers will join via [inFlight].
  Completer<bool> beginPreparation() {
    _isLoading = true;
    final completer = Completer<bool>();
    _inFlight = completer.future;
    return completer;
  }

  /// Clears the in-flight marker and the loading flag. Safe to call more than
  /// once; belongs in a `finally`.
  void endPreparation() {
    _isLoading = false;
    _inFlight = null;
  }

  /// Drops a failed in-flight future so the next caller retries fresh instead
  /// of re-awaiting a future that will only throw the same stale error again.
  void discardFailedPreparation() {
    _inFlight = null;
  }

  /// Records a successfully installed source.
  void markPrepared({
    required String reciterCode,
    required int pageNumber,
    required List<int> indexMapping,
  }) {
    _hasSource = true;
    _reciterCode = reciterCode;
    _pageNumber = pageNumber;
    _indexMap = PageAudioIndexMap(indexMapping);
  }

  /// Invalidates the loaded audio when the user picks a different reciter, so
  /// the next play rebuilds rather than continuing with the old recitation.
  ///
  /// A no-op when the pick matches what is already loaded, which keeps playback
  /// position intact if the user re-selects the current reciter.
  void invalidateIfReciterChanged(String newReciterCode) {
    if (_reciterCode != newReciterCode) {
      _reciterCode = null;
    }
  }

  /// Full reset, for the stop paths. Every field must go together: leaving any
  /// one set is what makes the player and the screen disagree about what is
  /// loaded.
  void clear() {
    _hasSource = false;
    _reciterCode = null;
    _pageNumber = null;
    _indexMap = PageAudioIndexMap.empty;
    _inFlight = null;
    _isLoading = false;
  }

  @override
  String toString() => 'PreparedPageAudio(page: $_pageNumber, '
      'reciter: $_reciterCode, hasSource: $_hasSource, loading: $_isLoading)';
}

/// The reciter whose recitation should accompany [edition].
///
/// Editions with their own associated recitation carry an `audioReciterKey`;
/// those without fall back to the user's selected Arabic reciter, so a reader
/// following a translation or tafsir still hears the Arabic ayah.
String reciterCodeForEdition(QuranEdition edition) =>
    edition.audioReciterKey ?? PreferencesService.getReciter();
