import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/repetition_passage.dart';
import '../models/surah.dart';

class RepetitionPassageEditor extends StatefulWidget {
  const RepetitionPassageEditor(
      {super.key,
      required this.surahs,
      required this.passage,
      required this.remember,
      required this.onApply, this.showRemember = true});
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
  Widget _boundFields({
    required bool start,
    required RepetitionPassage passage,
    required ValueChanged<VerseRef> onChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final ref = start ? passage.start : passage.end;
    final minVerse =
        !start && ref.surah == passage.start.surah ? passage.start.verse : 1;
    final total =
        widget.surahs.firstWhere((s) => s.order == ref.surah).totalVerses;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText:
                      start ? l10n.passageStartSurah : l10n.passageEndSurah),
              child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                isExpanded: true,
                value: ref.surah,
                items: [
                  for (final s in widget.surahs)
                    if (start || s.order >= passage.start.surah)
                      DropdownMenuItem(
                          value: s.order,
                          child: Text('${s.order}. ${s.name}',
                              overflow: TextOverflow.ellipsis))
                ],
                onChanged: (order) {
                  if (order == null) return;
                  final count = widget.surahs
                      .firstWhere((s) => s.order == order)
                      .totalVerses;
                  final min = !start && order == passage.start.surah
                      ? passage.start.verse
                      : 1;
                  onChanged((surah: order, verse: ref.verse.clamp(min, count)));
                },
              )),
            )),
        const SizedBox(width: 12),
        Expanded(
            flex: 2,
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText:
                      start ? l10n.passageStartVerse : l10n.passageEndVerse),
              child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                isExpanded: true,
                value: ref.verse,
                items: [
                  for (int n = minVerse; n <= total; n++)
                    DropdownMenuItem(value: n, child: Text('$n'))
                ],
                onChanged: (n) {
                  if (n != null) onChanged((surah: ref.surah, verse: n));
                },
              )),
            )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(children: [
      _boundFields(
          start: true,
          passage: draft,
          onChanged: (ref) => setState(() => draft = draft.withStart(ref))),
      _boundFields(
          start: false,
          passage: draft,
          onChanged: (ref) =>
              setState(() => draft = (start: draft.start, end: ref))),
      if (widget.showRemember) CheckboxListTile(
        title: Text(l10n.rememberPassage),
        subtitle: Text(l10n.rememberPassageHint),
        value: remember,
        onChanged: (value) => setState(() => remember = value ?? true),
      ),
      FilledButton(
        onPressed: () => widget.onApply(draft, remember),
        child: Text(l10n.applyPassage),
      ),
    ]);
  }
}
