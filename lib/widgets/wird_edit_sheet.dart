import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/models/wird_model.dart';
import 'package:qurani/responsive_config.dart';
import 'package:qurani/services/notification_service.dart';

/// Bottom-sheet form used for both creating and editing a [Wird].
///
/// Returns the edited [Wird] on save (never mutates the input — the caller
/// decides whether to persist it) or `null` if the user cancels.
///
/// Pass [existing] to pre-fill the form in "edit" mode; leave it `null` for
/// the "add" mode.
Future<Wird?> showWirdEditSheet(
  BuildContext context, {
  Wird? existing,
}) {
  return showModalBottomSheet<Wird>(
    context: context,
    isScrollControlled: true, // lets the keyboard push the sheet up
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _WirdEditSheet(existing: existing),
  );
}

class _WirdEditSheet extends StatefulWidget {
  const _WirdEditSheet({this.existing});
  final Wird? existing;

  @override
  State<_WirdEditSheet> createState() => _WirdEditSheetState();
}

class _WirdEditSheetState extends State<_WirdEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _dhikrController;
  late int _targetCount;
  late Set<int> _selectedDays; // DateTime.weekday values, 1=Mon..7=Sun
  late bool _notificationsEnabled;
  late TimeOfDay _notificationTime;

  /// `true` when the user hit Save with validation errors — drives the
  /// red underlines on the fields that failed. Cleared on any input.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _titleController = TextEditingController(text: w?.title ?? '');
    _dhikrController = TextEditingController(text: w?.dhikrText ?? '');
    _targetCount = w?.targetCount ?? 33;
    _selectedDays =
        Set<int>.from(w?.daysOfWeek ?? const <int>[1, 2, 3, 4, 5, 6, 7]);
    _notificationsEnabled = w?.notificationsEnabled ?? false;
    _notificationTime =
        w?.notificationTime ?? const TimeOfDay(hour: 14, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dhikrController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _toggleDay(int weekday) {
    setState(() {
      if (_selectedDays.contains(weekday)) {
        _selectedDays.remove(weekday);
      } else {
        _selectedDays.add(weekday);
      }
    });
  }

  void _selectAllDays() {
    setState(() {
      if (_selectedDays.length == 7) {
        // Second tap on "every day" -> clear so the user can pick a subset
        _selectedDays.clear();
      } else {
        _selectedDays = {1, 2, 3, 4, 5, 6, 7};
      }
    });
  }

  /// Fires an immediate test notification on the wird channel. Purely
  /// diagnostic — does not persist anything or touch the wird being
  /// edited.
  ///
  /// The SnackBar text branches on [WirdTestResult] so the user learns
  /// what to fix:
  ///   * [WirdTestResult.ok] → "sent; if you don't see it, check
  ///     system settings".
  ///   * [WirdTestResult.notificationPermissionDenied] → explicit
  ///     "notifications aren't allowed — grant permission".
  ///   * [WirdTestResult.unknownError] → generic "couldn't send".
  Future<void> _sendTestNotification() async {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context)!;
    // Prefer the values the user has typed so the test looks like their
    // real reminder. Fall back to localized placeholders for a blank form.
    final title = _titleController.text.trim().isEmpty
        ? l10n.wirdSectionTitle
        : _titleController.text.trim();
    // Body can legitimately be empty — the test's purpose is to verify
    // delivery, not to preview the full reminder. An empty body just
    // shows a title-only notification, which is the standard Android
    // rendering and still proves the channel works.
    final body = _dhikrController.text.trim();
    final result = await NotificationService.sendWirdTestNotification(
      title: title,
      body: body,
    );
    if (!mounted) return;
    final String message;
    switch (result) {
      case WirdTestResult.ok:
        message = l10n.wirdTestSent;
        break;
      case WirdTestResult.notificationPermissionDenied:
        message = l10n.wirdTestPermissionDenied;
        break;
      case WirdTestResult.unknownError:
        message = l10n.wirdTestFailed;
        break;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handles the reminder `Switch` being flipped.
  ///
  /// ### Why this isn't just `setState(() => _notificationsEnabled = v)`
  ///
  /// Flipping the switch to ON is the user saying "I want this wird to
  /// remind me". If `POST_NOTIFICATIONS` is denied (or `SCHEDULE_EXACT_ALARM`
  /// hasn't been granted on Android 13+), the saved wird's reminders would
  /// silently never fire — producing the exact "I scheduled it but got
  /// nothing" bug the user reported.
  ///
  /// So instead, turning ON triggers a permission prompt. If the user
  /// declines, the switch snaps back to OFF and a SnackBar explains why.
  /// Turning OFF is always allowed — no prompt, no state change guard.
  Future<void> _onReminderToggled(bool value) async {
    if (!value) {
      setState(() => _notificationsEnabled = false);
      return;
    }
    final granted = await NotificationService.ensureWirdNotificationPermissions();
    if (!mounted) return;
    if (!granted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.wirdTestPermissionDenied),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _notificationsEnabled = true);

    // Separately probe SCHEDULE_EXACT_ALARM. Without it the plugin falls
    // back to `setAndAllowWhileIdle`, which Doze batches into
    // maintenance windows — reminders can drift by 15+ minutes on a
    // stationary phone. Rather than let that surprise the user, flag it
    // explicitly here so they can choose to grant the permission in
    // system settings (the `ensureWirdNotificationPermissions` call
    // above has already redirected them once; this SnackBar reminds
    // them it stuck or not).
    final exactOk = await NotificationService.canScheduleExactWirdReminders();
    if (!mounted) return;
    if (exactOk == false) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.wirdExactAlarmDenied),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      // Force 24-hour on Arabic to match the rest of the app's time display.
      builder: (ctx, child) {
        final locale = Localizations.localeOf(ctx).languageCode;
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
            alwaysUse24HourFormat: locale == 'ar',
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() => _notificationTime = picked);
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    final dhikr = _dhikrController.text.trim();
    final hasErrors = title.isEmpty ||
        _selectedDays.isEmpty ||
        _targetCount < 1 ||
        _targetCount > 9999;
    if (hasErrors) {
      setState(() => _showErrors = true);
      HapticFeedback.vibrate();
      return;
    }

    final Wird result;
    final days = _selectedDays.toList()..sort();
    if (widget.existing == null) {
      result = Wird.create(
        title: title,
        dhikrText: dhikr,
        targetCount: _targetCount,
        daysOfWeek: days,
        notificationsEnabled: _notificationsEnabled,
        notificationTime: _notificationTime,
      );
    } else {
      result = widget.existing!.copyWith(
        title: title,
        dhikrText: dhikr,
        targetCount: _targetCount,
        daysOfWeek: days,
        notificationsEnabled: _notificationsEnabled,
        notificationTime: _notificationTime,
      );
    }
    Navigator.of(context).pop(result);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    // `useSafeArea: true` on showModalBottomSheet does NOT apply to the
    // bottom edge (Flutter docs are explicit about this). So the Android
    // gesture/navigation bar overlaps the bottom of the sheet and clips
    // the Save button. We pad the ListView's bottom ourselves with the
    // device's system-nav inset.
    final bottomSystemPad = mediaQuery.padding.bottom;
    final isEditing = widget.existing != null;

    return Padding(
      // Only the viewInsets (keyboard) push the sheet up; the scroll view
      // below handles the system-nav padding in its own content padding.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              _DragHandle(color: colorScheme.outline.withAlpha(96)),
              _Header(
                title: isEditing ? l10n.wirdEditTitle : l10n.wirdAddTitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  // +16 extra breathing room above the very bottom so the
                  // Save button isn't flush with the nav bar edge.
                  padding: EdgeInsets.fromLTRB(
                      20, 8, 20, 20 + bottomSystemPad + 16),
                  children: [
                    _FieldLabel(l10n.wirdFieldTitle),
                    TextField(
                      controller: _titleController,
                      onChanged: (_) {
                        if (_showErrors) setState(() => _showErrors = false);
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText:
                            _showErrors && _titleController.text.trim().isEmpty
                                ? l10n.wirdValidationTitleRequired
                                : null,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel(l10n.wirdFieldDhikrText),
                    TextField(
                      controller: _dhikrController,
                      maxLines: 3,
                      minLines: 1,
                      // Dhikr is almost always Arabic — force RTL regardless
                      // of UI locale so users on English/French UIs still
                      // see Arabic glyphs rendered correctly.
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FieldLabel(l10n.wirdFieldTargetCount),
                    _TargetCountStepper(
                      value: _targetCount,
                      onChanged: (v) => setState(() => _targetCount = v),
                      error: _showErrors &&
                          (_targetCount < 1 || _targetCount > 9999),
                      errorText: l10n.wirdValidationTargetInvalid,
                    ),
                    const SizedBox(height: 20),
                    _FieldLabel(l10n.wirdFieldDaysOfWeek),
                    _DaysPicker(
                      selected: _selectedDays,
                      onToggle: _toggleDay,
                      onSelectAll: _selectAllDays,
                      errorText: _showErrors && _selectedDays.isEmpty
                          ? l10n.wirdValidationDaysRequired
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _ReminderSection(
                      enabled: _notificationsEnabled,
                      time: _notificationTime,
                      onToggle: _onReminderToggled,
                      onPickTime: _pickTime,
                      onSendTest: _sendTestNotification,
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        isEditing
                            ? MaterialLocalizations.of(context).okButtonLabel
                            : l10n.wirdAddTitle,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small layout helpers — private to this file; not worth exporting.
// ---------------------------------------------------------------------------

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveConfig.getFontSize(context, 18),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonLabel,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: ResponsiveConfig.getFontSize(context, 13),
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
        ),
      ),
    );
  }
}

class _TargetCountStepper extends StatefulWidget {
  const _TargetCountStepper({
    required this.value,
    required this.onChanged,
    required this.error,
    required this.errorText,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final bool error;
  final String errorText;

  /// Reasonable target presets users reach for most often.
  static const List<int> _presets = [33, 100, 1000];

  /// Valid range for the target count. Kept here (not hard-coded in both
  /// the formatter and the validator) so they can't drift apart.
  static const int _minValue = 1;
  static const int _maxValue = 9999;

  @override
  State<_TargetCountStepper> createState() => _TargetCountStepperState();
}

class _TargetCountStepperState extends State<_TargetCountStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _TargetCountStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync the TextField when the external value changes (user tapped +/-
    // or a preset chip). We skip the sync while focused so in-progress
    // typing isn't overwritten by the same value we just emitted via
    // onChanged — which would reset the cursor to the start.
    if (!_focusNode.hasFocus &&
        widget.value.toString() != _controller.text) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// On focus loss, recover from empty / zero input by restoring the last
  /// committed value. This is a softer UX than showing a validation error
  /// mid-edit — the user can clear the field, think, and still get a sane
  /// value back if they just tap away.
  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < _TargetCountStepper._minValue) {
      _controller.text = widget.value.toString();
    }
  }

  /// Called on every keystroke. Non-numeric input is already filtered by
  /// the input formatter; here we just parse + clamp + propagate.
  /// Intermediate "0" or empty values are silently ignored (the last
  /// valid value stays committed) and corrected on focus loss.
  void _onTextChanged(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < _TargetCountStepper._minValue) return;
    final clamped = parsed > _TargetCountStepper._maxValue
        ? _TargetCountStepper._maxValue
        : parsed;
    if (clamped != widget.value) {
      widget.onChanged(clamped);
    }
  }

  void _bump(int delta) {
    final next = (widget.value + delta)
        .clamp(_TargetCountStepper._minValue, _TargetCountStepper._maxValue);
    widget.onChanged(next);
    // If the field isn't focused the didUpdateWidget sync will refresh
    // the controller; if it IS focused the user is typing and we should
    // still reflect the bump so keyboard + buttons stay consistent.
    _controller.text = next.toString();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: widget.value > _TargetCountStepper._minValue
                  ? () => _bump(-1)
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(60),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.error
                          ? theme.colorScheme.error
                          : theme.colorScheme.outline.withAlpha(40),
                    ),
                  ),
                  // TextField inherits the container's border/background
                  // and renders with its own chrome disabled.
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                      signed: false,
                    ),
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _focusNode.unfocus(),
                    style: TextStyle(
                      fontSize: ResponsiveConfig.getFontSize(context, 20),
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      // Hide the counter that would otherwise appear below
                      // the field because we set maxLength.
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: widget.value < _TargetCountStepper._maxValue
                  ? () => _bump(1)
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final p in _TargetCountStepper._presets)
              ChoiceChip(
                label: Text('$p'),
                selected: widget.value == p,
                onSelected: (_) => _bump(p - widget.value),
              ),
          ],
        ),
        if (widget.error)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.errorText,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _DaysPicker extends StatelessWidget {
  const _DaysPicker({
    required this.selected,
    required this.onToggle,
    required this.onSelectAll,
    required this.errorText,
  });
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final VoidCallback onSelectAll;
  final String? errorText;

  /// Weekday chip order: for Arabic locales we start on Saturday, matching
  /// the Hijri week; otherwise we start on Monday (Dart / ISO default).
  /// Values are DateTime.weekday — the rendering order differs, the stored
  /// integers do not.
  static const List<int> _orderFriSat = [6, 7, 1, 2, 3, 4, 5];
  static const List<int> _orderMonSun = [1, 2, 3, 4, 5, 6, 7];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final order = locale == 'ar' ? _orderFriSat : _orderMonSun;
    final allSelected = selected.length == 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The "every day" action is on its own row above the chips. This
        // way, full-name labels like "Wednesday" / "الأربعاء" have the
        // full sheet width to wrap across, and the action button itself
        // gets a proper accessible tap target instead of competing for
        // space beside the chips.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              onSelectAll();
            },
            icon: Icon(
              allSelected
                  ? Icons.select_all_rounded
                  : Icons.done_all_rounded,
              size: 18,
            ),
            label: Text(l10n.wirdAllDays),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in order)
              FilterChip(
                label: Text(_fullWeekdayLabel(l10n, d)),
                selected: selected.contains(d),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onToggle(d);
                },
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// Full localized weekday name for a `DateTime.weekday` value (1..7).
  /// Uses our own ARB keys (not `MaterialLocalizations.narrowWeekdays`)
  /// because narrow Arabic labels like س / ح / ج are ambiguous — several
  /// Arabic weekday names share the same first letter — and users could
  /// not tell e.g. الجمعة apart from الخميس.
  String _fullWeekdayLabel(AppLocalizations l10n, int weekday) {
    switch (weekday) {
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

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
    required this.onSendTest,
  });
  final bool enabled;
  final TimeOfDay time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;
  /// Fires a diagnostic notification in 5 seconds so the user can verify
  /// notifications actually reach them before trusting the scheduled time.
  final VoidCallback onSendTest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(30),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.wirdRemindMe),
            value: enabled,
            onChanged: onToggle,
            secondary: Icon(
              Icons.notifications_active_outlined,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          // AnimatedSize keeps the layout smooth when the time row appears
          // so the whole sheet doesn't jump when toggling the switch.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: enabled
                ? ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(l10n.wirdReminderTime),
                    trailing: FilledButton.tonal(
                      onPressed: onPickTime,
                      child: Text(time.format(context)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Diagnostic test row — DEBUG-ONLY. In production the user
          // relies on the permission prompt triggered by flipping the
          // reminder toggle; they don't need a dedicated "fire a test"
          // affordance (and exposing it clutters the form). In debug it
          // remains available so developers/QA can verify the
          // notification channel, permission state, and immediate
          // delivery without scheduling a real reminder.
          if (kDebugMode)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 4, end: 4),
                child: TextButton.icon(
                  onPressed: onSendTest,
                  icon: const Icon(Icons.notifications_active_outlined,
                      size: 16),
                  label: Text(l10n.wirdSendTest),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        theme.colorScheme.onSurface.withAlpha(170),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
