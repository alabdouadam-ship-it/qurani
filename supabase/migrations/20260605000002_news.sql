-- ============================================================================
-- Migration 0002 — News & notifications source
-- ============================================================================
-- Replaces the static `news-v1.json` fetch with a Supabase table.
-- Column names mirror the existing NewsItem.fromJson keys so the client mapper
-- needs minimal change.
--
-- Security model:
--   * RLS enabled. Anon (the app) may SELECT ONLY rows that are published and
--     not yet expired. No insert/update/delete for anon — authoring is done
--     from the Supabase dashboard / a privileged service role.
-- ============================================================================

create table if not exists public.news_items (
  id               text primary key,
  title            text not null,
  description      text not null default '',
  type             text not null default 'text',   -- 'text' | 'image' | 'youtube'
  media_url        text not null default '',
  source_url       text not null default '',
  publish_date     timestamptz not null default now(),
  valid_until      timestamptz not null,
  language         text not null default 'ar',
  category_ar      text,
  category_en      text,
  category_fr      text,
  target_languages text[] not null default '{}',
  -- Country targeting (ISO 3166-1 alpha-2, uppercase, e.g. 'SA','FR').
  -- Resolved client-side from the device locale country.
  --   * target_countries non-empty  → show ONLY to those countries.
  --   * excluded_countries non-empty → never show to those countries.
  --   * both empty (default)         → shown to everyone, none excluded.
  target_countries   text[] not null default '{}',
  excluded_countries text[] not null default '{}',
  is_featured      boolean not null default false,
  send_notification boolean not null default false,
  is_published     boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists idx_news_valid_until on public.news_items(valid_until);
create index if not exists idx_news_publish_date on public.news_items(publish_date desc);

-- Keep updated_at fresh on edits.
create or replace function public.touch_news_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_news_touch on public.news_items;
create trigger trg_news_touch
  before update on public.news_items
  for each row execute function public.touch_news_updated_at();

-- ---------------------------------------------------------------------------
-- RLS: anon can read only live (published + within validity window) items.
-- ---------------------------------------------------------------------------
alter table public.news_items enable row level security;

drop policy if exists news_public_read on public.news_items;
create policy news_public_read
  on public.news_items
  for select
  to anon, authenticated
  using (
    is_published = true
    and publish_date <= now()
    and valid_until > now()
  );

-- No insert/update/delete policies for anon → authoring is dashboard/service-role only.
