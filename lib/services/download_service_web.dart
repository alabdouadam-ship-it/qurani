// Web stub for `DownloadService`. The full IO implementation lives in
// `download_service_io.dart`; on web there is no persistent file system
// for audio caches, so every API returns an "empty / not-downloaded /
// not-verified" answer and downloads are no-ops.
class DownloadService {
  DownloadService._();

  static Future<String> localSurahPath(String reciter, int order) async {
    return '';
  }

  static Future<bool> isSurahDownloaded(String reciter, int order) async {
    return false;
  }

  static Future<void> downloadSurah(String reciter, int order) async {
    // No-op on web
  }

  static Future<void> downloadFullReciter(String reciter, {void Function(double progress)? onProgress, int concurrency = 4}) async {
    onProgress?.call(0.0);
  }

  static Future<void> downloadAyah({
    required String reciter,
    required int surahOrder,
    required int verseNumber,
  }) async {
    // No-op on web
  }

  // --- Integrity API stubs ---
  static Future<bool> verifyFile(Object file) async => false;
  static Future<bool> verifySurahFile(String reciter, int order) async => false;
  static Future<bool> verifySurahFileCached(
    String reciter,
    int order, {
    bool forceRefresh = false,
  }) async => false;
  static Future<({int present, int missing, int corrupt})>
      verifyAllSurahs(String reciter) async =>
          (present: 0, missing: 114, corrupt: 0);

  static Future<int> repairCorruptSurahs(String reciter) async => 0;
}


