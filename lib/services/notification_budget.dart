/// Pure, platform-agnostic notification-budget arithmetic.
///
/// No plugins, no I/O, no platform channels — every function here is a pure
/// function of its inputs, so it is unit-testable in isolation (see the
/// system-memory "testability" goal for the notification subsystem).
///
/// ### Why this exists
///
/// iOS (`UNUserNotificationCenter`) silently caps the number of *pending*
/// (scheduled-for-the-future) notifications at **64**. Anything beyond that is
/// dropped with no error, and you cannot predict which producer loses entries.
///
/// The app has two independent producers of *scheduled* notifications that
/// both run on iOS:
///   * **Adhan** — `(today + 7 days) × enabled prayers`, up to 8 × 5 = 40.
///   * **Wird** — a 7-day rolling window, ≤7 per reminder-enabled wird.
///
/// (News notifications use `plugin.show()` — they fire immediately and never
/// occupy a pending slot, so they are intentionally excluded from this math.)
///
/// A committed user (all 5 prayers + several daily wird reminders) can exceed
/// 64 and silently lose notifications. To keep both producers correct
/// *together*, Adhan keeps its full week (time-critical religious obligation)
/// and Wird's per-wird day-horizon is shrunk uniformly to fit the remaining
/// budget — so every wird still gets *some* upcoming days rather than a few
/// wirds getting a full week and the rest getting nothing.
class NotificationBudget {
  const NotificationBudget._();

  /// Hard iOS pending-notification ceiling.
  static const int iosPendingCap = 64;

  /// Slots held back from scheduling for the ongoing Adhan stop-notification
  /// (id `9999999`) and any transient one-shots (e.g. a wird test). Keeping a
  /// small reserve means a transient post can never tip us over the hard cap.
  static const int iosReservedSlots = 4;

  /// Budget actually available for *scheduled* content on iOS.
  static const int iosUsable = iosPendingCap - iosReservedSlots; // 60

  /// Sentinel "no practical cap" budget for platforms without a hard limit
  /// (Android, web). Large enough that [wirdDayHorizon] always returns 7.
  static const int unlimited = 1 << 30;

  /// Number of pending Adhan notifications the scheduler creates for a full
  /// pass: `(today + 7 future days) × enabledPrayerCount`. This is the
  /// conservative maximum (today often has fewer remaining prayers), which is
  /// the safe assumption when reserving budget.
  static int adhanPendingFor(int enabledPrayerCount) {
    final n = enabledPrayerCount < 0 ? 0 : enabledPrayerCount;
    return n * 8;
  }

  /// The uniform per-wird day-horizon (clamped to `1..7`) that keeps
  /// `adhanPendingFor(enabledPrayerCount) + reminderWirdCount * horizon`
  /// within [usable].
  ///
  /// * Returns `7` (the full rolling window, i.e. current behavior) when there
  ///   are no reminder wirds or when [usable] is effectively unlimited.
  /// * Never returns less than `1`: even under maximum Adhan pressure each
  ///   reminder wird keeps at least its nearest upcoming occurrence, because a
  ///   reminder that fires *some* days is far better than one that never fires.
  ///
  /// [usable] is the platform's usable scheduled-notification budget — pass
  /// [iosUsable] on iOS and [unlimited] elsewhere.
  static int wirdDayHorizon({
    required int enabledPrayerCount,
    required int reminderWirdCount,
    required int usable,
  }) {
    if (reminderWirdCount <= 0) return 7;
    final remaining = usable - adhanPendingFor(enabledPrayerCount);
    if (remaining <= 0) return 1; // Adhan saturates the budget.
    final perWird = remaining ~/ reminderWirdCount;
    if (perWird < 1) return 1;
    if (perWird > 7) return 7;
    return perWird;
  }
}
