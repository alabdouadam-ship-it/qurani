import 'package:flutter/material.dart';

class ArabicFontUtils {
  static const String fontAmiri = 'amiri_quran';
  static const String fontKfgqpcSmall = 'kfgqpc_hafs_small';
  static const String fontKfgqpcLarge = 'kfgqpc_hafs_large';

  static TextStyle buildTextStyle(
    String fontKey, {
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    Color? color,
  }) {
    switch (fontKey) {
      case fontKfgqpcSmall:
        return TextStyle(
          fontFamily: 'KFGQPCHafsSmall',
          fontSize: fontSize,
          height: height,
          fontWeight: fontWeight ?? FontWeight.w400,
          color: color,
        );
      case fontKfgqpcLarge:
        return TextStyle(
          fontFamily: 'KFGQPCHafsLarge',
          fontSize: fontSize,
          height: height,
          fontWeight: fontWeight ?? FontWeight.w400,
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

