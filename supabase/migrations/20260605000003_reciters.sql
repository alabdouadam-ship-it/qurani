-- ============================================================================
-- Migration 0003 — Reciters source
-- ============================================================================
-- Replaces the static `reciters.json` fetch with a Supabase table. Column
-- names mirror ReciterConfig (code, nameAr, nameLatin, ayahsPath, surahsPath).
--
-- Security model:
--   * RLS enabled. Anon may SELECT only enabled reciters. No writes for anon —
--     the catalogue is maintained from the dashboard / service role.
-- ============================================================================

create table if not exists public.reciters (
  code         text primary key,
  name_ar      text not null,
  name_latin   text not null,
  ayahs_path   text not null default '',
  surahs_path  text,
  sort_order   integer not null default 0,
  is_enabled   boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_reciters_sort on public.reciters(sort_order);

create or replace function public.touch_reciters_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_reciters_touch on public.reciters;
create trigger trg_reciters_touch
  before update on public.reciters
  for each row execute function public.touch_reciters_updated_at();

-- ---------------------------------------------------------------------------
-- RLS: anon can read only enabled reciters.
-- ---------------------------------------------------------------------------
alter table public.reciters enable row level security;

drop policy if exists reciters_public_read on public.reciters;
create policy reciters_public_read
  on public.reciters
  for select
  to anon, authenticated
  using (is_enabled = true);
