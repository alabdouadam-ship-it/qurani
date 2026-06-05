# Qurani Admin (admin-web)

A minimal, single-admin dashboard for managing the three Supabase-backed
subjects of the Qurani app: **Dashboard (stats)**, **News**, and **Reciters**.

- **Stack:** Next.js (App Router, latest) + TypeScript + Tailwind v4.
- **Backend:** Supabase ONLY — no custom server. The app is a client-side SPA
  that talks directly to Supabase under Row Level Security.
- **Auth:** username + password (the username is mapped to a synthetic email
  for Supabase Auth). A single admin level — no roles. Every news/reciter
  change records the admin's display name in `updated_by`.
- **i18n:** English + Arabic (full RTL).
- **Themes:** Light, Dark, Sand.

## Prerequisites (Supabase)

1. Apply the SQL migrations in `../supabase/migrations` in order:
   `0001` (stats) → `0002` (news) → `0003` (reciters) → `0004` (admin).
   Easiest path: Supabase dashboard → SQL Editor → paste each → Run.
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

## Run

```
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
```

## First admin

On first launch (while `public.admins` is empty), the login screen shows a
**"Create the first administrator"** form. After it's created, that flow is
permanently disabled by RLS — only that one admin exists, and only they can
sign in. Change the display name or password later from the **Account** page.

## Security model

- The stats tables are **read-only** to admins (writes come only from the app's
  `SECURITY DEFINER` RPCs). News + reciters are full CRUD for admins.
- A non-admin who somehow signs up gets a powerless auth user: RLS grants no
  data access and the login screen signs them back out.
