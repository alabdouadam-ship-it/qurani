import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'responsive_config.dart';
import 'services/preferences_service.dart';
import 'options_screen.dart';
import 'settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'qurani_player',
    androidNotificationChannelName: 'Qurani Playback',
    androidNotificationChannelDescription: 'Qurani audio playback controls',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/launcher_icon',
    androidResumeOnClick: true,
  );
  final audioSession = await AudioSession.instance;
  await audioSession.configure(const AudioSessionConfiguration.music());
  await _ensureNotificationPermission();
  await PreferencesService.init();
  runApp(const QuraniApp());
}

Future<void> _ensureNotificationPermission() async {
  if (!Platform.isAndroid) return;
  final sdk = await _androidSdkInt();
  if (sdk != null && sdk >= 33) {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
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

  static _QuraniAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_QuraniAppState>()!;
}

class _QuraniAppState extends State<QuraniApp> {
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
            background: Color(0xFF121212),
            onBackground: Colors.white,
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
    _loadLocale();
    _loadTheme();
    PreferencesService.languageNotifier.addListener(_onLanguageChanged);
    PreferencesService.themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
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
    );
  }
}
