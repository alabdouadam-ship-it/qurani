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
    return list.whereType<File>().where((f) => f.path.endsWith('.mp3')).length;
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

  static Future<void> downloadAllAyahAudios({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    int totalCount = 0;
    int completed = 0;
    for (int surah = 1; surah <= 114; surah++) {
      final ayahs = await QuranRepository.instance.loadSurahAyahs(surah, QuranEdition.simple);
      totalCount += ayahs.length;
    }
    onProgress(0, totalCount);
    for (int surah = 1; surah <= 114; surah++) {
      // Ayah-level cancel granularity is fine: a typical ayah is < 1MB,
      // so honouring cancel between ayahs caps the wasted bandwidth
      // without bloating DownloadService with a CancelToken parameter.
      if (cancelToken?.isCancelled == true) return;
      final ayahs = await QuranRepository.instance.loadSurahAyahs(surah, QuranEdition.simple);
      for (final a in ayahs) {
        if (cancelToken?.isCancelled == true) return;
        completed++;
        onProgress(completed, totalCount);
        try {
          // Delegate to DownloadService so ayah downloads inherit the
          // same `.part`/resume/MP3-validation behaviour as full surahs.
          await DownloadService.downloadAyah(
            reciter: reciterKey,
            surahOrder: surah,
            verseNumber: a.numberInSurah,
          );
        } catch (_) {
          // ignore and continue — the next bulk run will pick up misses.
        }
      }
    }
  }

  static Future<void> downloadAllFullSurahs({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    // Ensure the unified base dir exists once up-front; per-surah delegate
    // also creates it but this avoids a transient "0 of 114" race on the UI.
    await DownloadService.surahsBaseDir(reciterKey);
    int completed = 0;
    const int total = 114;
    onProgress(0, total);
    for (int surah = 1; surah <= 114; surah++) {
      // Coarse cancel granularity (per-surah). A surah is the smallest unit
      // that DownloadService can resume, so cancelling mid-surah would only
      // discard the in-memory progress — the `.part` file is preserved and
      // the next run will resume from the same byte offset.
      if (cancelToken?.isCancelled == true) {
        // Persist completion of finished items + flags so the offline
        // screen reflects partial progress on reopen.
        await PreferencesService.setDownloadedReciter(reciterKey);
        return;
      }
      try {
        // Delegates through DownloadService → `.part` resume, MP3
        // validation, retry/backoff, and pause-skip via PreferencesService.
        await DownloadService.downloadSurah(reciterKey, surah);
      } catch (_) {
        // ignore and continue — same forgiving semantics as before.
      }
      completed++;
      onProgress(completed, total);
    }
    await PreferencesService.setDownloadedFull(true);
    await PreferencesService.setDownloadedReciter(reciterKey);
  }
}


