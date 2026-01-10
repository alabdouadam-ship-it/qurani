
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
import 'services/reciter_config_service.dart';
import 'options_screen.dart';
import 'services/notification_service.dart';
import 'services/prayer_times_service.dart';
import 'services/device_info_service.dart';
import 'services/adhan_scheduler.dart';
import 'prayer_times_screen.dart';
import 'services/global_adhan_service.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';

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
      androidNotificationOngoing: true,
    );
    final audioSession = await AudioSession.instance;
    await audioSession.configure(const AudioSessionConfiguration.music());
  }
  await _ensureNotificationPermission();
  await _ensureAdhanPermissions();
  await PreferencesService.init();
  await PreferencesService.ensureInstallationId();
  
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
    
    
    ThemeData baseTheme;
    switch (themeName) {
      case 'gray':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF616175),      // رمادي داكن للـ AppBar
            onPrimary: Colors.white,                // نص أبيض
            secondary: Color(0xFF757575),
            surface: Color(0xFFF5F5F5),       // خلفية
            onSurface: Colors.black87,              // نص
          ),
        );
        break;
      case 'dark':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00796B),           // تركواز داكن
            onPrimary: Colors.white,
            secondary: Color(0xFF004D40),
            surface: Color(0xFF121212),            // خلفية داكنة جداً
            onSurface: Colors.white,
            primaryContainer: Color(0xFF1E1E1E),
            onPrimaryContainer: Colors.white,
          ),
        );
        break;
      case 'gold':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFFFBF0),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFB7950B),           // ذهبي داكن
            onPrimary: Colors.white,
            secondary: Color(0xFFD4AF37),          // ذهبي فاتح
            surface: Color(0xFFFFFBF0),            // خلفية كريمية
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFFFF9E6),
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'orange':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFFF3E0),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFE65100),           // برتقالي داكن
            onPrimary: Colors.white,
            secondary: Color(0xFFFF6F00),
            surface: Color(0xFFFFF3E0),            // خلفية برتقالية فاتحة
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFFFE0B2),
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'purple':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF3E5F5),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4A148C),           // بنفسجي داكن
            onPrimary: Colors.white,
            secondary: Color(0xFF7B1FA2),
            surface: Color(0xFFF3E5F5),            // خلفية بنفسجية فاتحة
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFE1BEE7),
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'brown':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFEFEBE9),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF5D4037),           // بني داكن
            onPrimary: Colors.white,
            secondary: Color(0xFF795548),
            surface: Color(0xFFEFEBE9),            // خلفية بنية فاتحة
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFD7CCC8),
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'lightBlue':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE1F5FE),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0288D1),           // أزرق فاتح
            onPrimary: Colors.white,
            secondary: Color(0xFF03A9F4),
            surface: Color(0xFFE1F5FE),            // خلفية أزرق فاتح جداً
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFB3E5FC),
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'skyBlue':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF0F8FF), // أزرق فاتح جداً (Alice Blue)
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF42A5D5),      // أزرق سماوي أفتح
            onPrimary: Colors.white,                // نص أبيض
            secondary: Color(0xFF64B5F6),     // أزرق سماوي فاتح
            surface: Color(0xFFF0F8FF),       // خلفية فاتحة جداً
            onSurface: Colors.black87,              // نص داكن
            primaryContainer: Color(0xFFE1F5FE), // حاويات بلون أزرق فاتح جداً
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'blueGrey':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFECEFF1),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF546E7A),           // رمادي-أزرق
            onPrimary: Colors.white,
            secondary: Color(0xFF78909C),
            surface: Color(0xFFECEFF1),            // خلفية رمادية-زرقاء فاتحة
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFCFD8DC),
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'teal':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE0F2F1),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF00796B),           // تركواز
            onPrimary: Colors.white,
            secondary: Color(0xFF009688),
            surface: Color(0xFFE0F2F1),            // خلفية تركواز فاتحة
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFB2DFDB),
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'oliveGreen':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF1F8E9),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF558B2F),           // أخضر زيتوني
            onPrimary: Colors.white,
            secondary: Color(0xFF689F38),
            surface: Color(0xFFF1F8E9),            // خلفية خضراء فاتحة
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFDCEDC8),
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'beige':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFFF8E1),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF8D6E63),           // بني فاتح للـ AppBar
            onPrimary: Colors.white,
            secondary: Color(0xFFA1887F),          // بني أفتح
            surface: Color(0xFFFFF8E1),            // خلفية بيج فاتحة
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFFFECB3),   // حاويات بيج فاتح جداً
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;
      case 'green':
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE8F5E9), // أخضر فاتح جداً
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2E7D32),           // أخضر داكن
            onPrimary: Colors.white,
            secondary: Color(0xFF43A047),         // أخضر متوسط
            surface: Color(0xFFE8F5E9),            // خلفية خضراء فاتحة
            onSurface: Colors.black87,
            primaryContainer: Color(0xFFC8E6C9),   // حاويات خضراء فاتحة
            onPrimaryContainer: Colors.black87,
          ),
        );
        break;

      default:
        baseTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF0F8FF), // أزرق فاتح جداً (Alice Blue)
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF42A5D5),      // أزرق سماوي أفتح
            onPrimary: Colors.white,
            secondary: Color(0xFF64B5F6),     // أزرق سماوي فاتح
            surface: Color(0xFFF0F8FF),       // خلفية فاتحة جداً
            onSurface: Colors.black87,              // نص داكن
            primaryContainer: Color(0xFFE1F5FE), // حاويات بلون أزرق فاتح جداً
            onPrimaryContainer: Colors.black87,
          ),
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
