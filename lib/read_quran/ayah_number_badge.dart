import 'package:flutter/material.dart';

/// Circular/pill badge showing an ayah number. Previously the private
/// `_AyahNumberBadge` inside `read_quran_screen.dart`.
class AyahNumberBadge extends StatelessWidget {
  const AyahNumberBadge({
    super.key,
    required this.number,
    required this.rtl,
    required this.colorScheme,
  });

  final int number;
  final bool rtl;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final content = number.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary),
        color: colorScheme.primary.withAlpha((255 * 0.1).round()),
      ),
      child: Text(
        content,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
