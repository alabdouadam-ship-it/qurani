import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/preferences_service.dart';
import 'options_screen.dart';
import 'services/notification_service.dart';
import 'services/prayer_times_service.dart';
import 'services/device_info_service.dart';
import 'services/adhan_scheduler.dart';
import 'prayer_times_screen.dart';
import 'services/global_adhan_service.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Background audio init is mobile-only; web is no-op via not calling.
  // (just_audio works on web without background controls)
  if (!kIsWeb) {
    // Initialize just_audio_background for background playback
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.qurani.app.audio',
      androidNotificationChannelName: 'Quran Audio Playback',
      androidNotificationChannelDescription: 'Background Quran audio playback',
      androidNotificationOngoing: true,
    );
    final audioSession = await AudioSession.instance;
    await audioSession.configure(const AudioSessionConfiguration.music());
  }
  await _ensureNotificationPermission();
  await _ensureAdhanPermissions();
  await PreferencesService.init();
  await PreferencesService.ensureInstallationId();
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
        // Previously this could auto-play Adhan based on current time.
        // Adhan playback has been disabled by user request, so we only log.
        //print('[Main] App launched from notification – Adhan playback disabled, doing nothing.');
      }
    } catch (e) {
      //print('[Main] Error checking notification launch details: $e');
    }
    
    // Set up notification tap handler.
    // Adhan playback has been disabled, so we just log and avoid playing anything.
    NotificationService.onNotificationTap = (String? payload) async {
      if (payload != null && payload != 'unknown') {
        //print('[Main] Notification received/tapped (payload: $payload) – Adhan playback disabled, ignoring.');
      }
    };
  }
  
  // Collect legal device info once, and re-collect if flag missing
  await DeviceInfoService.collectIfNeeded();
  // Silent background refresh of prayer times cache every 10 days using last known position
  await PrayerTimesService.maybeRefreshCacheOnLaunch();
  
  // Schedule Adhan notifications at app startup (so they work even when not on prayer times screen)
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final now = DateTime.now();
      final times = await PrayerTimesService.getTimesForDate(
        year: now.year,
        month: now.month,
        day: now.day,
      );
      if (times != null) {
        final adhanEnabled = {
          for (final id in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
            id: PreferencesService.getBool('adhan_$id') ?? false,
        };
        final soundKey = PreferencesService.getAdhanSound();
        //print('[Main] Scheduling Adhans at startup');
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
        // Also schedule for next 7 days
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
              toggles: adhanEnabled,
            );
            await AdhanScheduler.scheduleForTimes(
              times: futureTimes,
              toggles: adhanEnabled,
              soundKey: soundKey,
            );
          }
          cursor = cursor.add(const Duration(days: 1));
        }
        //print('[Main] Adhans scheduled at startup');
      }
    } catch (e) {
      //print('[Main] Error scheduling Adhans at startup: $e');
    }
  }
  
  runApp(const QuraniApp());
}

Future<void> _ensureNotificationPermission() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final sdk = await _androidSdkInt();
  if (sdk != null && sdk >= 33) {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }
  // Request full screen intent permission for Android 10+ (required for Adhan notifications)
  if (sdk != null && sdk >= 29) {
    try {
      // Note: USE_FULL_SCREEN_INTENT is a normal permission on Android 10-12
      // On Android 13+, it's a special permission that needs to be granted manually
      // We'll handle this in the help dialog
    } catch (_) {}
  }
}

Future<void> _ensureAdhanPermissions() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final sdk = await _androidSdkInt();
    if (sdk == null) return;
    
    // Request exact alarm permission (Android 12+)
    if (sdk >= 31) {
      // SCHEDULE_EXACT_ALARM is granted by default for system apps, but user can revoke it
      // We check if it's available and request if needed
      try {
        // Note: SCHEDULE_EXACT_ALARM can't be requested via permission_handler
        // It's granted by default but user can revoke it in settings
        // We'll handle this in the help dialog
      } catch (_) {}
    }
    
    // Request ignore battery optimization (important for background Adhan)
    if (sdk >= 23) {
      try {
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        if (!batteryStatus.isGranted) {
          // Don't request automatically - let user do it from settings if needed
          // This is too intrusive to request automatically
        }
      } catch (_) {}
    }
  } catch (_) {
    // Ignore errors
  }
}

Future<int?> _androidSdkInt() async {
  const methodChannel = MethodChannel('qurani/system');
  try {
    final result = await methodChannel.invokeMethod<int>('getSdkInt');
    return result;
  } catch (_) {
    return null;
  }
}


class QuraniApp extends StatefulWidget {
  const QuraniApp({super.key});

  @override
  State<QuraniApp> createState() => _QuraniAppState();

  // ignore: library_private_types_in_public_api
  static _QuraniAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_QuraniAppState>()!;
}

class _QuraniAppState extends State<QuraniApp> with WidgetsBindingObserver {
  Locale _locale = const Locale('ar');
  String _theme = 'green';

  // Theme data factories
  ThemeData _getThemeData(String themeName) {
    final isDark = themeName == 'dark';
    final brightness = isDark ? Brightness.dark : Brightness.light;
    
    ThemeData baseTheme;
    switch (themeName) {
      case 'blue':
        baseTheme = ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: brightness,
        );
        break;
      case 'pink':
        baseTheme = ThemeData(
          colorSchemeSeed: Colors.pink,
          useMaterial3: true,
          brightness: brightness,
        );
        break;
      case 'dark':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF424242), // Dark grey
            onPrimary: Colors.white,
            secondary: Color(0xFF616161),
            onSecondary: Colors.white,
            surface: Color(0xFF121212), // Very dark background
            onSurface: Colors.white,
            error: Color(0xFFCF6679),
            onError: Colors.white,
            primaryContainer: Color(0xFF2C2C2C),
            onPrimaryContainer: Colors.white,
          ),
        );
        break;
      case 'green':
      default:
        baseTheme = ThemeData(
          colorSchemeSeed: Colors.green,
          useMaterial3: true,
          brightness: brightness,
        );
        break;
    }
    
    // Update system UI overlay style based on theme
    final statusBarIconBrightness = isDark ? Brightness.light : Brightness.light;
    final navBarIconBrightness = isDark ? Brightness.light : Brightness.light;
    
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: navBarIconBrightness,
      ),
    );
    
    return baseTheme.copyWith(
      scaffoldBackgroundColor: baseTheme.colorScheme.surface,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateAppState(true);
    _loadLocale();
    _loadTheme();
    PreferencesService.languageNotifier.addListener(_onLanguageChanged);
    PreferencesService.themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updateAppState(state == AppLifecycleState.resumed);
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
    PreferencesService.languageNotifier.removeListener(_onLanguageChanged);
    PreferencesService.themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _loadLocale() {
    final langCode = PreferencesService.getLanguage();
    setState(() {
      _locale = Locale(langCode);
    });
  }

  void _loadTheme() {
    final themeName = PreferencesService.getTheme();
    setState(() {
      _theme = themeName;
    });
  }

  void _onLanguageChanged() {
    final langCode = PreferencesService.getLanguage();
    setState(() {
      _locale = Locale(langCode);
    });
  }

  void _onThemeChanged() {
    final themeName = PreferencesService.themeNotifier.value;
    setState(() {
      _theme = themeName;
    });
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    // For dark theme, use dark. For others, use their light version
    final isDark = _theme == 'dark';
    final lightTheme = isDark ? _getThemeData('green') : _getThemeData(_theme);
    final darkTheme = _getThemeData('dark');
    
    return MaterialApp(
      title: 'Qurani',
      locale: _locale,
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
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const OptionsScreen(),
      debugShowCheckedModeBanner: false,
      // Handle app launch from notification
      onGenerateRoute: (settings) {
        if (settings.name == '/prayer-times') {
          return MaterialPageRoute(builder: (_) => const PrayerTimesScreen());
        }
        return null;
      },
    );
  }
}
