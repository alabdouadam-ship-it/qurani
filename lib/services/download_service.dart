import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'preferences_service.dart';
import 'audio_service.dart';

class DownloadService {
  DownloadService._();
  static final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 60)));

  static Future<Directory> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/qurani/full');
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  static Future<String> localSurahPath(String reciter, int order) async {
    final base = await _baseDir();
    final padded = order.toString().padLeft(3, '0');
    final dir = Directory('${base.path}/$reciter');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '${dir.path}/$padded.mp3';
  }

  static Future<bool> isSurahDownloaded(String reciter, int order) async {
    final path = await localSurahPath(reciter, order);
    return File(path).exists();
  }

  static Future<void> downloadSurah(String reciter, int order) async {
    final url = AudioService.buildFullRecitationUrl(reciterKeyAr: reciter, surahOrder: order);
    if (url == null) {
      throw Exception('Unable to resolve download URL for surah $order');
    }
    final target = await localSurahPath(reciter, order);
    final file = File(target);
    if (await file.exists()) {
      return;
    }
    await _dio.download(url, target);
  }

  /// Download all 114 surahs for the given reciter.
  /// onProgress receives values in [0.0, 1.0].
  static Future<void> downloadFullReciter(String reciter, {void Function(double progress)? onProgress}) async {
    int completed = 0;
    for (int order = 1; order <= 114; order++) {
      final url = AudioService.buildFullRecitationUrl(reciterKeyAr: reciter, surahOrder: order);
      if (url == null) {
        completed++;
        onProgress?.call(completed / 114.0);
        continue;
      }
      final target = await localSurahPath(reciter, order);
      final file = File(target);
      if (await file.exists()) {
        completed++;
        onProgress?.call(completed / 114.0);
        continue;
      }
      await _dio.download(url, target, onReceiveProgress: (received, total) {
        if (total > 0) {
          final perFile = received / total;
          // Weight per-file equally into global progress
          final global = (completed + perFile) / 114.0;
          onProgress?.call(global);
        }
      });
      completed++;
      onProgress?.call(completed / 114.0);
    }
    await PreferencesService.setDownloadedFull(true);
    await PreferencesService.setDownloadedReciter(reciter);
  }
}







