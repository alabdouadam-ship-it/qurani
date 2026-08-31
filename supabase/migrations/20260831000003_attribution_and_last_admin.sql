-- ============================================================================
-- Migration 0015 — trustworthy change attribution, and last-admin protection
-- ============================================================================
-- Two independent hardening changes, together because both are triggers on
-- admin-facing tables and should be reviewed as one unit.
--
--
-- PART 1 — updated_by becomes evidence rather than a suggestion
-- ---------------------------------------------------------------------------
-- `updated_by` was added in 0004 and is written by the admin UI from the signed
-- in admin's display name (news/page.tsx, reciters/page.tsx). Because it is just
-- another column in the upsert payload, ANY authenticated admin can put any
-- string in it — including another admin's name — with a hand-rolled PostgREST
-- call. So the one field whose entire purpose is accountability was the one
-- field the client could forge.
--
-- Deriving it from auth.uid() server-side fixes that: the value no longer
-- depends on what the client sent.
--
-- Preserving the value when auth.uid() is null is deliberate. Migrations, the
-- SQL Editor and the service-role scripts in admin-web/scripts all run with no
-- JWT, so a naive `new.updated_by := lookup(auth.uid())` would blank the column
-- every time one of them touched a row. Attribution surviving an out-of-band
-- edit is more useful than recording "nobody".
--
-- The admin UI still sends updated_by. That is now redundant but harmless — the
-- trigger overwrites it — and leaving it means the panel behaves correctly
-- whether or not this migration has been applied yet, which decouples the deploy
-- order. Worth removing from the client later, once this is known to be live
-- everywhere.
--
--
-- PART 2 — the last admin cannot be deleted
-- ---------------------------------------------------------------------------
-- `admins` has no DELETE policy, so the browser can never remove an admin — good
-- — and removal is expected to go through `npm run admin:remove`, which counts
-- the remaining admins and refuses to delete the last one.
--
-- But that check lives only in JavaScript. The documented fallback path,
-- admin-web/scripts/sql/remove-admin.sql run in the Supabase SQL Editor, has no
-- such guard, and neither does a stray `delete from public.admins`. Deleting the
-- last row locks everyone out of the dashboard permanently *and* re-opens the
-- unauthenticated first-admin signup flow on /login, because that is gated on
-- `not admin_exists()`. So the worst case is not just lockout, it is a public
-- registration window on the admin panel.
--
-- A trigger enforces it everywhere, including for the service role: triggers are
-- not RLS and are not bypassed by it.
-- ============================================================================


-- ── Part 1: server-derived attribution ─────────────────────────────────────

create or replace function public.set_updated_by()
returns trigger
language plpgsql
-- SECURITY DEFINER so the lookup reads `admins` without depending on that
-- table's RLS, matching how is_admin() is declared in 0004.
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  select name into v_name from public.admins where id = auth.uid();

  if v_name is not null then
    new.updated_by := v_name;
  elsif tg_op = 'UPDATE' then
    -- No JWT: a migration, the SQL Editor or a service-role script. Keep the
    -- previous attribution rather than erasing it.
    new.updated_by := old.updated_by;
  end if;

  return new;
end;
$$;

comment on function public.set_updated_by() is
  'Sets updated_by from the calling admin (auth.uid()), ignoring whatever the '
  'client sent. Leaves the existing value untouched when there is no JWT.';

drop trigger if exists trg_news_updated_by on public.news_items;
create trigger trg_news_updated_by
  before insert or update on public.news_items
  for each row execute function public.set_updated_by();

drop trigger if exists trg_reciters_updated_by on public.reciters;
create trigger trg_reciters_updated_by
  before insert or update on public.reciters
  for each row execute function public.set_updated_by();


-- ── Part 2: refuse to delete the last administrator ────────────────────────

create or replace function public.prevent_last_admin_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.admins) <= 1 then
    raise exception
      'refusing to delete the last administrator (%): this would lock everyone '
      'out of the dashboard and re-open the unauthenticated first-admin setup '
      'flow. Add another admin first (npm run admin:add).', old.id;
  end if;
  return old;
end;
$$;

comment on function public.prevent_last_admin_delete() is
  'Blocks deletion of the final public.admins row, from any caller including '
  'the service role. To intentionally reset all admins, disable the trigger: '
  'alter table public.admins disable trigger trg_admins_prevent_last_delete;';

drop trigger if exists trg_admins_prevent_last_delete on public.admins;
create trigger trg_admins_prevent_last_delete
  before delete on public.admins
  for each row execute function public.prevent_last_admin_delete();

-- NOTE: public.admins.id references auth.users(id) ON DELETE CASCADE, so
-- deleting the last auth user (e.g. `admin:remove --delete-user`) now fails on
-- this trigger rather than silently emptying the table. That is the intended
-- outcome; the error message names the way out.
