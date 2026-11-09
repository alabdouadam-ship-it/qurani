import 'download_issue_service.dart';
import 'download_batch.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/download_service.dart';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/services/preferences_service.dart';

class OfflineAudioService {
  static Future<Directory> _ayahBaseDir(String reciterKey) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = await AudioService.ayahsReciterFolder(reciterKey);
    final base = Directory('${dir.path}/ayahs/$folder');
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  static Future<int> countDownloadedAyahs(String reciterKey) async {
    final base = await _ayahBaseDir(reciterKey);
    if (!await base.exists()) return 0;
    final list = await base.list(recursive: false).toList();
    int valid = 0;
    for (final file in list.whereType<File>().where((f) => f.path.endsWith('.mp3'))) {
      if (await DownloadService.verifyFile(file)) valid++;
    }
    return valid;
  }

  static Future<void> deleteDownloadedAyahs(String reciterKey) async {
    final base = await _ayahBaseDir(reciterKey);
    if (await base.exists()) {
      await base.delete(recursive: true);
    }
  }

  static Future<int> countDownloadedFullSurahs(String reciterKey) async {
    // Path layout owned by DownloadService — delegate so the two services
    // can never disagree on where files live.
    final newBase = await DownloadService.surahsBaseDir(reciterKey);
    final dir = await getApplicationDocumentsDirectory();
    final oldBase = Directory('${dir.path}/full/$reciterKey');
    int countNew = 0;
    int countOld = 0;
    if (await newBase.exists()) {
      final list = await newBase.list(recursive: false).toList();
      countNew = list.whereType<File>().where((f) => f.path.endsWith('.mp3')).length;
    }
    if (await oldBase.exists()) {
      final list = await oldBase.list(recursive: false).toList();
      countOld = list.whereType<File>().where((f) => f.path.endsWith('.mp3')).length;
    }
    return countNew > countOld ? countNew : countOld;
  }

  static Future<void> deleteDownloadedFullSurahs(String reciterKey) async {
    final newBase = await DownloadService.surahsBaseDir(reciterKey);
    final dir = await getApplicationDocumentsDirectory();
    final oldBase = Directory('${dir.path}/full/$reciterKey');
    if (await newBase.exists()) {
      await newBase.delete(recursive: true);
    }
    if (await oldBase.exists()) {
      await oldBase.delete(recursive: true);
    }
    // Drop integrity cache so next render shows a clean slate, not stale
    // "verified" entries that point at deleted files.
    await PreferencesService.clearVerifiedFullCache(reciterKey);
  }

  static Future<DownloadBatchResult> downloadAllAyahAudios({
    required String reciterKey, required void Function(int completed, int total) onProgress,
    CancelToken? cancelToken,
  }) => DownloadIssueService.track(DownloadIssue(reciter: reciterKey, surah: 0, verse: 0),
    () => _downloadAllAyahAudios(reciterKey: reciterKey, onProgress: onProgress, cancelToken: cancelToken),
    cancelToken: cancelToken);

  static Future<DownloadBatchResult> _downloadAllAyahAudios({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final items = <({int surah, int verse})>[];
    for (int surah = 1; surah <= 114; surah++) {
      if (cancelToken?.isCancelled == true) {
        return const DownloadBatchResult(total: 6236, completed: 0,
            failed: 0, cancelled: true);
      }
      final ayahs = await QuranRepository.instance.loadSurahAyahs(surah, QuranEditions.simple);
      if (ayahs.isEmpty) throw StateError('Missing ayahs for surah $surah');
      items.addAll(ayahs.map((a) => (surah: surah, verse: a.numberInSurah)));
    }
    return runDownloadBatch(
      items: items, cancelToken: cancelToken, onProgress: onProgress,
      download: (item) => DownloadService.downloadAyah(
        reciter: reciterKey, surahOrder: item.surah,
        verseNumber: item.verse, cancelToken: cancelToken),
    );
  }

  static Future<DownloadBatchResult> downloadAllFullSurahs({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    return DownloadService.downloadFullReciter(reciterKey,
      concurrency: 1, cancelToken: cancelToken,
      onProgress: (progress) => onProgress((progress * 114).round(), 114));
  }
}
