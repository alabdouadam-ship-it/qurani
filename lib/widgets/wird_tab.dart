import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/models/wird_model.dart';
import 'package:qurani/responsive_config.dart';
import 'package:qurani/services/wird_service.dart';
import 'package:qurani/widgets/modern_ui.dart';
import 'package:qurani/widgets/wird_edit_sheet.dart';

/// Which subset of wirds the [WirdTab] is currently showing. Drives the
/// Today / All segmented toggle at the top of the list, and determines
/// whether cards render with the "Start" action (Today, a do-dhikr view)
/// or with the schedule pills (All, a manage-your-list view).
enum _WirdFilter { today, all }

/// The "الورد" (Wird) tab content.
///
/// Renders today's active wirds as a scrollable list with progress, a Start
/// button, and a popup menu for edit/reset/delete. Also owns the floating
/// "+ Add" affordance (rendered by the parent scaffold; this widget exposes
/// [openAddSheet] via the [controller] so the parent can trigger it).
///
/// Keeps no state of its own beyond the fetched list + loading flag — all
/// mutations go through [WirdService] which persists + reschedules
/// notifications atomically.
class WirdTab extends StatefulWidget {
  const WirdTab({
    super.key,
    required this.onStartWird,
    this.controller,
  });

  /// Called when the user taps "Start" on a wird. The parent
  /// [TasbeehScreen] uses this to switch to the Tasbeeh tab and bind the
  /// counter to the selected wird.
  final void Function(Wird wird) onStartWird;

  /// Optional handle the parent uses to pop the "add wird" sheet from an
  /// AppBar / FAB action.
  final WirdTabController? controller;

  @override
  State<WirdTab> createState() => _WirdTabState();
}

/// Lightweight handle so the parent scaffold can trigger the add sheet
/// without having to own all the loading state of [WirdTab].
class WirdTabController {
  _WirdTabState? _state;
  void _attach(_WirdTabState state) => _state = state;
  void _detach(_WirdTabState state) {
    if (_state == state) _state = null;
  }

  /// Opens the add-wird sheet; no-op if the tab is not currently mounted.
  Future<void> openAddSheet() async {
    await _state?._openAddSheet();
  }

  /// Forces a reload from disk — useful if the wird list was mutated from
  /// outside this tab (e.g. the focused counter in the Tasbeeh tab).
  Future<void> refresh() async {
    await _state?._reload();
  }
}

class _WirdTabState extends State<WirdTab> {
  /// Wirds scheduled for today. Fed to the "Today" filter view.
  List<Wird> _todaysWirds = const [];

  /// Every non-deleted wird the user owns — used by the "All" filter
  /// view and to decide whether the filter toggle is worth rendering at
  /// all (if every wird is also in today's list, the toggle would be a
  /// no-op, so we hide it).
  List<Wird> _allWirds = const [];

  /// Current filter mode. Intentionally not persisted: the "Today"
  /// default is the right first-load experience every session — the tab
  /// should feel oriented around what the user needs to do *now*, with
  /// the management view a one-tap detour away.
  _WirdFilter _filter = _WirdFilter.today;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _reload();
  }

  @override
  void didUpdateWidget(covariant WirdTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _isLoading = true);
    // One `getActive()` call feeds both views. `getActive()` internally
    // calls `getAll()` which runs the daily-reset pass, so every time
    // the user returns to this tab after midnight we pick up fresh
    // zeros without any extra wiring.
    final active = await WirdService.getActive();
    final today = DateTime.now();
    final todays = active.where((w) => w.isActiveOn(today)).toList();
    if (!mounted) return;
    setState(() {
      _todaysWirds = todays;
      _allWirds = active;
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openAddSheet() async {
    final created = await showWirdEditSheet(context);
    if (created == null) return;
    await WirdService.add(created);
    await _reload();
  }

  Future<void> _openEditSheet(Wird wird) async {
    final edited = await showWirdEditSheet(context, existing: wird);
    if (edited == null) return;
    await WirdService.update(edited);
    await _reload();
  }

  Future<void> _confirmDelete(Wird wird) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(wird.title),
        content: Text(l10n.wirdDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await WirdService.delete(wird.id);
    await _reload();
  }

  Future<void> _resetProgress(Wird wird) async {
    await WirdService.resetProgress(wird.id);
    await _reload();
  }

  /// Swap between Today / All filter. Cheap — no network, no disk — just
  /// re-renders the list from the already-loaded `_allWirds` cache.
  void _setFilter(_WirdFilter f) {
    if (_filter == f) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = f);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isAllMode = _filter == _WirdFilter.all;
    // Only expose the toggle when it actually changes anything — if every
    // wird is today-active, both modes render the same set of cards and
    // the toggle would just be visual noise. The filter stays available
    // programmatically either way.
    final hasOtherDayWirds = _allWirds.length > _todaysWirds.length;
    final list = isAllMode ? _allWirds : _todaysWirds;

    return Column(
      children: [
        if (hasOtherDayWirds)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _FilterBar(
              filter: _filter,
              todayCount: _todaysWirds.length,
              totalCount: _allWirds.length,
              onChanged: _setFilter,
            ),
          ),
        Expanded(
          child: list.isEmpty
              ? _EmptyState(
                  onAdd: _openAddSheet,
                  mode: _filter,
                  hasOtherDayWirds: hasOtherDayWirds,
                  onSwitchToAll: () => _setFilter(_WirdFilter.all),
                )
              : _buildList(isAllMode: isAllMode, list: list),
        ),
      ],
    );
  }

  Widget _buildList({required bool isAllMode, required List<Wird> list}) {
    final l10n = AppLocalizations.of(context)!;
    // Today mode: sink completed wirds to the bottom so incomplete ones
    // stay prominent — that matches the "what's left to do today?"
    // intent of the tab. All mode: keep creation order. Completion is a
    // today-only signal, and re-sorting by it across a list that spans
    // multiple weekdays would feel arbitrary (why is last Friday's done
    // wird below Monday's untouched one?).
    final sorted = [...list]
      ..sort((a, b) {
        if (!isAllMode && a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: sorted.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Row(
                children: [
                  Icon(
                    isAllMode
                        ? Icons.list_alt_rounded
                        : Icons.auto_awesome_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAllMode
                        ? l10n.wirdAllScreenTitle
                        : l10n.wirdSectionTitle,
                    style: TextStyle(
                      fontSize: ResponsiveConfig.getFontSize(context, 15),
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }
          final wird = sorted[i - 1];
          if (isAllMode) {
            return _AllWirdCard(
              key: ValueKey(wird.id),
              wird: wird,
              onEdit: () => _openEditSheet(wird),
              onReset: () => _resetProgress(wird),
              onDelete: () => _confirmDelete(wird),
            );
          }
          return _WirdCard(
            key: ValueKey(wird.id),
            wird: wird,
            onStart: () => widget.onStartWird(wird),
            onEdit: () => _openEditSheet(wird),
            onDelete: () => _confirmDelete(wird),
            onResetProgress: () => _resetProgress(wird),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar — segmented Today / All toggle shown above the list.
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.todayCount,
    required this.totalCount,
    required this.onChanged,
  });
  final _WirdFilter filter;
  final int todayCount;
  final int totalCount;
  final ValueChanged<_WirdFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // A single-selection SegmentedButton is the M3 idiom for
    // "pick exactly one of these views". The counts in each segment
    // ('Today (3)', 'All (5)') give the user a preview of what they'll
    // see before tapping — useful when they've forgotten how many
    // non-today wirds they have.
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_WirdFilter>(
        segments: [
          ButtonSegment(
            value: _WirdFilter.today,
            icon: const Icon(Icons.today_rounded),
            label: Text('${l10n.wirdFilterToday} ($todayCount)'),
          ),
          ButtonSegment(
            value: _WirdFilter.all,
            icon: const Icon(Icons.list_alt_rounded),
            label: Text('${l10n.wirdFilterAll} ($totalCount)'),
          ),
        ],
        selected: {filter},
        onSelectionChanged: (set) => onChanged(set.first),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card widget
// ---------------------------------------------------------------------------

class _WirdCard extends StatelessWidget {
  const _WirdCard({
    super.key,
    required this.wird,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
    required this.onResetProgress,
  });

  final Wird wird;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onResetProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final done = wird.isCompleted;

    return ModernSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      // Dim completed wirds so the eye naturally lands on the remaining
      // work. We don't hide them — that would lose the sense of "I finished
      // today's istighfar".
      child: Opacity(
        opacity: done ? 0.78 : 1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LeadingBadge(done: done, colorScheme: colorScheme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wird.title,
                          style: TextStyle(
                            fontSize:
                                ResponsiveConfig.getFontSize(context, 16),
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (wird.dhikrText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            wird.dhikrText,
                            style: TextStyle(
                              fontSize:
                                  ResponsiveConfig.getFontSize(context, 13),
                              color: colorScheme.onSurface.withAlpha(160),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            // Dhikr is Arabic; force RTL even on EN/FR UI.
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _MenuButton(
                    onEdit: onEdit,
                    onReset: onResetProgress,
                    onDelete: onDelete,
                    hasProgress: wird.currentCount > 0,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProgressRow(wird: wird),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (wird.notificationsEnabled)
                    _ReminderPill(time: wird.notificationTime),
                  const Spacer(),
                  done
                      ? _DonePill(label: l10n.wirdCompletedBadge)
                      : FilledButton.icon(
                          onPressed: onStart,
                          icon: Icon(
                            wird.currentCount > 0
                                ? Icons.play_arrow_rounded
                                : Icons.play_circle_fill_rounded,
                          ),
                          label: Text(
                            wird.currentCount > 0
                                ? l10n.wirdResume
                                : l10n.wirdStart,
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadingBadge extends StatelessWidget {
  const _LeadingBadge({required this.done, required this.colorScheme});
  final bool done;
  final ColorScheme colorScheme;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: done
              ? [
                  colorScheme.secondary,
                  colorScheme.secondary.withAlpha(140),
                ]
              : [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        done
            ? Icons.check_rounded
            : Icons.auto_stories_outlined,
        color: colorScheme.onPrimary,
        size: 22,
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.wird});
  final Wird wird;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.wirdProgressFraction(wird.currentCount, wird.targetCount),
              style: TextStyle(
                fontSize: ResponsiveConfig.getFontSize(context, 13),
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withAlpha(210),
              ),
            ),
            const Spacer(),
            Text(
              '${(wird.progressRatio * 100).round()}%',
              style: TextStyle(
                fontSize: ResponsiveConfig.getFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: wird.progressRatio,
            minHeight: 8,
            // Soft indicator — no harsh red on incomplete, no celebratory
            // green on done. Calm UI is a spec requirement.
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withAlpha(120),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary.withAlpha(210),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderPill extends StatelessWidget {
  const _ReminderPill({required this.time});
  final TimeOfDay time;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(90),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            time.format(context),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonePill extends StatelessWidget {
  const _DonePill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.onEdit,
    required this.onReset,
    required this.onDelete,
    required this.hasProgress,
  });
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final VoidCallback onDelete;
  final bool hasProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (value) {
        HapticFeedback.selectionClick();
        switch (value) {
          case 'edit':
            onEdit();
            break;
          case 'reset':
            onReset();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 20),
              const SizedBox(width: 10),
              Text(l10n.wirdEditTitle),
            ],
          ),
        ),
        if (hasProgress)
          PopupMenuItem(
            value: 'reset',
            child: Row(
              children: [
                const Icon(Icons.refresh_rounded, size: 20),
                const SizedBox(width: 10),
                Text(l10n.wirdResetProgress),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 20, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 10),
              Text(l10n.delete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAdd,
    required this.mode,
    required this.hasOtherDayWirds,
    required this.onSwitchToAll,
  });
  final VoidCallback onAdd;
  final _WirdFilter mode;
  /// True when the user has wirds scheduled for non-today weekdays. Only
  /// meaningful in Today mode — surfaces a "switch to All" shortcut so
  /// the user doesn't think their Friday wird evaporated.
  final bool hasOtherDayWirds;
  final VoidCallback onSwitchToAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isAllMode = mode == _WirdFilter.all;
    // All-mode empty means "no wirds anywhere". Today-mode empty means
    // "no wirds today" — with a softer copy + the hint text about
    // editing days.
    final title = isAllMode ? l10n.wirdAllEmptyTitle : l10n.wirdTodayEmptyTitle;
    final icon = isAllMode ? Icons.list_alt_rounded : Icons.wb_twilight_rounded;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.primary.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveConfig.getFontSize(context, 17),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!isAllMode) ...[
              const SizedBox(height: 8),
              Text(
                l10n.wirdTodayEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ResponsiveConfig.getFontSize(context, 13),
                  color: theme.colorScheme.onSurface.withAlpha(160),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.wirdAddTitle),
            ),
            if (!isAllMode && hasOtherDayWirds) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onSwitchToAll,
                icon: const Icon(Icons.list_alt_rounded),
                label: Text(l10n.wirdFilterAll),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All-mode card — no Start button, no progress bar. Shows the wird's
// schedule (days-of-week + reminder) and target so the user can manage
// cross-week wirds at a glance.
// ---------------------------------------------------------------------------

class _AllWirdCard extends StatelessWidget {
  const _AllWirdCard({
    super.key,
    required this.wird,
    required this.onEdit,
    required this.onReset,
    required this.onDelete,
  });

  final Wird wird;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ModernSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LeadingBadge(done: false, colorScheme: colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wird.title,
                        style: TextStyle(
                          fontSize:
                              ResponsiveConfig.getFontSize(context, 16),
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (wird.dhikrText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          wird.dhikrText,
                          style: TextStyle(
                            fontSize:
                                ResponsiveConfig.getFontSize(context, 13),
                            color: colorScheme.onSurface.withAlpha(160),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ],
                  ),
                ),
                _MenuButton(
                  onEdit: onEdit,
                  onReset: onReset,
                  onDelete: onDelete,
                  hasProgress: wird.currentCount > 0,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DaysRow(daysOfWeek: wird.daysOfWeek, l10n: l10n),
            const SizedBox(height: 8),
            Row(
              children: [
                _TargetPill(target: wird.targetCount),
                if (wird.notificationsEnabled) ...[
                  const SizedBox(width: 8),
                  _ReminderPill(time: wird.notificationTime),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pills used by the All-mode card
// ---------------------------------------------------------------------------

class _DaysRow extends StatelessWidget {
  const _DaysRow({required this.daysOfWeek, required this.l10n});
  final List<int> daysOfWeek;
  final AppLocalizations l10n;

  /// Arabic week starts Saturday, matching the Hijri convention used
  /// by the edit-sheet day picker. Other locales follow ISO Mon-Sun.
  static const List<int> _orderAr = [6, 7, 1, 2, 3, 4, 5];
  static const List<int> _orderIso = [1, 2, 3, 4, 5, 6, 7];

  @override
  Widget build(BuildContext context) {
    // Collapse a full 7-day schedule to a single "Every day" pill —
    // otherwise the default istighfar wird renders a wall of 7 chips
    // which drowns out the rest of the card.
    if (daysOfWeek.length == 7) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [_DayPill(label: l10n.wirdAllDays, emphasized: true)],
      );
    }
    final locale = Localizations.localeOf(context).languageCode;
    final order = locale == 'ar' ? _orderAr : _orderIso;
    final ordered = [for (final d in order) if (daysOfWeek.contains(d)) d];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in ordered) _DayPill(label: _fullDayLabel(l10n, d)),
      ],
    );
  }

  String _fullDayLabel(AppLocalizations l10n, int w) {
    switch (w) {
      case 1:
        return l10n.dayMonday;
      case 2:
        return l10n.dayTuesday;
      case 3:
        return l10n.dayWednesday;
      case 4:
        return l10n.dayThursday;
      case 5:
        return l10n.dayFriday;
      case 6:
        return l10n.daySaturday;
      case 7:
        return l10n.daySunday;
      default:
        return '';
    }
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.label, this.emphasized = false});
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = emphasized
        ? theme.colorScheme.primaryContainer.withAlpha(180)
        : theme.colorScheme.primaryContainer.withAlpha(110);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _TargetPill extends StatelessWidget {
  const _TargetPill({required this.target});
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(110),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 14,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 4),
          // Force LTR so the number reads left-to-right in every locale
          // (same reasoning as the focused counter dial).
          Text(
            '$target',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
