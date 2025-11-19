import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';
import 'month_prayer_times_screen.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/prayer_times_service.dart';
import 'package:qurani/services/adhan_scheduler.dart';
import 'services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'services/media_item_compat.dart';
import 'services/net_utils.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String? _cityName;

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
      // Try to update city name from last known position (best effort)
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final city = await PrayerTimesService.getCityFromCoordinates(last);
          if (mounted) setState(() { _cityName = city; });
        }
      } catch (_) {}
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
        // Update city when we have a fresh position
        try { _cityName = await PrayerTimesService.getCityFromCoordinates(pos); } catch (_) {}
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
        try { _cityName = await PrayerTimesService.getCityFromCoordinates(pos); } catch (_) {}
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
              ? ['imsak','fajr','sunrise','dhuhr','asr','maghrib','isha']
              : ['fajr','sunrise','dhuhr','asr','maghrib','isha'];
        } else {
          final lang = PreferencesService.getLanguage();
          _hijriDay = hijri['day'];
          _hijriMonth = (lang == 'ar' ? hijri['monthAr'] : hijri['monthEn']);
          _hijriYear = hijri['year'];
          final monthAr = hijri['monthAr'];
          final monthEn = hijri['monthEn'];
          _isRamadan = (monthEn?.toLowerCase().contains('ramadan') ?? false) || (monthAr?.contains('رمضان') ?? false);
          final hasImsak = times != null && times.containsKey('imsak');
          final showImsak = _isRamadan || hasImsak;
          _prayers = showImsak
              ? ['imsak','fajr','sunrise','dhuhr','asr','maghrib','isha']
              : ['fajr','sunrise','dhuhr','asr','maghrib','isha'];
        }
        _loading = false;
      });
      // Schedule remaining adhans for today (even if app closes later)
      if (times != null) {
        final soundKey = PreferencesService.getAdhanSound();
        print('[PrayerTimesScreen] Re-scheduling Adhans for today');
        await NotificationService.scheduleRemainingAdhans(
          times: times,
          soundKey: soundKey,
          toggles: _adhanEnabled,
        );
        // Also schedule background full Adhan playback (Android)
        await AdhanScheduler.scheduleForTimes(
          times: times,
          toggles: _adhanEnabled,
          soundKey: soundKey,
        );
        // Also schedule for next 7 days to ensure coverage
        final now = DateTime.now();
        DateTime cursor = now.add(const Duration(days: 1));
        for (int i = 0; i < 7; i++) {
          final futureTimes = await PrayerTimesService.getTimesForDate(
            year: cursor.year,
            month: cursor.month,
            day: cursor.day,
          );
          if (futureTimes != null) {
            await NotificationService.scheduleRemainingAdhans(
              times: futureTimes,
              soundKey: soundKey,
              toggles: _adhanEnabled,
            );
            await AdhanScheduler.scheduleForTimes(
              times: futureTimes,
              toggles: _adhanEnabled,
              soundKey: soundKey,
            );
          }
          cursor = cursor.add(const Duration(days: 1));
        }
        print('[PrayerTimesScreen] Adhans re-scheduled');
      }
      _computeNextAndSchedule();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<bool> _hasInternet() => NetUtils.hasInternet();

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
    final nextDt = nextTime!; // safe: nextTime is set when nextId is found
    setState(() {
      _nextPrayerId = nextId;
      _countdown = nextDt.difference(now);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _nextPrayerId == null) return;
      final remain = nextDt.difference(DateTime.now());
      if (remain.isNegative) {
        _tick?.cancel();
        if (_nextPrayerId != null && _nextPrayerId != 'sunrise') {
          final id = _nextPrayerId ?? '';
          final enabled = _adhanEnabled[id] ?? false;
          if (enabled) {
            // ignore: discarded_futures
            _playAdhanForPrayer(id);
          }
        }
        _loadTimes();
      } else {
        setState(() => _countdown = remain);
      }
    });
    // Schedule silent alert 5 minutes before next prayer (no alert for sunrise)
    if (nextId != 'sunrise') {
      final alertTime = nextDt.subtract(const Duration(minutes: 5));
      if (alertTime.isAfter(DateTime.now())) {
        final alertBody = _buildSilentAlertBody(_localizedName(context, nextId));
        NotificationService.scheduleSilentAlert(
          id: _alertIdFor(nextId),
          triggerTimeLocal: alertTime,
          title: _localizedName(context, nextId),
          body: alertBody,
        );
      }
    }
    if (nextId != 'sunrise' && (_adhanEnabled[nextId] ?? false)) {
      final soundKey = PreferencesService.getAdhanSound();
      final isFajr = nextId == 'fajr';
      NotificationService.scheduleAdhanNotification(
        id: _alertIdFor(nextId) + 1000,
        triggerTimeLocal: nextDt,
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

  String _buildSilentAlertBody(String prayerName) {
    final lang = PreferencesService.getLanguage();
    switch (lang) {
      case 'en':
        return 'Adhan for $prayerName in 5 minutes';
      case 'fr':
        return 'Adhan de $prayerName dans 5 minutes';
      default:
        return 'سيحين أذان $prayerName بعد خمس دقائق';
    }
  }

  String _adhanVolumeLabel() {
    switch (PreferencesService.getLanguage()) {
      case 'en':
        return 'Adhan volume';
      case 'fr':
        return 'Volume de l\'adhan';
      default:
        return 'مستوى صوت الأذان';
    }
  }

  String _adhanVolumeHint() {
    switch (PreferencesService.getLanguage()) {
      case 'en':
        return 'Choose how loud the Adhan plays';
      case 'fr':
        return 'Choisissez l\'intensité sonore de l\'adhan';
      default:
        return 'اختر شدة صوت الأذان المناسبة لك';
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
    // Re-schedule for today with updated toggles
    try {
      if (_todayTimes != null) {
        final soundKey = PreferencesService.getAdhanSound();
        await NotificationService.scheduleRemainingAdhans(
          times: _todayTimes!,
          soundKey: soundKey,
          toggles: _adhanEnabled,
        );
        await AdhanScheduler.scheduleForTimes(
          times: _todayTimes!,
          toggles: _adhanEnabled,
          soundKey: soundKey,
        );
      }
    } catch (_) {}
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
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _openPrayerTimesHelp(context),
          ),
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

  void _openPrayerTimesHelp(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final bool isAr = lang == 'ar';
    final bool isFr = lang == 'fr';
    final List<Map<String, String>> faqsAr = [
      {
        'q': 'كيف أجعل الأذان يعمل في الخلفية حتى لو كان التطبيق مغلقًا؟',
        'a': '1) فعّل زر التبديل بجانب كل صلاة تريد تشغيل الأذان لها.\n2) امنح إذن الإشعارات للتطبيق.\n3) عطّل قيود توفير البطارية للتطبيق من إعدادات النظام.\n4) على بعض الأجهزة: فعّل خيار السماح بالتنبيهات الدقيقة (Exact alarms).\n5) اختر صوت الأذان من إعدادات الأذان.\nيتم جدولة الأذان لليوم و7 أيام قادمة من البيانات المخزّنة.'
      },
      {
        'q': 'لماذا لا يعمل الأذان في الخلفية على الويب؟',
        'a': 'متصفحات الويب لا تسمح بالتشغيل التلقائي للصوت في الخلفية. الأذان في الخلفية متاح على أندرويد فقط.'
      },
      {
        'q': 'ما وظيفة أزرار التبديل بجانب كل صلاة؟',
        'a': 'تتحكم في تشغيل الأذان لتلك الصلاة. إن كان الزر غير مفعّل فلن يعمل الأذان لتلك الصلاة حتى لو حان وقتها.'
      },
      {
        'q': 'هل يوجد تنبيه قبل الصلاة؟',
        'a': 'قد يظهر تنبيه صامت قبل 5 دقائق من الصلاة (باستثناء الشروق) للتذكير، حسب إعدادات النظام.'
      },
      {
        'q': 'ماذا يحدث إذا لم يتوفر إنترنت أو GPS؟',
        'a': 'يعتمد التطبيق على التقويم المخزّن. إن تعذّر التحديث، تُستخدم آخر بيانات متاحة. يُفضّل فتح الصفحة دوريًا لتحديث أوقات الشهر الجاري والقادم.'
      },
      {
        'q': 'كيف أغيّر صوت الأذان؟',
        'a': 'اضغط على أيقونة الإعدادات في الشريط العلوي واختر صوت الأذان المفضّل (وصوت الفجر إن رغبت).'
      },
      {
        'q': 'غيّرت موقعي أو سافرت إلى مدينة أخرى، ماذا أفعل؟',
        'a': 'افتح صفحة أوقات الصلاة مع تفعيل الإنترنت والموقع كي يتم تحديث التقويم تلقائيًا حسب موقعك الجديد.'
      },
    ];
    final List<Map<String, String>> faqsEn = [
      {
        'q': 'How to play full Adhan in background when the app is closed?',
        'a': '1) Enable the toggle next to each prayer you want.\n2) Grant notification permission.\n3) Disable battery optimization for the app.\n4) On some devices: allow exact alarms.\n5) Choose the Adhan sound from settings.\nWe schedule Adhan for today and the next 7 days using cached data.'
      },
      {
        'q': 'Why Adhan background is not available on Web?',
        'a': 'Browsers disallow auto audio playback in background. Background Adhan is Android-only.'
      },
      {
        'q': 'What do the toggles next to prayers do?',
        'a': 'They enable/disable Adhan for that prayer. If off, no Adhan will play even at prayer time.'
      },
      {
        'q': 'Is there a pre-prayer reminder?',
        'a': 'A silent reminder may appear 5 minutes before prayer (except Sunrise), subject to system settings.'
      },
      {
        'q': 'What if Internet or GPS is unavailable?',
        'a': 'The app uses cached calendar if updates fail. Open this page periodically to refresh current/next month.'
      },
      {
        'q': 'How to change Adhan sound?',
        'a': 'Tap the settings icon in the AppBar and pick your preferred Adhan (and Fajr sound if desired).'
      },
      {
        'q': 'I moved to a new city, what now?',
        'a': 'Open the Prayer Times page with Internet and Location enabled to refresh the calendar for your new region.'
      },
    ];
    final List<Map<String, String>> faqsFr = [
      {
        'q': 'Comment faire fonctionner l’Adhan en arrière-plan quand l’app est fermée ?',
        'a': '1) Activez le bouton à côté de chaque prière voulue.\n2) Autorisez les notifications.\n3) Désactivez l’optimisation de batterie pour l’app.\n4) Sur certains appareils : autorisez les alarmes exactes.\n5) Choisissez le son de l’Adhan dans les paramètres.\nL’Adhan est planifié pour aujourd’hui et 7 jours à venir.'
      },
      {
        'q': 'Pourquoi l’Adhan en arrière-plan n’est pas disponible sur le Web ?',
        'a': 'Les navigateurs refusent la lecture audio automatique en arrière-plan. Fonction réservé à Android.'
      },
      {
        'q': 'À quoi servent les interrupteurs à côté des prières ?',
        'a': 'Ils activent/désactivent l’Adhan pour la prière concernée. S’il est désactivé, aucun Adhan ne sera joué.'
      },
      {
        'q': 'Y a-t-il un rappel avant la prière ?',
        'a': 'Un rappel silencieux peut apparaître 5 minutes avant (sauf lever du soleil), selon les réglages du système.'
      },
      {
        'q': 'Sans Internet ou GPS ?',
        'a': 'L’app utilise le calendrier en cache si la mise à jour échoue. Ouvrez cette page périodiquement pour rafraîchir.'
      },
      {
        'q': 'Changer le son de l’Adhan ?',
        'a': 'Touchez l’icône paramètres dans la barre supérieure et choisissez le son souhaité.'
      },
      {
        'q': 'J’ai changé de ville, que faire ?',
        'a': 'Ouvrez la page des horaires avec Internet et la localisation activés pour rafraîchir le calendrier.'
      },
    ];
    final faqs = isAr ? faqsAr : (isFr ? faqsFr : faqsEn);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Column(
              children: [
                // Permission buttons section
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isAr ? 'إعدادات الصلاحيات' : isFr ? 'Paramètres des permissions' : 'Permission Settings',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Geolocator.openAppSettings();
                          },
                          icon: const Icon(Icons.settings),
                          label: Text(isAr ? 'فتح إعدادات التطبيق' : isFr ? 'Ouvrir les paramètres de l\'app' : 'Open App Settings'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await Permission.ignoreBatteryOptimizations.request();
                            } catch (_) {
                              await Geolocator.openAppSettings();
                            }
                          },
                          icon: const Icon(Icons.battery_saver),
                          label: Text(isAr ? 'تعطيل توفير البطارية' : isFr ? 'Désactiver l\'optimisation batterie' : 'Disable Battery Optimization'),
                        ),
                      ],
                    ),
                  ),
                // FAQs list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: faqs.length,
                    itemBuilder: (c, i) {
                      final item = faqs[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ExpansionTile(
                          title: Text(item['q'] ?? ''),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                item['a'] ?? '',
                                textAlign: TextAlign.start,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            final primary = theme.colorScheme.primary.withAlpha((255 * 0.85).round());
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onLongPress: () async {
                                await NotificationService.scheduleTestAdhanInSeconds(10, title: 'Test Adhan', body: 'Plays in 10 seconds');
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.selectedLabel.replaceFirst('{value}', _toWesternDigits('10')))),
                                );
                              },
                              child: ElevatedButton.icon(
                                onPressed: _onRefreshPressed,
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.refresh),
                              ),
                            ),
                            if (_cityName != null && _cityName!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _cityName!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
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
          final borderSide = isNext ? BorderSide(color: theme.colorScheme.primary.withAlpha((255 * 0.6).round()), width: 1.2) : BorderSide.none;
          return Opacity(
            opacity: isPast && !isNext ? 0.55 : 1.0,
            child: Card(
              elevation: isNext ? 4 : 2,
              color: isNext ? Colors.amber.withAlpha((255 * 0.15).round()) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: borderSide),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isNext ? Colors.amber.withAlpha((255 * 0.3).round()) : theme.colorScheme.primary.withAlpha((255 * 0.12).round()),
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
                      // Debug mode: Prayer time adjustment button
                      if (kDebugMode && id != 'sunrise' && id != 'imsak')
                        IconButton(
                          icon: const Icon(Icons.tune, size: 20),
                          tooltip: 'معايرة الوقت',
                          onPressed: () => _openPrayerTimeAdjustment(context, id, dtAdj),
                        ),
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
    double modalVolume = PreferencesService.getAdhanVolume();
    final entries = [
      ('basit', 'عبد الباسط عبد الصمد'),
      ('afs', 'مشاري العفاسي'),
      ('mecca', 'أذان مكة'),
      ('medina', 'أذان المدينة'),
      ('ibrahim-jabr-masr', 'ابراهيم جبر - مصر'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String selectedKey = initial;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 0,
                  right: 0,
                  top: 8,
                  bottom: MediaQuery.of(ctx).viewPadding.bottom + 80,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.timeFormatTitle),
                        const Spacer(),
                        ChoiceChip(
                          label: Text(l10n.twelveHour),
                          selected: PreferencesService.getTimeFormat12h(),
                          onSelected: (v) async {
                            await PreferencesService.saveTimeFormat12h(true);
                            setState(() {});
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: Text(l10n.twentyFourHour),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.volume_up, size: 18),
                            const SizedBox(width: 8),
                            Text(_adhanVolumeLabel()),
                            const Spacer(),
                            Text('${(modalVolume * 100).round()}%'),
                          ],
                        ),
                        Slider(
                          value: modalVolume.clamp(0.2, 1.0),
                          min: 0.2,
                          max: 1.0,
                          divisions: 8,
                          label: '${(modalVolume * 100).round()}%',
                          onChanged: (value) async {
                            modalVolume = value;
                            await PreferencesService.saveAdhanVolume(value);
                            setModalState(() {});
                          },
                        ),
                        Text(
                          _adhanVolumeHint(),
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(l10n.adhanSound),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const Divider(height: 1),
                  ...entries.map((e) {
                    final key = e.$1;
                    final label = e.$2;
                    final selected = key == selectedKey;
                    // Consider previewing when this key is the active preview target
                    final isPreviewing = _previewKey == key;
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
                  const SizedBox(height: 24),
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
      // Stop any current preview before switching keys to ensure responsiveness
      await _previewPlayer.stop();
      _previewKey = key;
      if (mounted) setState(() {});
      onUiUpdate?.call();
      await _previewPlayer.setVolume(PreferencesService.getAdhanVolume().clamp(0.0, 1.0));
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
      await _adhanPlayer.setVolume(PreferencesService.getAdhanVolume().clamp(0.0, 1.0));
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

  // Debug mode: Open prayer time adjustment dialog
  Future<void> _openPrayerTimeAdjustment(BuildContext context, String prayerId, DateTime? currentTime) async {
    final prayerName = _localizedName(context, prayerId);
    
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // Always read the latest time from _todayTimes (which includes adjustments)
            final displayedTime = _todayTimes?[prayerId] ?? currentTime;
            
            int currentAdjustment = PreferencesService.getPrayerTimeAdjustment(prayerId);
            
            // Calculate original time (displayedTime is already adjusted, so subtract adjustment to get original)
            DateTime? originalTime;
            DateTime? adjustedTime;
            if (displayedTime != null) {
              originalTime = displayedTime.subtract(Duration(minutes: currentAdjustment));
              adjustedTime = originalTime.add(Duration(minutes: currentAdjustment));
            }
            
            Future<void> applyAdjustment(int offsetMinutes) async {
              await PreferencesService.adjustPrayerTime(prayerId, offsetMinutes);
              if (mounted) {
                setState(() {});
                await _loadTimes(fetchIfMissing: false);
              }
              setModalState(() {});
            }
            
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Theme.of(ctx).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'معايرة وقت $prayerName',
                              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // Current time display
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'الوقت الأصلي',
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            originalTime != null ? _formatClock(originalTime) : '—',
                            style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(ctx).colorScheme.primary,
                            ),
                          ),
                          if (currentAdjustment != 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'التعديل: ${currentAdjustment > 0 ? '+' : ''}$currentAdjustment دقيقة',
                              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                color: currentAdjustment > 0 
                                    ? Colors.green 
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (adjustedTime != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'الوقت بعد التعديل: ${_formatClock(adjustedTime)}',
                                style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ] else if (originalTime != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'لا يوجد تعديل',
                              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Adjustment buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // -5 minutes
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => applyAdjustment(-5),
                              icon: const Icon(Icons.remove_circle_outline),
                              label: const Text('-5 د'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // -1 minute
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => applyAdjustment(-1),
                              icon: const Icon(Icons.remove),
                              label: const Text('-1 د'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // +1 minute
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => applyAdjustment(1),
                              icon: const Icon(Icons.add),
                              label: const Text('+1 د'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // +5 minutes
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => applyAdjustment(5),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('+5 د'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Reset button
                    if (currentAdjustment != 0)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await PreferencesService.setPrayerTimeAdjustment(prayerId, 0);
                            currentAdjustment = 0;
                            setModalState(() {});
                            if (mounted) {
                              setState(() {});
                              await _loadTimes(fetchIfMissing: false);
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة تعيين'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


