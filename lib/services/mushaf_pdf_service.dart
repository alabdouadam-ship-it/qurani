import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum MushafType {
  blue,
  green,
  tajweed;

  String get id => name;

  String get displayNameAr {
    switch (this) {
      case MushafType.blue:
        return 'النسخة الزرقاء';
      case MushafType.green:
        return 'النسخة الخضراء';
      case MushafType.tajweed:
        return 'النسخة المجودة';
    }
  }
  
  String get fileName => '$name.pdf';
  
  String get downloadUrl => 'https://qurani.info/data/pdfs/$fileName';
}

class MushafPdfService {
  MushafPdfService._();
  
  static final MushafPdfService instance = MushafPdfService._();
  final Dio _dio = Dio();
  
  Future<String> _getDownloadPath() async {
    final dir = await getApplicationSupportDirectory();
    final pdfDir = Directory(p.join(dir.path, 'pdfs'));
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir.path;
  }
  
  Future<String> getPdfPath(MushafType type) async {
    final dirPath = await _getDownloadPath();
    return p.join(dirPath, type.fileName);
  }
  
  Future<bool> isDownloaded(MushafType type) async {
    final path = await getPdfPath(type);
    return File(path).existsSync();
  }
  
  Future<void> downloadMushaf(
    MushafType type, {
    required Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final path = await getPdfPath(type);
    
    // Create a temporary file path
    final tempPath = '$path.download';
    
    try {
      // 1. Check Content-Type (Optional but good)
      // We skip HEAD request to avoid double connectivity issues, 
      // but we will validate the file header after download.

      await _dio.download(
        type.downloadUrl,
        tempPath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      
      // 2. Validate PDF Header (Magic Bytes)
      final file = File(tempPath);
      if (await file.exists()) {
        final handle = await file.open(mode: FileMode.read);
        final header = await handle.read(4);
        await handle.close();
        
        final headerString = String.fromCharCodes(header);
        if (!headerString.startsWith('%PDF')) {
           await file.delete();
           throw Exception('Invalid PDF file format (Header: $headerString)');
        }
      } else {
         throw Exception('Download failed: Temp file not found');
      }
      
      // Rename temp file to actual file upon completion
      await file.rename(path);
    } catch (e) {
      // Clean up temp file on error
      try {
        final file = File(tempPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }
  
  Future<void> deleteMushaf(MushafType type) async {
    final path = await getPdfPath(type);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// Helper to get what page offset might be needed
  /// Usually standard PDFs have some cover pages.
  /// User said "First page of Quran might not be the first in PDF"
  /// We'll default to 0 for now and adjust via testing/config if needed.
  int getPageOffset(MushafType type) {
    switch (type) {
      case MushafType.blue:
      case MushafType.green:
        return 3; // Page 1 of Quran is Page 4 of PDF
      case MushafType.tajweed:
        return 9; // Page 1 of Quran is Page 10 of PDF

    }
  }
}
