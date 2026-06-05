-- ============================================================================
-- Migration 0001 — Anonymous app usage statistics
-- ============================================================================
-- Privacy & legality notes (read before changing):
--   * Identity is the app's RANDOM installation UUID (installation_id_v1),
--     NOT a hardware/device id, NOT an advertising id, NOT any PII.
--   * Only coarse, non-identifying data is collected: platform/OS/model,
--     app version, language, COARSE country (derived from locale), timezone,
--     and anonymous product preferences (theme, reciter, notif on/off).
--   * NO precise GPS, NO contacts, NO names/emails, NO IP storage by us.
--   * This basis is "anonymous usage analytics" — disclose it in the privacy
--     policy and provide an in-app opt-out (the client honours a flag).
--
-- Security model:
--   * RLS is ENABLED on every table with NO policies for anon/authenticated,
--     so the public anon key can NEVER read or scan these tables directly.
--   * All client writes go through SECURITY DEFINER functions (RPCs) that the
--     anon role may only EXECUTE. This prevents arbitrary reads/updates while
--     still allowing anonymous telemetry inserts.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.app_installations (
  installation_id          uuid primary key,
  first_seen               timestamptz not null default now(),
  last_seen                timestamptz not null default now(),
  platform                 text,       -- 'android' | 'ios' | 'web'
  os_version               text,
  device_model             text,
  manufacturer             text,
  is_physical_device       boolean,
  app_version              text,
  app_build                text,
  app_language             text,       -- user-selected app language
  locale_language          text,       -- system locale language
  country_code             text,       -- coarse, from locale country
  timezone                 text,
  tz_offset_minutes        integer,
  theme_id                 text,       -- anonymous product preference
  reciter_code             text,       -- anonymous product preference
  notifications_enabled    boolean,
  total_sessions           integer not null default 0,
  total_foreground_seconds bigint  not null default 0,
  total_feature_events     bigint  not null default 0,
  updated_at               timestamptz not null default now()
);
comment on table public.app_installations is
  'One anonymous row per install (random UUID, not a device id). No PII.';

create table if not exists public.usage_sessions (
  id               uuid primary key default gen_random_uuid(),
  installation_id  uuid not null,
  started_at       timestamptz not null,
  ended_at         timestamptz not null default now(),
  duration_seconds integer not null default 0,
  app_version      text,
  created_at       timestamptz not null default now()
);
create index if not exists idx_usage_sessions_install on public.usage_sessions(installation_id);
create index if not exists idx_usage_sessions_started on public.usage_sessions(started_at);

create table if not exists public.feature_events (
  id              bigint generated always as identity primary key,
  installation_id uuid not null,
  feature         text not null,            -- e.g. 'read_quran', 'tasbeeh'
  action          text not null default 'open',  -- 'open' | 'view' (timed)
  duration_seconds integer,                 -- set for 'view' (screen-time) events
  occurred_at     timestamptz not null default now(),
  app_version     text
);
create index if not exists idx_feature_events_install on public.feature_events(installation_id);
create index if not exists idx_feature_events_feature on public.feature_events(feature);
create index if not exists idx_feature_events_time    on public.feature_events(occurred_at);

-- One row per (installation, calendar day) the app was opened. This is the
-- canonical source for DAU / MAU / retention cohorts — a per-launch upsert on
-- app_installations only tells you "last seen", whereas this keeps the full
-- daily-active history cheaply (the client pings it at most once per day).
create table if not exists public.installation_active_days (
  installation_id uuid not null,
  day             date not null,
  app_version     text,
  first_seen_at   timestamptz not null default now(),
  primary key (installation_id, day)
);
create index if not exists idx_active_days_day on public.installation_active_days(day);

-- ---------------------------------------------------------------------------
-- Row Level Security: lock down ALL direct access (writes go via RPC only)
-- ---------------------------------------------------------------------------
alter table public.app_installations enable row level security;
alter table public.usage_sessions    enable row level security;
alter table public.feature_events     enable row level security;
alter table public.installation_active_days enable row level security;
-- Intentionally NO policies: anon/authenticated get no direct row access.

-- ---------------------------------------------------------------------------
-- RPC: upsert the installation identity + current anonymous attributes
-- ---------------------------------------------------------------------------
create or replace function public.record_installation(
  p_installation_id       uuid,
  p_platform              text default null,
  p_os_version            text default null,
  p_device_model          text default null,
  p_manufacturer          text default null,
  p_is_physical_device    boolean default null,
  p_app_version           text default null,
  p_app_build             text default null,
  p_app_language          text default null,
  p_locale_language       text default null,
  p_country_code          text default null,
  p_timezone              text default null,
  p_tz_offset_minutes     integer default null,
  p_theme_id              text default null,
  p_reciter_code          text default null,
  p_notifications_enabled boolean default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.app_installations as ai (
    installation_id, platform, os_version, device_model, manufacturer,
    is_physical_device, app_version, app_build, app_language, locale_language,
    country_code, timezone, tz_offset_minutes, theme_id, reciter_code,
    notifications_enabled, last_seen, updated_at
  ) values (
    p_installation_id, p_platform, p_os_version, p_device_model, p_manufacturer,
    p_is_physical_device, p_app_version, p_app_build, p_app_language, p_locale_language,
    p_country_code, p_timezone, p_tz_offset_minutes, p_theme_id, p_reciter_code,
    p_notifications_enabled, now(), now()
  )
  on conflict (installation_id) do update set
    platform              = coalesce(excluded.platform, ai.platform),
    os_version            = coalesce(excluded.os_version, ai.os_version),
    device_model          = coalesce(excluded.device_model, ai.device_model),
    manufacturer          = coalesce(excluded.manufacturer, ai.manufacturer),
    is_physical_device    = coalesce(excluded.is_physical_device, ai.is_physical_device),
    app_version           = coalesce(excluded.app_version, ai.app_version),
    app_build             = coalesce(excluded.app_build, ai.app_build),
    app_language          = coalesce(excluded.app_language, ai.app_language),
    locale_language       = coalesce(excluded.locale_language, ai.locale_language),
    country_code          = coalesce(excluded.country_code, ai.country_code),
    timezone              = coalesce(excluded.timezone, ai.timezone),
    tz_offset_minutes     = coalesce(excluded.tz_offset_minutes, ai.tz_offset_minutes),
    theme_id              = coalesce(excluded.theme_id, ai.theme_id),
    reciter_code          = coalesce(excluded.reciter_code, ai.reciter_code),
    notifications_enabled = coalesce(excluded.notifications_enabled, ai.notifications_enabled),
    last_seen             = now(),
    updated_at            = now();

  -- Record today's active-day (idempotent: at most one row per install/day).
  insert into public.installation_active_days(installation_id, day, app_version)
  values (p_installation_id, (now() at time zone 'utc')::date, p_app_version)
  on conflict (installation_id, day) do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: record one finished foreground session (duration), bump counters
-- ---------------------------------------------------------------------------
create or replace function public.record_session(
  p_installation_id uuid,
  p_started_at      timestamptz,
  p_duration_seconds integer,
  p_app_version     text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_duration_seconds is null or p_duration_seconds < 0 then
    p_duration_seconds := 0;
  elsif p_duration_seconds > 86400 then  -- clamp absurd values (> 24h)
    p_duration_seconds := 86400;
  end if;

  insert into public.usage_sessions(installation_id, started_at, ended_at, duration_seconds, app_version)
  values (p_installation_id, coalesce(p_started_at, now()), now(), p_duration_seconds, p_app_version);

  update public.app_installations
     set total_sessions           = total_sessions + 1,
         total_foreground_seconds = total_foreground_seconds + p_duration_seconds,
         last_seen                = now(),
         updated_at               = now()
   where installation_id = p_installation_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: batch-insert feature usage events (one network call per flush)
--   p_events = jsonb array of {feature, action, occurred_at}
-- ---------------------------------------------------------------------------
create or replace function public.record_feature_events(
  p_installation_id uuid,
  p_events          jsonb,
  p_app_version     text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if p_events is null or jsonb_typeof(p_events) <> 'array' then
    return;
  end if;

  insert into public.feature_events(installation_id, feature, action, duration_seconds, occurred_at, app_version)
  select
    p_installation_id,
    coalesce(e->>'feature', 'unknown'),
    coalesce(e->>'action', 'open'),
    nullif(e->>'duration_seconds', '')::integer,
    coalesce((e->>'occurred_at')::timestamptz, now()),
    p_app_version
  from jsonb_array_elements(p_events) as e
  where e->>'feature' is not null;

  get diagnostics v_count = row_count;

  update public.app_installations
     set total_feature_events = total_feature_events + v_count,
         last_seen            = now(),
         updated_at           = now()
   where installation_id = p_installation_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissions: anon/authenticated may ONLY execute the RPCs (no table access)
-- ---------------------------------------------------------------------------
revoke all on function public.record_installation(
  uuid,text,text,text,text,boolean,text,text,text,text,text,text,integer,text,text,boolean
) from public;
grant execute on function public.record_installation(
  uuid,text,text,text,text,boolean,text,text,text,text,text,text,integer,text,text,boolean
) to anon, authenticated;

revoke all on function public.record_session(uuid,timestamptz,integer,text) from public;
grant execute on function public.record_session(uuid,timestamptz,integer,text) to anon, authenticated;

revoke all on function public.record_feature_events(uuid,jsonb,text) from public;
grant execute on function public.record_feature_events(uuid,jsonb,text) to anon, authenticated;
