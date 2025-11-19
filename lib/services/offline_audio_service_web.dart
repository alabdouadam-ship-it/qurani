class OfflineAudioService {
  static Future<int> countDownloadedAyahs(String reciterKey) async => 0;
  static Future<void> deleteDownloadedAyahs(String reciterKey) async {}
  static Future<int> countDownloadedFullSurahs(String reciterKey) async => 0;
  static Future<void> deleteDownloadedFullSurahs(String reciterKey) async {}

  static Future<void> downloadAllAyahAudios({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    Object? cancelToken,
  }) async {
    onProgress(0, 0);
  }

  static Future<void> downloadAllFullSurahs({
    required String reciterKey,
    required void Function(int completed, int total) onProgress,
    Object? cancelToken,
  }) async {
    onProgress(0, 114);
  }
}


