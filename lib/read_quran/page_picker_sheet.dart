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
  final l10n = AppLocalizations.of(context)!;
  final initialIndex = currentPage - 1;
  final textController = TextEditingController(text: currentPage.toString());

  final selected = await showModalBottomSheet<int>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      int tempIndex = initialIndex;
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
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: TextField(
                  controller: textController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                  decoration: InputDecoration(
                    labelText: l10n.pageNumber,
                    hintText: '1-$totalPages',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
              SizedBox(
                height: 200,
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController:
                      FixedExtentScrollController(initialItem: initialIndex),
                  onSelectedItemChanged: (value) {
                    tempIndex = value;
                    textController.text = (value + 1).toString();
                  },
                  children: List.generate(
                    totalPages,
                    (i) => Center(
                      child: Text(
                        '${i + 1}',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        final page = int.tryParse(textController.text);
                        if (page != null &&
                            page >= 1 &&
                            page <= totalPages) {
                          Navigator.pop<int>(sheetContext, page);
                        } else {
                          Navigator.pop<int>(sheetContext, tempIndex + 1);
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
    },
  );

  textController.dispose();
  return selected;
}
