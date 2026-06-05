-- ============================================================================
-- Migration 0004 — Admin access (for the admin-web Next.js dashboard)
-- ============================================================================
-- Adds a single-level admin model on top of Supabase Auth:
--   * `admins` table: links an auth user to a display name (used to attribute
--     every change). No roles — being in this table IS being the admin.
--   * First-admin self-registration is allowed ONLY while the table is empty;
--     afterwards no new admin rows can be created from the client (so a stray
--     signup yields a powerless auth user with no data access).
--   * Admins (authenticated + in `admins`) get full read/write on news +
--     reciters and read on the stats tables. The mobile app's anon policies
--     are untouched.
--   * `updated_by` columns record the admin NAME that last changed a row.
--
-- Apply AFTER 0001/0002/0003.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- admins table + helpers
-- ---------------------------------------------------------------------------
create table if not exists public.admins (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now()
);

alter table public.admins enable row level security;

-- SECURITY DEFINER so it bypasses RLS on `admins` (avoids recursive policy
-- evaluation). Returns whether the current auth user is a registered admin.
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.admins where id = auth.uid());
$$;

-- Anon-safe check used by the setup page to decide whether the first-admin
-- flow should be shown. Returns only a boolean, never admin data.
create or replace function public.admin_exists()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.admins);
$$;
grant execute on function public.admin_exists() to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- admins RLS:
--   * read: only admins, and the function bypasses RLS so no recursion.
drop policy if exists admins_select on public.admins;
create policy admins_select on public.admins
  for select to authenticated
  using (public.is_admin());

--   * insert: ONLY the first admin (table empty) registering their own row.
drop policy if exists admins_insert_first on public.admins;
create policy admins_insert_first on public.admins
  for insert to authenticated
  with check (id = auth.uid() and not public.admin_exists());

--   * update: an admin may edit their own display name.
drop policy if exists admins_update_self on public.admins;
create policy admins_update_self on public.admins
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- Change-attribution columns (admin NAME that last wrote the row)
-- ---------------------------------------------------------------------------
alter table public.news_items add column if not exists updated_by text;
alter table public.reciters   add column if not exists updated_by text;

-- ---------------------------------------------------------------------------
-- Admin write/read policies (mobile anon policies remain untouched)
-- ---------------------------------------------------------------------------

-- News: full CRUD for admins (in addition to the existing anon live-read).
drop policy if exists news_admin_all on public.news_items;
create policy news_admin_all on public.news_items
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Reciters: full CRUD for admins.
drop policy if exists reciters_admin_all on public.reciters;
create policy reciters_admin_all on public.reciters
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Stats tables: read-only for admins (the dashboard shows current + history).
-- Writes still come exclusively from the app's SECURITY DEFINER RPCs.
drop policy if exists app_installations_admin_read on public.app_installations;
create policy app_installations_admin_read on public.app_installations
  for select to authenticated using (public.is_admin());

drop policy if exists usage_sessions_admin_read on public.usage_sessions;
create policy usage_sessions_admin_read on public.usage_sessions
  for select to authenticated using (public.is_admin());

drop policy if exists feature_events_admin_read on public.feature_events;
create policy feature_events_admin_read on public.feature_events
  for select to authenticated using (public.is_admin());

drop policy if exists active_days_admin_read on public.installation_active_days;
create policy active_days_admin_read on public.installation_active_days
  for select to authenticated using (public.is_admin());
