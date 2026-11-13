import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/repetition_passage.dart';
import '../models/surah.dart';
import '../util/text_normalizer.dart';

enum _SurahPickerMode { list, buttons }

String _cleanSurahName(String raw) =>
    raw.replaceFirst(RegExp(r'^(سُورَةُ|سورة)\s+'), '');

class RepetitionPassageEditor extends StatefulWidget {
  const RepetitionPassageEditor({
    super.key,
    required this.surahs,
    required this.passage,
    required this.remember,
    required this.onApply,
    this.showRemember = true,
  });

  final List<Surah> surahs;
  final RepetitionPassage passage;
  final bool remember;
  final bool showRemember;
  final void Function(RepetitionPassage, bool) onApply;

  @override
  State<RepetitionPassageEditor> createState() =>
      _RepetitionPassageEditorState();
}

class _RepetitionPassageEditorState extends State<RepetitionPassageEditor> {
  late RepetitionPassage draft = widget.passage;
  late bool remember = widget.remember;

  void _applySurahSelection({
    required bool start,
    required int order,
    required RepetitionPassage passage,
    required ValueChanged<VerseRef> onChanged,
  }) {
    final ref = start ? passage.start : passage.end;
    final count =
        widget.surahs.firstWhere((s) => s.order == order).totalVerses;
    final min =
        !start && order == passage.start.surah ? passage.start.verse : 1;
    onChanged((surah: order, verse: ref.verse.clamp(min, count)));
  }

  Future<void> _openSurahPicker({
    required bool start,
    required RepetitionPassage passage,
    required ValueChanged<VerseRef> onChanged,
    _SurahPickerMode initialMode = _SurahPickerMode.list,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final ref = start ? passage.start : passage.end;
    final availableSurahs = [
      for (final s in widget.surahs)
        if (start || s.order >= passage.start.surah) s,
    ];
    final selectedOrder = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _SurahSearchPickerSheet(
        title: start ? l10n.passageStartSurah : l10n.passageEndSurah,
        surahs: availableSurahs,
        selectedOrder: ref.surah,
        initialMode: initialMode,
      ),
    );
    if (!mounted || selectedOrder == null) return;
    _applySurahSelection(
      start: start,
      order: selectedOrder,
      passage: passage,
      onChanged: onChanged,
    );
  }

  Widget _boundFields({
    required bool start,
    required RepetitionPassage passage,
    required ValueChanged<VerseRef> onChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ref = start ? passage.start : passage.end;
    final minVerse =
        !start && ref.surah == passage.start.surah ? passage.start.verse : 1;
    final total =
        widget.surahs.firstWhere((s) => s.order == ref.surah).totalVerses;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText:
                    start ? l10n.passageStartSurah : l10n.passageEndSurah,
                labelStyle: labelStyle,
                floatingLabelStyle: labelStyle,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  value: ref.surah,
                  style: valueStyle,
                  icon: InkWell(
                    onTap: () => _openSurahPicker(
                      start: start,
                      passage: passage,
                      onChanged: onChanged,
                    ),
                    child: const Padding(
                      padding: EdgeInsetsDirectional.only(start: 4),
                      child: Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                  selectedItemBuilder: (context) => [
                    for (final s in widget.surahs)
                      if (start || s.order >= passage.start.surah)
                        InkWell(
                          key: ValueKey(
                            start
                                ? 'start_surah_searchable_dropdown_${s.order}'
                                : 'end_surah_searchable_dropdown_${s.order}',
                          ),
                          onTap: () => _openSurahPicker(
                            start: start,
                            passage: passage,
                            onChanged: onChanged,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '${s.order}. ${s.name}',
                              style: valueStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  ],
                  items: [
                    for (final s in widget.surahs)
                      if (start || s.order >= passage.start.surah)
                        DropdownMenuItem(
                          value: s.order,
                          child: Text(
                            '${s.order}. ${s.name}',
                            style: valueStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (order) {
                    if (order == null) return;
                    _applySurahSelection(
                      start: start,
                      order: order,
                      passage: passage,
                      onChanged: onChanged,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText:
                    start ? l10n.passageStartVerse : l10n.passageEndVerse,
                labelStyle: labelStyle,
                floatingLabelStyle: labelStyle,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  value: ref.verse,
                  style: valueStyle,
                  items: [
                    for (int n = minVerse; n <= total; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text('$n', style: valueStyle),
                      ),
                  ],
                  onChanged: (n) {
                    if (n != null) onChanged((surah: ref.surah, verse: n));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      children: [
        _boundFields(
          start: true,
          passage: draft,
          onChanged: (ref) => setState(() => draft = draft.withStart(ref)),
        ),
        const SizedBox(height: 12),
        _boundFields(
          start: false,
          passage: draft,
          onChanged: (ref) =>
              setState(() => draft = (start: draft.start, end: ref)),
        ),
        const SizedBox(height: 6),
        if (widget.showRemember)
          CheckboxListTile(
            title: Text(
              l10n.rememberPassage,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              l10n.rememberPassageHint,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
            ),
            value: remember,
            onChanged: (value) => setState(() => remember = value ?? true),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () => widget.onApply(draft, remember),
          child: Text(l10n.applyPassage),
        ),
      ],
    );
  }
}

class _SurahSearchPickerSheet extends StatefulWidget {
  const _SurahSearchPickerSheet({
    required this.title,
    required this.surahs,
    required this.selectedOrder,
    required this.initialMode,
  });

  final String title;
  final List<Surah> surahs;
  final int selectedOrder;
  final _SurahPickerMode initialMode;

  @override
  State<_SurahSearchPickerSheet> createState() =>
      _SurahSearchPickerSheetState();
}

class _SurahSearchPickerSheetState extends State<_SurahSearchPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late _SurahPickerMode _mode = widget.initialMode;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Surah> _filteredSurahs() {
    final trimmed = _query.trim();
    if (trimmed.isEmpty) return widget.surahs;
    final normalizedQuery = TextNormalizer.normalize(trimmed);
    return widget.surahs.where((s) {
      if (s.order.toString().contains(trimmed)) return true;
      final normalizedName = TextNormalizer.normalize(s.name);
      final normalizedClean =
          TextNormalizer.normalize(_cleanSurahName(s.name));
      return normalizedName.contains(normalizedQuery) ||
          normalizedClean.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredSurahs();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900
        ? 4
        : width >= 600
            ? 3
            : 2;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Fixed Header with Back button + Title + List/Buttons toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Material(
                    color: colorScheme.surfaceContainerHighest.withAlpha(160),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: const ValueKey('surah_picker_back_button'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('surah_picker_mode_toggle'),
                    icon: Icon(
                      _mode == _SurahPickerMode.list
                          ? Icons.grid_view_rounded
                          : Icons.view_list_rounded,
                      size: 24,
                      color: colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _mode = _mode == _SurahPickerMode.list
                            ? _SurahPickerMode.buttons
                            : _SurahPickerMode.list;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Fixed Search Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                key: const ValueKey('surah_picker_search_field'),
                controller: _searchController,
                style: const TextStyle(fontSize: 17),
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.searchSurah,
                  hintStyle: const TextStyle(fontSize: 16),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Scrollable Results (Dropdown List Mode or Surah Buttons Mode)
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noResultsFound,
                        style: const TextStyle(fontSize: 17),
                      ),
                    )
                  : _mode == _SurahPickerMode.list
                      ? ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final surah = filtered[index];
                            final isSelected =
                                surah.order == widget.selectedOrder;
                            return ListTile(
                              key: ValueKey('surah_list_item_${surah.order}'),
                              selected: isSelected,
                              selectedTileColor: colorScheme.primaryContainer
                                  .withAlpha(90),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.primary.withAlpha(28),
                                foregroundColor: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                                child: Text(
                                  '${surah.order}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                surah.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 18,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${surah.totalVerses} ${l10n.verses}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                              onTap: () =>
                                  Navigator.of(context).pop(surah.order),
                            );
                          },
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.4,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final surah = filtered[index];
                            final isSelected =
                                surah.order == widget.selectedOrder;
                            return Material(
                              color: isSelected
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest
                                      .withAlpha(110),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                key: ValueKey(
                                    'surah_button_item_${surah.order}'),
                                borderRadius: BorderRadius.circular(14),
                                onTap: () =>
                                    Navigator.of(context).pop(surah.order),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.outlineVariant
                                              .withAlpha(120),
                                      width: isSelected ? 1.6 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.primary.withAlpha(28),
                                        foregroundColor: isSelected
                                            ? colorScheme.onPrimary
                                            : colorScheme.primary,
                                        child: Text(
                                          '${surah.order}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _cleanSurahName(surah.name),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? colorScheme
                                                        .onPrimaryContainer
                                                    : colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              '${surah.totalVerses} ${l10n.verses}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                fontSize: 13,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
