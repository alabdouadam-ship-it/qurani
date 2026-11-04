# Qurani Admin (admin-web)

A minimal, single-admin dashboard for managing the three Supabase-backed
subjects of the Qurani app: **Dashboard (stats)**, **News**, and **Reciters**.

- **Stack:** Next.js (App Router) + TypeScript + Tailwind v4, exported as static
  files (`output: "export"`).
- **Backend:** Supabase ONLY — no custom server. The app is a client-side SPA
  that talks directly to Supabase under Row Level Security.
- **Auth:** username + password (the username is mapped to a synthetic email
  for Supabase Auth). A single admin level — no roles.
- **i18n:** English, Arabic (full RTL) and French.
- **Themes:** Light, Dark, Sand.

## Prerequisites (Supabase)

1. Apply every migration in `../supabase/migrations` in filename order. There
   are 15 as of `20260831000003`, and the set grows — apply whatever is there
   rather than a fixed list.

   ```
   npx supabase db push          # from the repo root, against the linked project
   ```

   Or paste each file into the Supabase dashboard → SQL Editor → Run. The ones
   the dashboard depends on directly are `0002` (news), `0003` (reciters),
   `0004` (admin: the `admins` table, `is_admin()`, and the RLS policies that
   are the actual security boundary), `0005` (grants) and `0011`/`0012`
   (`admin_dashboard_stats`).

   Two later migrations are required by the current UI: `..._news_group_id`
   adds the `group_id` column the news list groups translations by — **without
   it, saving a news item fails** — and `..._attribution_and_last_admin` moves
   `updated_by` and the last-admin guard server-side.

2. In **Auth → Providers → Email**, turn **OFF "Confirm email"** so the first
   admin can sign in immediately after self-registration (usernames map to
   `username@qurani.info`, which receives no real mail).

## Configure

```
cp .env.example .env.local
```

Fill `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` from
Supabase → Project Settings → API. (The anon key is public-by-design; RLS is
what protects the data.)

`SUPABASE_SERVICE_ROLE_KEY` is only needed for the `admin:*` scripts below. It
bypasses RLS — keep it out of the browser and out of git.

## Run

```
npm install
npm run dev      # http://localhost:3000
npm run build    # production build into ./out
npm run lint
```

## Deploy

The admin fixes from 2026-11-04 also require migration
`20261104000001_admin_concurrency_and_news_arrays.sql`. It serializes administrator
membership changes and rejects new targeting arrays containing null elements.
Apply it through the normal migration process before publishing this build.
It has been exercised against an isolated PostgreSQL 17 instance, not the live
Supabase database. Existing malformed targeting rows are preserved for review
(`NOT VALID` constraint); the admin reports a loading failure instead of silently
broadening their audience. Repair those rows explicitly before validating the
constraint.

Offline application regressions: `npm test`.
SQL regressions require a fresh disposable local PostgreSQL cluster, with no
existing roles/database from a previous run:

```
node scripts/admin-sql-regression.mjs <path-to-psql> <local-port>
```

The SQL test uses only `127.0.0.1`, creates `qurani_admin_regression`, and never
reads `.env.local`. Stop the disposable server after testing. Do not run it on
a local instance containing real application data.

```
npm run deploy
```

Builds and publishes to Firebase Hosting site **`quraniapp`** in project
`qurani-appli` (see `firebase.json` / `.firebaserc`). The script chains the
build so a stale `out/` can't be shipped.

This is a **different hosting site** from the Flutter web app, which is
configured separately at the repo root and deploys to target `webapp`. The two
do not collide, but note that each directory has its own `firebase.json`, so run
this one from `admin-web/`.

`npm run build` runs `scripts/fix-export-rsc.mjs`, which works around Next's
static-export layout for React Server Component page segments: the client
requests a flat `__next.<route>.__PAGE__.txt` while the export writes it into a
subfolder, which 404s on a plain static host and breaks client-side navigation.
It pins to an undocumented filename layout, so it fails the build if it ever
stops matching rather than letting a broken export through.

## Managing admins

The first admin self-registers (below). Every admin after that is added with the
service-role scripts, because RLS permanently closes the browser path once one
admin exists:

```
npm run admin:list
npm run admin:add <username> <password> ["Display Name"]
npm run admin:password <username> <newPassword>
npm run admin:remove <username> [--delete-user]
```

`scripts/sql/` holds SQL equivalents for the same operations, for when you have
the SQL Editor but not the service-role key. Prefer the scripts: the SQL writes
GoTrue's own `auth.users` / `auth.identities` rows by hand and can break on a
Supabase upgrade.

Deleting the **last** admin is refused by a database trigger, not just by the
script — emptying `public.admins` would lock everyone out *and* re-open the
unauthenticated first-admin form on `/login`.

## First admin

On first launch (while `public.admins` is empty), the login screen shows a
**first administrator** form. After it's created, that flow is permanently
disabled by RLS. Change the display name or password later from the **Account**
page; changing the password requires the current one.

## Security model

- Page *access* is not protected — this is a static export, so every HTML and JS
  file is public and the route guard is a client-side redirect. That is a UX
  redirect, not a security control.
- *Data* access is protected server-side by RLS. Every write to `news_items` and
  `reciters` is gated on `public.is_admin()`, and `admin_dashboard_stats()`
  re-checks it in the function body and raises `not authorized` otherwise.
  Someone with the public anon key and `curl` gets exactly what the mobile app
  gets: published news and enabled reciters.
- The stats tables are **read-only** to admins; writes come only from the app's
  `SECURITY DEFINER` RPCs.
- `updated_by` is set by a trigger from `auth.uid()`, so attribution can't be
  forged by a hand-rolled request.
- A non-admin who somehow signs up gets a powerless auth user: RLS grants no
  data access and the login screen signs them back out.

## Notes for future work

- `src/lib/database.types.ts` is hand-written because
  `supabase gen types typescript --linked` is rejected by the current access
  token. It catches column typos, but it cannot detect schema drift — a renamed
  column must be edited there in the same commit as the migration. Regenerate
  properly if the token is ever upgraded.
- There is no test runner here yet, so `news-visibility.ts`,
  `news-validation.ts` and `news-grouping.ts` — pure, self-contained logic — are
  untested.
