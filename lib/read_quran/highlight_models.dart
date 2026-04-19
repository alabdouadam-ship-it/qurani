import 'package:qurani/services/quran_repository.dart';

/// A highlighted ayah entry paired with the stored color. Previously
/// `_HighlightedAyah` inside `read_quran_screen.dart`.
class HighlightedAyah {
  const HighlightedAyah({
    required this.ayahNumber,
    required this.ayah,
    required this.color,
  });

  final int ayahNumber;
  final AyahData ayah;
  final int color;
}

/// Actions offered by the ayah-options bottom sheet. Previously
/// `_AyahAction` inside `read_quran_screen.dart`.
enum AyahAction {
  pickColor,
  highlight,
  removeHighlight,
  translateArabic,
  translateEnglish,
  translateFrench,
  tafsir,
  share,
}
