import 'dart:convert';
import 'dart:ui' as ui;
// TODO: Replace 'dart:html' with 'package:web/web.dart' and 'dart:js_interop' when all dependencies migrate. Using 'dart:html' for now for browser info collection; safe to ignore info-level warning in analyzer.
// ignore: deprecated_member_use
import 'dart:html' as html;

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

  static Future<Map<String, dynamic>> _buildInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    final locale = ui.PlatformDispatcher.instance.locale;
    final tzName = DateTime.now().timeZoneName;
    final tzOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    final nav = html.window.navigator;
    final screen = html.window.screen;

    return <String, dynamic>{
      'app': {
        'appName': pkg.appName,
        'packageName': pkg.packageName,
        'version': pkg.version,
        'buildNumber': pkg.buildNumber,
      },
      'installationId': PreferencesService.getInstallationId(),
      'platform': {
        'os': 'web',
        'userAgent': nav.userAgent,
        'platform': nav.platform,
        'language': nav.language,
        'hardwareConcurrency': nav.hardwareConcurrency,
        'screen': {
          'width': screen?.width,
          'height': screen?.height,
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


