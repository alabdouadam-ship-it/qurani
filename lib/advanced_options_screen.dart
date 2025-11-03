import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/preferences_service.dart';

class AdvancedOptionsScreen extends StatefulWidget {
  const AdvancedOptionsScreen({super.key});

  @override
  State<AdvancedOptionsScreen> createState() => _AdvancedOptionsScreenState();
}

class _AdvancedOptionsScreenState extends State<AdvancedOptionsScreen> {
  late String _method;
  late String _adhanSound;

  @override
  void initState() {
    super.initState();
    _method = PreferencesService.getPrayerCalcMethod();
    _adhanSound = PreferencesService.getAdhanSound();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerTimesSettings)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.calculationMethod, style: Theme.of(context).textTheme.titleMedium),
          ),
          RadioListTile<String>(
            value: 'mwl',
            groupValue: _method,
            title: Text(l10n.methodMWL),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _method = v);
              await PreferencesService.savePrayerCalcMethod(v);
            },
          ),
          RadioListTile<String>(
            value: 'umm_al_qura',
            groupValue: _method,
            title: Text(l10n.methodUmmAlQura),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _method = v);
              await PreferencesService.savePrayerCalcMethod(v);
            },
          ),
          RadioListTile<String>(
            value: 'egyptian',
            groupValue: _method,
            title: Text(l10n.methodEgyptian),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _method = v);
              await PreferencesService.savePrayerCalcMethod(v);
            },
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.adhanSound, style: Theme.of(context).textTheme.titleMedium),
          ),
          RadioListTile<String>(
            value: 'adhan_1',
            groupValue: _adhanSound,
            title: Text(l10n.adhanSoundOption1),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _adhanSound = v);
              await PreferencesService.saveAdhanSound(v);
            },
          ),
          RadioListTile<String>(
            value: 'adhan_2',
            groupValue: _adhanSound,
            title: Text(l10n.adhanSoundOption2),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _adhanSound = v);
              await PreferencesService.saveAdhanSound(v);
            },
          ),
          RadioListTile<String>(
            value: 'adhan_3',
            groupValue: _adhanSound,
            title: Text(l10n.adhanSoundOption3),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _adhanSound = v);
              await PreferencesService.saveAdhanSound(v);
            },
          ),
        ],
      ),
    );
  }
}


