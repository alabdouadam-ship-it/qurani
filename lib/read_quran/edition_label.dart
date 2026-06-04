import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_repository.dart';

/// Returns a localized display label for [edition].
///
/// Fixed editions (Arabic scripts + the english/french translations) use their
/// l10n keys. The data-driven editions (extra translations + tafsir books) have
/// no per-edition l10n string; they display their native name when the app is
/// in Arabic and their English name otherwise — sourced from the edition JSON's
/// `edition.name` / `edition.englishName`.
String editionLabel(QuranEdition edition, AppLocalizations l10n) {
  switch (edition.l10nKey) {
    case 'simple':
      return '${l10n.arabic} (${l10n.simple})';
    case 'uthmani':
      return '${l10n.arabic} (${l10n.uthmani})';
    case 'tajweed':
      return l10n.editionArabicTajweed;
    case 'irab':
      return l10n.editionIrab;
    case 'english':
      return l10n.english;
    case 'french':
      return l10n.french;
    case 'turkish':
      return l10n.editionTurkish;
    case 'german':
      return l10n.editionGerman;
  }
  // Data-driven editions (turkish/german/extra tafsirs).
  final isArabicUi = l10n.localeName == 'ar';
  final native = edition.nativeName;
  final english = edition.englishName;
  if (isArabicUi && native != null && native.isNotEmpty) return native;
  if (english != null && english.isNotEmpty) return english;
  return native ?? edition.id;
}
