import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/preferences_service.dart';
import 'services/notification_permissions.dart';
import 'services/supabase_config.dart';
import 'services/reciter_config_service.dart';
import 'options_screen.dart';
import 'services/notification_service.dart';
import 'services/prayer_times_service.dart';
import 'services/device_info_service.dart';
import 'services/adhan_scheduler.dart';
import 'services/adhan_audio_manager.dart';
import 'prayer_times_screen.dart';
import 'tasbeeh_screen.dart';
import 'services/global_adhan_service.dart';
import 'services/wird_service.dart';
import 'services/usage_stats_service.dart';
import 'services/screen_time_observer.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'themes/app_theme_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_state_providers.dart';

/// Global navigator key so notification-tap handlers (which run outside any
/// widget's BuildContext) can push routes. Attached to the root MaterialApp.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

/// Single navigator observer that measures per-screen view time (named routes
/// only) and reports it via UsageStatsService. Held at top level so the app
/// lifecycle handler can flush the in-progress screen when backgrounded.
final ScreenTimeObserver screenTimeObserver = ScreenTimeObserver();

/// Pushes the Tasbeeh screen opened on its Wird tab. Used by the
/// `wird_<id>` notification deep-link. Safe to call from the notification
/// tap handler: it no-ops if the navigator isn't mounted yet.
void _openWirdTab() {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(
    MaterialPageRoute(
      builder: (_) => const TasbeehScreen(initialTab: 1),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Pdfrx cache directory (Required for Android)
  try {
    Pdfrx.getCacheDirectory = () async {
      final dir = await getApplicationCacheDirectory();
      return dir.path;
    };
  } catch (e) {
    debugPrint('Error initializing Pdfrx: $e');
  }
  // Background audio init is mobile-only; web is no-op via not calling.
  // (just_audio works on web without background controls)
  if (!kIsWeb) {
    // Initialize just_audio_background for background playback
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.qurani.app.audio',
      androidNotificationChannelName: 'Quran Audio Playback',
      androidNotificationChannelDescription: 'Background Quran audio playback',
    );
    final audioSession = await AudioSession.instance;
    await audioSession.configure(const AudioSessionConfiguration.music());
  }
  await _ensureNotificationPermissions();
  await PreferencesService.init();
  await PreferencesService.ensureInstallationId();

  // Link Supabase (online-only enhancement). No-op when credentials aren't
  // provided via --dart-define; never blocks the offline experience.
  await SupabaseConfig.initialize();

  // Force a clean slate for the cross-isolate foreground flag at every cold
  // start. If the previous process was force-killed (Settings → Force Stop,
  // low-memory kill, or crash) the `dispose()` path that resets this flag
  // never ran and the pref stayed `true`. The Adhan background alarm isolate
  // reads this pref to decide whether to suppress the stop-notification, so
  // a stale `true` would wrongly silence the "Stop Adhan" action on the
  // next alarm. Writing `false` here guarantees the flag is only `true`
  // while our UI isolate is actually alive; `QuraniApp.initState` and the
  // lifecycle observer flip it back to `true` once the first frame is drawn.
  try {
    await (await SharedPreferences.getInstance())
        .setBool('is_app_in_foreground', false);
  } catch (_) {
    // Best-effort reset; any failure just leaves the previous value in place.
  }

  // Load reciter configurations from JSON (same for both platforms)
  await ReciterConfigService.loadReciters();
  
  await NotificationService.init();
  
  // Initialize AdhanScheduler with proper background callback registration
  await AdhanScheduler.init();
  
  // Initialize global Adhan service for cross-screen playback
  await GlobalAdhanService.init();
  
  // Handle when app is opened from notification (mobile only)
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      // On Android, plugin is available; on web it's a stub
      final plugin = NotificationService.plugin;
      final initialNotificationResponse = await plugin.getNotificationAppLaunchDetails();
      if (initialNotificationResponse?.didNotificationLaunchApp ?? false) {
        // Cold launch from a notification tap. Adhan auto-play stays disabled,
        // but a `wird_<id>` reminder should still deep-link to the Wird tab.
        // Defer until after the first frame so the root navigator exists.
        final launchPayload =
            initialNotificationResponse?.notificationResponse?.payload;
        if (launchPayload != null && launchPayload.startsWith('wird_')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openWirdTab();
          });
        }
      }
    } catch (e) {
      //print('[Main] Error checking notification launch details: $e');
    }
    
    // Set up notification tap handler.
    //
    // - `wird_<id>` reminders deep-link to the Wird tab so tapping a reminder
    //   lands the user where they can act on it.
    // - Adhan playback has been disabled, so adhan-related taps are ignored.
    NotificationService.onNotificationTap = (String? payload) async {
      if (payload == null || payload == 'unknown') return;
      if (payload.startsWith('wird_')) {
        _openWirdTab();
      }
    };
  }
  
  // Collect legal device info once, and re-collect if flag missing
  await DeviceInfoService.collectIfNeeded();

  // Anonymous, opt-out-able usage stats. No-op when Supabase isn't configured,
  // the user opted out, or offline. Never blocks startup.
  unawaited(UsageStatsService.instance.init());
  // Silent background refresh of prayer times cache every 10 days using last known position
  await PrayerTimesService.maybeRefreshCacheOnLaunch();
  
  runApp(
    const ProviderScope(
      child: QuraniApp(),
    ),
  );

  // Defer the 7-day Adhan scheduling pass until AFTER the first frame so the
  // user sees the UI immediately instead of a black pre-splash while we do
  // ~8 sequential day lookups + NotificationService + AlarmManager writes.
  //
  // Correctness trade-off: if the user opens the app literally seconds before
  // a prayer, there is now a ~1-frame (≤16ms) delay before the alarm would be
  // re-armed. This is acceptable because:
  //   1. `AdhanScheduler.shouldScheduleThroughDay` already dedups — a fresh
  //      scheduling pass is a no-op if one ran recently.
  //   2. Today's imminent Adhan is handled by the already-scheduled alarm
  //      from the previous session; we're only re-arming day+1..+7 here.
  //   3. `unawaited` + `Future.microtask` ensures this runs on the event
  //      loop after the first frame without blocking runApp.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    unawaited(Future.microtask(_scheduleSevenDaysOfAdhans));
  }

  // Daily Wird: seed defaults on first launch, apply the daily-reset pass,
  // and re-arm the rolling 7-day one-shot notification window for every
  // active wird. Runs on all platforms — on web the NotificationService
  // scheduling calls are no-ops, but the seeding + reset logic still
  // works so users get a consistent Wird UI everywhere.
  //
  // Kept outside the Android gate because wird reminders are also a valid
  // iOS feature, and the seeding step must run regardless of platform.
  unawaited(Future.microtask(WirdService.ensureReadyAndReschedule));
}

/// Schedules up to 7 days of Adhan notifications + alarm-manager entries.
/// Extracted from `main()` so it can be deferred until after the first frame.
/// Any failure is swallowed — the prayer-times screen re-runs this flow when
/// the user navigates to it, so a startup miss is recoverable.
Future<void> _scheduleSevenDaysOfAdhans() async {
  try {
    final now = DateTime.now();
    final times = await PrayerTimesService.getTimesForDate(
      year: now.year,
      month: now.month,
      day: now.day,
    );
    if (times == null) return;

    final adhanEnabled = {
      for (final id in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
        id: PreferencesService.getBool('adhan_$id') ?? false,
    };
    final soundKey = PreferencesService.getAdhanSound();
    // Gate the 7-day scheduling pass behind AdhanScheduler's dedup check:
    // without this guard, the same alarms get re-queued 3-4× per cold
    // start (main + maybeRefreshCacheOnLaunch + prayer_times_screen init)
    // which triggers Android alarm-manager throttling on API 31+.
    final shouldSchedule = await AdhanScheduler.shouldScheduleThroughDay(
      soundKey: soundKey,
      toggles: adhanEnabled,
      daysAhead: 7,
    );
    if (!shouldSchedule) return;

    await NotificationService.scheduleRemainingAdhans(
      times: times,
      soundKey: soundKey,
      toggles: adhanEnabled,
    );
    await AdhanScheduler.scheduleForTimes(
      times: times,
      toggles: adhanEnabled,
      soundKey: soundKey,
    );
    // Also schedule for the next 7 days.
    //
    // DST safety: advance the cursor via the calendar-aware
    // `DateTime(y, m, d + 1)` constructor rather than
    // `cursor.add(Duration(days: 1))`. The latter adds 86400s of
    // absolute time, which on DST transition days drifts the
    // wall-clock by ±1 hour and can make the loop skip or double
    // a calendar date. See `prayer_times_service_io.dart` for the
    // full rationale.
    DateTime cursor = DateTime(now.year, now.month, now.day + 1);
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
          toggles: adhanEnabled,
        );
        await AdhanScheduler.scheduleForTimes(
          times: futureTimes,
          toggles: adhanEnabled,
          soundKey: soundKey,
        );
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    await AdhanScheduler.markScheduledThroughDay(
      soundKey: soundKey,
      toggles: adhanEnabled,
      daysAhead: 7,
    );
  } catch (e) {
    debugPrint('[Main] Error scheduling Adhans at startup: $e');
  }
}

Future<void> _ensureNotificationPermissions() async {
  // Delegated to the shared gateway so Adhan's startup permission requests
  // live in exactly one place (see NotificationPermissions for the rationale
  // and the deliberate Wird-path exception).
  await NotificationPermissions.ensureBaselineForAdhan();
}


class QuraniApp extends ConsumerStatefulWidget {
  const QuraniApp({super.key});

  @override
  ConsumerState<QuraniApp> createState() => _QuraniAppState();
}

 class _QuraniAppState extends ConsumerState<QuraniApp> with WidgetsBindingObserver {
  void _applySystemUiOverlay(AppThemeOption themeOption) {
    final iconBrightness = themeOption.isDark
        ? Brightness.light
        : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        systemNavigationBarColor: themeOption.surfaceColor,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateAppState(true);
    // Apply overlay once for the initial theme. Subsequent theme changes are
    // driven by the `ref.listen` call in `build` so `setSystemUIOverlayStyle`
    // never fires from inside build() itself (which would spam the platform
    // channel on every rebuild).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final themeId = ref.read(themeProvider);
      _applySystemUiOverlay(AppThemeConfig.getTheme(themeId));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The Adhan background alarm isolate reads `is_app_in_foreground` from
    // shared prefs to decide whether to show the stop-notification. We must
    // therefore mark the app as backgrounded on *any* non-resumed state
    // (paused, inactive, hidden, detached) — not only on `resumed`. This
    // prevents a stale `true` flag after the user swipes the app away, which
    // was previously suppressing the stop-notification on the next alarm.
    final isForeground = state == AppLifecycleState.resumed;
    _updateAppState(isForeground);
    if (isForeground) {
      // Begin a new usage-stats session on resume.
      UsageStatsService.instance.startSession();
      screenTimeObserver.onAppResumed();
      // Reconcile the in-memory "Adhan playing" notifier with the cross-isolate
      // shared-prefs flag so the UI reflects playback that was started in the
      // AndroidAlarmManager background isolate while we were backgrounded.
      AdhanAudioManager.syncPlayingStateFromPrefs();
      // Resume the foreground prayer-time polling timer: while foreground, the
      // app (not the alarm isolate) is the primary Adhan trigger.
      GlobalAdhanService.resume();
    } else {
      // Flush + record the finished session's duration (fire-and-forget).
      screenTimeObserver.onAppPaused();
      unawaited(UsageStatsService.instance.endSession());
      // Backgrounded: hand Adhan responsibility to the AndroidAlarmManager
      // background isolate and stop the foreground polling timer so the two
      // don't race near prayer time (and so we don't burn battery ticking
      // every 30s in the background).
      GlobalAdhanService.pause();
    }
  }

  Future<void> _updateAppState(bool isForeground) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_app_in_foreground', isForeground);
    } catch (e) {
      debugPrint('Error updating app state: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateAppState(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeId = ref.watch(themeProvider);

    // React to theme changes exactly once per transition instead of on every
    // rebuild. `ref.listen` keeps `SystemChrome.setSystemUIOverlayStyle` out of
    // the hot path; the initial application is handled by the post-frame
    // callback registered in `initState`.
    ref.listen<String>(themeProvider, (previous, next) {
      if (previous == next) return;
      _applySystemUiOverlay(AppThemeConfig.getTheme(next));
    });

    final currentTheme = AppThemeConfig.getTheme(themeId);
    final activeThemeData = AppThemeConfig.themeDataFor(currentTheme.id);
    final darkThemeData = AppThemeConfig.themeDataFor(AppThemeConfig.deepNightThemeId);

    return MaterialApp(
      title: 'Qurani',
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [screenTimeObserver],
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
        Locale('fr'),
      ],
      theme: activeThemeData,
      darkTheme: darkThemeData,
      themeMode: currentTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 320),
      themeAnimationCurve: Curves.easeOutCubic,
      // Clamp OS text scale to [1.0, 1.4] globally. Rationale:
      //   - We honor the user's accessibility preference up to +40%, which
      //     covers all standard Android/iOS "large text" settings.
      //   - Above 1.4× the 2-col Surah grid, Prayer Times pills, and the
      //     Read-Quran toolbar overflow in ways that require per-screen fixes
      //     we haven't shipped yet; clamping is the pragmatic interim.
      //   - We never shrink below 1.0 even if the OS reports 0.85× (Android
      //     "smaller"), because Arabic diacritics become unreadable.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.4,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const OptionsScreen(),
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        if (settings.name == '/prayer-times') {
          return MaterialPageRoute(builder: (_) => const PrayerTimesScreen());
        }
        return null;
      },
    );
  }
}
