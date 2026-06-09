/// Central configuration + initialization for the app's Supabase link.
///
/// The project URL and publishable (anon) key are NOT hardcoded here. They are
/// injected at build time via `--dart-define`, so credentials live outside
/// source control:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<your-publishable-key>
/// ```
///
/// For older Supabase dashboards that still label it the "anon" key, the
/// build accepts `SUPABASE_ANON_KEY` as a fallback name — the value is the
/// same public client key either way. Add the same defines to your release
/// build / CI.
///
/// ### Why the publishable (anon) key is safe to ship
/// This key is designed to be embedded in client apps. It only grants whatever
/// your Row Level Security (RLS) policies allow — so every table this app
/// touches MUST have RLS enabled with explicit policies. Never put the secret
/// (`service_role`) key in the app; it bypasses RLS.
///
/// ### Graceful degradation
/// If the defines are absent (e.g. a local build that doesn't need Supabase),
/// [isConfigured] is false and [initialize] is a no-op. The rest of the app —
/// all offline Quran features — must never assume Supabase is available; treat
/// it as an optional, online-only enhancement.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  /// Project URL, e.g. `https://abcdefgh.supabase.co`.
  static const String url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// Publishable (a.k.a. anon) client key. Prefers the newer
  /// `SUPABASE_PUBLISHABLE_KEY` define and falls back to the legacy
  /// `SUPABASE_ANON_KEY` name so either works.
  static const String _publishableKeyDefine =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');
  static const String _anonKeyDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static String get publishableKey =>
      _publishableKeyDefine.isNotEmpty ? _publishableKeyDefine : _anonKeyDefine;

  /// True only when both the URL and a key were provided at build time.
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// Set to true only after [Supabase.initialize] actually succeeds. Distinct
  /// from [isConfigured] (which only checks that build defines exist): if
  /// initialization throws, [isConfigured] stays true but the client is NOT
  /// usable. Call sites must gate `.client` access on [isReady], not
  /// [isConfigured], so we never touch an uninitialized client.
  static bool _initialized = false;

  /// True when Supabase is configured AND successfully initialized — i.e. it
  /// is safe to use [client]. This is the flag every feature should check.
  static bool get isReady => isConfigured && _initialized;

  /// Convenience accessor for the initialized client. Only valid when
  /// [isReady] is true; guard call sites accordingly.
  static SupabaseClient get client => Supabase.instance.client;

  /// Initializes Supabase if credentials are present. Safe to call once during
  /// startup. Never throws to the caller — a failed/absent link must not break
  /// app launch, since the core experience is fully offline.
  static Future<void> initialize() async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint(
            '[Supabase] Skipped init: SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY not set.');
      }
      return;
    }
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        // This app uses ONLY the anon key + RPCs — it never signs users in.
        // Disable auth session persistence and auto-refresh so supabase_flutter
        // doesn't store/restore a session or loop on token refreshes. This also
        // prevents a stale session from a previously-configured project (saved
        // in local storage during earlier testing) from triggering background
        // refresh attempts against a now-dead host.
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          // No persisted session ⇒ nothing to restore or refresh on launch.
          localStorage: EmptyLocalStorage(),
        ),
      );
      _initialized = true;
      if (kDebugMode) debugPrint('[Supabase] Initialized.');
    } catch (e) {
      _initialized = false;
      if (kDebugMode) debugPrint('[Supabase] Init failed: $e');
    }
  }
}
