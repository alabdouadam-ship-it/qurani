import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/services/preferences_service.dart';

class OfflineAudioService {
  static Future<Directory> _ayahBaseDir(String reciterKey) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = AudioService.ayahsReciterFolder(reciterKey);
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
    final dir = await getApplicationDocumentsDirectory();
    final folder = reciterKey; // convention: full/<reciter>/<SSS>.mp3
    final base = Directory('${dir.path}/full/$folder');
    if (!await base.exists()) return 0;
    final list = await base.list(recursive: false).toList();
    return list.whereType<File>().where((f) => f.path.endsWith('.mp3')).length;
  }

  static Future<void> downloadAllAyahAudios({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30)));
    int totalCount = 0;
    int completed = 0;
    // First pass: compute total
    for (int surah = 1; surah <= 114; surah++) {
      final ayahs = await QuranRepository.instance.loadSurahAyahs(surah, QuranEdition.simple);
      totalCount += ayahs.length;
    }
    onProgress(0, totalCount);
    // Second pass: download if missing
    for (int surah = 1; surah <= 114; surah++) {
      final ayahs = await QuranRepository.instance.loadSurahAyahs(surah, QuranEdition.simple);
      for (final a in ayahs) {
        final url = AudioService.buildVerseUrl(
          reciterKeyAr: reciterKey,
          surahOrder: surah,
          verseNumber: a.numberInSurah,
        );
        final localPath = await AudioService.localAyahFilePath(
          reciterKeyAr: reciterKey,
          surahOrder: surah,
          verseNumber: a.numberInSurah,
        );
        completed++;
        onProgress(completed, totalCount);
        if (url == null) continue;
        final file = File(localPath);
        if (await file.exists()) continue;
        await file.parent.create(recursive: true);
        try {
          await dio.download(url, localPath, cancelToken: cancelToken);
        } catch (_) {
          // ignore and continue
        }
      }
    }
  }
}


