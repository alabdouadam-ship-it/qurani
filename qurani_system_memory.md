# Qurani — System Memory & Architecture Study

> **Status:** Read-only audit — zero code modifications performed.
> **Date:** 2026-04-26

---

## 1. Project Identity

| Field | Value |
|---|---|
| **Domain** | Islamic companion app (Quran reader, Adhan, Qibla, Tasbeeh, Daily Wird, Hadith, Memorization) |
| **Framework** | Flutter 3.x (Dart) |
| **Platforms** | Android, iOS, Web (conditional exports `_io` / `_web`) |
| **Package name** | `qurani` |
| **Locales** | Arabic (default), English, French via `.arb` files |

---

## 2. Project Structure

```
lib/
├── main.dart                   # Entry point, lifecycle observer, cold-start init
├── options_screen.dart         # App dashboard / home grid
├── tasbeeh_screen.dart         # Tasbeeh + Wird two-tab host (852 lines)
├── quran_screen.dart           # Quran reader page
├── responsive_config.dart      # Breakpoints + font scaling
│
├── models/
│   ├── surah.dart              # Lightweight Surah DTO
│   ├── tasbeeh_model.dart      # TasbeehGroup, TasbeehItem
│   ├── wird_model.dart         # Wird (daily dhikr scheduling)
│   └── news_item.dart          # News/announcement model
│
├── providers/
│   └── app_state_providers.dart # Riverpod 2.x codegen bridge to PreferencesService
│
├── services/
│   ├── preferences_service.dart      # Core SharedPreferences wrapper (915 lines)
│   ├── notification_service.dart     # Conditional export stub
│   ├── notification_service_io.dart  # Full notification impl (888 lines)
│   ├── adhan_audio_manager.dart      # Unified Adhan playback engine
│   ├── global_adhan_service.dart     # Foreground 30s poll-based Adhan trigger
│   ├── adhan_scheduler_io.dart       # AndroidAlarmManager background scheduling
│   ├── prayer_times_service.dart     # Adhan calculation
│   ├── quran_repository_io.dart      # SQLite-backed Quran data (LRU cache)
│   ├── quran_database_service.dart   # Shared quran.db opener + schema validation
│   ├── user_database_service.dart    # User-mutable SQLite DB (qurani_user.db)
│   ├── tasbeeh_service.dart          # Tasbeeh CRUD, SQLite-backed
│   ├── wird_service.dart             # Wird CRUD + notification scheduling
│   ├── news_service.dart             # Remote + cached news feed
│   ├── update_service.dart           # In-app update (Android)
│   └── logger.dart                   # Structured logging (debug+release)
│
├── themes/
│   └── app_theme_config.dart   # 10+ themes, WCAG contrast modes
│
├── widgets/
│   ├── wird_tab.dart           # Daily Wird tab UI (1005 lines)
│   ├── wird_edit_sheet.dart    # Add/Edit wird bottom sheet (858 lines)
│   └── modern_ui.dart          # Shared scaffold / card components
│
├── util/
│   └── tajweed_parser.dart     # Tajweed tag → colored InlineSpan
│
└── l10n/                       # ARB locale files
```

---

## 3. Architecture Pattern

**Feature-first modules** with a **static services layer**:

- **UI Screens** are standard `StatefulWidget`s that call static service methods directly. No formal "ViewModel" or "Bloc".
- **State Management**: Transitioning to **Riverpod 2.x** (`riverpod_generator`). Currently, most providers act as thin bridges: they wrap existing `PreferencesService` static getters into Riverpod state so widgets can `watch` them. Legacy `ValueNotifier` is still used in several services (`NewsService.unseenCountNotifier`, `AdhanAudioManager.isPlayingListenable`).
- **Persistence**: Dual-database strategy:
  - `quran.db` — bundled read-only asset (24 MB), managed by `QuranDatabaseService`.
  - `qurani_user.db` — user-mutable SQLite, managed by `UserDatabaseService` (Tasbeeh data).
  - `SharedPreferences` — all settings, Wird data (JSON blob), feature flags.
- **Navigation**: Standard `MaterialPageRoute` pushes from the dashboard grid. No `go_router` in active use.

---

## 4. Key Services

### 4.1 `PreferencesService` (915 lines)
Central disk I/O singleton. All keys, getters, setters, and migration logic live here. Uses a null-safe `_prefs` static field hydrated at `init()`. Contains a dedicated `ensureInitialized()` for background isolates.

### 4.2 `AdhanAudioManager` (391 lines)
The **single authoritative** Adhan playback engine. Three fallback engines:
1. Native Android `MediaPlayer` via `qurani/adhan` MethodChannel
2. `just_audio` from cached file (`adhan_cache/`)
3. `just_audio` from bundled asset

Cross-isolate state sync via `SharedPreferences` (`adhan_is_playing`, `adhan_playing_start_ms`). A 6-minute safety timeout prevents stale "playing" flags.

### 4.3 `NotificationService` (888 lines)
Handles Adhan notifications, News notifications, and Wird reminders. Key design:
- **Notification ID namespacing**: Adhan IDs = `ymd * 10 + prayerCode`; News = `0x50000000 | FNV-1a`; Wird = `0x60000000 | (hash << 3) | weekday`.
- **Wird channel**: `wird_reminders_v2` — silent (no sound, no vibration), default importance. Channel v2 exists because Android locks channel settings after creation.
- **Full-screen intent**: Runtime-probed via `qurani/system` MethodChannel on Android 14+.
- **Graceful degradation**: Exact alarm → inexact alarm fallback on `SCHEDULE_EXACT_ALARM` denial.

### 4.4 `QuranRepository` (621 lines)
Singleton with LRU page cache (32 entries). All reads go through SQLite indexed queries. Supports 7 editions (Simple, Uthmani, Tajweed, English, French, Tafsir, Irab). Auto-reconnects on `database_closed` errors.

### 4.5 `Logger` (144 lines)
Structured logger with 4 levels (debug/info/warn/error). Emits via `dart:developer.log` (survives release builds) + `debugPrint` (debug only). Exposes `onRecord` callback for crash-reporting integration.

---

## 5. Data Models

### 5.1 `Wird` ([wird_model.dart](file:///e:/Flutter/Qurani/Qurani/lib/models/wird_model.dart))

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (UUID) | Stable identity for notifications & persistence |
| `title` | `String` | User-visible name |
| `dhikrText` | `String` | The actual dhikr text (Arabic) |
| `targetCount` | `int` | Goal per day (1–9999) |
| `currentCount` | `int` | Today's progress, auto-reset at midnight |
| `daysOfWeek` | `List<int>` | `DateTime.weekday` values (1=Mon..7=Sun) |
| `notificationsEnabled` | `bool` | Toggle for scheduled reminders |
| `notificationTime` | `TimeOfDay` | Persisted as `"HH:mm"` |
| `lastUpdatedDate` | `DateTime?` | Calendar date only (timezone-safe) |
| `isDeleted` | `bool` | Soft-delete flag |
| `createdAt` | `DateTime` | Stable ordering |

**Design decisions:**
- `lastUpdatedDate` is date-only (`YYYY-MM-DD` string in JSON) to prevent timezone drift on the daily-reset comparison.
- `daysOfWeek` uses Dart-native weekday encoding (1–7) so scheduling arithmetic is direct. The UI reorders chips for Arabic (Saturday-first).
- `isDeleted` keeps soft-deleted rows so in-flight notifications can still render the wird title.

### 5.2 `TasbeehGroup` / `TasbeehItem` ([tasbeeh_model.dart](file:///e:/Flutter/Qurani/Qurani/lib/models/tasbeeh_model.dart))
Simple mutable DTOs. `TasbeehItem.count` is mutated directly for optimistic UI. The fields (`id`, `text`, `count`) have both `toJson()` and SQL backing.

---

## 6. Deep Scan: Tasbeeh & Wird Features

### 6.1 Architecture Overview

The two features share a single screen (`TasbeehScreen`) with a `TabController(length: 2)`:
- **Tab 0**: Classic Tasbeeh groups grid (dhikr counter)
- **Tab 1**: Daily Wird system (scheduled reminders)

They are coupled via a **"Focus Mode"** flow: the Wird tab's "Start" button sets `_activeWird` in the parent, which replaces the Tasbeeh tab body with a full-screen counter dial tied to `WirdService.increment()`.

### 6.2 Tasbeeh System

#### Storage: SQLite (`qurani_user.db`)
- **Tables**: `tasbeeh_groups` + `tasbeeh_items` (FK with `ON DELETE CASCADE`)
- **Why SQLite**: Atomic increments via `UPDATE count = count + 1` — no read-modify-write race on fast tapping. Previous JSON blob approach had to rewrite the entire tree on every tap.
- **Migration**: Three legacy layouts detected and migrated on first run:
  1. `tasbeeh_data_v2` (JSON blob) → SQL
  2. `tasbeeh_phrases` + `tasbeeh_total_counts` (v1 key:value) → SQL
  3. Fresh install → seed 8 default groups with curated adhkar

#### UI Flow
```
_TasbeehScreenState
  ├── _loadData() → TasbeehService.getGroups()
  ├── _incrementCount() → HapticFeedback + optimistic setState + service write
  ├── _sessionCounts (Map) → ephemeral per-session tracking (lost on exit)
  └── GroupTile → ExpansionTile → AzkarItem (tap-to-count)
```

> [!IMPORTANT]
> **Session counts are ephemeral.** `_sessionCounts` lives in widget state and is never persisted. If the user navigates away and comes back, the session counter resets to 0 while the total count survives in SQLite. This is intentional (not a bug) — sessions are meant to be lightweight, per-visit counters.

#### Default Groups (seeded)
| Key | Content |
|---|---|
| `groupMyAzkar` | User's custom dhikr |
| `groupPostPrayerGeneral` | After Dhuhr/Asr/Isha (9 items) |
| `groupPostPrayerFajrMaghrib` | Fajr+Maghrib extras (12 items) |
| `groupMorning` / `groupEvening` | Morning/evening adhkar (8 items each) |
| `groupSleep` | Before-sleep adhkar (6 items) |
| `groupFriday` | Friday-specific (3 items) |

### 6.3 Wird System

#### Storage: SharedPreferences JSON Blob
All wirds (including soft-deleted) stored in a single JSON array under `wirds_v1`. An in-memory `_cache` is read-through: hydrated once on first `getAll()`, then all writes go through `_persist()` which rewrites the blob.

> [!NOTE]
> **Why SharedPreferences (not SQLite)?** The service's own comment: "Wirds are a tiny dataset (dozens at most), so rewriting the whole list on every mutation is cheaper than the operational overhead of a new SQLite table + migration."

#### Daily Reset Logic ([wird_service.dart:225](file:///e:/Flutter/Qurani/Qurani/lib/services/wird_service.dart#L225))
On every `getAll()` call, for each active wird whose `lastUpdatedDate` is strictly before today **AND** today is in the wird's `daysOfWeek`:
- Reset `currentCount = 0`
- Set `lastUpdatedDate = today`
- Wirds not scheduled for today are **left alone** — Friday's progress survives Thursday's rollover.

#### Notification Scheduling ([wird_service.dart:302](file:///e:/Flutter/Qurani/Qurani/lib/services/wird_service.dart#L302))
- **Strategy**: One-shot notifications for the next **14 days** (not recurring `DateTimeComponents.dayOfWeekAndTime`).
- **Why not recurring?** The spec forbids notifying after today's completion. Cancelling a recurring entry kills the following week too, requiring a reschedule that defeats the purpose.
- **14-day window**: A Friday-only wird completed on Friday 13:00 with a 7-day lookahead would schedule nothing (today skipped, days 1–6 don't match). 14 days covers this.
- **ID collision by design**: Notification IDs use `(wirdId hash, weekday)` — only 7 slots per wird. "This Friday" and "next Friday" would collide, so we use a `scheduledWeekdays` set to keep only the **nearest** future occurrence of each weekday.
- **Skip logic**: Today is skipped if wird is already completed OR the notification time has passed.

#### Notification Permissions ([wird_edit_sheet.dart:162](file:///e:/Flutter/Qurani/Qurani/lib/widgets/wird_edit_sheet.dart#L162))
When the reminder switch is flipped ON:
1. `ensureWirdNotificationPermissions()` prompts for `POST_NOTIFICATIONS`
2. If denied → switch snaps back OFF + SnackBar
3. If granted → also opportunistically requests `SCHEDULE_EXACT_ALARM`
4. If exact alarm denied → SnackBar warning about Doze delays

#### Focus Mode Flow
```
WirdTab "Start" button
  → TasbeehScreen._startWird(wird)
    → setState(_activeWird = wird)
    → _tabController.animateTo(0)  // switch to Tasbeeh tab
    → Replaces tab body with _buildFocusMode()
      → InkWell covering full screen
      → _FocusedCounterDial (CircularProgressIndicator + count)
      → Each tap → WirdService.increment(id)
      → On completion → HapticFeedback + SnackBar

"End session" / Back button
  → _exitWirdFocus()
    → setState(_activeWird = null)
    → _tabController.animateTo(1)  // back to Wird tab
    → _wirdTabController.refresh() // reload from disk
```

#### WirdTab Controller Pattern
A lightweight `WirdTabController` class uses `_attach` / `_detach` to hold a reference to the `_WirdTabState`. The parent `TasbeehScreen` can call `openAddSheet()` and `refresh()` without lifting the entire wird state up. This avoids the overhead of a formal `GlobalKey<WirdTabState>`.

#### UI: Two Filter Modes
| Mode | Shows | Card style |
|---|---|---|
| **Today** | `getTodays()` — active today wirds | Progress bar + Start/Resume button. Completed wirds dimmed + sunk to bottom |
| **All** | `getActive()` — every non-deleted wird | Days-of-week pills + target pill. No progress bar, no Start |

The toggle is hidden when every wird is today-active (both modes would show the same cards).

---

## 7. Design System

### Theme Engine
`AppThemeConfig` produces `ThemeData` objects. Supports 10+ named themes including accessibility-first high-contrast variants. All themes are RTL-aware by default.

### Responsive Strategy
`ResponsiveConfig` defines breakpoints by screen width:
- **Compact** (< 600): single-column, standard fonts
- **Medium** (600–900): 2-column grids
- **Expanded** (> 900): 3-column grids, tablet landscape logic

Font scaling: `ResponsiveConfig.getFontSize(context, baseSize)` applies a multiplier.
Global `MediaQuery` text scale clamped to `1.0–1.4` to maintain Arabic diacritic integrity.

### RTL
- DHikr text always forced `textDirection: TextDirection.rtl` regardless of UI locale
- Numeric counters forced `TextDirection.ltr` (ratios like "45 / 100" are locale-independent)
- Day picker order: Arabic → Saturday-first; other locales → Monday-first
- Time picker: Arabic → 24-hour format forced

---

## 8. Lifecycle & Cross-Isolate Coordination

### App Lifecycle Observer (`main.dart`)
Uses `WidgetsBindingObserver` to write `is_app_in_foreground` to SharedPreferences:
- `resumed` → set `true`, reload prefs, sync Adhan playback state
- `paused` / `detached` → set `false`

This flag is the IPC mechanism between the main isolate and the `AndroidAlarmManager` background isolate — the background isolate checks it to decide whether to play Adhan natively or via `just_audio`.

### Cold-Start Sequence
```
main()
  → WidgetsFlutterBinding.ensureInitialized()
  → PreferencesService.init()
  → NotificationService.init()
  → AdhanScheduler.init()          // Android only
  → WirdService.ensureReadyAndReschedule()
  → GlobalAdhanService.init()      // starts 30s poll timer
  → runApp(ProviderScope(child: QuraniApp()))
```

---

## 9. Risk & Fragility Map

### 🔴 Critical

| # | Area | Risk | Location |
|---|---|---|---|
| 1 | **Wird JSON blob** | Single SharedPreferences key stores ALL wirds. A corrupt write (crash mid-persist, disk-full) loses every wird with no recovery. SQLite (like Tasbeeh) would give atomic transactions. | [wird_service.dart:214](file:///e:/Flutter/Qurani/Qurani/lib/services/wird_service.dart#L214) |
| 2 | **Adhan cross-isolate race** | `SharedPreferences.reload()` is the only sync mechanism between isolates. On some OEM ROMs, `reload()` reads a stale disk cache, causing the main isolate to see `adhan_is_playing=true` from a previous session → UI stuck with stop button. | [adhan_audio_manager.dart:204](file:///e:/Flutter/Qurani/Qurani/lib/services/adhan_audio_manager.dart#L204) |
| 3 | **Background isolate cold-start** | `AdhanAudioManager.playAdhan` calls `PreferencesService.ensureInitialized()` but does NOT call `NotificationService.init()`. If the alarm fires and the notification plugin isn't initialized, the "stop adhan" action won't work. | [adhan_audio_manager.dart:84](file:///e:/Flutter/Qurani/Qurani/lib/services/adhan_audio_manager.dart#L84) |

### 🟡 Medium

| # | Area | Risk | Location |
|---|---|---|---|
| 4 | **Wird `_cache` stale across tabs** | `WirdService._cache` is a process-global static. The Tasbeeh tab's focus mode calls `WirdService.increment()` which writes to cache + disk, but the Wird tab's local `_todaysWirds` list holds a stale copy. This is mitigated by `_wirdTabController.refresh()` on focus-exit, but if the user swipes between tabs (without exiting focus) they'll see stale data. | [wird_service.dart:58](file:///e:/Flutter/Qurani/Qurani/lib/services/wird_service.dart#L58) |
| 5 | **Tasbeeh optimistic mutation** | `_incrementCount` mutates `item.count++` directly on the model object. This is a side-effect on the model fetched from `TasbeehService.getGroups()`. If a re-render triggers `_loadData()` mid-session, the in-memory count is lost until the next SQLite read. | [tasbeeh_screen.dart:290](file:///e:/Flutter/Qurani/Qurani/lib/tasbeeh_screen.dart#L290) |
| 6 | **14-day notification cap** | Wird scheduling relies on the user opening the app at least once every 14 days to re-arm. Power users with 5+ wirds × 7 days approach iOS's 64-pending-notification hard cap (≈ 5×7×2 = 70 pending). | [wird_service.dart:334](file:///e:/Flutter/Qurani/Qurani/lib/services/wird_service.dart#L334) |
| 7 | **News notification timing** | `NewsService.getNews()` fires push notifications inline during a data fetch. If the user's first launch after install fetches 10 news items, all 10 notifications fire synchronously. | [news_service.dart:85](file:///e:/Flutter/Qurani/Qurani/lib/services/news_service.dart#L85) |
| 8 | **Database closed retry loops** | `QuranRepository` and `QuranDatabaseService` both have `database_closed` catch clauses that recursively retry with no backoff or attempt limit. A persistent close condition (corrupted WAL, permissions) will stack overflow. | [quran_repository_io.dart:180](file:///e:/Flutter/Qurani/Qurani/lib/services/quran_repository_io.dart#L180) |

### 🟢 Low / Cosmetic

| # | Area | Risk | Location |
|---|---|---|---|
| 9 | **Wird model mutability** | `Wird` fields (`title`, `dhikrText`, `currentCount`, etc.) are non-final. `copyWith` exists but the model allows direct mutation, which could bypass `WirdService._persist()`. | [wird_model.dart:49](file:///e:/Flutter/Qurani/Qurani/lib/models/wird_model.dart#L49) |
| 10 | **TasbeehItem mutability** | Same as above — `TasbeehItem.count` is mutated directly in the UI layer for optimistic updates. | [tasbeeh_model.dart:6](file:///e:/Flutter/Qurani/Qurani/lib/models/tasbeeh_model.dart#L6) |
| 11 | **Legacy prefs migration debt** | `PreferencesService` contains ~15 legacy key migration paths. Some have no cleanup (old keys remain forever). | [preferences_service.dart](file:///e:/Flutter/Qurani/Qurani/lib/services/preferences_service.dart) |
| 12 | **Wird daily reset runs on every `getAll()`** | The reset pass iterates every wird and writes to disk if anything changed. For a user with 20 wirds, opening the Wird tab triggers a full scan + potential disk write. Not expensive today but scales linearly. | [wird_service.dart:225](file:///e:/Flutter/Qurani/Qurani/lib/services/wird_service.dart#L225) |

---

## 10. Special Constraints & Known Behaviors

1. **Adhan playback is disabled in the main loop** per user requirement — the system logs activity but does not trigger playback from the foreground `GlobalAdhanService`.
2. **`MediaQuery` text scale is globally clamped** to `1.0–1.4` to maintain Arabic diacritic rendering integrity.
3. **Installation identity** uses a stable UUID (`installation_id_v1`) in SharedPreferences, not hardware identifiers.
4. **Wird test notifications** (`sendWirdTestNotification`) are gated behind `kDebugMode` in the UI — the button only renders in debug builds.
5. **TajweedParser** handles broken/malformed tag sequences gracefully — strips unmatched brackets and renders as plain text rather than crashing.
6. **Quran DB schema validation** probes column presence at startup; any missing column forces a full re-copy from assets (schema version bump).

---

## 11. Database Schema Reference

### `quran.db` (read-only asset)
```sql
ayah (id PK, surah_order, number_in_surah, juz, page,
      text_simple, text_uthmani, text_tajweed,
      text_english, text_french, text_tafsir)

surah (order_no PK, name_ar, name_en, name_en_translation,
       revelation_type, total_verses)
```

### `qurani_user.db` (user-mutable, schema v1)
```sql
tasbeeh_groups (id TEXT PK, name TEXT, is_custom INT, position INT)

tasbeeh_items (id TEXT PK, group_id TEXT FK→tasbeeh_groups ON DELETE CASCADE,
              text TEXT, count INT DEFAULT 0, position INT)

INDEX idx_tasbeeh_items_group ON tasbeeh_items(group_id, position)
```
