/// Translation between *source* indices (positions in the player's
/// [ConcatenatingAudioSource]) and *ayah* indices (positions in
/// `PageData.ayahs`).
///
/// The two are not the same. `buildPageAudioSourcesWithMapping` skips any ayah
/// whose audio file could not be resolved — a missing download, a gap in the
/// reciter's set — so on such a page source index 3 may be ayah index 5. Get
/// this wrong and the reader highlights and scrolls to the wrong ayah while a
/// different one is recited, which is subtle enough to ship unnoticed.
///
/// This logic used to be open-coded in four places inside
/// `read_quran_screen.dart` — when starting playback, when seeking to the
/// previous ayah, when tapping an ayah, and in the `sequenceStateStream`
/// listener — each with its own bounds check. It is consolidated here so the
/// conversion is written once and tested, while the *fallbacks* stay explicit
/// at each call site because they legitimately differ: the stream listener
/// leaves the highlight untouched when a lookup fails, whereas seeking falls
/// back to the page's first ayah.
class PageAudioIndexMap {
  const PageAudioIndexMap(this.sourceToAyah);

  /// `sourceToAyah[sourceIndex] == ayahIndex`, as produced by
  /// [PageAudioSourcesResult.indexMapping].
  final List<int> sourceToAyah;

  /// No audio prepared. Lookups return null / their explicit fallback.
  static const PageAudioIndexMap empty = PageAudioIndexMap(<int>[]);

  int get length => sourceToAyah.length;

  bool get isEmpty => sourceToAyah.isEmpty;

  /// The ayah index a given source index plays, or null when [sourceIndex] is
  /// outside the mapping.
  int? ayahIndexOf(int sourceIndex) {
    if (sourceIndex < 0 || sourceIndex >= sourceToAyah.length) return null;
    final ayahIndex = sourceToAyah[sourceIndex];
    return ayahIndex >= 0 ? ayahIndex : null;
  }

  /// Like [ayahIndexOf] but falls back to [sourceIndex] itself when the
  /// mapping does not cover it.
  ///
  /// This identity fallback is what the previous inline code did, and it is
  /// correct in the common case: when no ayah was skipped the mapping is the
  /// identity, so treating an out-of-range source index as its own ayah index
  /// degrades gracefully rather than losing the highlight entirely.
  int ayahIndexOrIdentity(int sourceIndex) =>
      ayahIndexOf(sourceIndex) ?? sourceIndex;

  /// The source index that plays a given ayah index, or null when that ayah has
  /// no audio (it was skipped while building the sources).
  int? sourceIndexOf(int ayahIndex) {
    final index = sourceToAyah.indexOf(ayahIndex);
    return index >= 0 ? index : null;
  }

  /// Like [sourceIndexOf] but falls back to the first source, matching the
  /// previous behaviour when starting playback on an ayah with no audio.
  int sourceIndexOrFirst(int ayahIndex) => sourceIndexOf(ayahIndex) ?? 0;

  /// The source index one step back, clamped at the first source.
  ///
  /// Stepping backwards happens in source space, not ayah space: the previous
  /// *audible* ayah is the previous source, which may be several ayahs earlier
  /// if the ones in between had no audio.
  int previousSourceIndex(int currentSourceIndex) =>
      currentSourceIndex > 0 ? currentSourceIndex - 1 : 0;

  /// True when every source maps to the ayah at the same position, i.e. nothing
  /// was skipped. Useful in tests and diagnostics.
  bool get isIdentity {
    for (var i = 0; i < sourceToAyah.length; i++) {
      if (sourceToAyah[i] != i) return false;
    }
    return true;
  }

  @override
  String toString() => 'PageAudioIndexMap($sourceToAyah)';
}

/// Whether the prepared audio source has to be rebuilt before playing [page]
/// with [reciterCode].
///
/// Extracted from `_preparePageAudio` so the condition is stated once and can be
/// tested. Rebuilding is expensive (one network/disk probe per ayah plus a
/// `setAudioSource` round trip), and rebuilding when it was not needed resets
/// playback position — which is why the check exists at all.
///
/// [preparedPageNumber] and [preparedReciterCode] describe what is currently
/// loaded into the player; both are null when nothing is.
bool pageAudioNeedsReload({
  required bool hasSource,
  required int? preparedPageNumber,
  required String? preparedReciterCode,
  required int pageNumber,
  required String reciterCode,
}) {
  if (!hasSource) return true;
  if (preparedReciterCode != reciterCode) return true;
  // Compared against an independently tracked page number rather than the
  // volatile current PageData, which is nulled during page transitions.
  if (preparedPageNumber != pageNumber) return true;
  return false;
}
