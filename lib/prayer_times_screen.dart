import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';
import 'month_prayer_times_screen.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/prayer_times_service.dart';
import 'services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  late Map<String, bool> _adhanEnabled;
  // API-only cache navigation state
  late DateTime _currentDate;
  String? _hijriDay;
  String? _hijriMonth;
  String? _hijriYear;
  late TapGestureRecognizer _hijriMonthTap;
  late TapGestureRecognizer _gregorianMonthTap;

  List<String> _prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  bool _loading = true;
  bool _needsPermission = false;
  bool _needsService = false;
  bool _needsInternet = false;
  bool _isRamadan = false;

  @override
  void initState() {
    super.initState();
    _hijriMonthTap = TapGestureRecognizer()..onTap = _onHijriMonthTap;
    _gregorianMonthTap = TapGestureRecognizer()..onTap = _onGregorianMonthTap;
    _adhanEnabled = {
      for (final id in _prayers) id: PreferencesService.getBool('adhan_$id') ?? false,
    };
    // Sunrise should not have adhan toggle enabled
    _adhanEnabled['sunrise'] = false;
    // Load computed times
    // ignore: discarded_futures
    _currentDate = DateTime.now();
    _initialLoad();
  }

  @override
  void dispose() {
    _hijriMonthTap.dispose();
    _gregorianMonthTap.dispose();
    _previewPlayer.dispose();
    _adhanPlayer.dispose();
    super.dispose();
  }

  String _localizedName(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      case 'fajr':
        return l10n.fajr;
      case 'imsak':
        return l10n.imsak;
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

  String _formatTimePlaceholder() => '—';

  Map<String, DateTime>? _todayTimes;
  String? _nextPrayerId;
  Duration? _countdown;
  Timer? _tick;
  final AudioPlayer _previewPlayer = AudioPlayer();
  final AudioPlayer _adhanPlayer = AudioPlayer();
  String? _previewKey;

  Future<void> _initialLoad() async {
    // Ensure we have cached months or fetch using GPS+Internet
    await _loadTimes(fetchIfMissing: true);
  }

  Future<void> _loadTimes({bool fetchIfMissing = false}) async {
    setState(() {
      _loading = true;
      _needsPermission = false;
      _needsService = false;
      _needsInternet = false;
    });
    try {
      // Ensure cache for prev, current, next months
      final currMonth = DateTime(_currentDate.year, _currentDate.month, 1);
      final prevMonth = DateTime(_currentDate.year, _currentDate.month - 1, 1);
      final nextMonth = DateTime(_currentDate.year, _currentDate.month + 1, 1);

      Future<void> fetchAll(Position pos) async {
        final method = await PrayerTimesService.resolveMethodForRegionFromPosition(pos);
        await PrayerTimesService.fetchAndCacheMonth(year: prevMonth.year, month: prevMonth.month, latitude: pos.latitude, longitude: pos.longitude, method: method);
        await PrayerTimesService.fetchAndCacheMonth(year: currMonth.year, month: currMonth.month, latitude: pos.latitude, longitude: pos.longitude, method: method);
        await PrayerTimesService.fetchAndCacheMonth(year: nextMonth.year, month: nextMonth.month, latitude: pos.latitude, longitude: pos.longitude, method: method);
        await PrayerTimesService.cleanupKeepPrevCurrentNext(_currentDate);
      }

      bool haveCurr = await PrayerTimesService.hasMonth(currMonth.year, currMonth.month);
      bool haveNext = await PrayerTimesService.hasMonth(nextMonth.year, nextMonth.month);
      bool havePrev = await PrayerTimesService.hasMonth(prevMonth.year, prevMonth.month);

      if (fetchIfMissing && (!havePrev || !haveCurr || !haveNext)) {
        // Need to fetch; require internet + GPS
        final hasNet = await _hasInternet();
        if (!hasNet) {
          if (!mounted) return;
          setState(() {
            _needsInternet = true;
            _loading = false;
          });
          return;
        }
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
        await fetchAll(pos);
      }

      final times = await PrayerTimesService.getTimesForDate(
        year: _currentDate.year,
        month: _currentDate.month,
        day: _currentDate.day,
      );
      final hijri = await PrayerTimesService.getHijriForDate(
        year: _currentDate.year,
        month: _currentDate.month,
        day: _currentDate.day,
      );
      // If no cached data for this day, try fetching prev/current/next months now
      if ((times == null || hijri == null) && !fetchIfMissing) {
        final hasNet = await _hasInternet();
        if (!hasNet) {
          if (!mounted) return;
          setState(() {
            _needsInternet = true;
            _loading = false;
          });
          return;
        }
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
        await fetchAll(pos);
        // Reload from cache after fetching
        await _loadTimes(fetchIfMissing: false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _todayTimes = times;
        if (hijri == null) {
          _hijriDay = null;
          _hijriMonth = null;
          _hijriYear = null;
          _isRamadan = false;
          final hasImsak = times != null && times.containsKey('imsak');
          _prayers = hasImsak
              ? ['fajr','imsak','sunrise','dhuhr','asr','maghrib','isha']
              : ['fajr','sunrise','dhuhr','asr','maghrib','isha'];
        } else {
          final lang = PreferencesService.getLanguage();
          _hijriDay = hijri['day'] as String?;
          _hijriMonth = (lang == 'ar' ? hijri['monthAr'] : hijri['monthEn']) as String?;
          _hijriYear = hijri['year'] as String?;
          final monthAr = hijri['monthAr'] as String?;
          final monthEn = hijri['monthEn'] as String?;
          _isRamadan = (monthEn?.toLowerCase().contains('ramadan') ?? false) || (monthAr?.contains('رمضان') ?? false);
          final hasImsak = times != null && times.containsKey('imsak');
          final showImsak = _isRamadan || hasImsak;
          _prayers = showImsak
              ? ['fajr','imsak','sunrise','dhuhr','asr','maghrib','isha']
              : ['fajr','sunrise','dhuhr','asr','maghrib','isha'];
        }
        _loading = false;
      });
      // Schedule remaining adhans for today (even if app closes later)
      if (times != null) {
        final soundKey = PreferencesService.getAdhanSound();
        await NotificationService.scheduleRemainingAdhans(
          times: times,
          soundKey: soundKey,
          toggles: _adhanEnabled,
        );
      }
      _computeNextAndSchedule();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _computeNextAndSchedule() {
    _tick?.cancel();
    if (_todayTimes == null) return;
    final now = DateTime.now();
    final order = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
    String? nextId;
    DateTime? nextTime;
    for (final id in order) {
      final base = _todayTimes![id];
      if (base == null) continue;
      final dt = base;
      if (dt.isAfter(now)) {
        nextId = id;
        nextTime = dt;
        break;
      }
    }
    if (nextId == null) {
      // Next day not handled here; keep as null
      setState(() {
        _nextPrayerId = null;
        _countdown = null;
      });
      return;
    }
    setState(() {
      _nextPrayerId = nextId;
      _countdown = nextTime!.difference(now);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _nextPrayerId == null || nextTime == null) return;
      final remain = nextTime!.difference(DateTime.now());
      if (remain.isNegative) {
        _tick?.cancel();
        if (_nextPrayerId != null && _nextPrayerId != 'sunrise') {
          final enabled = _adhanEnabled[_nextPrayerId!] ?? false;
          if (enabled) {
            // ignore: discarded_futures
            _playAdhanForPrayer(_nextPrayerId!);
          }
        }
        _loadTimes();
      } else {
        setState(() => _countdown = remain);
      }
    });
    // Schedule silent alert 5 minutes before next prayer (no alert for sunrise)
    if (nextId != 'sunrise') {
      final alertTime = nextTime!.subtract(const Duration(minutes: 5));
      if (alertTime.isAfter(DateTime.now())) {
        NotificationService.scheduleSilentAlert(
          id: _alertIdFor(nextId),
          triggerTimeLocal: alertTime,
          title: _localizedName(context, nextId),
          body: '5 minutes remaining',
        );
      }
    }
    if (nextId != 'sunrise' && (_adhanEnabled[nextId] ?? false)) {
      final soundKey = PreferencesService.getAdhanSound();
      final isFajr = nextId == 'fajr';
      NotificationService.scheduleAdhanNotification(
        id: _alertIdFor(nextId) + 1000,
        triggerTimeLocal: nextTime!,
        title: _localizedName(context, nextId),
        body: '',
        soundKey: soundKey,
        isFajr: isFajr,
      );
    }
  }

  int _alertIdFor(String id) {
    switch (id) {
      case 'fajr':
        return 101;
      case 'sunrise':
        return 102;
      case 'dhuhr':
        return 103;
      case 'asr':
        return 104;
      case 'maghrib':
        return 105;
      case 'isha':
        return 106;
    }
    return 100;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prayerTimes),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings),
            onPressed: _openAdhanSettings,
          ),
        ],
      ),
      body: _buildBody(context, theme, l10n),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsInternet || _needsService || _needsPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                _needsInternet
                    ? l10n.prayerInternetGpsRequired
                    : _needsService
                        ? l10n.qiblaLocationDisabled
                        : l10n.qiblaPermissionRequired,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (_needsInternet)
                TextButton(
                  onPressed: _loadTimes,
                  child: Text(l10n.qiblaRetry),
                ),
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 36),
        itemCount: _prayers.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final localeName = Localizations.localeOf(context).toString();
            final weekday = DateFormat.EEEE(localeName).format(_currentDate);
            final gDay = DateFormat('dd', localeName).format(_currentDate);
            final gMonth = DateFormat.MMMM(localeName).format(_currentDate);
            final gYear = DateFormat('yyyy', localeName).format(_currentDate);
            final primary = theme.colorScheme.primary.withOpacity(0.85);
            final onSurface = theme.colorScheme.onSurface;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: l10n.previousLabel,
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _canGoPrev() ? _goPrevDay : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: _onRefreshPressed,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.refresh),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: l10n.nextLabel,
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _canGoNext() ? _goNextDay : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.titleMedium?.copyWith(color: onSurface),
                    children: [
                      if (_hijriDay != null && _hijriMonth != null && _hijriYear != null) ...[
                        TextSpan(text: _toWesternDigits(_hijriDay!)),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: _hijriMonth!,
                          style: TextStyle(color: primary),
                          recognizer: _hijriMonthTap,
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: _toWesternDigits(_hijriYear!)),
                      ],
                      const TextSpan(text: '  -  '),
                      TextSpan(text: weekday),
                      const TextSpan(text: '  -  '),
                      TextSpan(text: _toWesternDigits(gDay)),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: gMonth,
                        style: TextStyle(color: primary),
                        recognizer: _gregorianMonthTap,
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(text: _toWesternDigits(gYear)),
                    ],
                  ),
                ),
              ],
            );
          }
          if (index == _prayers.length + 1) {
            // Footer spacer
            return const SizedBox(height: 8);
          }
          final idx = index - 1;
          final id = _prayers[idx];
          final title = _localizedName(context, id);
          final dt = _todayTimes?[id];
          final DateTime? dtAdj = dt;
          final enabled = _adhanEnabled[id] ?? false;
          final bool isNext = id == _nextPrayerId;
          final bool isPast = dtAdj != null && dtAdj.isBefore(DateTime.now());
          final borderSide = isNext ? BorderSide(color: theme.colorScheme.primary.withOpacity(0.6), width: 1.2) : BorderSide.none;
          return Opacity(
            opacity: isPast && !isNext ? 0.55 : 1.0,
            child: Card(
              elevation: isNext ? 4 : 2,
              color: isNext ? Colors.amber.withOpacity(0.15) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: borderSide),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isNext ? Colors.amber.withOpacity(0.3) : theme.colorScheme.primary.withOpacity(0.12),
                  foregroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.access_time),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: isNext ? const TextStyle(fontWeight: FontWeight.bold) : null),
                    if (isNext && _countdown != null)
                      Text(_formatDuration(_countdown!), style: TextStyle(color: theme.colorScheme.primary)),
                  ],
                ),
                subtitle: Text(_formatClock(dtAdj)),
                trailing: Semantics(
                  label: '${AppLocalizations.of(context)!.adhanSound}: $title',
                  button: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (id != 'sunrise' && id != 'imsak')
                        Switch.adaptive(
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          value: enabled,
                          onChanged: (v) => _toggleAdhan(context, id, v),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return _toWesternDigits('${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}');
    }
    return _toWesternDigits('${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}');
  }

  String _formatClock(DateTime? dt) {
    if (dt == null) return _formatTimePlaceholder();
    final pattern = PreferencesService.getTimeFormat12h() ? 'h:mm a' : 'HH:mm';
    String s = DateFormat(pattern, Localizations.localeOf(context).toString()).format(dt);
    return _toWesternDigits(s);
  }

  String _toEasternDigits(String input) {
    final sb = StringBuffer();
    for (final ch in input.runes) {
      if (ch >= 0x30 && ch <= 0x39) {
        sb.writeCharCode(0x0660 + (ch - 0x30));
      } else {
        sb.writeCharCode(ch);
      }
    }
    return sb.toString();
  }

  String _toWesternDigits(String input) {
    final buffer = StringBuffer();
    for (final ch in input.runes) {
      if (ch >= 0x0660 && ch <= 0x0669) {
        buffer.writeCharCode('0'.codeUnitAt(0) + (ch - 0x0660));
        continue;
      }
      if (ch >= 0x06F0 && ch <= 0x06F9) {
        buffer.writeCharCode('0'.codeUnitAt(0) + (ch - 0x06F0));
        continue;
      }
      buffer.writeCharCode(ch);
    }
    return buffer.toString();
  }

  bool _canGoNext() {
    final endOfNext = DateTime(_currentDate.year, _currentDate.month + 2, 0); // last day of next month
    return _currentDate.isBefore(endOfNext);
  }

  bool _canGoPrev() {
    final startOfPrev = DateTime(_currentDate.year, _currentDate.month - 1, 1); // first day of prev month
    return !_currentDate.isBefore(startOfPrev);
  }

  Future<void> _goNextDay() async {
    if (!_canGoNext()) return;
    setState(() => _currentDate = _currentDate.add(const Duration(days: 1)));
    await _loadTimes(fetchIfMissing: false);
  }

  Future<void> _goPrevDay() async {
    if (!_canGoPrev()) return;
    setState(() => _currentDate = _currentDate.subtract(const Duration(days: 1)));
    await _loadTimes(fetchIfMissing: false);
  }

  Future<void> _onRefreshPressed() async {
    setState(() => _loading = true);
    try {
      final hasNet = await _hasInternet();
      if (!hasNet) {
        setState(() { _needsInternet = true; _loading = false; });
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _needsService = true; _loading = false; });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() { _needsPermission = true; _loading = false; });
        return;
      }
      final pos = await PrayerTimesService.getCurrentPosition();
      final method = await PrayerTimesService.resolveMethodForRegionFromPosition(pos);
      final currMonth = DateTime(_currentDate.year, _currentDate.month, 1);
      final nextMonth = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      await PrayerTimesService.fetchAndCacheMonth(year: currMonth.year, month: currMonth.month, latitude: pos.latitude, longitude: pos.longitude, method: method);
      await PrayerTimesService.fetchAndCacheMonth(year: nextMonth.year, month: nextMonth.month, latitude: pos.latitude, longitude: pos.longitude, method: method);
      await PrayerTimesService.cleanupKeepPrevCurrentNext(_currentDate);
      await _loadTimes(fetchIfMissing: false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onHijriMonthTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthPrayerTimesScreen(baseDate: _currentDate, mode: MonthViewMode.hijri),
      ),
    );
  }

  void _onGregorianMonthTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthPrayerTimesScreen(baseDate: _currentDate, mode: MonthViewMode.gregorian),
      ),
    );
  }

  Future<void> _openAdhanSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final initial = PreferencesService.getAdhanSound();
    final entries = [
      ('basit', 'عبد الباسط عبد الصمد'),
      ('afs', 'مشاري العفاسي'),
      ('mecca', 'أذان مكة'),
      ('medina', 'أذان المدينة'),
      ('ibrahim-jabr-masr', 'ابراهيم جبر - مصر'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      builder: (ctx) {
        String selectedKey = initial;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.adhanSound),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 18),
                        const SizedBox(width: 8),
                        const Text('Time format'),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('12h'),
                          selected: PreferencesService.getTimeFormat12h(),
                          onSelected: (v) async {
                            await PreferencesService.saveTimeFormat12h(true);
                            setState(() {});
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('24h'),
                          selected: !PreferencesService.getTimeFormat12h(),
                          onSelected: (v) async {
                            await PreferencesService.saveTimeFormat12h(false);
                            setState(() {});
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...entries.map((e) {
                    final key = e.$1;
                    final label = e.$2;
                    final selected = key == selectedKey;
                    final isPreviewing = _previewKey == key && _previewPlayer.playing;
                    return ListTile(
                      title: Text(label),
                      leading: selected ? const Icon(Icons.check, color: Colors.green) : const SizedBox(width: 24),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: isPreviewing ? l10n.stopPlayback : l10n.playSurahAudio,
                            icon: Icon(isPreviewing ? Icons.stop : Icons.play_arrow),
                            onPressed: () async {
                              await _togglePreview(key, onUiUpdate: () { try { setModalState(() {}); } catch (_) {} });
                            },
                          ),
                          TextButton(
                            onPressed: () async {
                              // Stop any preview first
                              await _previewPlayer.stop();
                              await PreferencesService.saveAdhanSound(key);
                              selectedKey = key;
                              setModalState(() {});
                              if (mounted) setState(() {});
                            },
                            child: Text(selected ? l10n.selectedLabel : l10n.selectLabel),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
          },
        );
      },
    ).whenComplete(() async {
      await _previewPlayer.stop();
      _previewKey = null;
    });
  }

  Future<void> _togglePreview(String key, {VoidCallback? onUiUpdate}) async {
    if (_previewKey == key) {
      _previewKey = null;
      await _previewPlayer.stop();
      if (mounted) setState(() {});
      onUiUpdate?.call();
      return;
    }
    try {
      // Ensure audio session is configured and active for preview playback
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        await session.setActive(true);
      } catch (_) {}
      await _adhanPlayer.stop();
      _previewKey = key;
      if (mounted) setState(() {});
      onUiUpdate?.call();
      await _previewPlayer.stop();
      await _previewPlayer.setVolume(1.0);
      try {
        final primary = 'assets/audio/$key.mp3';
        debugPrint('[AdhanPreview] Trying asset: ' + primary);
        await _previewPlayer.setAudioSource(
          AudioSource.asset(
            primary,
            tag: MediaItem(
              id: primary,
              album: 'Adhan',
              title: key,
            ),
          ),
        );
      } catch (e) {
        // Fallback to fajr variant if generic not found
        final fallback = 'assets/audio/' + key + '-fajr.mp3';
        debugPrint('[AdhanPreview] Primary failed (' + e.toString() + '), trying fallback: ' + fallback);
        await _previewPlayer.setAudioSource(
          AudioSource.asset(
            fallback,
            tag: MediaItem(
              id: fallback,
              album: 'Adhan',
              title: key + ' (fajr)',
            ),
          ),
        );
      }
      await _previewPlayer.play();
      debugPrint('[AdhanPreview] Playback started for key: ' + key);
      _previewPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed).then((_) {
        _previewKey = null;
        if (mounted) setState(() {});
        try { onUiUpdate?.call(); } catch (_) {}
        debugPrint('[AdhanPreview] Playback completed for key: ' + key);
      });
    } catch (e) {
      debugPrint('[AdhanPreview] Error: ' + e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingAudio)),
        );
      }
      _previewKey = null;
      if (mounted) setState(() {});
      onUiUpdate?.call();
    }
  }

  Future<void> _playAdhanForPrayer(String prayerId) async {
    try {
      // Ensure audio session is configured and active for adhan playback
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        await session.setActive(true);
      } catch (_) {}
      final base = PreferencesService.getAdhanSound();
      final isFajr = prayerId == 'fajr';
      final asset = isFajr ? 'assets/audio/' + base + '-fajr.mp3' : 'assets/audio/' + base + '.mp3';
      debugPrint('[AdhanPlay] Prayer=' + prayerId + ', sound=' + base + ', asset=' + asset);
      await _adhanPlayer.stop();
      await _adhanPlayer.setAudioSource(
        AudioSource.asset(
          asset,
          tag: MediaItem(
            id: asset,
            album: 'Adhan',
            title: (isFajr ? 'Fajr' : 'Adhan') + ' - ' + base,
          ),
        ),
      );
      await _adhanPlayer.play();
      debugPrint('[AdhanPlay] Playback started');
    } catch (e) {
      debugPrint('[AdhanPlay] Error: ' + e.toString());
      // ignore
    }
  }
}


