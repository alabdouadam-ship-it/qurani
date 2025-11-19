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

  static Future<void> downloadFullReciter(String reciter, {void Function(double progress)? onProgress}) async {
    onProgress?.call(0.0);
  }
}


