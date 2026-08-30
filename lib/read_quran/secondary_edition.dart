/// Which edition the reader's per-ayah expandable panel should display.
///
/// The reader has one *primary* edition — the text you are actually reading —
/// and optionally one *secondary* edition, shown one ayah at a time in a panel
/// that opens under the ayah. The user configures the secondary edition once in
/// the reader settings; it then applies to every ayah on every page.
///
/// The wrinkle is that the primary edition changes freely while the secondary
/// preference stays put, so the two can end up being the same edition — at
/// which point the panel would just repeat the text directly above it. The user
/// therefore configures two editions: a [preferred] one and a [fallback] used
/// only when [preferred] collides with the primary.
///
/// This logic lives in its own file, separate from the widget code, because it
/// is the only part of the feature that can be tested without a device.
library;

import 'package:qurani/services/quran_repository.dart';

/// True when [a] and [b] would render the same text.
///
/// Compares the underlying text source rather than the edition id, because
/// distinct editions can share one. `simple` and `irab` both read
/// `text_simple`: they are different editions with different renderings, but
/// the *words* are identical, so showing one as the secondary of the other is
/// exactly the duplication this guard exists to prevent.
///
/// `dbColumn` is used as the source identity because it is populated for every
/// edition in the registry on all platforms — the web repository keys off
/// `webDataDir` instead, but the two agree 1:1 on which editions share text.
bool editionsShareText(QuranEdition a, QuranEdition b) =>
    a.id == b.id || (a.dbColumn != null && a.dbColumn == b.dbColumn);

/// Editions offerable as a secondary.
///
/// Excludes `irab`, whose value is its interactive word-by-word grammar widget
/// rather than its text — as a flat panel it would render the `simple` text and
/// nothing more.
List<QuranEdition> secondaryEditionOptions() =>
    QuranEditions.values.where((e) => !e.isIrab).toList();

/// Editions offerable as the fallback secondary, given the chosen [preferred].
///
/// Excludes anything sharing text with [preferred]. The fallback exists solely
/// to answer "what do we show when [preferred] is what you're reading", so a
/// fallback that duplicates [preferred] would leave that question unanswered.
List<QuranEdition> secondaryFallbackOptions(QuranEdition preferred) =>
    secondaryEditionOptions()
        .where((e) => !editionsShareText(e, preferred))
        .toList();

/// Resolves the edition to show in the per-ayah panel, or null for "show no
/// panel at all" (the arrow is then hidden entirely).
///
/// Returns null when the feature is off, and also when neither configured
/// edition can produce something distinct from [primary] — better to hide the
/// affordance than to offer one that opens onto a copy of the ayah above it.
QuranEdition? resolveSecondaryEdition({
  required bool enabled,
  required QuranEdition primary,
  required QuranEdition preferred,
  required QuranEdition fallback,
}) {
  if (!enabled) return null;
  if (!editionsShareText(preferred, primary)) return preferred;
  // preferred is what we're reading — fall back, unless that collides too.
  if (!editionsShareText(fallback, primary)) return fallback;
  return null;
}
