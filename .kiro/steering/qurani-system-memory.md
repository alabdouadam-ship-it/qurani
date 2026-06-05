---
inclusion: always
---

# Qurani — System Memory Summary

Internal architecture map used to guide all future work on this codebase.
Read-only study; no behavior described here should be changed without explicit intent.

## 1. What the app is
Qurani (`pubspec` name `qurani`, v1.0.9+51) is a production Islamic companion app:
full Quran (multiple editions/translations), audio recitation (online + offline
download), prayer times + Adhan notifications, Qibla finder, Tasbeeh, Wird (daily
dhikr), memorization tools, Hadith library, and news. Targets Android (primary),
iOS, and Web. Arabic / English / French; Arabic is the default locale and RTL.
Core Quran text + reading works offline; audio/prayer-times/news need network.

## 2. Architecture pattern (high level)
- **No formal layered/Clean architecture and NO go_router.** Navigation is
  **imperative `Navigator.push(MaterialPageRoute(...))`** from `OptionsScreen`
  (the home hub, set as `MaterialApp.home`). Only one named route exists:
  `/prayer-times` via `onGenerateRoute`.
- Effective layers by convention:
  - **UI**: top-level `*_screen.dart` files in `lib/` + helper widget folders
    (`lib/widgets/`, `lib/read_quran/`, `lib/audio_player/`).
  - **State**: Riverpod (codegen `@riverpod`) for a SMALL slice of global state.
    Most screen state is plain `StatefulWidget`/`ConsumerStatefulWidget` +
    `setState`. `ValueNotifier`s and `just_audio` streams carry the rest.
  - **Services** (`lib/services/`): static-method or singleton classes holding
    all business logic, persistence, and platform/network access.
  - **Models** (`lib/models/`): plain data classes; some json_serializable.
- **Platform split via conditional exports**: `X.dart` does
  `export 'X_io.dart' if (dart.library.html) 'X_web.dart';`. Web variants are
  usually stubs/no-ops. Applies to: prayer_times_service, adhan_scheduler,
  notification_service, audio_service, download_service, offline_audio_service,
  device_info_service, net_utils, media_item_compat, quran_repository,
  surah_service, quran_search_service, local_webview_screen.
  **When editing one of these, check ALL THREE files (.dart facade, _io, _web)
  and keep enums/models in sync — `QuranEdition`/`PageData`/`AyahData` are
  defined TWICE (io + web) and must be hand-synced.**

## 3. State management (Riverpod) — the global providers
All use codegen (`*.g.dart`, `riverpod_generator`). After editing a provider,
run `dart run build_runner build --delete-conflicting-outputs`.
- `providers/app_state_providers.dart`:
  - `localeProvider` (alias of `localeNotifierProvider`) — `Locale`, persisted via `PreferencesService.saveLanguage`.
  - `themeProvider` (alias of `themeNotifierProvider`) — theme id `String`.
  - `disabledScreensProvider` — `Set<String>` of hidden home-menu screen ids.
  - Aliases exist because codegen renames classes to avoid `Locale`/`Theme` collisions; keep the `final xProvider = xNotifierProvider;` aliases.
- `providers/reader_prefs_providers.dart`: `arabicFontProvider` — mirrors `PreferencesService.arabicFontNotifier` (ValueNotifier → Riverpod).
- `providers/audio_providers.dart`: `queueProvider` — mirrors `QueueService().queueNotifier` (`List<int>` surah orders).
- `providers/news_provider.dart`: `newsProvider` (AsyncNotifier), `unreadNewsIds`, `savedNewsIds`, `unseenNewsCount`, `hiddenNewsIds`.
- **Pattern**: several providers are *mirrors* of an underlying `ValueNotifier`
  (writes go through the service/notifier, the provider only reflects state).
  Don't add a competing write path.

## 4. Persistence — three stores (know which is which)
1. **SharedPreferences** via `PreferencesService` (static, `init()` in `main`):
   the catch-all KV store. Holds: language, theme, reciter, font size/family,
   editions, last-read page, **ayah highlights** (`highlighted_ayahs_colors`
   JSON) + **PDF page bookmarks** (`highlighted_pdf_pages`), audio bookmarks
   (`audio_bookmarks_list_v1` JSON), playback positions, history, download
   flags/pause-state/integrity cache, prayer adjustments, adhan toggles
   (`adhan_<prayer>`)/sound/volume, installation id, memorization stats, and the
   cross-isolate Adhan flags. `ensureInitialized()` is the lightweight hydration
   used by the background alarm isolate (which never runs `main`).
2. **Bundled read-only SQLite** `assets/data/quran.db` via
   `QuranDatabaseService` (single shared handle, schema v3). Tables: `ayah`
   (`id` global PK, `surah_order`, `number_in_surah`, `juz`, `page`,
   `text_simple/uthmani/tajweed/english/french/tafsir`, `normalized`) and
   `surah` (`order_no` PK, `name_ar/en/en_translation`, `revelation_type`,
   `total_verses`). Shared by `QuranRepository`, `SurahService`,
   `QuranSearchService`. Copy-from-asset + schema-probe + re-copy on mismatch.
   `database_closed` errors are recovered by string-matching + bounded retry.
3. **Writable SQLite** `qurani_user.db` via `UserDatabaseService`
   (schema v2, `PRAGMA foreign_keys=ON`, append-only `_migrations`). Tables:
   `tasbeeh_groups`, `tasbeeh_items` (FK CASCADE), `wirds` (soft-delete
   `is_deleted`). **Never edit an existing migration — append a new one.**
- Web has no SQLite: `quran_repository_web` loads bundled `quran-*.json`.
- **NOT in user DB**: memorization stats, highlights, audio bookmarks — those
  are all SharedPreferences JSON.

## 5. Lifecycle flow (critical, fragile)
### App startup (`main.dart`)
`WidgetsFlutterBinding.ensureInitialized` → Pdfrx cache dir → (mobile)
`JustAudioBackground.init` + AudioSession → notification/adhan permission
requests → `PreferencesService.init` + `ensureInstallationId` → **force-reset
`is_app_in_foreground=false`** (guards against force-kill leaving it stale) →
`ReciterConfigService.loadReciters` → `NotificationService.init` →
`AdhanScheduler.init` → `GlobalAdhanService.init` → notification-launch/tap
handlers (Adhan auto-play intentionally disabled) →
`DeviceInfoService.collectIfNeeded` → `PrayerTimesService.maybeRefreshCacheOnLaunch`
→ `runApp(ProviderScope(QuraniApp))`. **Deferred after first frame**
(`unawaited(Future.microtask(...))`): `_scheduleSevenDaysOfAdhans` (Android) and
`WirdService.ensureReadyAndReschedule` (all platforms).

### `QuraniApp` (ConsumerStatefulWidget + WidgetsBindingObserver)
- `initState`: sets `is_app_in_foreground=true`, applies system UI overlay once via post-frame callback.
- `build`: watches `localeProvider`/`themeProvider`; `ref.listen(themeProvider)` re-applies overlay only on change (keeps `setSystemUIOverlayStyle` out of hot path). Clamps OS text scale to `[1.0, 1.4]`. `themeMode` derived from `currentTheme.isDark`.
- `didChangeAppLifecycleState`: writes `is_app_in_foreground` (`true` only on `resumed`); on resume calls `AdhanAudioManager.syncPlayingStateFromPrefs()`.
- `dispose`: removes observer, sets foreground flag false.

### Adhan background pipeline (most fragile area)
- **Cross-isolate via SharedPreferences**: `is_app_in_foreground`,
  `adhan_is_playing`, `adhan_playing_start_ms`, `adhan_playing_prayer_id`.
- `AndroidAlarmManager.oneShotAt(exact, wakeup, allowWhileIdle)` fires
  `@pragma('vm:entry-point') _playAdhanCallback` in a **separate isolate** that
  never ran `main`; it hydrates prefs, re-checks the `adhan_<prayer>` toggle,
  pre-caches the audio file, calls `AdhanAudioManager.playAdhan`, shows the
  stop-notification (id 9999999), then **blocks on `awaitCurrentSession(6min)`**
  so the isolate isn't torn down mid-Adhan.
- `AdhanAudioManager.playAdhan` engine order: (1) native Android MediaPlayer via
  `MethodChannel('qurani/adhan')` (only when an Activity is alive = warm
  foreground), (2) `just_audio` cached file `<docs>/adhan_cache/<key>[-fajr].mp3`,
  (3) `just_audio` bundled asset. `isPlayingListenable` (ValueNotifier) is the
  in-isolate truth; reconciled with prefs on resume; stale flags cleared after
  6 min (`_maxAdhanDuration`) or 30s-orphan check.
- **7-day scheduling has THREE entry points** (`main`,
  `maybeRefreshCacheOnLaunch`, `prayer_times_screen._rescheduleAllAdhans`) all
  guarded by one dedup triple in prefs
  (`adhan_last_scheduled_through_day/_sound_hash/_toggles_hash`).
  `shouldScheduleThroughDay` / `markScheduledThroughDay` /
  `invalidateScheduling` (call `invalidateFirst:true` after the user changes
  sound/toggles). Without invalidation, scheduling short-circuits.
- **Known quirks (do not "fix" silently):** `is_app_in_foreground` is written
  but has **no reader** (intended stop-notification suppression was never
  wired). `GlobalAdhanService` runs a 30s `Timer.periodic` that never stops and
  can race with the alarm isolate (deduped only by the playing flag).
  `_rescheduleAllAdhans` uses DST-unsafe `add(Duration(days:1))` whereas
  `main`/`maybeRefresh` use DST-safe `DateTime(y,m,d+1)`.

## 6. Audio playback model
- **No singleton player.** Each screen owns its own `just_audio` `AudioPlayer`
  (audio_player_screen `_player`, read_quran `_pagePlayer`, search,
  repetition_range `_previewPlayer`, prayer_times preview, plus
  AdhanAudioManager's static players). Only the OS audio session coordinates
  them → two screens *can* play at once.
- `AudioService` (static) only builds URLs (`https://www.qurani.info/...NNN.mp3`)
  / `AudioSource`s and resolves local-preferred file paths. `MediaItem` comes
  from `media_item_compat` (io = just_audio_background; web = local stub).
- **Two queue concepts**: `QueueService` (singleton `List<int>` + notifier,
  surface for the UI "play next" queue) vs the actual playback
  `ConcatenatingAudioSource` **sliding window `[Previous, Current, Next]`** that
  `audio_player_screen._onCurrentIndexChanged` self-heals (cull/insert) on every
  track change, guarded by a monotonic `_playbackGeneration` counter against
  stale async writes. `ConcatenatingAudioSource` is a deprecated just_audio API.
- **Downloads** (`download_service_io`): `<docs>/qurani/full/<reciter>/NNN.mp3`
  (legacy `<docs>/full/<reciter>` still read), ayahs at
  `<docs>/ayahs/<folder>/SSSVVV.mp3`. `.part` temp + HTTP Range resume +
  exp-backoff retry + MP3 magic-byte validation + atomic rename; 4-worker pool.
  Integrity cache keyed size+mtime in prefs (`verified_full_<reciter>`).
  Pause/resume persisted (`bulk_paused_full_<reciter>`, per-surah paused list).

## 7. Quran reading subsystem
- `ReadQuranScreen` (ConsumerStatefulWidget), 604 pages. Two modes:
  - **Text mode**: `PageView.builder` → `_buildPageContent`/`_buildAyahTile`.
    Uses `TajweedParser.parseSpans` (tajweed edition) / `buildPlainSpans`
    (colors diacritics separately). For `QuranEdition.irab` renders
    `IrabVerseWidget`. Has its OWN unbounded screen-level `_pageCache`
    (separate from repository's bounded LRU of 32).
  - **PDF (mushaf) mode**: `pdfrx` `PdfDocument.openFile`, RTL `PageView`,
    `ZoomablePdfPage` (InteractiveViewer, KeepAlive). PDFs downloaded by
    `MushafPdfService` (blue/green/tajweed) from `https://qurani.info/data/pdfs/`.
    **Hardcoded page offsets** (blue/green=3, tajweed=9) convert Quran↔PDF index
    in several spots — keep them in sync.
- `QuranEdition` enum: `simple, uthmani, tajweed, english, french, tafsir, irab`
  (irab uses `text_simple` for audio). `isRtl/isTranslation/isTafsir/isIrab`.
- Search (`QuranSearchService`): Arabic uses precomputed `normalized` column with
  `instr()`; en/fr use `LOWER(col) LIKE`. Note leftover debug queries/prints in io.
- Two normalizers exist with intentionally different folding rules:
  `QuranSearchService.normalize` vs `util/text_normalizer.dart`.
- `IrabService` parses `assets/data/MASAQ.csv` (or downloaded) in a `compute()`
  isolate; cached by `"surah:verse"`.

## 8. Design system
- **Themes** (`themes/app_theme_config.dart`): 10 `AppThemeOption`s (skyBlue
  default, green, emerald, royalPurple, warmSand, dark/"Deep Night",
  roseGold, tealOcean, + High Contrast Light/Dark targeting WCAG AAA). Each
  defines primary/accent/text/surface/card/gradient + brightness. Legacy theme
  ids aliased via `legacyThemeAliases`; always go through `resolveThemeId`.
  `themeDataFor` builds Material3 `ThemeData` (rounded 18-24 radii, transparent
  AppBar, floating snackbars). Theme is a full light/dark swap, not just
  `ThemeMode` — `themeMode` is derived from the selected option's brightness.
- **Color tokens**: consumed via `Theme.of(context).colorScheme`
  (primary/secondary/surface/primaryContainer/onSurface/outline). Avoid
  hardcoded colors; gradients use primary→secondary or container alpha blends.
- **Typography**: Material text theme tinted by `textColor`. Arabic Quran fonts
  via `ArabicFontUtils`: `Amiri Quran` (default), `KFGQPCHafsSmall`,
  `KFGQPCHafsLarge` (keys `amiri_quran`/`kfgqpc_hafs_small`/`kfgqpc_hafs_large`,
  normalized in `PreferencesService`). Font size steps 16/20/24/28 (default 24).
- **Reusable components** (`widgets/modern_ui.dart`): `ModernPageScaffold`
  (gradient + SafeArea + AppBar — the standard screen wrapper),
  `ModernHeroHeader`, `ModernSurfaceCard`, `ModernFeatureTile` (home grid tile,
  haptic, badge), `ModernFilterChip`. Other shared widgets: `SurahGrid`,
  `EmptyStateView`, `ThemeCard`/`ThemeSelector`, `NewsCard`, `SoundEqualizer`,
  `IrabVerseWidget`, wird widgets, share sheets.
- **Spacing/responsive** (`responsive_config.dart`): width tiers small<360 /
  medium / large≥600 / tablet≥768 / landscapeTablet≥960&landscape. Use
  `ResponsiveConfig.getFontSize/getPadding/getGridColumnCount/isSmallScreen`
  rather than raw MediaQuery widths.
- **Dark mode**: per-theme `brightness`; widgets branch on
  `theme.brightness == Brightness.dark` for alpha/elevation tuning.
- **RTL**: driven by locale (Arabic) through `GlobalMaterialLocalizations`.
  Reading screens additionally wrap content in explicit `Directionality` based
  on `edition.isRtl`; use `AlignmentDirectional`/`EdgeInsetsDirectional` and
  `edition.isRtl` for ayah layout.
- **Animations**: theme transition 320ms easeOutCubic; tile/chip 200ms;
  ayah highlight `TweenAnimationBuilder` 250ms; haptics on grid/chip taps.

## 9. Networking & external dependencies
- `dio` + `http` for: Aladhan prayer-times API
  (`api.aladhan.com/v1/calendar/...`), audio/PDF/hadith/irab downloads from
  `qurani.info`. **News & reciters are Supabase-only now** (no remote JSON
  fetch): news = Supabase `news_items` → SharedPreferences cache → nothing
  (no bundled asset; `news_initial.json` removed). Reciters = Supabase
  `reciters` → cache → bundled `assets/data/reciters.json`. Empty DB result
  is treated as "no data" so the cache/bundled fallback is preserved.
- `geolocator` + `geocoding` for location/method resolution; `flutter_qiblah`
  for compass. `flutter_local_notifications` + `android_alarm_manager_plus` +
  `timezone`/`flutter_timezone` for alarms. `just_audio(_background)` +
  `audio_session`. `in_app_update` (Android update prompts). `webview_flutter`
  + `pdfrx` for HTML docs/mushaf. `permission_handler`, `wakelock_plus`,
  `screenshot`, `share_plus`, `url_launcher`.
- Two MethodChannels to native: `qurani/system` (`getSdkInt`,
  `canUseFullScreenIntent`) and `qurani/adhan` (native MediaPlayer
  `playAdhan`/`stopAdhan` + `adhanPlaybackEnded` callback).

## 10. Performance-sensitive screens
- `ReadQuranScreen`: tajweed span parsing on every ayah build (no memoization);
  unbounded screen-level page cache; `ZoomablePdfPage` keep-alive accumulates
  rasterized PDF pages across a 604-page PageView.
- `audio_player_screen`: intricate sliding-window playlist mutation on every
  index change.
- `OptionsScreen` (home hub): rebuilds on every theme/locale/news change;
  Hijri-date future memoized in a `late final` to avoid recompute.
- `prayer_times_screen`: large (~1900+ lines), drives scheduling + previews.

## 11. Areas requiring caution when modifying
1. **Adhan/alarm/notification pipeline** — cross-isolate prefs, exact-alarm
   permission gates (SCHEDULE_EXACT_ALARM API33+, USE_FULL_SCREEN_INTENT
   API34+), 6-min isolate-keepalive, 3 scheduling entry points + dedup triple,
   DST cursor handling. Easy to break silently. Always call
   `AdhanScheduler.invalidateScheduling()` when changing sound/toggles.
2. **Conditional-export trios** — edit .dart/_io/_web together; keep duplicated
   enums/models (`QuranEdition`, `PageData`, `AyahData`) in sync.
3. **DB schema changes** — bump `QuranDatabaseService._schemaVersion` (forces
   asset re-copy) for `quran.db`; for `qurani_user.db` APPEND a migration, never
   edit existing ones.
4. **Riverpod codegen** — re-run build_runner after provider edits; preserve the
   `xProvider = xNotifierProvider` back-compat aliases.
5. **Audio players** — multiple independent instances; dispose all stream subs +
   the player; respect `_playbackGeneration` guards around awaits.
6. **PDF page offsets** (`MushafPdfService.getPageOffset`) used in multiple
   index conversions.
7. **One-shot prefs→SQLite migrations** (Tasbeeh, Wird) run lazily, flag-guarded;
   don't disturb the guard keys.
8. **Web platform**: many features are no-op stubs (downloads, native audio,
   prayer-times scheduling, qibla/prayer hidden from home). Guard new
   mobile-only code with `kIsWeb`/`defaultTargetPlatform`.

## 12. Open assumptions to clarify before deep work
- Adhan auto-play on notification tap is intentionally disabled (commented out
  in `main`) — confirm before re-enabling.
- `is_app_in_foreground` is currently dead (write-only) — confirm whether the
  stop-notification-suppression feature is wanted before wiring a reader.
- DST inconsistency in `_rescheduleAllAdhans` — confirm whether to align it with
  the DST-safe cursor used elsewhere.
- Leftover debug `debugPrint`/diagnostic queries in `quran_search_service_io` —
  confirm whether to remove.
- Single read-write handle on a "read-only" bundled `quran.db` — opened
  `readOnly:false`; confirm intent before relying on writes.

## 13. Build / verify commands
- Codegen: `dart run build_runner build --delete-conflicting-outputs`
- Analyze: `flutter analyze`
- Tests: `flutter test` (note: very few tests exist; `flutter_test` + `sqlite3`
  dev deps present). On Windows shell, chain with `;` not `&&`.
- Long-running (`flutter run`) must be started by the user, not by the agent.
