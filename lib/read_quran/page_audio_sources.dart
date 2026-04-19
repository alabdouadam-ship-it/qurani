import 'package:just_audio/just_audio.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/media_item_compat.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_repository.dart';

/// Result of building the audio sources for a [PageData]: the list of
/// resolved sources (skipping any ayahs whose audio could not be loaded)
/// plus a mapping from each source index to its position inside
/// `page.ayahs`.
///
/// Previously `_PageAudioSourcesResult` inside `read_quran_screen.dart`.
class PageAudioSourcesResult {
  const PageAudioSourcesResult(this.sources, this.indexMapping);
  final List<AudioSource> sources;
  final List<int> indexMapping;
}

/// Builds audio sources for every ayah on [page] using [reciterCode] and
/// returns both the sources and an index → ayah-index mapping so that
/// skipped null sources (e.g. missing audio files) don't break the
/// correspondence used by the SequenceState listener.
///
/// Previously the top-level private `_buildPageAudioSourcesWithMapping`
/// inside `read_quran_screen.dart`.
Future<PageAudioSourcesResult> buildPageAudioSourcesWithMapping(
  PageData page,
  String reciterCode,
) async {
  final sources = <AudioSource>[];
  final indexMapping = <int>[];
  final langCode = PreferencesService.getLanguage();
  final reciterName = AudioService.reciterDisplayName(reciterCode, langCode);

  for (int i = 0; i < page.ayahs.length; i++) {
    final ayah = page.ayahs[i];
    final mediaItem = MediaItem(
      id: '${reciterCode}_${ayah.surah.number}_${ayah.numberInSurah}',
      title: '${ayah.surah.name} • ${ayah.numberInSurah}',
      album: reciterName,
      artUri: null,
      extras: {
        'surahOrder': ayah.surah.number,
        'verse': ayah.numberInSurah,
        'page': page.number,
      },
    );
    final src = await AudioService.buildVerseAudioSource(
      reciterKeyAr: reciterCode,
      surahOrder: ayah.surah.number,
      verseNumber: ayah.numberInSurah,
      mediaItem: mediaItem,
    );
    if (src != null) {
      sources.add(src);
      indexMapping.add(i); // source[sources.length-1] → ayahs[i]
    }
  }
  return PageAudioSourcesResult(sources, indexMapping);
}
