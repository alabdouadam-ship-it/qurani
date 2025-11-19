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
    final folder = reciterKey;
    final newBase = Directory('${dir.path}/qurani/full/$folder');
    final oldBase = Directory('${dir.path}/full/$folder');
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
    final dir = await getApplicationDocumentsDirectory();
    final newBase = Directory('${dir.path}/qurani/full/$reciterKey');
    final oldBase = Directory('${dir.path}/full/$reciterKey');
    if (await newBase.exists()) {
      await newBase.delete(recursive: true);
    }
    if (await oldBase.exists()) {
      await oldBase.delete(recursive: true);
    }
  }

  static Future<void> downloadAllAyahAudios({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30)));
    int totalCount = 0;
    int completed = 0;
    for (int surah = 1; surah <= 114; surah++) {
      final ayahs = await QuranRepository.instance.loadSurahAyahs(surah, QuranEdition.simple);
      totalCount += ayahs.length;
    }
    onProgress(0, totalCount);
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

  static Future<void> downloadAllFullSurahs({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 60)));
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/qurani/full/$reciterKey');
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    int completed = 0;
    const int total = 114;
    onProgress(0, total);
    for (int surah = 1; surah <= 114; surah++) {
      final url = AudioService.buildFullRecitationUrl(reciterKeyAr: reciterKey, surahOrder: surah);
      if (url == null) {
        completed++;
        onProgress(completed, total);
        continue;
      }
      final padded = surah.toString().padLeft(3, '0');
      final file = File('${base.path}/$padded.mp3');
      if (!await file.exists()) {
        await file.parent.create(recursive: true);
        try {
          await dio.download(url, file.path, cancelToken: cancelToken);
        } catch (_) {
          // ignore errors and continue
        }
      }
      completed++;
      onProgress(completed, total);
    }
    await PreferencesService.setDownloadedFull(true);
    await PreferencesService.setDownloadedReciter(reciterKey);
  }
}


