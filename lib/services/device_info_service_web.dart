import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;
import 'package:web/web.dart' as web;

import 'package:package_info_plus/package_info_plus.dart';

import 'preferences_service.dart';

class DeviceInfoService {
  static Future<void> collectIfNeeded() async {
    final already = PreferencesService.isDeviceInfoCollected();
    if (already) return;
    final info = await _buildInfo();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(info);
    await PreferencesService.saveDeviceInfoJson(jsonStr);
    await PreferencesService.setDeviceInfoCollected(true);
  }

  /// Detects whether the web build is running inside a Telegram Mini App.
  ///
  /// Telegram injects `window.Telegram.WebApp` into the Mini-App page, so its
  /// presence is the primary, reliable signal. We also accept two weaker
  /// fallbacks (user-agent containing "Telegram", or a `tgWebApp*` launch
  /// param in the URL) in case the object isn't ready yet on some clients.
  /// All checks are wrapped — any interop failure just returns false (→ "web").
  static bool _isInTelegram() {
    try {
      final telegram = globalContext['Telegram'];
      if (telegram.isDefinedAndNotNull && telegram is JSObject) {
        if (telegram.has('WebApp')) return true;
      }
    } catch (_) {}
    try {
      final ua = web.window.navigator.userAgent.toLowerCase();
      if (ua.contains('telegram')) return true;
    } catch (_) {}
    try {
      final href = web.window.location.href.toLowerCase();
      if (href.contains('tgwebapp')) return true;
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>> _buildInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    final locale = ui.PlatformDispatcher.instance.locale;
    final tzName = DateTime.now().timeZoneName;
    final tzOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    final nav = web.window.navigator;
    final screen = web.window.screen;

    // A Telegram Mini App runs our web build inside Telegram's in-app browser.
    // Report it as a distinct platform ('telegram') so it's counted separately
    // from regular web in stats, while keeping `host: 'web'` to record that the
    // underlying runtime is still the web build.
    final inTelegram = _isInTelegram();

    return <String, dynamic>{
      'app': {
        'appName': pkg.appName,
        'packageName': pkg.packageName,
        'version': pkg.version,
        'buildNumber': pkg.buildNumber,
      },
      'installationId': PreferencesService.getInstallationId(),
      'platform': {
        'os': inTelegram ? 'telegram' : 'web',
        'host': 'web',
        'userAgent': nav.userAgent,
        'platform': nav.platform,
        'language': nav.language,
        'hardwareConcurrency': nav.hardwareConcurrency,
        'screen': {
          'width': screen.width,
          'height': screen.height,
          'pixelRatio': ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio,
        },
      },
      'locale': {
        'languageCode': locale.languageCode,
        'countryCode': locale.countryCode,
        'preferredLanguage': PreferencesService.getLanguage(),
      },
      'timezone': {
        'name': tzName,
        'offsetMinutes': tzOffsetMinutes,
      },
      'collectedAt': DateTime.now().toIso8601String(),
    };
  }
}


