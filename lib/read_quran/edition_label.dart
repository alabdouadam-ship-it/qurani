import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_repository.dart';

/// Returns a localized display label for [edition]. Previously the
/// top-level private `_editionLabel` in `read_quran_screen.dart`.
String editionLabel(QuranEdition edition, AppLocalizations l10n) {
  switch (edition) {
    case QuranEdition.simple:
      return '${l10n.arabic} (${l10n.simple})';
    case QuranEdition.uthmani:
      return '${l10n.arabic} (${l10n.uthmani})';
    case QuranEdition.tajweed:
      return l10n.editionArabicTajweed;
    case QuranEdition.english:
      return l10n.english;
    case QuranEdition.french:
      return l10n.french;
    case QuranEdition.tafsir:
      return l10n.tafsir;
    case QuranEdition.irab:
      return l10n.editionIrab;
  }
}
