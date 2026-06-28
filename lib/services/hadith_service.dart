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

  // One-entry cache of the most recently loaded book. Returning to a book you
  // just opened (e.g. opening a search result in a fresh reader on top of the
  // search) then reuses the same parsed object instead of re-reading and
  // re-parsing the JSON (which is several MB for Bukhari/Muslim). Both readers
  // share the same immutable HadithBook reference, so there's no extra data
  // memory either.
  String? _lastBookId;
  HadithBook? _lastBook;

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

  /// Categorizes books into Sahihain, Sunan, and Others.
  ///
  /// Matching is done on the stable `collection.id` (e.g. `ara-bukhari`,
  /// `eng-tirmidhi`) rather than the localized `name`, because `name` is a
  /// display string that may not contain the English keyword in every
  /// language — which would silently misfile books into "Others".
  Map<String, List<HadithEditionEntry>> categorizeBooks(List<HadithEditionEntry> editions) {
    final Map<String, List<HadithEditionEntry>> categories = {
      'Sahihain': [],
      'Sunan': [],
      'Others': [],
    };

    for (var edition in editions) {
      // Build a keyword string from both the name and every collection id so
      // categorization is robust regardless of the display language.
      final keys = <String>[
        edition.name.toLowerCase(),
        ...edition.collection.map((c) => c.id.toLowerCase()),
      ].join(' ');

      if (keys.contains('bukhari') || keys.contains('muslim')) {
        categories['Sahihain']!.add(edition);
      } else if (keys.contains('sunan') ||
          keys.contains('tirmidhi') ||
          keys.contains('abudawud') ||
          keys.contains('nasai') ||
          keys.contains('ibnmajah')) {
        // Tirmidhi is a Jami but is conventionally grouped with the Sunan.
        categories['Sunan']!.add(edition);
      } else {
        categories['Others']!.add(edition);
      }
    }
    return categories;
  }

  /// Resolves the download URL for a book id.
  ///
  /// * Web: jsDelivr mirror of the same dataset. GitHub *release* assets don't
  ///   send `Access-Control-Allow-Origin`, so a browser fetch from the web app
  ///   is blocked by CORS; jsDelivr serves byte-identical files WITH `ACAO: *`.
  /// * Mobile: the GitHub release `link` from editions.json (downloaded to the
  ///   filesystem; no CORS constraints off-browser).
  Future<String?> _resolveBookUrl(String bookId) async {
    if (kIsWeb) {
      return 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/$bookId.json';
    }
    final editions = await loadEditions();
    for (final e in editions) {
      for (final c in e.collection) {
        if (c.id == bookId) return c.link;
      }
    }
    return null;
  }

  /// Loads book content.
  ///
  /// Resolution order:
  ///   1. Bundled asset (if shipped in the app).
  ///   2. Local downloaded file (mobile only).
  ///   3. Hosted URL from editions.json (GitHub release). This is the PRIMARY
  ///      path on Web — there is no filesystem there, so the book JSON is
  ///      fetched into memory. On mobile it's a fallback when the book hasn't
  ///      been downloaded yet.
  Future<HadithBook> loadBook(String bookId) async {
    // Serve the most-recently-loaded book from cache so reopening the same
    // book (e.g. a search result in a fresh reader) is instant.
    if (_lastBookId == bookId && _lastBook != null) {
      return _lastBook!;
    }
    String? jsonString;

    // 1. Try bundled asset.
    try {
      jsonString = await rootBundle.loadString('$_booksPath$bookId.json');
    } catch (_) {
      jsonString = null;
    }

    // 2. Try a previously downloaded local file (mobile only).
    if (jsonString == null && !kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$bookId.json');
        if (await file.exists()) {
          jsonString = await file.readAsString();
        }
      } catch (_) {
        // ignore; fall through to remote fetch
      }
    }

    // 3. Fetch from the hosted URL (GitHub release). In-memory — no filesystem
    //    needed, so this works on Web.
    if (jsonString == null) {
      final url = await _resolveBookUrl(bookId);
      if (url != null && url.isNotEmpty) {
        try {
          final resp = await Dio().get<String>(
            url,
            options: Options(responseType: ResponseType.plain),
          );
          if (resp.statusCode == 200 &&
              resp.data != null &&
              resp.data!.isNotEmpty) {
            jsonString = resp.data;
          }
        } catch (e) {
          debugPrint('[HadithService] remote fetch failed for $bookId: $e');
        }
      }
    }

    if (jsonString == null) {
      throw Exception('Book not found');
    }

    final jsonMap = json.decode(jsonString);
    final book = HadithBook.fromJson(jsonMap);
    _lastBookId = bookId;
    _lastBook = book;
    return book;
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
