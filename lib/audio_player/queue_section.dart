import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/surah.dart';
import '../widgets/modern_ui.dart';

/// Horizontal chip list of the current playback queue.
///
/// Previously `_buildQueueSection` inside `_AudioPlayerScreenState`;
/// extracted unchanged in behaviour. Callers own the queue mutation logic
/// (`onPlayOrder`, `onRemoveOrder`, `onClearQueue`) so this widget has no
/// direct coupling to `QueueService`.
class AudioPlayerQueueSection extends StatelessWidget {
  const AudioPlayerQueueSection({
    super.key,
    required this.queue,
    required this.currentOrder,
    required this.findSurah,
    required this.color,
    required this.onPlayOrder,
    required this.onRemoveOrder,
    required this.onClearQueue,
  });

  final List<int> queue;
  final int currentOrder;
  final Surah? Function(int order) findSurah;
  final ColorScheme color;
  final ValueChanged<int> onPlayOrder;
  final ValueChanged<int> onRemoveOrder;
  final VoidCallback onClearQueue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ModernSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.queue,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: queue.isEmpty ? null : onClearQueue,
                icon: const Icon(Icons.clear_all, size: 18),
                label: Text(l10n.clearQueue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: queue.map((order) {
              final surah = findSurah(order);
              final isCurrent = order == currentOrder;
              final label = surah != null
                  ? '${surah.order}. ${surah.name}'
                  : '${l10n.surah} $order';
              return InputChip(
                label: Text(label),
                selected: isCurrent,
                onPressed: () => onPlayOrder(order),
                onDeleted: () => onRemoveOrder(order),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Single row in the surah list. Previously `_buildPlaylistTile` in
/// `_AudioPlayerScreenState`; extracted unchanged.
class AudioPlayerPlaylistTile extends StatelessWidget {
  const AudioPlayerPlaylistTile({
    super.key,
    required this.surah,
    required this.currentOrder,
    required this.isFeatured,
    required this.inQueue,
    required this.color,
    required this.isRtl,
    required this.onPlay,
    required this.onToggleQueue,
    required this.onToggleFeature,
  });

  final Surah surah;
  final int currentOrder;
  final bool isFeatured;
  final bool inQueue;
  final ColorScheme color;
  final bool isRtl;
  final VoidCallback onPlay;
  final VoidCallback onToggleQueue;
  final VoidCallback onToggleFeature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCurrent = surah.order == currentOrder;
    final backgroundColor = isCurrent
        ? color.primaryContainer.withAlpha((255 * 0.5).round())
        : color.surface;
    final textAlign = isRtl ? TextAlign.right : TextAlign.left;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ModernSurfaceCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: onPlay,
            title: Text(
              '${surah.order}. ${surah.name}',
              textAlign: textAlign,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: color.onSurface,
              ),
            ),
            subtitle: Text(
              '${surah.totalVerses} ${l10n.verses}',
              textAlign: textAlign,
              style: TextStyle(
                  color: color.onSurface.withAlpha((255 * 0.6).round())),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  icon: Icon(
                    inQueue ? Icons.playlist_remove : Icons.playlist_add,
                  ),
                  tooltip: inQueue ? l10n.clearQueue : l10n.addToQueue,
                  onPressed: onToggleQueue,
                ),
                IconButton(
                  icon: Icon(
                    isFeatured ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade600,
                  ),
                  tooltip:
                      isFeatured ? l10n.removeFeatureSurah : l10n.featureSurah,
                  onPressed: onToggleFeature,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
