import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArabicFontUtils {
  static const String fontAmiri = 'amiri_quran';
  static const String fontScheherazade = 'scheherazade_new';
  static const String fontLateef = 'lateef';

  static TextStyle buildTextStyle(
    String fontKey, {
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    Color? color,
  }) {
    switch (fontKey) {
      case fontScheherazade:
        return GoogleFonts.scheherazadeNew(
          fontSize: fontSize,
          height: height,
          fontWeight: fontWeight,
          color: color,
        );
      case fontLateef:
        return GoogleFonts.lateef(
          fontSize: fontSize,
          height: height,
          fontWeight: fontWeight,
          color: color,
        );
      case fontAmiri:
      default:
        return TextStyle(
          fontFamily: 'Amiri Quran',
          fontSize: fontSize,
          height: height,
          fontWeight: fontWeight ?? FontWeight.w400,
          color: color,
        );
    }
  }
}

