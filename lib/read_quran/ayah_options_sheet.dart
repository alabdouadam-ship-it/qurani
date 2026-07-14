import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_repository.dart';

import 'highlight_models.dart';

/// Result of the ayah-options sheet: either a simple [action] (highlight /
/// share / …) OR a specific [viewEdition] to display (a translation or a
/// tafsir book chosen from the grouped sub-menus).
class AyahOptionSelection {
  const AyahOptionSelection.action(AyahAction this.action) : viewEdition = null;
  const AyahOptionSelection.view(QuranEdition this.viewEdition) : action = null;

  final AyahAction? action;
  final QuranEdition? viewEdition;
}

/// Human label for an edition inside the translation/tafsir sub-menus and the
/// text-dialog title. Language names are shown in their own script (clearest
/// for the reader picking a language); tafsir shows its Arabic name.
String editionMenuTitle(QuranEdition e, String appLang) {
  switch (e.id) {
    case 'english':
      return appLang == 'ar' ? 'الإنجليزية' : 'English';
    case 'french':
      return appLang == 'ar' ? 'الفرنسية' : 'Français';
    case 'tr.vakfi':
      return appLang == 'ar' ? 'التركية' : 'Türkçe';
    case 'de.bubenheim':
      return appLang == 'ar' ? 'الألمانية' : 'Deutsch';
    case 'simple':
    case 'uthmani':
    case 'tajweed':
    case 'irab':
      return appLang == 'ar' ? 'العربية' : 'Arabic';
    default:
      // Tafsir (and any other edition): show ONLY the name matching the app
      // language — Arabic name for an Arabic UI, English name otherwise.
      if (appLang == 'ar') return e.nativeName ?? e.displayName;
      return e.englishName ?? e.nativeName ?? e.displayName;
  }
}

/// Short language code badge shown for translation rows (EN / FR / …).
String? _languageBadge(QuranEdition e) {
  final code = e.languageCode;
  if (code == null) return null;
  return code.toUpperCase();
}

/// Modal bottom sheet presenting long-press options for an ayah:
/// highlight/un-highlight, share, and two accordions — Translation (EN/FR/DE/TR)
/// and Tafsir (all tafsir books) — that expand inline.
Future<AyahOptionSelection?> showAyahOptionsSheet(
  BuildContext context, {
  required AyahData ayah,
  required bool isHighlighted,
  required QuranEdition edition,
}) {
  return showModalBottomSheet<AyahOptionSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _AyahOptionsSheet(
      ayah: ayah,
      isHighlighted: isHighlighted,
      edition: edition,
    ),
  );
}

enum _Section { none, translation, tafsir }

class _AyahOptionsSheet extends StatefulWidget {
  const _AyahOptionsSheet({
    required this.ayah,
    required this.isHighlighted,
    required this.edition,
  });

  final AyahData ayah;
  final bool isHighlighted;
  final QuranEdition edition;

  @override
  State<_AyahOptionsSheet> createState() => _AyahOptionsSheetState();
}

class _AyahOptionsSheetState extends State<_AyahOptionsSheet> {
  _Section _expanded = _Section.none;

  void _toggle(_Section s) {
    HapticFeedback.selectionClick();
    setState(() => _expanded = _expanded == s ? _Section.none : s);
  }

  /// Translations offered (excluding the one currently being read). An Arabic
  /// entry is included when the reader is on a non-Arabic edition.
  List<QuranEdition> get _translationOptions {
    final list = <QuranEdition>[];
    if (!widget.edition.isArabicScript) list.add(QuranEditions.simple);
    for (final e in QuranEditions.translations) {
      if (e.id != widget.edition.id) list.add(e);
    }
    return list;
  }

  List<QuranEdition> get _tafsirOptions =>
      QuranEditions.tafsirs.where((e) => e.id != widget.edition.id).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final appLang = Localizations.localeOf(context).languageCode;
    final size = MediaQuery.of(context).size;

    final title = '${widget.ayah.surah.name} • ${widget.ayah.numberInSurah}';

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: size.height * 0.78),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Ayah reference header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Highlight ──────────────────────────────────────────
                    _ActionRow(
                      icon: Icons.brush_rounded,
                      color: cs.primary,
                      label:
                          widget.isHighlighted ? l10n.bookmarks : l10n.addHighlight,
                      onTap: () => Navigator.pop(
                        context,
                        const AyahOptionSelection.action(AyahAction.pickColor),
                      ),
                    ),
                    if (widget.isHighlighted)
                      _ActionRow(
                        icon: Icons.format_color_reset_rounded,
                        color: cs.error,
                        label: l10n.removeHighlight,
                        onTap: () => Navigator.pop(
                          context,
                          const AyahOptionSelection.action(
                              AyahAction.removeHighlight),
                        ),
                      ),
                    // ── Share ──────────────────────────────────────────────
                    _ActionRow(
                      icon: Icons.ios_share_rounded,
                      color: cs.primary,
                      label: l10n.shareAyah,
                      onTap: () => Navigator.pop(
                        context,
                        const AyahOptionSelection.action(AyahAction.share),
                      ),
                    ),

                    // ── Translation accordion ──────────────────────────────
                    if (_translationOptions.isNotEmpty) ...[
                      _ExpanderRow(
                        icon: Icons.translate_rounded,
                        color: cs.primary,
                        label: appLang == 'ar' ? 'الترجمة' : 'Translation',
                        expanded: _expanded == _Section.translation,
                        onTap: () => _toggle(_Section.translation),
                      ),
                      _Expandable(
                        expanded: _expanded == _Section.translation,
                        child: Column(
                          children: _translationOptions
                              .map((e) => _SubOptionRow(
                                    title: editionMenuTitle(e, appLang),
                                    badge: _languageBadge(e),
                                    onTap: () => Navigator.pop(
                                      context,
                                      AyahOptionSelection.view(e),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],

                    // ── Tafsir accordion ───────────────────────────────────
                    if (_tafsirOptions.isNotEmpty) ...[
                      _ExpanderRow(
                        icon: Icons.auto_stories_rounded,
                        color: cs.tertiary,
                        label: l10n.tafsir,
                        expanded: _expanded == _Section.tafsir,
                        onTap: () => _toggle(_Section.tafsir),
                      ),
                      _Expandable(
                        expanded: _expanded == _Section.tafsir,
                        child: Column(
                          children: _tafsirOptions
                              .map((e) => _SubOptionRow(
                                    title: editionMenuTitle(e, appLang),
                                    onTap: () => Navigator.pop(
                                      context,
                                      AyahOptionSelection.view(e),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A primary action row (highlight / share).
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            _IconBubble(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row that expands/collapses a group (Translation / Tafsir).
class _ExpanderRow extends StatelessWidget {
  const _ExpanderRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            _IconBubble(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated container that reveals its [child] when [expanded].
class _Expandable extends StatelessWidget {
  const _Expandable({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedCrossFade(
      firstChild: const SizedBox(width: double.infinity, height: 0),
      secondChild: Container(
        width: double.infinity,
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
      crossFadeState:
          expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 220),
      sizeCurve: Curves.easeOutCubic,
    );
  }
}

/// An indented sub-option (a specific translation / tafsir book).
class _SubOptionRow extends StatelessWidget {
  const _SubOptionRow({
    required this.title,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(30, 11, 20, 11),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsetsDirectional.only(end: 14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(title, style: theme.textTheme.bodyMedium),
            ),
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rounded tinted icon container used by the primary rows.
class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
