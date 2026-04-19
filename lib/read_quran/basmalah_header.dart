import 'package:flutter/material.dart';

/// Centered large Basmalah glyph rendered above the first ayah of most
/// surahs. Previously the private `_BasmalahHeader` inside
/// `read_quran_screen.dart`.
class BasmalahHeader extends StatelessWidget {
  const BasmalahHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Text(
          '﷽',
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: 42,
            height: 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}
