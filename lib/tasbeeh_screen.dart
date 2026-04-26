import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/models/tasbeeh_model.dart';
import 'package:qurani/models/wird_model.dart';
import 'package:qurani/services/tasbeeh_service.dart';
import 'package:qurani/services/wird_service.dart';
import 'package:qurani/widgets/wird_tab.dart';
import 'responsive_config.dart';
import 'widgets/modern_ui.dart';

/// Screen layout note: this is a **two-tab** scaffold. The first tab hosts
/// the classic Tasbeeh groups grid; the second tab is the new Daily Wird
/// system.
///
/// The two systems intentionally share one screen (not two sibling routes)
/// because:
///   1. The "Start" button in the Wird tab switches back to the Tasbeeh
///      tab with the Wird in focus-mode — keeping both tabs inside one
///      `TasbeehScreen` makes that switch a trivial `_tabController.index`
///      write rather than a navigator transition with argument passing.
///   2. The mental model "tasbeeh is the counter, wird is the schedule" is
///      unified in one muscle-memory destination for the user.
class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen>
    with TickerProviderStateMixin {
  List<TasbeehGroup> _groups = [];
  bool _isLoading = true;
  final Map<String, int> _sessionCounts = {}; // Key: "${groupId}_${itemId}"

  late final TabController _tabController;

  /// When non-null, the Tasbeeh tab body is replaced by a single-wird
  /// focused counter. This is set by the Wird tab's "Start" button and
  /// cleared by the focus view's "End session" action.
  Wird? _activeWird;

  /// Lightweight handle we pass down to [WirdTab] so we can imperatively
  /// refresh / open-add from this parent without lifting [WirdTab]'s
  /// state up.
  final WirdTabController _wirdTabController = WirdTabController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Rebuild actions/FAB whenever the tab changes so they stay in sync
    // with the currently-visible tab.
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.indexIsChanging || _tabController.index == 1) {
        if (_tabController.index == 1) {
          _wirdTabController.refresh();
        }
      }
      setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tasbeeh tab — existing groups CRUD (behavior unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final groups = await TasbeehService.getGroups();
    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    }
  }

  String _getLocalizedGroupName(TasbeehGroup group, AppLocalizations l10n) {
    if (group.isCustom) return group.name;

    switch (group.name) {
      case 'groupMyAzkar':
        return l10n.groupMyAzkar;
      case 'groupMorning':
        return l10n.groupMorning;
      case 'groupEvening':
        return l10n.groupEvening;
      case 'groupPostPrayerGeneral':
        return l10n.groupPostPrayerGeneral;
      case 'groupPostPrayerFajrMaghrib':
        return l10n.groupPostPrayerFajrMaghrib;
      case 'groupFriday':
        return l10n.groupFriday;
      case 'groupSleep':
        return l10n.groupSleep;
      case 'groupWaking':
        return l10n.groupWaking;
      default:
        return group.name;
    }
  }

  Future<void> _showAddGroupDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    bool confirmed = false;
    String enteredText = '';
    try {
      confirmed = (await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.createNewGroup),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: l10n.enterGroupName,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: Text(l10n.addGroup),
                ),
              ],
            ),
          )) ??
          false;
      enteredText = controller.text.trim();
    } finally {
      controller.dispose();
    }

    if (confirmed && enteredText.isNotEmpty) {
      await TasbeehService.addGroup(enteredText);
      await _loadData();
    }
  }

  Future<void> _deleteGroup(TasbeehGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteGroup),
        content: Text(l10n.deleteGroupConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteGroup),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TasbeehService.removeGroup(group.id);
      await _loadData();
    }
  }

  Future<void> _resetGroup(TasbeehGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetGroup),
        content: Text(l10n.resetGroupConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.resetGroup),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TasbeehService.resetGroupCounts(group.id);
      setState(() {
        for (var item in group.items) {
          _sessionCounts['${group.id}_${item.id}'] = 0;
        }
      });
      await _loadData();
    }
  }

  Future<void> _addItem(TasbeehGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    bool confirmed = false;
    String enteredText = '';
    try {
      confirmed = (await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.addAzkar),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: l10n.enterAzkar,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: Text(l10n.addAzkar),
                ),
              ],
            ),
          )) ??
          false;
      enteredText = controller.text.trim();
    } finally {
      controller.dispose();
    }

    if (confirmed && enteredText.isNotEmpty) {
      await TasbeehService.addItem(group.id, enteredText);
      await _loadData();
    }
  }

  Future<void> _deleteItem(TasbeehGroup group, TasbeehItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteAzkarConfirmation(item.text)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.delete)),
        ],
      ),
    );

    if (confirmed == true) {
      await TasbeehService.removeItem(group.id, item.id);
      await _loadData();
    }
  }

  Future<void> _incrementCount(TasbeehGroup group, TasbeehItem item) async {
    HapticFeedback.lightImpact();

    // Optimistic update
    final sessionKey = '${group.id}_${item.id}';
    setState(() {
      _sessionCounts[sessionKey] = (_sessionCounts[sessionKey] ?? 0) + 1;
      item.count++;
    });

    await TasbeehService.incrementCount(group.id, item.id);
  }

  Future<void> _resetSession(TasbeehGroup group, TasbeehItem item) async {
    final sessionKey = '${group.id}_${item.id}';
    setState(() {
      _sessionCounts[sessionKey] = 0;
    });
  }

  Future<void> _resetAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetAll),
        content: Text(l10n.resetAllConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.resetAll),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await TasbeehService.resetAllCounts();
      setState(() {
        _sessionCounts.clear();
      });
      await _loadData();
    }
  }

  // ---------------------------------------------------------------------------
  // Wird integration
  // ---------------------------------------------------------------------------

  /// Enter "focused counter" mode for the given wird and switch the user
  /// over to the Tasbeeh tab so they can start counting immediately.
  Future<void> _startWird(Wird wird) async {
    setState(() => _activeWird = wird);
    _tabController.animateTo(0);
  }

  /// Exit focus mode. Returns the user to the Wird tab they came from
  /// (not the Tasbeeh tab) so they immediately see the updated progress
  /// or completion badge of the wird they were just counting. Also asks
  /// the Wird tab to refresh from disk — completing a wird may have
  /// changed its progress / badge / scheduling.
  Future<void> _exitWirdFocus() async {
    setState(() => _activeWird = null);
    _tabController.animateTo(1);
    await _wirdTabController.refresh();
  }

  /// Called when the user taps the focused wird's big counter surface.
  /// Increments via [WirdService] (which is the source of truth for
  /// persistence + notification dedup) and surfaces completion on the
  /// final tap.
  Future<void> _incrementActiveWird() async {
    final wird = _activeWird;
    if (wird == null) return;
    if (wird.isCompleted) return; // already done — tap is a no-op

    HapticFeedback.lightImpact();

    // Optimistic local update so the big number ticks without waiting on
    // SharedPreferences. The service's own increment is the write-of-record.
    final next = wird.copyWith(
      currentCount: wird.currentCount + 1,
      lastUpdatedDate: DateTime.now(),
    );
    setState(() => _activeWird = next);

    final justCompleted = await WirdService.increment(wird.id);
    if (!mounted) return;
    if (justCompleted) {
      HapticFeedback.mediumImpact();
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.wirdCompletedToast),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onWirdTab = _tabController.index == 1;
    final inFocus = _activeWird != null;

    // PopScope intercepts the Android system back button. When the user is
    // in focus mode we don't want the back button to pop the whole screen
    // (which would drop them on the app's home) — we want it to exit
    // focus mode and return to the Wird tab, matching the "End session"
    // affordance. When not in focus, canPop=true lets the standard
    // navigator behavior take over.
    return PopScope(
      canPop: !inFocus,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (inFocus) _exitWirdFocus();
      },
      child: ModernPageScaffold(
        title: l10n.tasbeeh,
        icon: Icons.auto_awesome_rounded,
        subtitle: onWirdTab ? l10n.wirdTabSubtitle : l10n.tasbeehDescription,
        // In focus mode we hide the tab bar entirely — the user is in a
        // "do one thing" flow, and the distracting affordances (reset all,
        // add group, switch tabs) would just invite mis-taps on the huge
        // central target.
        appBarBottom: inFocus
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  controller: _tabController,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: [
                    Tab(text: l10n.tasbeehTabLabel),
                    Tab(text: l10n.wirdTabLabel),
                  ],
                ),
              ),
        actions:
            inFocus ? _focusModeActions(l10n) : _tabActions(l10n, onWirdTab),
        body: inFocus
            ? _buildFocusMode(theme, l10n)
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildGroupsView(l10n, theme),
                  WirdTab(
                    controller: _wirdTabController,
                    onStartWird: _startWird,
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _tabActions(AppLocalizations l10n, bool onWirdTab) {
    if (onWirdTab) {
      return [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: l10n.wirdAddTitle,
          onPressed: () => _wirdTabController.openAddSheet(),
        ),
      ];
    }
    return [
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: l10n.resetAll,
        onPressed: _resetAll,
      ),
      IconButton(
        icon: const Icon(Icons.add_rounded),
        tooltip: l10n.createNewGroup,
        onPressed: _showAddGroupDialog,
      ),
    ];
  }

  List<Widget> _focusModeActions(AppLocalizations l10n) {
    return [
      TextButton.icon(
        onPressed: _exitWirdFocus,
        icon: const Icon(Icons.stop_circle_outlined),
        label: Text(l10n.wirdExitFocus),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Tab content builders
  // ---------------------------------------------------------------------------

  Widget _buildGroupsView(AppLocalizations l10n, ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return _buildGroupTile(group, l10n, theme);
      },
    );
  }

  Widget _buildFocusMode(ThemeData theme, AppLocalizations l10n) {
    final wird = _activeWird!;
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: _incrementActiveWird,
      borderRadius: BorderRadius.circular(24),
      // Inkwell default splash is too loud for a meditative flow — keep
      // the highlight but tame the splash.
      splashColor: colorScheme.primary.withAlpha(28),
      highlightColor: colorScheme.primary.withAlpha(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
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
            const Spacer(),
            // The huge count is the center of gravity; progress arc wraps
            // it so the user gets both "how many" and "how close" at a
            // glance.
            _FocusedCounterDial(
              current: wird.currentCount,
              target: wird.targetCount,
              done: wird.isCompleted,
            ),
            const SizedBox(height: 24),
            Text(
              wird.isCompleted
                  ? l10n.wirdCompletedToast
                  : l10n.wirdFocusHintTap,
              style: TextStyle(
                fontSize: ResponsiveConfig.getFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: wird.isCompleted
                    ? colorScheme.primary
                    : colorScheme.onSurface.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(
      TasbeehGroup group, AppLocalizations l10n, ThemeData theme) {
    return ModernSurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: Key(group.id),
          initiallyExpanded: group.name == 'groupMyAzkar',
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            _getLocalizedGroupName(group, l10n),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveConfig.getFontSize(context, 17),
            ),
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              group.isCustom
                  ? Icons.folder_shared_outlined
                  : Icons.folder_special_outlined,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'add') _addItem(group);
              if (value == 'reset') _resetGroup(group);
              if (value == 'delete') _deleteGroup(group);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.addAzkar),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.refresh, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(l10n.resetGroup),
                  ],
                ),
              ),
              if (group.isCustom)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l10n.deleteGroup),
                    ],
                  ),
                ),
            ],
          ),
          children: [
            if (group.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.noAzkarInGroup,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ...group.items.map((item) => _buildAzkarItem(group, item, theme, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildAzkarItem(TasbeehGroup group, TasbeehItem item, ThemeData theme,
      AppLocalizations l10n) {
    final sessionCount = _sessionCounts['${group.id}_${item.id}'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withAlpha(25)),
        ),
        color: theme.colorScheme.surface.withAlpha(128),
      ),
      child: InkWell(
        onTap: () => _incrementCount(group, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildBadge(
                            theme,
                            "${l10n.sessionLabel}: $sessionCount",
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        _buildBadge(
                            theme,
                            "${l10n.totalLabel}: ${item.count}",
                            theme.colorScheme.secondaryContainer,
                            theme.colorScheme.onSecondaryContainer),
                      ],
                    )
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => _resetSession(group, item),
                    tooltip: l10n.resetSessionTooltip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.grey),
                    onPressed: () => _deleteItem(group, item),
                    tooltip: l10n.delete,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(ThemeData theme, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Big circular counter used by the focused-wird mode. Shows
/// `currentCount` in the middle, a ring that fills as progress advances,
/// and a checkmark overlay when the target is hit.
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
        final size = constraints.maxWidth.clamp(0.0, 320.0);
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
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // FittedBox prevents a 3-digit count from clipping the
                    // dial on narrow phones where the base font would
                    // render wider than the ring's inner diameter.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$current',
                        style: TextStyle(
                          fontSize: ResponsiveConfig.getFontSize(context, 64),
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '/ $target',
                      style: TextStyle(
                        fontSize: ResponsiveConfig.getFontSize(context, 18),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
