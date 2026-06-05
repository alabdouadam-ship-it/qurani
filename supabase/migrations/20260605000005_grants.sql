-- ============================================================================
-- Migration 0005 — Table-level GRANTs
-- ============================================================================
-- RLS decides WHICH ROWS a role may touch, but Postgres first requires a
-- coarse table-level GRANT for the role to access the table at all. Tables
-- created by CLI SQL migrations do not always inherit Supabase's default
-- privileges for anon/authenticated, which produced:
--     "permission denied for table admins"
--
-- This migration grants the minimum privileges each role needs; RLS (from
-- 0002/0003/0004) still narrows access to the correct rows. Idempotent.
-- ============================================================================

-- ── admins (dashboard auth/profile) ────────────────────────────────────────
-- Authenticated admins read their row, insert the first admin, update their
-- own name. RLS enforces the row-level rules; this just opens the table.
grant select, insert, update on public.admins to authenticated;

-- ── news_items ──────────────────────────────────────────────────────────
-- anon (mobile app) reads live rows; admins do full CRUD. RLS scopes both.
grant select on public.news_items to anon, authenticated;
grant insert, update, delete on public.news_items to authenticated;

-- ── reciters ──────────────────────────────────────────────────────────────
grant select on public.reciters to anon, authenticated;
grant insert, update, delete on public.reciters to authenticated;

-- ── stats tables ──────────────────────────────────────────────────────────
-- Writes happen only through the SECURITY DEFINER RPCs (which run as owner and
-- need no role grant). Admins READ these tables directly in the dashboard, so
-- grant SELECT to authenticated only. anon gets nothing here (RLS has no anon
-- policy either, so anon stays fully locked out).
grant select on public.app_installations to authenticated;
grant select on public.usage_sessions to authenticated;
grant select on public.feature_events to authenticated;
grant select on public.installation_active_days to authenticated;
