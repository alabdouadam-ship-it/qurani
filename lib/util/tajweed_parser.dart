import 'package:flutter/material.dart';

/// Parses Tajweed-annotated Quran text (e.g. `[h:3[ٱ]`) into styled spans.
class TajweedParser {
  static final RegExp _tokenPattern =
      RegExp(r'\[([a-z]+)(?::[^\[]+)?\[(.*?)\]', caseSensitive: false);

  // Approximate colors for different tajweed rule groups.
  static const Map<String, Color> _ruleColors = {
    'h': Color(0xFF0F62FE), // Hamzat / Wasl markers
    'l': Color(0xFFFF7043), // Lam Shamsiyah
    'n': Color(0xFF009688), // Noon / Tanween related
    'p': Color(0xFF8E24AA),
    'q': Color(0xFFE53935), // Qalqalah
    'g': Color(0xFF2E7D32),
    'm': Color(0xFF3949AB), // Madd
    's': Color(0xFF546E7A),
    'f': Color(0xFF6A1B9A),
    'o': Color(0xFF795548),
    'u': Color(0xFF00838F),
    'w': Color(0xFF6D4C41),
    'y': Color(0xFF1E88E5),
    'z': Color(0xFF7CB342),
    'a': Color(0xFF5D4037),
    'c': Color(0xFF8D6E63),
    'd': Color(0xFFB71C1C),
    'e': Color(0xFFAD1457),
    't': Color(0xFF26C6DA),
    'k': Color(0xFF4CAF50),
    'r': Color(0xFFCDDC39),
    'b': Color(0xFF26A69A),
    'j': Color(0xFFEF6C00),
    'x': Color(0xFFF06292),
  };

  static const Map<String, String> _glyphReplacements = {
    'ٲ': 'ٱ',
    'ٳ': 'ٱ',
    'ٵ': 'ٱ',
    'ﭐ': 'ٱ',
    'ﭑ': 'ٱ',
  };

  // Arabic diacritic / Quranic mark codepoints to draw in a separate color.
  static const List<int> _diacriticCodepoints = [
    // Harakat
    0x0610, 0x0611, 0x0612, 0x0613, 0x0614, 0x0615, 0x0616, 0x0617, 0x0618,
    0x0619, 0x061A, //
    0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652, 0x0653,
    0x0654, 0x0655, 0x0656, 0x0657, 0x0658, 0x0659, 0x065A, 0x065B, 0x065C,
    0x065D, 0x065E, 0x065F, //
    0x0670, // superscript alif
    // Quranic annotation signs
    0x06D6,
    0x06D7,
    0x06D8,
    0x06D9,
    0x06DA,
    0x06DB,
    0x06DC,
    0x06DF,
    0x06E0,
    0x06E1,
    0x06E2,
    0x06E3,
    0x06E4,
    0x06E5,
    0x06E6,
    0x06E7,
    0x06E8,
    0x06EA,
    0x06EB,
    0x06EC,
    0x06ED,
  ];

  static bool _isDiacritic(int rune) =>
      _diacriticCodepoints.contains(rune);

  /// Parse Tajweed-annotated text, optionally coloring diacritics separately.
  static List<InlineSpan> parseSpans(
    String text,
    TextStyle baseStyle, {
    TextStyle? diacriticStyle,
  }) {
    if (text.isEmpty) {
      return const [];
    }
    final List<InlineSpan> spans = [];
    int cursor = 0;

    while (cursor < text.length) {
      final match = _tokenPattern.matchAsPrefix(text, cursor);
      if (match == null) {
        // Add remaining plain text until next potential token or end.
        final nextTokenIndex = text.indexOf('[', cursor);
        final end = nextTokenIndex == -1 ? text.length : nextTokenIndex;
        final plain = _normalizeGlyphs(text.substring(cursor, end));
        if (plain.isNotEmpty) {
          spans.addAll(
            _buildWithDiacritics(plain, baseStyle, diacriticStyle),
          );
        }
        cursor = end;
        if (nextTokenIndex == -1) {
          break;
        }
        continue;
      }

      // Add any content before the token (if regex skipped preceding text).
      if (match.start > cursor) {
        final gap = _normalizeGlyphs(text.substring(cursor, match.start));
        spans.addAll(
          _buildWithDiacritics(gap, baseStyle, diacriticStyle),
        );
      }

      final rule = match.group(1)?.toLowerCase() ?? '';
      final content = _normalizeGlyphs(match.group(2) ?? '');
      final color = _ruleColors[rule];
      final style =
          color == null ? baseStyle : baseStyle.copyWith(color: color);
      spans.addAll(
        _buildWithDiacritics(content, style, diacriticStyle),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      final tail = _normalizeGlyphs(text.substring(cursor));
      spans.addAll(
        _buildWithDiacritics(tail, baseStyle, diacriticStyle),
      );
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: _normalizeGlyphs(text), style: baseStyle));
    }
    return spans;
  }

  /// Build spans for plain (non-Tajweed) text with optional diacritic color.
  static List<InlineSpan> buildPlainSpans(
    String text,
    TextStyle baseStyle, {
    TextStyle? diacriticStyle,
  }) {
    final normalized = _normalizeGlyphs(text);
    return _buildWithDiacritics(normalized, baseStyle, diacriticStyle);
  }

  static String _normalizeGlyphs(String input) {
    if (input.isEmpty) return input;
    final StringBuffer buffer = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(_glyphReplacements[char] ?? char);
    }
    return buffer.toString();
  }

  static List<InlineSpan> _buildWithDiacritics(
    String text,
    TextStyle baseStyle,
    TextStyle? diacriticStyle,
  ) {
    if (text.isEmpty) {
      return const [];
    }
    if (diacriticStyle == null) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final List<InlineSpan> spans = [];
    final StringBuffer buffer = StringBuffer();
    bool bufferIsDia = false;

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(
        TextSpan(
          text: buffer.toString(),
          style: bufferIsDia ? diacriticStyle : baseStyle,
        ),
      );
      buffer.clear();
    }

    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final isDia = _isDiacritic(rune);
      if (buffer.isEmpty) {
        bufferIsDia = isDia;
        buffer.write(ch);
      } else if (isDia == bufferIsDia) {
        buffer.write(ch);
      } else {
        flush();
        bufferIsDia = isDia;
        buffer.write(ch);
      }
    }
    flush();
    return spans;
  }
}

