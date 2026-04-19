import 'package:flutter/material.dart';

/// Reusable empty-state / error-state presentation.
///
/// Shows a centered icon, title, optional description, and zero or more CTAs.
/// Use this instead of bespoke `Column(Icon+Text)` blocks so that error and
/// empty surfaces stay visually consistent across Read Quran, Memorization,
/// Qibla, Hadith, and News.
///
/// Example:
/// ```dart
/// EmptyStateView(
///   icon: Icons.wifi_off,
///   title: l10n.networkErrorTitle,
///   description: l10n.networkErrorBody,
///   primaryAction: EmptyStateAction(
///     label: l10n.retry,
///     icon: Icons.refresh,
///     onPressed: _reload,
///   ),
/// )
/// ```
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.primaryAction,
    this.secondaryAction,
    this.iconColor,
    this.padding = const EdgeInsets.all(24),
  });

  final IconData icon;
  final String title;
  final String? description;
  final EmptyStateAction? primaryAction;
  final EmptyStateAction? secondaryAction;

  /// If null, defaults to `colorScheme.onSurfaceVariant` (neutral).
  /// Pass `colorScheme.error` for destructive/error states.
  final Color? iconColor;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedIconColor = iconColor ?? colorScheme.onSurfaceVariant;

    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: resolvedIconColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (primaryAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: primaryAction!.onPressed,
                icon: Icon(primaryAction!.icon ?? Icons.arrow_forward),
                label: Text(primaryAction!.label),
              ),
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: secondaryAction!.onPressed,
                icon: Icon(secondaryAction!.icon ?? Icons.settings_outlined),
                label: Text(secondaryAction!.label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Describes a single CTA button inside an [EmptyStateView].
class EmptyStateAction {
  const EmptyStateAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}
