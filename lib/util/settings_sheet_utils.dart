import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/audio_service.dart';

class SettingsSheetUtils {
  static Future<void> showReciterSelectionSheet(
    BuildContext context, {
    required Function(String) onReciterSelected,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final currentReciter = PreferencesService.getReciter();
    final langCode = PreferencesService.getLanguage();
    
    // List of available reciters
    final reciters = [
      {'id': 'afs', 'name': AudioService.reciterDisplayName('afs', langCode)},
      {'id': 'basit', 'name': AudioService.reciterDisplayName('basit', langCode)},
      {'id': 'sds', 'name': AudioService.reciterDisplayName('sds', langCode)},
      {'id': 'frs_a', 'name': AudioService.reciterDisplayName('frs_a', langCode)},
      {'id': 'husr', 'name': AudioService.reciterDisplayName('husr', langCode)},
      {'id': 'minsh', 'name': AudioService.reciterDisplayName('minsh', langCode)},
      {'id': 'suwaid', 'name': AudioService.reciterDisplayName('suwaid', langCode)},
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      l10n.chooseReciter,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  StatefulBuilder(
                    builder: (context, setState) {
                      final alwaysStart = PreferencesService.getAlwaysStartFromBeginning();
                      return SwitchListTile(
                        title: Text(l10n.alwaysStartFromBeginning),
                        subtitle: Text(l10n.alwaysStartFromBeginningDesc, style: Theme.of(context).textTheme.bodySmall),
                        value: alwaysStart,
                        onChanged: (value) async {
                          await PreferencesService.saveAlwaysStartFromBeginning(value);
                          setState(() {});
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: reciters.length,
                      itemBuilder: (context, index) {
                        final reciter = reciters[index];
                        final isSelected = reciter['id'] == currentReciter;
                        return ListTile(
                          title: Text(reciter['name'] ?? ''),
                          leading: isSelected
                              ? Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary)
                              : const SizedBox(width: 24),
                          onTap: () {
                            onReciterSelected(reciter['id'] ?? '');
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            });
      },
    );
  }
}
