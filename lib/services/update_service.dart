import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/preferences_service.dart';

class UpdateService {
  static const String _keyLastAttemptEpoch = 'update_last_attempt_epoch';
  static const String _keyLastSuccessEpoch = 'update_last_success_epoch';
  static const String _keyLastNotifyEpoch = 'update_last_notify_epoch';

  static Future<void> maybeCheckForUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final DateTime today = _stripTime(DateTime.now().toUtc());
    final int todayEpoch = today.millisecondsSinceEpoch;

    final int lastAttempt = PreferencesService.getInt(_keyLastAttemptEpoch) ?? 0;
    if (_isSameDayEpoch(lastAttempt, todayEpoch)) {
      return; // attempted today already
    }

    // Only one successful check per Sunday-anchored week
    final int lastSuccess = PreferencesService.getInt(_keyLastSuccessEpoch) ?? 0;
    final DateTime weekStart = _sundayOf(today);
    if (lastSuccess >= weekStart.millisecondsSinceEpoch) {
      return; // already checked this week
    }

    // Record attempt day to avoid repeated attempts today
    await PreferencesService.setInt(_keyLastAttemptEpoch, todayEpoch);

    try {
      final info = await InAppUpdate.checkForUpdate();
      // Mark weekly success regardless of availability if the API call succeeds
      await PreferencesService.setInt(_keyLastSuccessEpoch, todayEpoch);

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await _notifyOncePerDay(context);
      }
    } catch (_) {
      // ignore: network or Play services errors; will retry next day within this week
    }
  }

  static Future<void> _notifyOncePerDay(BuildContext context) async {
    final DateTime today = _stripTime(DateTime.now().toUtc());
    final int todayEpoch = today.millisecondsSinceEpoch;
    final int lastNotify = PreferencesService.getInt(_keyLastNotifyEpoch) ?? 0;
    if (_isSameDayEpoch(lastNotify, todayEpoch)) return;

    await PreferencesService.setInt(_keyLastNotifyEpoch, todayEpoch);

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.updateAvailable),
        action: SnackBarAction(
          label: l10n.updateNow,
          textColor: theme.colorScheme.onPrimary,
          onPressed: () async {
            try {
              await InAppUpdate.performImmediateUpdate();
            } catch (_) {
              // If immediate update fails, ignore; user will be prompted again tomorrow
            }
          },
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static DateTime _stripTime(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

  static DateTime _sundayOf(DateTime dt) {
    // Dart weekday: Monday=1..Sunday=7. For Sunday-anchored week, subtract (weekday % 7)
    final int daysSinceSunday = dt.weekday % 7; // Sunday -> 0, Monday -> 1, ...
    return _stripTime(dt.subtract(Duration(days: daysSinceSunday)));
  }

  static bool _isSameDayEpoch(int aMs, int bMs) {
    if (aMs == 0 || bMs == 0) return false;
    final a = DateTime.fromMillisecondsSinceEpoch(aMs, isUtc: true);
    final b = DateTime.fromMillisecondsSinceEpoch(bMs, isUtc: true);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}


