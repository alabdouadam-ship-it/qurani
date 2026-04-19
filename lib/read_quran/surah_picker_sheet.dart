import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/quran_constants.dart';
import 'package:qurani/services/quran_repository.dart';

import '../util/text_normalizer.dart';

/// Modal sheet that lists all 114 surahs with a diacritic-insensitive
/// search field. Returns the selected [SurahMeta] when the user taps a
/// row, or null when dismissed.
///
/// Previously the private `_SurahPickerSheet` inside
/// `read_quran_screen.dart`.
class SurahPickerSheet extends StatefulWidget {
  const SurahPickerSheet({super.key, required this.surahs});

  final List<SurahMeta> surahs;

  @override
  State<SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<SurahPickerSheet> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      setState(() {
        _query = TextNormalizer.normalize(_controller.text);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final filtered = _query.isEmpty
        ? widget.surahs
        : widget.surahs.where((s) {
            final normalizedEnglishName =
                TextNormalizer.normalize(s.englishName);
            final normalizedEnglishTranslation =
                TextNormalizer.normalize(s.englishNameTranslation);
            final normalizedArabicName = TextNormalizer.normalize(s.name);
            final numberText = s.number.toString();
            return normalizedEnglishName.contains(_query) ||
                normalizedEnglishTranslation.contains(_query) ||
                normalizedArabicName.contains(_query) ||
                numberText.contains(_query);
          }).toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                l10n.chooseSurah,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final surah = filtered[index];
                    final startPage = surahStartPages[surah.number] ?? 1;
                    return ListTile(
                      title: Text(
                        surah.name,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 18),
                      ),
                      subtitle: Text(
                        '${surah.number}. ${surah.englishName} • ${l10n.page} $startPage',
                      ),
                      onTap: () => Navigator.pop(context, surah),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: filtered.length,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
