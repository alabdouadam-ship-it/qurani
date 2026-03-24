import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

// ──────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────

/// A single morphological segment of a word.
class IrabSegment {
  final String segmentedWord;
  final String morphTag;
  final String morphType; // Prefix, Stem, Suffix
  final String invariableDeclinable;
  final String syntacticRole;
  final String possessiveConstruct;
  final String caseMood;
  final String caseMoodMarker;
  final String phrase;
  final String phrasalFunction;
  final String notes;

  const IrabSegment({
    required this.segmentedWord,
    required this.morphTag,
    required this.morphType,
    required this.invariableDeclinable,
    required this.syntacticRole,
    required this.possessiveConstruct,
    required this.caseMood,
    required this.caseMoodMarker,
    required this.phrase,
    required this.phrasalFunction,
    required this.notes,
  });
}

/// A single Quran word with its full diacritized form and segments.
class IrabWord {
  final String word; // Diacritized Arabic word
  final String withoutDiacritics;
  final int wordPosition; // Position in verse (Column5)
  final List<IrabSegment> segments;

  const IrabWord({
    required this.word,
    required this.withoutDiacritics,
    required this.wordPosition,
    required this.segments,
  });

  /// The primary syntactic role for display (from the Stem segment).
  String get primaryRole {
    for (final seg in segments) {
      if (seg.morphType == 'Stem' && seg.syntacticRole.isNotEmpty) {
        return seg.syntacticRole;
      }
    }
    return '';
  }

  /// The primary case/mood for display.
  String get primaryCaseMood {
    for (final seg in segments) {
      if (seg.morphType == 'Stem' && seg.caseMood.isNotEmpty) {
        return seg.caseMood;
      }
    }
    return '';
  }

  /// The primary case/mood marker for display.
  String get primaryCaseMoodMarker {
    for (final seg in segments) {
      if (seg.morphType == 'Stem' && seg.caseMoodMarker.isNotEmpty) {
        return seg.caseMoodMarker;
      }
    }
    return '';
  }

  /// The primary morph tag (POS) from Stem.
  String get primaryMorphTag {
    for (final seg in segments) {
      if (seg.morphType == 'Stem') {
        return seg.morphTag;
      }
    }
    return '';
  }

  /// The primary invariable/declinable type.
  String get primaryInvariableDeclinable {
    for (final seg in segments) {
      if (seg.morphType == 'Stem' && seg.invariableDeclinable.isNotEmpty) {
        return seg.invariableDeclinable;
      }
    }
    return '';
  }

  /// Build the annotation line: "<role> - <case> (<marker>)"
  String get annotation {
    final parts = <String>[];
    final role = primaryRole;
    if (role.isNotEmpty) parts.add(role);
    final mood = primaryCaseMood;
    if (mood.isNotEmpty) {
      final marker = primaryCaseMoodMarker;
      if (marker.isNotEmpty) {
        parts.add('$mood ($marker)');
      } else {
        parts.add(mood);
      }
    }
    return parts.join(' - ');
  }
}

/// All I'rab data for a single verse.
class IrabVerse {
  final int surahNumber;
  final int verseNumber;
  final List<IrabWord> words;

  const IrabVerse({
    required this.surahNumber,
    required this.verseNumber,
    required this.words,
  });
}

// ──────────────────────────────────────────────
// Service
// ──────────────────────────────────────────────

class IrabService {
  static const String _assetPath = 'assets/data/MASAQ.csv';
  static const String _remoteUrl =
      'https://qurani.info/data/about-qurani/MASAQ.csv';
  static const String _localFileName = 'MASAQ.csv';

  static final IrabService _instance = IrabService._internal();
  factory IrabService() => _instance;
  IrabService._internal();

  /// Parsed data: key = "surah:verse"
  Map<String, IrabVerse>? _cache;
  bool _loading = false;

  /// Whether the CSV data is loaded and ready.
  bool get isLoaded => _cache != null;

  /// Check if data is available locally (assets or downloaded file).
  Future<bool> isDataAvailable() async {
    // 1. Check assets
    try {
      await rootBundle.loadString(_assetPath);
      return true;
    } catch (_) {}

    // 2. Check local file
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_localFileName');
      return file.existsSync();
    }
    return false;
  }

  /// Download the CSV from remote server.
  Future<void> downloadData({ProgressCallback? onProgress}) async {
    if (kIsWeb) {
      throw Exception('Download not supported on web');
    }
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$_localFileName';
    final dio = Dio();
    await dio.download(_remoteUrl, filePath, onReceiveProgress: onProgress);
    // Invalidate cache so it reloads from new file
    _cache = null;
  }

  /// Load and parse the CSV. Returns true if successful.
  Future<bool> loadData() async {
    if (_cache != null) return true;
    if (_loading) return false;
    _loading = true;

    try {
      String csvText;

      // 1. Try assets
      try {
        csvText = await rootBundle.loadString(_assetPath);
      } catch (_) {
        // 2. Try local file
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$_localFileName');
          if (await file.exists()) {
            csvText = await file.readAsString();
          } else {
            _loading = false;
            return false;
          }
        } else {
          _loading = false;
          return false;
        }
      }

      // Parse in isolate to avoid UI jank on large CSV
      _cache = await compute(_parseCsv, csvText);
      _loading = false;
      return true;
    } catch (e) {
      debugPrint('[IrabService] Error loading data: $e');
      _loading = false;
      return false;
    }
  }

  /// Get I'rab data for a specific verse.
  IrabVerse? getVerse(int surahNumber, int verseNumber) {
    return _cache?['$surahNumber:$verseNumber'];
  }

  /// Get all verses for a surah.
  List<IrabVerse> getSurahVerses(int surahNumber) {
    if (_cache == null) return [];
    final verses = <IrabVerse>[];
    for (final entry in _cache!.entries) {
      if (entry.value.surahNumber == surahNumber) {
        verses.add(entry.value);
      }
    }
    verses.sort((a, b) => a.verseNumber.compareTo(b.verseNumber));
    return verses;
  }

  /// Static parse function for compute isolate.
  static Map<String, IrabVerse> _parseCsv(String csvText) {
    final lines = const LineSplitter().convert(csvText);
    if (lines.isEmpty) return {};

    // Skip header
    // Temporary grouping: key = "surah:verse:wordPos" → segments
    final wordMap = <String, List<_RawRow>>{};

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = _parseCsvLine(line);
      if (fields.length < 19) continue;

      final surahNo = int.tryParse(fields[1]) ?? 0;
      final verseNo = int.tryParse(fields[2]) ?? 0;
      final wordPos = int.tryParse(fields[3]) ?? 0;
      final wordNo = int.tryParse(fields[4]) ?? 0;

      if (surahNo == 0 || verseNo == 0) continue;

      final key = '$surahNo:$verseNo:$wordPos';
      wordMap.putIfAbsent(key, () => []);
      wordMap[key]!.add(_RawRow(
        surahNo: surahNo,
        verseNo: verseNo,
        wordPos: wordPos,
        wordNo: wordNo,
        word: fields[5],
        withoutDiacritics: fields[6],
        segmentedWord: fields[7],
        morphTag: fields[8],
        morphType: fields[9],
        punctuation: fields[10],
        invariableDeclinable: fields[11],
        syntacticRole: fields[12],
        possessiveConstruct: fields[13],
        caseMood: fields[14],
        caseMoodMarker: fields[15],
        phrase: fields[16],
        phrasalFunction: fields[17],
        notes: fields[18],
      ));
    }

    // Group words into verses
    final verseMap = <String, List<IrabWord>>{};

    for (final entry in wordMap.entries) {
      final rows = entry.value;
      if (rows.isEmpty) continue;

      final first = rows.first;
      final verseKey = '${first.surahNo}:${first.verseNo}';

      final segments = rows.map((r) => IrabSegment(
            segmentedWord: r.segmentedWord,
            morphTag: r.morphTag,
            morphType: r.morphType,
            invariableDeclinable: r.invariableDeclinable,
            syntacticRole: r.syntacticRole,
            possessiveConstruct: r.possessiveConstruct,
            caseMood: r.caseMood,
            caseMoodMarker: r.caseMoodMarker,
            phrase: r.phrase,
            phrasalFunction: r.phrasalFunction,
            notes: r.notes,
          )).toList();

      final word = IrabWord(
        word: first.word,
        withoutDiacritics: first.withoutDiacritics,
        wordPosition: first.wordPos,
        segments: segments,
      );

      verseMap.putIfAbsent(verseKey, () => []);
      verseMap[verseKey]!.add(word);
    }

    // Build final IrabVerse map
    final result = <String, IrabVerse>{};
    for (final entry in verseMap.entries) {
      final parts = entry.key.split(':');
      final surah = int.parse(parts[0]);
      final verse = int.parse(parts[1]);
      final words = entry.value..sort((a, b) => a.wordPosition.compareTo(b.wordPosition));
      result[entry.key] = IrabVerse(
        surahNumber: surah,
        verseNumber: verse,
        words: words,
      );
    }

    return result;
  }

  /// Simple CSV line parser that handles quoted fields.
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }
}

/// Internal raw parsed row.
class _RawRow {
  final int surahNo;
  final int verseNo;
  final int wordPos;
  final int wordNo;
  final String word;
  final String withoutDiacritics;
  final String segmentedWord;
  final String morphTag;
  final String morphType;
  final String punctuation;
  final String invariableDeclinable;
  final String syntacticRole;
  final String possessiveConstruct;
  final String caseMood;
  final String caseMoodMarker;
  final String phrase;
  final String phrasalFunction;
  final String notes;

  const _RawRow({
    required this.surahNo,
    required this.verseNo,
    required this.wordPos,
    required this.wordNo,
    required this.word,
    required this.withoutDiacritics,
    required this.segmentedWord,
    required this.morphTag,
    required this.morphType,
    required this.punctuation,
    required this.invariableDeclinable,
    required this.syntacticRole,
    required this.possessiveConstruct,
    required this.caseMood,
    required this.caseMoodMarker,
    required this.phrase,
    required this.phrasalFunction,
    required this.notes,
  });
}
