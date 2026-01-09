import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/quran_repository.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/util/tajweed_parser.dart';
import 'package:qurani/util/text_normalizer.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class ShareAyahSheet extends StatefulWidget {
  final SurahMeta surah;
  final AyahData ayah;
  final bool isTranslation;
  final TextDirection textDirection;
  final String? reciterIdentifier;

  const ShareAyahSheet({
    super.key,
    required this.surah,
    required this.ayah,
    required this.isTranslation,
    required this.textDirection,
    this.reciterIdentifier,
  });

  @override
  State<ShareAyahSheet> createState() => _ShareAyahSheetState();
}

class _ShareAyahSheetState extends State<ShareAyahSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isGeneratingImage = false;

  Future<void> _shareText(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    String surahName = widget.surah.name;
    if (widget.isTranslation) {
        surahName = widget.surah.englishName;
    } else {
       // Normalize to remove diacritics for check
       final normalizedName = TextNormalizer.normalize(widget.surah.name);
       if (normalizedName.contains('سورة')) {
          // Name already contains Surah, do nothing
       }
    }
    
    // Construct footer carefully
    String footer;
    if (widget.isTranslation) {
       footer = "[Surah $surahName - ${widget.ayah.numberInSurah}]";
    } else {
       // For Arabic, text is usually "سورة البقرة".
       // Normalize to remove diacritics for check
       final normalizedName = TextNormalizer.normalize(widget.surah.name);
       if (normalizedName.contains('سورة')) {
          footer = "[${widget.surah.name} - ${widget.ayah.numberInSurah}]";
       } else {
          footer = "[${l10n.surah} ${widget.surah.name} - ${widget.ayah.numberInSurah}]";
       }
    }

    final String processedText = widget.isTranslation 
        ? widget.ayah.text 
        : TajweedParser.stripTags(widget.ayah.text);

    final text = '$processedText \n\n$footer';
    await Share.share(text);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _shareAudio(BuildContext context) async {
     final reciterKey = widget.reciterIdentifier ?? PreferencesService.getReciter();
     final url = await AudioService.buildVerseUrl(
        reciterKeyAr: reciterKey,
        surahOrder: widget.surah.number,
        verseNumber: widget.ayah.numberInSurah
     );

     if (url != null) {
       await Share.share(url);
       if (context.mounted) Navigator.pop(context);
     } else {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Could not generate audio link')),
         );
       }
     }
  }

  Future<void> _shareImage(BuildContext context) async {
    setState(() => _isGeneratingImage = true);
    try {
      // Capture the hidden widget
      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        _AyahCardGenerator(
          surah: widget.surah,
          ayahText: widget.ayah.text,
          ayahNumber: widget.ayah.numberInSurah,
          isTranslation: widget.isTranslation,
          textDirection: widget.textDirection,
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0, // High resolution
        context: context,
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/ayah_share.png').create();
      await imagePath.writeAsBytes(imageBytes);

      if (context.mounted) {
         await Share.shareXFiles([XFile(imagePath.path)], text: '${widget.surah.name} : ${widget.ayah.numberInSurah}');
         if (context.mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error generating image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              l10n.shareAyah,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.shareAudio),
            onTap: () => _shareAudio(context),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(l10n.shareText),
            onTap: () => _shareText(context),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: Text(l10n.shareImage),
            trailing: _isGeneratingImage
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isGeneratingImage ? null : () => _shareImage(context),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _AyahCardGenerator extends StatelessWidget {
  final SurahMeta surah;
  final String ayahText;
  final int ayahNumber;
  final bool isTranslation;
  final TextDirection textDirection;

  const _AyahCardGenerator({
    required this.surah,
    required this.ayahText,
    required this.ayahNumber,
    required this.isTranslation,
    required this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed width container to simulate detailed phone screen width
    // Height will adapt to content
    
    // Determine header text
    String headerText;
    if (isTranslation) {
       headerText = "Surah ${surah.englishName}";
    } else {
       headerText = surah.name; // Use name directly as per user feedback
    }

    final TextStyle baseStyle = TextStyle(
       fontFamily: 'Amiri Quran',
       fontSize: isTranslation ? 22 : 26,
       color: Colors.black,
       height: 2.0,
    );
    final TextStyle diacriticStyle = baseStyle.copyWith(color: const Color(0xFF006633)); // Using theme primary

    // Parse text
    final spans = isTranslation 
        ? [TextSpan(text: ayahText, style: baseStyle)]
        : TajweedParser.parseSpans(ayahText, baseStyle, diacriticStyle: diacriticStyle);


    return Container(
      width: 1080 / 2, // Simulate high-res width scaled down
      color: const Color(0xFFFFFBE8), // Background color matching the template roughly
      child: IntrinsicHeight( // Allows Stack to expand to child's height
        child: Stack(
          children: [
             // 1. Background Image
             Positioned.fill(
                child: Image.asset(
                  'assets/images/ayah_card_template.png',
                  fit: BoxFit.fill, // Stretch vertically to fill the expanded content
                ),
             ),

             // 2. Header (Surah Name) - Positioned in the top banner
             Positioned(
               top: 20, // Moved up from 28
               left: 0,
               right: 0, 
               child: Center(
                 child: Padding(
                   padding: const EdgeInsets.only(left: 20.0), // Slight shift to right (visually left in LTR code, but check layout)
                                                              // Actually for 'Center', padding left moves it Right.
                   child: Text(
                      headerText,
                      textDirection: isTranslation ? TextDirection.ltr : TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Amiri Quran', 
                        fontSize: 26, 
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6D5220), // Dark Golden/Bronze color
                      ),
                    ),
                 ),
               ),
             ),

            // 3. Content Body
            Padding(
              // Safe area + Header spacing
              padding: const EdgeInsets.fromLTRB(40.0, 100.0, 40.0, 60.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Shrink wrap content
                crossAxisAlignment: CrossAxisAlignment.stretch, // Ensure Text fills width
                children: [
                  // --- Ayah Text ---
                  Directionality(
                    textDirection: textDirection,
                    child: RichText(
                      textAlign: TextAlign.justify, // Keep justify for Quran text look
                      text: TextSpan(
                        style: baseStyle,
                        children: [
                          ...spans,
                           WidgetSpan(
                            alignment: PlaceholderAlignment.middle, // Middle usually works best with line-height
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0, left: 8.0),
                              child: Transform.translate(
                                offset: const Offset(0, 4), // Push it down slightly if it feels too high
                                child: _buildAyahNumberWidget(ayahNumber)
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahNumberWidget(int number) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF006633), width: 1.5),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF006633),
        ),
      ),
    );
  }
}
