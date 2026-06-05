# Supabase — schema & migrations

SQL migrations for the Qurani backend. Each file in `migrations/` is an
idempotent, forward-only script named `YYYYMMDDHHMMSS_description.sql`. Apply
them **in filename order**.

## Subjects

| Migration | Subject | App status |
|---|---|---|
| `0001_app_stats.sql` | Anonymous usage statistics (installations, active-days, sessions, feature events) | Client implemented (`UsageStatsService`, offline-first queue) |
| `0002_news.sql` | News & notifications source table | Client implemented (`NewsService`, Supabase-first + JSON fallback) |
| `0003_reciters.sql` | Reciters catalogue source table | Client implemented (`ReciterConfigService`, Supabase-first + JSON/cache/asset fallback) |
| `0004_admin.sql` | Admin access for the `admin-web` dashboard (admins table, RLS, attribution) | Used by the Next.js admin dashboard |
| `0005_grants.sql` | Table-level GRANTs for anon/authenticated (RLS scopes the rows; grants open the tables) | Required — fixes "permission denied for table" |
| `0006_seed_reciters.sql` | Seeds `reciters` from the bundled `assets/data/reciters.json` (idempotent, `ON CONFLICT DO NOTHING`) | Pre-populates the admin Reciters section + client fetch |
| `0007_seed_news_ar.sql` | Seeds three Arabic announcements (tafsir books, TR/DE translations, search→read) into `news_items` (idempotent) | Initial Arabic news feed content |
| `0008_seed_news_en_fr.sql` | English + French copies of the three 0007 announcements (one row per language, language-targeted) | Initial EN/FR news feed content |

## How to apply

**Option A — Dashboard (quickest):** open the project → SQL Editor → paste a
migration file's contents → Run. Do them in order.

**Option B — Supabase CLI:**
```
supabase db push           # applies migrations/ to the linked project
```
(Requires `supabase link --project-ref zqqqipzbkkrgpdnzliyg` once.)

## Security model (important)

- **Stats tables** (`app_installations`, `installation_active_days`,
  `usage_sessions`, `feature_events`): RLS enabled with **no anon policies**.
  The public anon key cannot read or scan them. All client writes go through
  `SECURITY DEFINER` RPCs (`record_installation`, `record_session`,
  `record_feature_events`) that anon may only `EXECUTE`. This allows anonymous
  telemetry inserts without exposing any read/scan surface.
- **News / Reciters**: RLS enabled, anon has **read-only** access to live rows
  (`news_items`: published + within validity window; `reciters`: enabled).
  Authoring is dashboard / service-role only.

## Privacy / legality

Telemetry identity is the app's **random installation UUID** — never a
hardware id, advertising id, or any PII. Only coarse, non-identifying data is
stored (platform/OS/model, app version, language, coarse country from locale,
timezone, anonymous product preferences, and usage counters). No precise GPS,
contacts, names, emails, or IPs are stored by the app. This must be disclosed
in the privacy policy and is gated behind an in-app opt-out
(`analytics_opt_out`) the client honours before sending anything.

## Write cadence & performance (client)

Telemetry is bursty, lifecycle-bound, and off the interaction path:

- **Hot path (`logFeature`)** — pure **in-memory** list append. No disk, no
  JSON, no network, no await on a feature tap. Zero cost when opted out /
  unconfigured (returns on the first line).
- **Disk** — touched only on lifecycle edges: the in-memory buffer is persisted
  **once on background** (durability) and reloaded on next launch. No
  per-interaction SharedPreferences writes.
- **Installation heartbeat** — at most **once per calendar day**; upserts
  install attributes + records the active-day (DAU).
- **Session** — **one insert per foreground session** on background;
  crash-resilient (start persisted, recovered on next launch).
- **Feature events** — sent in a **single batched RPC** on background or when
  the in-memory buffer reaches 20. Buffer bounded to 500. Two kinds:
  `action='open'` (a feature was opened, logged from the home hub) and
  `action='view'` with `duration_seconds` (per-screen time, measured by a
  single root `NavigatorObserver` — `ScreenTimeObserver` — over named routes,
  with no per-screen timer wiring).

All sends are connectivity-gated and `unawaited`; offline use accumulates the
buffer (persisted on background) and flushes on the next online launch. The
only loss window is a hard crash mid-session before any background event —
acceptable for best-effort telemetry.

