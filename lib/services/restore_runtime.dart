import 'package:flutter/foundation.dart';
import 'preferences_service.dart';
import 'adhan_scheduler.dart';
import 'adhan_schedule_logic.dart';
import 'notification_service.dart';
import 'wird_service.dart';
import 'prayer_times_service.dart';
import 'global_adhan_service.dart';

Future<void> refreshRuntimeAfterRestore() async {
  await PreferencesService.init();
  if (kIsWeb) return;
  GlobalAdhanService.pause();
  try {
    await AdhanScheduler.cancelScheduledWindow();
    final pending =
        await NotificationService.plugin.pendingNotificationRequests();
    for (final item in pending) {
      if (item.payload?.startsWith('wird_') == true) {
        await NotificationService.plugin.cancel(item.id);
      }
    }
    await PrayerTimesService.maybeRefreshCacheOnLaunch();
    final now = DateTime.now();
    final toggles = {
      for (final p in AdhanScheduleLogic.adhanPrayers)
        p: PreferencesService.getBool('adhan_$p') ?? false
    };
    for (var i = 0; i < 8; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final times = await PrayerTimesService.getTimesForDate(
          year: d.year, month: d.month, day: d.day);
      if (times != null) {
        await AdhanScheduler.scheduleForTimes(
            times: times,
            toggles: toggles,
            soundKey: PreferencesService.getAdhanSound());
      }
    }
    await WirdService.rescheduleAll();
  } finally {
    await GlobalAdhanService.resume();
  }
}
