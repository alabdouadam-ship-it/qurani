import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qurani/services/media_item_compat.dart';
import 'package:qurani/services/reciter_config_service.dart';

class AudioService {
  /// Get reciter display name
  /// Uses ReciterConfigService to load from JSON
  static String reciterDisplayName(String code, String langCode) {
    // Synchronous access - data should be preloaded at app startup
    final reciter = ReciterConfigService.reciterMap?[code];
    if (reciter == null) return code;
    return reciter.getDisplayName(langCode);
  }

  static String _normalizeArabic(String input) {
    const diacritics = r"[\u064B-\u0652\u0670\u0640]";
    return input.replaceAll(RegExp(diacritics), '').trim();
  }

  static Future<String> _resolveBaseForReciter(String reciterKeyAr) async {
    // Try exact match first
    final reciter = await ReciterConfigService.getReciter(reciterKeyAr);
    if (reciter?.surahsPath != null) {
      return reciter!.surahsPath!;
    }
    
    // Try normalized match
    final norm = _normalizeArabic(reciterKeyAr);
    final reciters = await ReciterConfigService.getReciters();
    for (final r in reciters) {
      if (_normalizeArabic(r.code) == norm && r.surahsPath != null) {
        return r.surahsPath!;
      }
    }
    
    // Fallback to basit
    return '/data/full/basit';
  }

  static String? _pad3(int order) {
    if (order < 1 || order > 999) return null;
    return order.toString().padLeft(3, '0');
  }

  static Future<String?> buildFullRecitationUrl({required String reciterKeyAr, required int surahOrder}) async {
    final base = await _resolveBaseForReciter(reciterKeyAr);
    final padded = _pad3(surahOrder);
    if (padded == null) return null;
    
    // Handle external URL
    if (base.startsWith('http')) {
      return '$base/$padded.mp3';
    }
    
    return 'https://www.qurani.info$base/$padded.mp3';
  }

  static Future<String?> buildVerseUrl({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
  }) async {
    final s = _pad3(surahOrder);
    final v = _pad3(verseNumber);
    if (s == null || v == null) return null;
    
    final reciter = await ReciterConfigService.getReciter(reciterKeyAr);
    if (reciter == null) return null;
    
    final ayahsPath = reciter.ayahsPath;
    return '$ayahsPath/$s$v.mp3';
  }

  static Future<String> _getAyahsReciterFolder(String reciterKeyAr) async {
    final reciter = await ReciterConfigService.getReciter(reciterKeyAr);
    if (reciter == null) return 'afs'; // Fallback
    
    // Extract folder name from ayahsPath
    final path = reciter.ayahsPath;
    if (path.contains('/')) {
      return path.split('/').last;
    }
    return path;
  }

  static Future<String> ayahsReciterFolder(String reciterKeyAr) async {
    return await _getAyahsReciterFolder(reciterKeyAr);
  }

  static Future<List<String>> buildVerseUrls({
    required String reciterKeyAr,
    required int surahOrder,
    required int totalVerses,
  }) async {
    final urls = <String>[];
    for (int i = 1; i <= totalVerses; i++) {
      final url = await buildVerseUrl(
        reciterKeyAr: reciterKeyAr,
        surahOrder: surahOrder,
        verseNumber: i,
      );
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  static Future<String> localAyahFilePath({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final reciterFolder = await _getAyahsReciterFolder(reciterKeyAr);
    final s = _pad3(surahOrder) ?? '001';
    final v = _pad3(verseNumber) ?? '001';
    final base = Directory('${dir.path}/ayahs/$reciterFolder');
    return '${base.path}/$s$v.mp3';
  }

  static Future<bool> isLocalAyahAvailable({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
  }) async {
    try {
      final p = await localAyahFilePath(
        reciterKeyAr: reciterKeyAr,
        surahOrder: surahOrder,
        verseNumber: verseNumber,
      );
      return File(p).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<Uri?> getVerseUriPreferLocal({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
  }) async {
    try {
      final p = await localAyahFilePath(
        reciterKeyAr: reciterKeyAr,
        surahOrder: surahOrder,
        verseNumber: verseNumber,
      );
      if (await File(p).exists()) {
        return Uri.file(p);
      }
    } catch (_) {}
    final url = await buildVerseUrl(
      reciterKeyAr: reciterKeyAr,
      surahOrder: surahOrder,
      verseNumber: verseNumber,
    );
    return url != null ? Uri.parse(url) : null;
  }

  static Future<AudioSource?> buildVerseAudioSource({
    required String reciterKeyAr,
    required int surahOrder,
    required int verseNumber,
    required MediaItem mediaItem,
  }) async {
    final uri = await getVerseUriPreferLocal(
      reciterKeyAr: reciterKeyAr,
      surahOrder: surahOrder,
      verseNumber: verseNumber,
    );
    if (uri == null) return null;
    return AudioSource.uri(uri, tag: mediaItem);
  }
}


