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

    // Cleaner logic for Surah Name
    String cleanSurahName(String name) {
       var cleaned = name.trim();
       final prefixes = ['Surah', 'surah', 'سورة', 'السورة'];
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

    final rawName = isTranslation ? surah.englishName : surah.name;
    final cleanedName = cleanSurahName(rawName);
    
    // Force standard prefix
    final footerName = isTranslation 
       ? "Surah $cleanedName" 
       : "سورة $cleanedName";

    
    final footer = "[$footerName - ${ayah.numberInSurah}]";

    final String processedText = isTranslation 
        ? ayah.text 
        : TajweedParser.stripTags(ayah.text);

    // Generate Audio Link
    final reciterKey = reciterIdentifier ?? PreferencesService.getReciter();
    final url = await AudioService.buildVerseUrl(
       reciterKeyAr: reciterKey,
       surahOrder: surah.number,
       verseNumber: ayah.numberInSurah
    );

    final text = '$processedText \n\n$footer${url != null ? '\n\n$url' : ''}';
    // Calculate share position origin for iPad
    final box = context.findRenderObject() as RenderBox?;
    
    await Share.share(
      text,
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
  }
}
