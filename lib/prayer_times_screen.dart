import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/prayer_times_service.dart';
import 'advanced_options_screen.dart';
import 'package:geolocator/geolocator.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  late Map<String, bool> _adhanEnabled;
  late Map<String, int> _offsetMin;

  final List<String> _prayers = const ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  bool _loading = true;
  bool _needsPermission = false;
  bool _needsService = false;

  @override
  void initState() {
    super.initState();
    _adhanEnabled = {
      for (final id in _prayers) id: PreferencesService.getBool('adhan_$id') ?? false,
    };
    _offsetMin = {
      for (final id in _prayers) id: PreferencesService.getInt('offset_$id') ?? 0,
    };
    // Sunrise should not have adhan toggle enabled
    _adhanEnabled['sunrise'] = false;
    // Load computed times
    // ignore: discarded_futures
    _loadTimes();
  }

  String _localizedName(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      case 'fajr':
        return l10n.fajr;
      case 'sunrise':
        return l10n.sunrise;
      case 'dhuhr':
        return l10n.dhuhr;
      case 'asr':
        return l10n.asr;
      case 'maghrib':
        return l10n.maghrib;
      case 'isha':
        return l10n.isha;
    }
    return id;
  }

  String _formatTimePlaceholder() {
    // Placeholder until calculation method is implemented in later request
    return '—';
  }

  Future<Map<String, DateTime>?> _tryFetchFromApi(double lat, double lng) async {
    // API not working per requirement; return null to force local fallback
    return null;
  }

  PrayerCalcMethod _selectedMethod() {
    final key = PreferencesService.getPrayerCalcMethod();
    switch (key) {
      case 'umm_al_qura':
        return PrayerCalcMethod.ummAlQura;
      case 'egyptian':
        return PrayerCalcMethod.egyptian;
      case 'mwl':
      default:
        return PrayerCalcMethod.mwl;
    }
  }

  Map<String, DateTime>? _todayTimes;

  Future<void> _loadTimes() async {
    setState(() {
      _loading = true;
      _needsPermission = false;
      _needsService = false;
    });
    try {
      // Check location services and permission
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _needsService = true;
          _loading = false;
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _needsPermission = true;
          _loading = false;
        });
        return;
      }

      final pos = await PrayerTimesService.getCurrentPosition();
      final lat = pos.latitude;
      final lng = pos.longitude;
      Map<String, DateTime>? times = await _tryFetchFromApi(lat, lng);
      if (times == null) {
        // fallback to local
        times = await PrayerTimesService.computeTodayTimes(
          latitude: lat,
          longitude: lng,
          method: _selectedMethod(),
        );
      }
      if (!mounted) return;
      setState(() {
        _todayTimes = times;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleAdhan(BuildContext context, String id, bool value) async {
    setState(() {
      _adhanEnabled[id] = value;
    });
    await PreferencesService.setBool('adhan_$id', value);
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? l10n.adhanEnabledMsg : l10n.adhanDisabledMsg)),
    );
  }

  Future<void> _adjust(String id, int delta) async {
    final next = (_offsetMin[id] ?? 0) + delta;
    setState(() {
      _offsetMin[id] = next;
    });
    await PreferencesService.setInt('offset_$id', next);
  }

  void _openAdjustSheet(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.adjustTime, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(onPressed: () => _adjust(id, -10), child: Text(l10n.minus10Min)),
                    OutlinedButton(onPressed: () => _adjust(id, -1), child: Text(l10n.minus1Min)),
                    OutlinedButton(onPressed: () => _adjust(id, 1), child: Text(l10n.plus1Min)),
                    OutlinedButton(onPressed: () => _adjust(id, 10), child: Text(l10n.plus10Min)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${_offsetMin[id] ?? 0} min'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prayerTimes),
        actions: [
          IconButton(
            tooltip: l10n.advancedOptions,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdvancedOptionsScreen(),
                ),
              ).then((_) {
                // Reload times in case method changed
                _loadTimes();
              });
            },
          )
        ],
      ),
      body: _buildBody(context, theme, l10n),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsService || _needsPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                _needsService ? l10n.qiblaLocationDisabled : l10n.qiblaPermissionRequired,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (_needsPermission)
                ElevatedButton.icon(
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                    if (!mounted) return;
                    _loadTimes();
                  },
                  icon: const Icon(Icons.app_settings_alt),
                  label: Text(l10n.qiblaOpenAppSettings),
                ),
              if (_needsService)
                const SizedBox(height: 8),
              if (_needsService)
                ElevatedButton.icon(
                  onPressed: () async {
                    await Geolocator.openLocationSettings();
                    if (!mounted) return;
                    _loadTimes();
                  },
                  icon: const Icon(Icons.gps_fixed),
                  label: Text(l10n.qiblaOpenLocationSettings),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadTimes,
                child: Text(l10n.qiblaRetry),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _prayers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final id = _prayers[index];
          final title = _localizedName(context, id);
          final dt = _todayTimes?[id];
          final offset = _offsetMin[id] ?? 0;
          final DateTime? dtAdj = dt != null ? dt.add(Duration(minutes: offset)) : null;
          final timeStr = dtAdj != null ? TimeOfDay.fromDateTime(dtAdj).format(context) : _formatTimePlaceholder();
          final offsetLabel = offset == 0 ? '' : ' (${offset > 0 ? '+' : ''}${offset}m)';
          final enabled = _adhanEnabled[id] ?? false;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                foregroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.access_time),
              ),
              title: Text(title),
              subtitle: Text('$timeStr$offsetLabel'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.adjustTime,
                    icon: const Icon(Icons.tune),
                    onPressed: () => _openAdjustSheet(context, id),
                  ),
                  if (id != 'sunrise')
                    Switch(
                      value: enabled,
                      onChanged: (v) => _toggleAdhan(context, id, v),
                    ),
                ],
              ),
            ),
          );
        },
      );
  }
}


