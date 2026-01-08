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

  Timer? _uiRefreshTimer;
  
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
    
    // Refresh UI periodically to update stop button visibility
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _hijriMonthTap.dispose();
    _gregorianMonthTap.dispose();
    _previewPlayer.dispose();
    _uiRefreshTimer?.cancel();
    _tick?.cancel();
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

  String _getLocalizedMethodName(AppLocalizations l10n, int methodId) {
    switch (methodId) {
      case 0:
        return l10n.method0;
      case 1:
        return l10n.method1;
      case 2:
        return l10n.method2;
      case 3:
        return l10n.method3;
      case 4:
        return l10n.method4;
      case 5:
        return l10n.method5;
      case 7:
        return l10n.method7;
      case 8:
        return l10n.method8;
      case 9:
        return l10n.method9;
      case 10:
        return l10n.method10;
      case 11:
        return l10n.method11;
      case 12:
        return l10n.method12;
      case 13:
        return l10n.method13;
      case 14:
        return l10n.method14;
      case 15:
        return l10n.method15;
      case 16:
        return l10n.method16;
      case 17:
        return l10n.method17;
      case 18:
        return l10n.method18;
      case 19:
        return l10n.method19;
      case 20:
        return l10n.method20;
      case 21:
        return l10n.method21;
      case 22:
        return l10n.method22;
      case 23:
        return l10n.method23;
      default:
        return 'Method $methodId';
    }
  }

  String _formatTimePlaceholder() => '—';

  Map<String, DateTime>? _todayTimes;
  String? _nextPrayerId;
  Duration? _countdown;
  Timer? _tick;
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewKey;

  Future<void> _initialLoad() async {
    // Ensure we have cached months or fetch using GPS+Internet
    await _loadTimes(fetchIfMissing: true);
  }

  Future<void> _loadTimes({bool fetchIfMissing = false, bool forceRefresh = false}) async {
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

      // Force refresh when method changes, or fetch if missing
      if (forceRefresh || (fetchIfMissing && (!havePrev || !haveCurr || !haveNext))) {
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
        //print('[PrayerTimesScreen] Re-scheduling Adhans for today');
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
        //print('[PrayerTimesScreen] Adhans re-scheduled');
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
        // GlobalAdhanService will handle playing the Adhan
        // We just reload times to update the UI
        _loadTimes();
      } else {
        setState(() => _countdown = remain);
      }
    });
    // Previously we also scheduled a silent alert 5 minutes before the prayer
    // and an Adhan notification at the exact time from this screen.
    // These are now disabled globally via NotificationService and we avoid
    // scheduling them here to respect the user's preference.
  }


  Future<void> _toggleAdhan(BuildContext context, String id, bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _adhanEnabled[id] = value;
    });
    await PreferencesService.setBool('adhan_$id', value);
    if (!mounted) return;
    messenger.showSnackBar(
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
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.orange.withAlpha(30),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Icon(Icons.info, color: Colors.orange),
                                const SizedBox(height: 8),
                                Text(
                                  isAr ? 'لتشغيل الأذان عند إغلاق التطبيق:' : 
                                  isFr ? 'Pour l\'Adhan quand l\'app est fermée :' : 
                                  'For Adhan when app is closed:',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isAr ? '1. عطّل توفير البطارية\n2. امنح إذن التنبيهات الدقيقة\n3. أعد تشغيل التطبيق' : 
                                  isFr ? '1. Désactivez l\'optimisation batterie\n2. Autorisez les alarmes exactes\n3. Redémarrez l\'application' : 
                                  '1. Disable battery optimization\n2. Allow exact alarms\n3. Restart the app',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
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
                                // Test background Adhan after 10 seconds
                                final messenger = ScaffoldMessenger.of(context);
                                await AdhanScheduler.testAdhanPlaybackAfterSeconds(10, PreferencesService.getAdhanSound());

                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('أذان تجريبي بعد 10 ثواني - أغلق التطبيق للاختبار'),
                                    duration: Duration(seconds: 8),
                                  ),
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
                title: Text(
                  title,
                  style: isNext ? const TextStyle(fontWeight: FontWeight.bold) : null,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(_formatClock(dtAdj)),
                    ),
                    if (isNext && _countdown != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: Text(
                          _formatDuration(_countdown!),
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                  ],
                ),
                trailing: Semantics(
                  label: '${AppLocalizations.of(context)!.adhanSound}: $title',
                  button: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (id != 'sunrise' && id != 'imsak')
                        IconButton(
                          icon: const Icon(Icons.tune, size: 20),
                          tooltip: AppLocalizations.of(context)!.prayerAdjustmentTooltip,
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

  String _formatSignedMinutes(AppLocalizations l10n, int minutes) {
    final absLabel = l10n.minutesShort(minutes.abs());
    if (minutes > 0) return '+$absLabel';
    if (minutes < 0) return '-$absLabel';
    return absLabel;
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
    // final initialMethod = PreferencesService.getPrayerMethod();
    bool methodChanged = false;
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
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calculate, size: 18),
                            const SizedBox(width: 8),
                            Text(l10n.prayerMethodSectionTitle),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          initialValue: PreferencesService.getPrayerMethod(),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(l10n.prayerMethodAuto),
                            ),
                            const DropdownMenuItem<int?>(value: 0, child: Text('0')),
                            const DropdownMenuItem<int?>(value: 1, child: Text('1')),
                            const DropdownMenuItem<int?>(value: 2, child: Text('2')),
                            const DropdownMenuItem<int?>(value: 3, child: Text('3')),
                            const DropdownMenuItem<int?>(value: 4, child: Text('4')),
                            const DropdownMenuItem<int?>(value: 5, child: Text('5')),
                            const DropdownMenuItem<int?>(value: 7, child: Text('7')),
                            const DropdownMenuItem<int?>(value: 8, child: Text('8')),
                            const DropdownMenuItem<int?>(value: 9, child: Text('9')),
                            const DropdownMenuItem<int?>(value: 10, child: Text('10')),
                            const DropdownMenuItem<int?>(value: 11, child: Text('11')),
                            const DropdownMenuItem<int?>(value: 12, child: Text('12')),
                            const DropdownMenuItem<int?>(value: 13, child: Text('13')),
                            const DropdownMenuItem<int?>(value: 14, child: Text('14')),
                            const DropdownMenuItem<int?>(value: 15, child: Text('15')),
                            const DropdownMenuItem<int?>(value: 16, child: Text('16')),
                            const DropdownMenuItem<int?>(value: 17, child: Text('17')),
                            const DropdownMenuItem<int?>(value: 18, child: Text('18')),
                            const DropdownMenuItem<int?>(value: 19, child: Text('19')),
                            const DropdownMenuItem<int?>(value: 20, child: Text('20')),
                            const DropdownMenuItem<int?>(value: 21, child: Text('21')),
                            const DropdownMenuItem<int?>(value: 22, child: Text('22')),
                            const DropdownMenuItem<int?>(value: 23, child: Text('23')),
                          ].map((item) {
                            if (item.value == null) return item;
                            final methodId = item.value!;
                            return DropdownMenuItem<int?>(
                              value: methodId,
                              child: Text(_getLocalizedMethodName(l10n, methodId)),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value == null) {
                              await PreferencesService.clearPrayerMethod();
                            } else {
                              await PreferencesService.savePrayerMethod(value);
                            }
                            methodChanged = true;
                            // Force refresh prayer times with new method
                            await _loadTimes(forceRefresh: true);
                            // Don't call setModalState here as it may be disposed after async operation
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.prayerMethodSectionDesc,
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
                  }),
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
      
      // If method changed, show notification and force refresh
      if (methodChanged) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.prayerMethodChangedDesc),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Force refresh prayer times one more time to ensure everything is updated
          await _loadTimes(forceRefresh: true);
          setState(() {});
        }
      }
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
      // Stop any current preview before switching keys to ensure responsiveness
      await _previewPlayer.stop();
      _previewKey = key;
      if (mounted) setState(() {});
      onUiUpdate?.call();
      await _previewPlayer.setVolume(PreferencesService.getAdhanVolume().clamp(0.0, 1.0));
      try {
        final primary = 'assets/audio/$key.mp3';
        debugPrint('[AdhanPreview] Trying asset: $primary');
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
        final fallback = 'assets/audio/$key-fajr.mp3';
        debugPrint('[AdhanPreview] Primary failed ($e), trying fallback: $fallback');
        await _previewPlayer.setAudioSource(
          AudioSource.asset(
            fallback,
            tag: MediaItem(
              id: fallback,
              album: 'Adhan',
              title: '$key (fajr)',
            ),
          ),
        );
      }
      await _previewPlayer.play();
      debugPrint('[AdhanPreview] Playback started for key: $key');
      _previewPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed).then((_) {
        _previewKey = null;
        if (mounted) setState(() {});
        try { onUiUpdate?.call(); } catch (_) {}
        debugPrint('[AdhanPreview] Playback completed for key: $key');
      });
    } catch (e) {
      debugPrint('[AdhanPreview] Error: $e');
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
            final l10n = AppLocalizations.of(ctx)!;
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
                              l10n.prayerAdjustmentTitle(prayerName),
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
                            l10n.prayerAdjustmentOriginal,
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
                              l10n.prayerAdjustmentChange(
                                _formatSignedMinutes(l10n, currentAdjustment),
                              ),
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
                                l10n.prayerAdjustmentAfter(_formatClock(adjustedTime)),
                                style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ] else if (originalTime != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              l10n.prayerAdjustmentNoChange,
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
                              label: Text(l10n.minutesShort(5)),
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
                              label: Text(l10n.minutesShort(1)),
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
                              label: Text(l10n.minutesShort(1)),
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
                              label: Text(l10n.minutesShort(5)),
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
                          label: Text(l10n.prayerAdjustmentReset),
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


