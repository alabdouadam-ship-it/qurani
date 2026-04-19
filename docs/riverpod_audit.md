# Riverpod / State-Management Audit

> **Phase 7d deliverable.** Non-code pass that inventories every state-sharing mechanism in the app and proposes a target paradigm. Feeds directly into **7e–7h** (`PreferencesService` migration, paradigm unification).

Baseline taken from `lib/` as of the end of Phase 7c (read-quran split).

---

## 1. What's already in the `pubspec`

```yaml
# pubspec.yaml
flutter_riverpod: ^2.5.1
riverpod_annotation: ^2.3.5
riverpod_generator: ^2.6.5   # dev dependency
build_runner: ^2.5.4
```

Both codegen packages (`riverpod_annotation`, `riverpod_generator`) are **present but unused** — there is zero `@riverpod`-annotated code in the repo. Adding `build_runner` to the pipeline costs nothing extra.

---

## 2. Paradigm inventory

The repo has **five distinct paradigms** coexisting today.

### 2.1 Riverpod — new `Notifier` API (manual, no codegen)

**File:** `lib/providers/app_state_providers.dart`

| Provider | Notifier | State type | Purpose |
|----------|----------|------------|---------|
| `localeProvider` | `LocaleNotifier extends Notifier<Locale>` | `Locale` | App locale; wraps `PreferencesService.saveLanguage` |
| `themeProvider` | `ThemeNotifier extends Notifier<String>` | `String` | Active theme id |
| `disabledScreensProvider` | `DisabledScreensNotifier extends Notifier<Set<String>>` | `Set<String>` | User-disabled feature tiles |

All three are class-based (no arrow function), initialised via `build()` that reads from `PreferencesService`, and mutate via a public setter that writes back through `PreferencesService.saveX` and assigns `state = …`.

### 2.2 Riverpod — mixed legacy / new APIs

**File:** `lib/providers/news_provider.dart`

| Provider | Shape | Base class | API era |
|----------|-------|------------|---------|
| `newsProvider` | `AsyncNotifierProvider<NewsNotifier, List<NewsItem>>` | `AsyncNotifier` | **new** |
| `unreadNewsIdsProvider` | `FutureProvider<Set<String>>((ref) async { … })` | arrow function | **legacy** |
| `savedNewsIdsProvider` | `StateNotifierProvider<SavedNewsNotifier, Set<String>>` | `StateNotifier` | **legacy** (deprecated by Riverpod 2.0) |
| `unseenNewsCountProvider` | `Provider<int>((ref) { … })` | arrow function | **legacy** |
| `hiddenNewsIdsProvider` | `StateNotifierProvider<HiddenNewsNotifier, Set<String>>` | `StateNotifier` | **legacy** |

This single file is the clearest example of the paradigm drift — three API flavours inside 97 lines.

### 2.3 `ValueNotifier` as an app-wide event bus

Static `ValueNotifier` fields on service singletons broadcast changes across isolates / screens.

| Notifier | Source | Consumed by |
|----------|--------|-------------|
| `PreferencesService.languageNotifier` | `lib/services/preferences_service.dart:45` | `main.dart` (pre-Riverpod), now stale — `localeProvider` owns this |
| `PreferencesService.themeNotifier` | `lib/services/preferences_service.dart:46-47` | `main.dart` (pre-Riverpod), stale — `themeProvider` owns this |
| `PreferencesService.arabicFontNotifier` | `lib/services/preferences_service.dart:48-49` | `read_quran_screen.dart`, `repetition_range_screen.dart` via `addListener` + `setState` |
| `PreferencesService.disabledScreensNotifier` | `lib/services/preferences_service.dart:50-51` | (no direct consumers; `disabledScreensProvider` now authoritative) |
| `QueueService._queueNotifier` | `lib/services/queue_service.dart:9` | `audio_player_screen.dart` via `addListener` + `setState` |
| `NewsService.unseenCountNotifier` | `lib/services/news_service.dart:19` | (no consumers — `unseenNewsCountProvider` wraps the same data) |
| `AdhanAudioManager.isPlayingListenable` | `lib/services/adhan_audio_manager.dart:60-61` | Adhan stop-button UI via `ValueListenableBuilder` |
| `GlobalAdhanService.isPlayingListenable` | `lib/services/global_adhan_service.dart:27-28` | Forwarder to the one above (kept for legacy call sites) |

**Observation:** three of these (`languageNotifier`, `themeNotifier`, `disabledScreensNotifier`) are **duplicates** of existing Riverpod providers. They're write-once-read-many cached in the service class but never updated when the corresponding Riverpod notifier fires. This is a latent bug surface.

### 2.4 Local `ValueNotifier` inside a StatefulWidget (legit usage)

These are *not* duplication — they're the right tool for a single-screen hot-tick:

| Location | Purpose |
|----------|---------|
| `prayer_times_screen.dart:163` | 1-Hz countdown via `ValueListenableBuilder` (migrated in Phase 5) |
| `read_quran_screen.dart:839` | Ephemeral download-progress dialog |
| `repetition_range_screen.dart:720` | Same pattern — ephemeral download-progress dialog |

### 2.5 Pure `StatefulWidget` + `setState` + static singletons

The **majority** of screens. All the following still use manual state only:

- `read_quran_screen.dart` (2540 L post-7c)
- `audio_player_screen.dart` (1371 L post-7b)
- `prayer_times_screen.dart`
- `memorization_test_screen.dart`, `memorization_stats_screen.dart`
- `tasbeeh_screen.dart`
- `search_quran_screen.dart`
- `repetition_range_screen.dart`, `repetition_memorization_screen.dart`
- `qibla_screen.dart`
- `hadith_books_screen.dart`, `hadith_read_screen.dart`
- `offline_audio_screen.dart`
- `month_prayer_times_screen.dart`
- `listen_quran_screen.dart`
- `settings_screen.dart`
- `test_questions_screen.dart`

All cross-screen state is reached via `PreferencesService.xxx()` **static** method calls, with optional `addListener` on one of the notifiers in §2.3.

### 2.6 `ChangeNotifier` — not used

Zero hits in `lib/`. Good: no accidental drift toward the Provider (v4) paradigm.

---

## 3. Consumer inventory

Screens that already touch Riverpod's `ref`:

| Screen | Widget type | Providers consumed |
|--------|-------------|--------------------|
| `main.dart` → `QuraniApp` | `ConsumerStatefulWidget` | `localeProvider`, `themeProvider` (+ `ref.listen` for overlay style) |
| `options_screen.dart` | `ConsumerStatefulWidget` | `disabledScreensProvider`, `unseenNewsCountProvider` |
| `preferences_screen.dart` | `ConsumerStatefulWidget` | `themeProvider.notifier`, `localeProvider.notifier` |
| `screen_customization_screen.dart` | `ConsumerStatefulWidget` | `disabledScreensProvider`(+.notifier) |
| `news_notifications_screen.dart` | `ConsumerStatefulWidget` | `newsProvider`, `savedNewsIdsProvider`, `unreadNewsIdsProvider`, `hiddenNewsIdsProvider` |

That's it — **5 of ~25 screens**. The Riverpod footprint is narrow but already spans both paradigm eras.

---

## 4. Drift / inconsistency hotspots

1. **Two sources of truth for language & theme.** `PreferencesService.languageNotifier` + `themeNotifier` are instantiated and exported, but `localeProvider` / `themeProvider` now own the read side. Any code path that writes to the `ValueNotifier` directly will desync the Riverpod state, and vice versa.
2. **`StateNotifier` deprecation.** Riverpod 2.0 (June 2022) deprecated `StateNotifier` in favour of `Notifier`. `news_provider.dart` still has two `StateNotifier`s.
3. **Three Riverpod styles in one file.** `news_provider.dart` mixes `AsyncNotifier` (new), arrow-function `FutureProvider` (legacy), arrow-function `Provider` (legacy) and `StateNotifier` (legacy deprecated).
4. **`ValueNotifier` → manual `addListener` → `setState`** in two screens (`read_quran_screen.dart` for `arabicFontNotifier`, `audio_player_screen.dart` for `queueNotifier`). Each one is a mini-reactive system built by hand; `ref.watch` would replace the pattern with a single line.
5. **No codegen.** `riverpod_generator` is a dev dependency but produces nothing. Future providers incur the same boilerplate tax as existing ones.

---

## 5. Recommendation

### 5.1 Target paradigm

**`@riverpod` codegen**, class-based where state mutates (`class Foo extends _$Foo`), function-based where state is derived (`@riverpod Foo foo(FooRef ref) => …`).

**Why not stay on manual `NotifierProvider`?**
- Boilerplate: each provider duplicates the type in the generic (`NotifierProvider<FooNotifier, Foo>`) and the class (`extends Notifier<Foo>`).
- No family/autoDispose type-safety sugar: with codegen those are compile-time-generated getters on the generated variable.
- Official Riverpod docs have led with codegen examples since 2.3 (late 2023); community packages increasingly assume it.

**Why not keep `StateNotifier`?**
- Deprecated upstream; Riverpod will eventually drop it. Migration cost only grows.

**Why not rip out Riverpod entirely and use `ValueNotifier` everywhere?**
- `ValueNotifier` broadcasts a single value and has no dependency graph. Every derived value (e.g. "unread count" derived from "news + seen ids") has to be recomputed by hand. `Provider<int>((ref) => ref.watch(newsProvider) - ref.watch(seenIdsProvider))` gets this for free.
- We already have 5 Riverpod-wired screens; removing Riverpod means rewriting all of them.

### 5.2 Migration plan (sequenced with existing Phase 7 sub-phases)

**Step 1 — `news_provider.dart` paradigm unification** *(part of 7h, ~0.5 day, low risk)*

- Convert the two `StateNotifier` classes to `Notifier<Set<String>>` using the new API.
- Rewrite every provider in this file as `@riverpod`-annotated. Run `dart run build_runner build`.
- Public API surface (`savedNewsIdsProvider`, `hiddenNewsIdsProvider`, `newsProvider`, etc.) stays byte-compatible because codegen generates the same top-level names.
- Regression test: `news_notifications_screen.dart` compiles unchanged; smoke-test news list, swipe-dismiss, save toggle.

**Step 2 — `app_state_providers.dart` to codegen** *(part of 7h, ~0.25 day, low risk)*

- Rewrite the three notifiers as `@riverpod class Xxx extends _$Xxx`. Same public names.
- Verify `main.dart`, `options_screen.dart`, `preferences_screen.dart`, `screen_customization_screen.dart` still compile (they should — the generated provider names are designed for this).

**Step 3 — Deprecate the duplicate `ValueNotifier`s** *(part of 7e, ~0.5 day, medium risk)*

- Mark `PreferencesService.languageNotifier`, `themeNotifier`, `disabledScreensNotifier` as `@Deprecated("Use Riverpod providers — see providers/app_state_providers.dart")`.
- Audit every `addListener` call on those three. There should be zero — but a grep is mandatory before delete.
- Delete them in a follow-up once one release has shipped without crashes.

**Step 4 — PreferencesService read-side → Riverpod facade** *(7e proper, ~1 day, medium risk)*

For each prefs read used by screen UI, introduce an `@riverpod` provider that delegates to the existing static getter. Example:

```dart
@riverpod
String arabicFont(Ref ref) {
  // Subscribe to changes if the notifier still exists.
  return PreferencesService.getArabicFontFamily();
}
```

The provider reads stay idempotent; writes continue to use the static API. This lets screens migrate one-at-a-time without a big-bang cutover.

Priority targets (screens that already use `addListener`):

- `read_quran_screen.dart` — replace `PreferencesService.arabicFontNotifier.addListener(_onArabicFontChanged)` with `ref.watch(arabicFontProvider)`.
- `repetition_range_screen.dart` — same.
- `audio_player_screen.dart` — replace `QueueService.queueNotifier.addListener(...)` with a `queueProvider`.

**Step 5 — PreferencesService write-side** *(7f, ~1 day, medium risk)*

- Move write methods (`saveTheme`, `saveLanguage`, `saveArabicFontFamily`, etc.) into the corresponding Notifier's `set…` method.
- Static methods on `PreferencesService` become `@Deprecated` forwarders that call the notifier.
- **Invariant**: SharedPreferences *keys* are untouched — the byte-on-disk format does not change. This is the hard constraint because the app is live on Play Store + App Store.

**Step 6 — Delete static forwarders** *(7g, ~0.25 day, after one stable release)*

**Step 7 — Migrate holdout screens** *(7h tail, incremental)*

One screen per commit:
1. `ConsumerStatefulWidget` + `ConsumerState`
2. Replace `PreferencesService.getXxx()` reads in `build()` with `ref.watch(xxxProvider)`
3. Delete matching `addListener` / `removeListener` pairs
4. Regression smoke-test

Recommended order (smallest first): `search_quran_screen` → `tasbeeh_screen` → `memorization_*` → `offline_audio_screen` → `prayer_times_screen` → `audio_player_screen` → `read_quran_screen`.

### 5.3 What NOT to migrate

- **Ephemeral local `ValueNotifier`s** (download progress dialogs, 1-Hz countdown). Scoped to one `StatefulWidget`'s lifetime. Riverpod adds nothing here.
- **`just_audio` / `AudioPlayer` stream subscriptions** in the player screens. These are native stream consumers, not app state; `StreamBuilder` is the right tool.
- **`AdhanAudioManager.isPlayingListenable`** — it bridges a background isolate and the foreground UI via `ValueNotifier` + `SharedPreferences`. Riverpod providers do not cross isolate boundaries. Leave this as-is.

### 5.4 Definition of done for the full migration

- Zero references to `StateNotifier` in `lib/`.
- Zero `ValueNotifier` on service classes whose data is also represented by a provider.
- Every screen either uses `ConsumerStatefulWidget` with `ref.watch` OR is proven not to need cross-screen state.
- `riverpod_generator` produces `.g.dart` files; `dart run build_runner build --delete-conflicting-outputs` is part of the CI/build README.
- `flutter analyze` clean (modulo the pre-existing `qurani_news_editor` deprecation info).

---

## 6. Glossary

| Term | Definition |
|------|------------|
| **Notifier** | Riverpod 2.x base class; replaces `StateNotifier`. `build()` returns initial state; mutate via `state = newValue`. |
| **AsyncNotifier** | Async analogue of `Notifier`; `build()` is `Future<T>`; surface is `AsyncValue<T>`. |
| **`@riverpod` codegen** | `riverpod_generator` synthesises the provider variable from an annotated class/function. Produces a `_YourThing.g.dart` file. |
| **`ConsumerStatefulWidget`** | Flutter `StatefulWidget` whose `State` is `ConsumerState<T>`; the state class exposes `ref`. |
| **Legacy `StateNotifier`** | Riverpod 1.x base class, still functional but deprecated since 2.0. |

---

_Last updated: Phase 7d, 2026-04-18._
