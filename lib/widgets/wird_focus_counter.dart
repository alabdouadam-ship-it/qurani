import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/wird_model.dart';
import '../responsive_config.dart';

class WirdFocusCounter extends StatelessWidget {
  const WirdFocusCounter({super.key, required this.wird, required this.onTap});

  final Wird wird;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final heading = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        wird.title,
        style: TextStyle(
          fontSize: ResponsiveConfig.getFontSize(context, 18),
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        textAlign: TextAlign.center,
      ),
      if (wird.dhikrText.isNotEmpty) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            wird.dhikrText,
            style: TextStyle(
              fontSize: ResponsiveConfig.getFontSize(context, 22),
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ),
      ],
    ]);
    final hint = Text(
      wird.isCompleted ? l10n.wirdCompletedToast : l10n.wirdFocusHintTap,
      style: TextStyle(
        fontSize: ResponsiveConfig.getFontSize(context, 13),
        fontWeight: FontWeight.w600,
        color: wird.isCompleted
            ? colorScheme.primary
            : colorScheme.onSurface.withAlpha(150),
      ),
      textAlign: TextAlign.center,
    );
    final dial = _FocusedCounterDial(
        current: wird.currentCount,
        target: wird.targetCount,
        done: wird.isCompleted);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: colorScheme.primary.withAlpha(28),
      highlightColor: colorScheme.primary.withAlpha(12),
      child: LayoutBuilder(builder: (context, bounds) {
        if (bounds.maxWidth > bounds.maxHeight && bounds.maxWidth >= 420) {
          return Row(children: [
            Expanded(
                child: Center(
                    child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                heading,
                const SizedBox(height: 16),
                hint,
              ]),
            ))),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Center(child: dial))),
          ]);
        }
        return Center(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            heading,
            const SizedBox(height: 24),
            dial,
            const SizedBox(height: 24),
            hint,
          ]),
        ));
      }),
    );
  }
}

class _FocusedCounterDial extends StatelessWidget {
  const _FocusedCounterDial({
    required this.current,
    required this.target,
    required this.done,
  });

  final int current;
  final int target;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Grow the dial with available space but cap it so it stays
        // readable on large tablets.
        final size = constraints.biggest.shortestSide.clamp(0.0, 320.0);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  // AlwaysStoppedAnimation because we drive progress
                  // manually per tap — we don't want an implicit tween
                  // that stutters behind fast taps.
                  valueColor: AlwaysStoppedAnimation<Color>(
                    done
                        ? colorScheme.secondary
                        : colorScheme.primary.withAlpha(220),
                  ),
                  backgroundColor:
                      colorScheme.surfaceContainerHighest.withAlpha(140),
                ),
              ),
              // Force LTR on the numeric stack: "45 / 100" is a ratio, not
              // a sentence, so its reading direction should be locale-
              // independent. Without this the slash and target flip in
              // Arabic and render as "100 /" which reads awkwardly.
              Padding(
                padding: EdgeInsets.all(size * 0.12),
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$current',
                            style: TextStyle(
                              fontSize:
                                  ResponsiveConfig.getFontSize(context, 64),
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '/ $target',
                            style: TextStyle(
                              fontSize:
                                  ResponsiveConfig.getFontSize(context, 18),
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                          if (done) ...[
                            const SizedBox(height: 10),
                            Icon(
                              Icons.check_circle_rounded,
                              color: colorScheme.secondary,
                              size: 30,
                            ),
                          ],
                        ],
                      ),
                    )),
              ),
            ],
          ),
        );
      },
    );
  }
}
