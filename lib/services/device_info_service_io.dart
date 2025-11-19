import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'preferences_service.dart';

class DeviceInfoService {
  static const String _fileName = 'device_info.json';

  static Future<void> collectIfNeeded() async {
    final already = PreferencesService.isDeviceInfoCollected();
    if (already) {
      // If the file was deleted but flag exists, re-create file for consistency
      final file = await _deviceInfoFile();
      if (!await file.exists()) {
        final existingJson = PreferencesService.getDeviceInfoJson();
        if (existingJson != null && existingJson.isNotEmpty) {
          await file.writeAsString(existingJson);
        }
      }
      return;
    }
    final info = await _buildInfo();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(info);
    try {
      final file = await _deviceInfoFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonStr);
    } catch (_) {
      // If writing file fails, at least persist JSON to preferences
    }
    await PreferencesService.saveDeviceInfoJson(jsonStr);
    await PreferencesService.setDeviceInfoCollected(true);
  }

  static Future<File> _deviceInfoFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<Map<String, dynamic>> _buildInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    final Map<String, dynamic> platform = <String, dynamic>{};

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await deviceInfo.androidInfo;
          platform.addAll({
            'os': 'android',
            'version': a.version.release,
            'sdkInt': a.version.sdkInt,
            'manufacturer': a.manufacturer,
            'model': a.model,
            'isPhysicalDevice': a.isPhysicalDevice,
          });
          break;
        case TargetPlatform.iOS:
          final i = await deviceInfo.iosInfo;
          platform.addAll({
            'os': 'ios',
            'systemName': i.systemName,
            'systemVersion': i.systemVersion,
            'model': i.utsname.machine,
            'isPhysicalDevice': i.isPhysicalDevice,
          });
          break;
        case TargetPlatform.macOS:
          final m = await deviceInfo.macOsInfo;
          platform.addAll({
            'os': 'macos',
            'arch': m.arch,
            'model': m.model,
            'osRelease': m.osRelease,
          });
          break;
        case TargetPlatform.windows:
          final w = await deviceInfo.windowsInfo;
          platform.addAll({
            'os': 'windows',
            'computerName': w.computerName,
            'numberOfCores': w.numberOfCores,
            'systemMemoryInMegabytes': w.systemMemoryInMegabytes,
          });
          break;
        case TargetPlatform.linux:
          final l = await deviceInfo.linuxInfo;
          platform.addAll({
            'os': 'linux',
            'name': l.name,
            'version': l.version,
            'machineId': l.machineId,
          });
          break;
        case TargetPlatform.fuchsia:
          platform.addAll({'os': 'fuchsia'});
          break;
      }
    } catch (_) {
      platform.addAll({'os': defaultTargetPlatform.name});
    }

    final locale = ui.PlatformDispatcher.instance.locale;
    final tzName = DateTime.now().timeZoneName;
    final tzOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    return <String, dynamic>{
      'app': {
        'appName': pkg.appName,
        'packageName': pkg.packageName,
        'version': pkg.version,
        'buildNumber': pkg.buildNumber,
      },
      'installationId': PreferencesService.getInstallationId(),
      'platform': platform,
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


