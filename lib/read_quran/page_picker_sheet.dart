import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';

/// Shows a modal bottom sheet with a numeric text field and a
/// CupertinoPicker for choosing a Quran page in the range
/// `[1, totalPages]`. Resolves to the selected page (or `null` on cancel).
///
/// Previously the private `_openPagePicker` in `read_quran_screen.dart`.
Future<int?> showPagePickerSheet(
  BuildContext context, {
  required int currentPage,
  required int totalPages,
}) async {
  if (totalPages < 1) return null;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PagePicker(
        currentPage: currentPage.clamp(1, totalPages), totalPages: totalPages),
  );
}

class _PagePicker extends StatefulWidget {
  const _PagePicker({required this.currentPage, required this.totalPages});
  final int currentPage;
  final int totalPages;

  @override
  State<_PagePicker> createState() => _PagePickerState();
}

class _PagePickerState extends State<_PagePicker> {
  late int tempIndex = widget.currentPage - 1;
  late final textController =
      TextEditingController(text: widget.currentPage.toString());
  late final pickerController =
      FixedExtentScrollController(initialItem: tempIndex);

  @override
  void dispose() {
    textController.dispose();
    pickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalPages = widget.totalPages;
    return SafeArea(
      child: SizedBox(
        height: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.goToPage,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
                decoration: InputDecoration(
                  labelText: l10n.pageNumber,
                  hintText: '1-$totalPages',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                onChanged: (value) {
                  final page = int.tryParse(value);
                  if (page != null && page >= 1 && page <= totalPages) {
                    tempIndex = page - 1;
                  }
                },
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 1),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: pickerController,
                onSelectedItemChanged: (value) {
                  tempIndex = value;
                  textController.text = (value + 1).toString();
                },
                children: List.generate(
                  totalPages,
                  (i) => Center(
                    child: Text(
                      '${i + 1}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final page = int.tryParse(textController.text);
                      if (page != null && page >= 1 && page <= totalPages) {
                        Navigator.pop<int>(context, page);
                      } else {
                        Navigator.pop<int>(context, tempIndex + 1);
                      }
                    },
                    child: Text(l10n.go),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
