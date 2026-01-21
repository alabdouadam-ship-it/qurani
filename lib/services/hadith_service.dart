import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:dio/dio.dart'; // Project uses Dio
import '../models/hadith_model.dart';

class HadithService {
  static const String _editionsPath = 'assets/data/hadithdata/editions.json';
  static const String _booksPath = 'assets/data/hadithdata/';

  // Cache for loaded editions
  List<HadithEditionEntry>? _cachedEditions;

  // Singleton instance
  static final HadithService _instance = HadithService._internal();
  factory HadithService() => _instance;
  HadithService._internal();

  /// Loads all available editions from parsed JSON
  Future<List<HadithEditionEntry>> loadEditions() async {
    if (_cachedEditions != null) return _cachedEditions!;

    try {
      final jsonString = await rootBundle.loadString(_editionsPath);
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      
      final List<HadithEditionEntry> editions = [];
      jsonMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          // value is like {"name":..., "collection": [...]}
          // We need to inject the key (e.g. "bukhari") if needed, or just parse
          editions.add(HadithEditionEntry.fromJson(value));
        }
      });
      
      debugPrint('Loaded ${editions.length} editions from $_editionsPath');
      _cachedEditions = editions;
      return editions;
    } catch (e) {
      debugPrint('Error loading editions from $_editionsPath: $e');
      return [];
    }
  }

  /// Categorizes books into Sahihain, Sunan, and Others
  Map<String, List<HadithEditionEntry>> categorizeBooks(List<HadithEditionEntry> editions) {
    final Map<String, List<HadithEditionEntry>> categories = {
      'Sahihain': [],
      'Sunan': [],
      'Others': [],
    };

    for (var edition in editions) {
      final nameLower = edition.name.toLowerCase();
      if (nameLower.contains('bukhari') || nameLower.contains('muslim')) {
        categories['Sahihain']!.add(edition);
      } else if (nameLower.contains('sunan') || nameLower.contains('tirmidhi')) { // Tirmidhi is Jami but often grouped with Sunan
         categories['Sunan']!.add(edition);
      } else {
        categories['Others']!.add(edition);
      }
    }
    return categories;
  }

  /// Checks if a book file exists locally (assets or downloaded)
  Future<bool> isBookAvailable(String bookId) async {
    // Check assets first
    try {
      // We can't synchronously check asset existence easily without loading.
      // But we know specific files:
      // partial check based on file listing I saw earlier:
      final assetFiles = [
        'ara-abudawud.json', 'ara-bukhari.json', 'ara-dehlawi.json',
        'ara-ibnmajah.json', 'ara-malik.json', 'ara-muslim.json',
        'ara-nasai.json', 'ara-nawawi.json', 'ara-qudsi.json',
        'ara-tirmidhi.json', 'eng-abudawud.json', 'eng-bukhari.json',
        'eng-dehlawi.json', 'eng-ibnmajah.json', 'eng-malik.json',
        'eng-muslim.json', 'eng-nasai.json', 'eng-nawawi.json',
        'eng-qudsi.json', 'eng-tirmidhi.json', 'fra-abudawud.json',
        'fra-bukhari.json', 'fra-dehlawi.json', 'fra-ibnmajah.json',
        'fra-malik.json', 'fra-muslim.json', 'fra-nasai.json',
        'fra-nawawi.json', 'fra-qudsi.json'
      ];
      
      if (assetFiles.contains('$bookId.json')) {
        return true;
      }
    } catch (_) {}

    // Check local storage
    if (kIsWeb) return false; // Web doesn't have file storage in the same way, assume assets only for now or network needed

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$bookId.json');
    return file.exists();
  }

  /// Loads book content
  Future<HadithBook> loadBook(String bookId) async {
    String jsonString;
    
    // 1. Try Assets
    try {
      jsonString = await rootBundle.loadString('$_booksPath$bookId.json');
    } catch (_) {
      // 2. Try Local Storage
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$bookId.json');
        if (await file.exists()) {
          jsonString = await file.readAsString();
        } else {
          throw Exception('Book not found locally');
        }
      } else {
         throw Exception('Book not found');
      }
    }

    final jsonMap = json.decode(jsonString);
    return HadithBook.fromJson(jsonMap);
  }

  /// Downloads a book entry from URL
  Future<void> downloadBook(String bookId, String url, {ProgressCallback? onProgress}) async {
    if (kIsWeb) {
      throw Exception('Downloading to file system not supported on Web yet');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$bookId.json';
    
    final dio = Dio();
    await dio.download(
      url, 
      filePath,
      onReceiveProgress: onProgress,
    );
  }

  /// Verifies if a book file actually exists and is readable
  Future<bool> verifyBookIntegrity(String bookId) async {
    // 1. Try Assets
    try {
      await rootBundle.loadString('$_booksPath$bookId.json');
      return true;
    } catch (_) {
      // 2. Try Local Storage
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$bookId.json');
        return await file.exists();
      }
    }
    return false;
  }
  /// Static map of known book sizes to avoid network requests
  static const Map<String, String> _staticBookSizes = {
    'ara-abudawud.json': '7.0 MB',
    'eng-abudawud.json': '4.1 MB',
    'fra-abudawud.json': '4.4 MB',
    'ara-bukhari.json': '9.3 MB',
    'eng-bukhari.json': '4.9 MB',
    'fra-bukhari.json': '5.3 MB',
    'ara-dehlawi.json': '9.0 KB',
    'eng-dehlawi.json': '7.9 KB',
    'fra-dehlawi.json': '8.2 KB',
    'ara-ibnmajah.json': '5.3 MB',
    'eng-ibnmajah.json': '3.1 MB',
    'fra-ibnmajah.json': '3.1 MB',
    'ara-malik.json': '2.1 MB',
    'eng-malik.json': '1.5 MB',
    'fra-malik.json': '1.4 MB',
    'ara-muslim.json': '8.3 MB',
    'eng-muslim.json': '4.1 MB',
    'fra-muslim.json': '4.2 MB',
    'ara-nasai.json': '6.8 MB',
    'eng-nasai.json': '3.8 MB',
    'fra-nasai.json': '4.0 MB',
    'ara-nawawi.json': '48.2 KB',
    'eng-nawawi.json': '35.2 KB',
    'fra-nawawi.json': '31.4 KB',
    'ara-qudsi.json': '54.0 KB',
    'eng-qudsi.json': '40.4 KB',
    'fra-qudsi.json': '35.6 KB',
    'ara-tirmidhi.json': '6.8 MB',
    'eng-tirmidhi.json': '3.0 MB',
  };

  /// Fetches the file size of the book from the server (HEAD request)
  /// Uses a static map if available to avoid network call
  Future<String?> getBookSize(String url) async {
    try {
      final fileName = url.split('/').last;
      if (_staticBookSizes.containsKey(fileName)) {
        return _staticBookSizes[fileName];
      }
      
      final dio = Dio();
      final response = await dio.head(url);
      final size = response.headers.value('content-length');
      if (size != null) {
        final bytes = int.parse(size);
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      debugPrint('Error fetching book size: $e');
    }
    return null;
  }
}
