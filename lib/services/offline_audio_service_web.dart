import 'download_batch.dart';
class OfflineAudioService {
  static Future<int> countDownloadedAyahs(String reciterKey) async => 0;
  static Future<void> deleteDownloadedAyahs(String reciterKey) async {}
  static Future<int> countDownloadedFullSurahs(String reciterKey) async => 0;
  static Future<void> deleteDownloadedFullSurahs(String reciterKey) async {}

  static Future<DownloadBatchResult> downloadAllAyahAudios({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    Object? cancelToken,
  }) async {
    throw UnsupportedError('Offline audio downloads are unavailable on web');
  }

  static Future<DownloadBatchResult> downloadAllFullSurahs({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    Object? cancelToken,
  }) async {
    throw UnsupportedError('Offline audio downloads are unavailable on web');
  }
}


