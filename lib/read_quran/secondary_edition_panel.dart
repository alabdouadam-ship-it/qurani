import 'package:flutter/material.dart';

/// The per-ayah secondary-edition affordance: a rotating arrow plus the panel
/// it opens.
///
/// Deliberately stateless — the reader owns which ayahs are expanded and the
/// fetched text, because expansion state has to survive tile rebuilds (a tile
/// rebuilds on selection, playback highlight and every animation tick) and has
/// to be cleared on page and edition changes.
///
/// Each ayah's panel is independent: opening one does not close another. The
/// only way to close a panel is to re-tap its own arrow.
class SecondaryEditionPanel extends StatelessWidget {
  const SecondaryEditionPanel({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.editionLabel,
    required this.textDirection,
    required this.loading,
    required this.spans,
    required this.unavailableLabel,
    required this.expandTooltip,
    required this.collapseTooltip,
    required this.animationDuration,
  });

  final bool expanded;
  final VoidCallback onToggle;

  /// Localized name of the resolved secondary edition, shown as the panel's
  /// header so the reader knows which book they are looking at.
  final String editionLabel;

  /// Direction of the *secondary* text, which is independent of the primary's:
  /// reading English with an Arabic tafsir secondary means an LTR ayah above an
  /// RTL panel.
  final TextDirection textDirection;

  final bool loading;

  /// Parsed spans for the secondary text, or null when the fetch produced
  /// nothing for this ayah (some tafsir books have gaps).
  final List<InlineSpan>? spans;

  final String unavailableLabel;
  final String expandTooltip;
  final String collapseTooltip;

  /// Zero while page audio is playing, so the reader's scroll-to-playing-ayah
  /// never measures a mid-animation height. See `_toggleSecondary`.
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The arrow sits on the trailing edge, which the ancestor
        // Directionality already resolves: left for RTL, right for LTR.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Tooltip(
            message: expanded ? collapseTooltip : expandTooltip,
            child: InkWell(
              // Its own InkWell so the tap never reaches the tile's onTap,
              // which would select the ayah and seek the audio player.
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: AnimatedRotation(
                  // Half turn: chevron points down when closed, up when open.
                  turns: expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: animationDuration,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? _buildBody(context, theme, cs)
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, ColorScheme cs) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest
            .withAlpha(theme.brightness == Brightness.dark ? 90 : 130),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editionLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          // Explicit Directionality: the secondary text's direction comes from
          // the secondary edition, not from the ayah above it.
          Directionality(
            textDirection: textDirection,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : spans == null
                    ? Text(
                        unavailableLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withAlpha(150),
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : RichText(
                        textDirection: textDirection,
                        textAlign: textDirection == TextDirection.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        text: TextSpan(children: spans),
                      ),
          ),
        ],
      ),
    );
  }
}
