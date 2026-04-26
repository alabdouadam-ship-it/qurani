import 'package:flutter/material.dart';

import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/util/tajweed_parser.dart';
import 'package:share_plus/share_plus.dart';

class ShareAyahUtils {
  static Future<void> shareAyahAsText(
    BuildContext context, {
    required SurahMeta surah,
    required AyahData ayah,
    required bool isTranslation,
    String? reciterIdentifier,
  }) async {
    return shareRawAyahAsText(
      context,
      surahOrder: surah.number,
      numberInSurah: ayah.numberInSurah,
      surahName: isTranslation ? surah.englishName : surah.name,
      ayahText: ayah.text,
      isTranslation: isTranslation,
      reciterIdentifier: reciterIdentifier,
    );
  }

  static Future<void> shareRawAyahAsText(
    BuildContext context, {
    required int surahOrder,
    required int numberInSurah,
    required String surahName,
    required String ayahText,
    required bool isTranslation,
    String? reciterIdentifier,
  }) async {
    // Cleaner logic for Surah Name
    String cleanSurahName(String name) {
       var cleaned = name.trim();
       final prefixes = [
         'Surah', 'surah', 
         'سورة', 'السورة',
         'سُورَةُ', 'سُورَةِ', 'سُورَةَ'
       ];
       bool changed = true;
       while (changed) {
          changed = false;
          for (final prefix in prefixes) {
             if (cleaned.startsWith(prefix)) {
                 cleaned = cleaned.substring(prefix.length).trim();
                 changed = true;
             }
          }
       }
       return cleaned;
    }

    final cleanedName = cleanSurahName(surahName);
    
    // Force standard prefix
    final footerName = isTranslation 
       ? "Surah $cleanedName" 
       : "سورة $cleanedName";

    final footer = "[$footerName - $numberInSurah]";

    final String processedText = isTranslation 
        ? ayahText 
        : TajweedParser.stripTags(ayahText);

    // Generate Audio Link
    final reciterKey = reciterIdentifier ?? PreferencesService.getReciter();
    final url = await AudioService.buildVerseUrl(
       reciterKeyAr: reciterKey,
       surahOrder: surahOrder,
       verseNumber: numberInSurah
    );

    final text = '$processedText \n\n$footer${url != null ? '\n\n$url' : ''}';
    // Calculate share position origin for iPad
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    
    // ignore: deprecated_member_use
    await Share.share(
      text,
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
  }
}
