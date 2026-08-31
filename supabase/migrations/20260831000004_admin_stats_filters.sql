-- ============================================================================
-- Migration 0016 — filterable dashboard statistics
-- ============================================================================
-- admin_dashboard_stats() took no arguments and answered exactly one question:
-- "everything, all time". That makes a number hard to interpret — you can see
-- 666 Android installs but not how many are on the current version, nor whether
-- last week looked different from last month.
--
-- ---------------------------------------------------------------------------
-- The two kinds of filter, and why conflating them would make the numbers lie
-- ---------------------------------------------------------------------------
-- COHORT filters (platform, version, country, city, language, theme, reciter,
-- notifications, device, manufacturer) select a SET OF INSTALLATIONS. They are
-- properties of an install, not of an event.
--
-- The TIME WINDOW (p_from / p_to) restricts EVENTS: sessions, feature events,
-- active days, and first-seen dates.
--
-- Applying the time window to install attributes would be wrong. "Installs by
-- platform, for last week" has no meaning — an install's platform is not
-- something that happened during a week. So:
--
--   * every breakdown and totalInstalls answer over the cohort, ignoring the
--     window (they describe who matches, not when anything happened);
--   * sessions, features, activeInRange and newInstalls answer over the cohort
--     WITHIN the window.
--
-- activeToday / active7 / active30 keep their fixed windows deliberately. They
-- are the standard DAU/WAU/MAU triple and are meaningless if redefined by an
-- arbitrary range — that is what activeInRange is for. They do respect the
-- cohort, so "Android DAU" works.
--
-- ---------------------------------------------------------------------------
-- Cohort resolution
-- ---------------------------------------------------------------------------
-- The matching installation ids are collected once into an array and reused, so
-- the filter predicate is written once rather than repeated across seven
-- queries where the copies could drift.
--
-- An array is the right shape at this scale (hundreds of installs, and the
-- breakdowns are already capped at ten rows). If app_installations ever reaches
-- six figures, replace `v_cohort uuid[]` plus `= any(v_cohort)` with a
-- `create temp table ... on commit drop` holding the ids and join against it —
-- that also means dropping STABLE from the function, since creating a temp
-- table is not read-only.
--
-- Backwards compatible: every parameter defaults to null, and null means "no
-- filter". `select admin_dashboard_stats()` returns the same shape as before
-- plus the new keys, so an un-deployed dashboard keeps working.
-- ============================================================================

-- Distinct values available for each filter, so the dashboard's dropdowns offer
-- only values that actually occur. Separate from the stats call because the
-- option lists do not depend on the current selection and can be fetched once.
create or replace function public.admin_stats_filter_options()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_out jsonb;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'platforms', (
      select coalesce(jsonb_agg(distinct platform order by platform), '[]'::jsonb)
      from public.app_installations where nullif(platform, '') is not null
    ),
    'versions', (
      select coalesce(jsonb_agg(distinct app_version order by app_version desc), '[]'::jsonb)
      from public.app_installations where nullif(app_version, '') is not null
    ),
    'countries', (
      select coalesce(jsonb_agg(distinct country_code order by country_code), '[]'::jsonb)
      from public.app_installations where nullif(country_code, '') is not null
    ),
    'gpsCountries', (
      select coalesce(jsonb_agg(distinct gps_country order by gps_country), '[]'::jsonb)
      from public.app_installations where nullif(gps_country, '') is not null
    ),
    'cities', (
      select coalesce(jsonb_agg(distinct city order by city), '[]'::jsonb)
      from public.app_installations where nullif(city, '') is not null
    ),
    'languages', (
      select coalesce(jsonb_agg(distinct lang order by lang), '[]'::jsonb)
      from (
        select coalesce(nullif(app_language, ''), nullif(locale_language, '')) as lang
        from public.app_installations
      ) s where lang is not null
    ),
    'themes', (
      select coalesce(jsonb_agg(distinct theme_id order by theme_id), '[]'::jsonb)
      from public.app_installations where nullif(theme_id, '') is not null
    ),
    'reciters', (
      select coalesce(jsonb_agg(distinct reciter_code order by reciter_code), '[]'::jsonb)
      from public.app_installations where nullif(reciter_code, '') is not null
    ),
    'manufacturers', (
      select coalesce(jsonb_agg(distinct manufacturer order by manufacturer), '[]'::jsonb)
      from public.app_installations where nullif(manufacturer, '') is not null
    ),
    'features', (
      select coalesce(jsonb_agg(distinct feature order by feature), '[]'::jsonb)
      from public.feature_events where nullif(feature, '') is not null
    ),
    -- Lets the UI bound its date pickers to the data that exists.
    'firstDay', (select min(day) from public.installation_active_days),
    'lastDay',  (select max(day) from public.installation_active_days)
  ) into v_out;

  return v_out;
end;
$$;

revoke all on function public.admin_stats_filter_options() from public;
grant execute on function public.admin_stats_filter_options() to authenticated;


create or replace function public.admin_dashboard_stats(
  -- Time window for events. Inclusive dates, UTC. Null = unbounded.
  p_from            date    default null,
  p_to              date    default null,
  -- Cohort filters. Null = no filter on that dimension.
  p_platform        text    default null,
  p_app_version     text    default null,
  p_country         text    default null,
  p_gps_country     text    default null,
  p_city            text    default null,
  p_language        text    default null,
  p_theme           text    default null,
  p_reciter         text    default null,
  p_manufacturer    text    default null,
  p_notifications   boolean default null,
  p_physical_device boolean default null
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_today            date := (now() at time zone 'utc')::date;
  -- Sentinels so every comparison can be unconditional.
  v_from             date := coalesce(p_from, '-infinity'::date);
  v_to               date := coalesce(p_to,   'infinity'::date);
  v_cohort           uuid[];
  v_total_installs   bigint;
  v_new_installs     bigint;
  v_active_today     bigint;
  v_active_7         bigint;
  v_active_30        bigint;
  v_active_range     bigint;
  v_total_sessions   bigint;
  v_avg_session_min  numeric;
  v_sessions_per     numeric;
  v_features         jsonb;
  v_locale_countries jsonb;
  v_gps_countries    jsonb;
  v_cities           jsonb;
  v_platforms        jsonb;
  v_languages        jsonb;
  v_versions         jsonb;
  v_themes           jsonb;
  v_reciters         jsonb;
  v_manufacturers    jsonb;
  v_os_versions      jsonb;
  v_notif            jsonb;
  v_daily            jsonb;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  -- Resolve the cohort once.
  select coalesce(array_agg(installation_id), '{}'::uuid[])
    into v_cohort
  from public.app_installations
  where (p_platform     is null or platform     = p_platform)
    and (p_app_version  is null or app_version  = p_app_version)
    and (p_country      is null or country_code = p_country)
    and (p_gps_country  is null or gps_country  = p_gps_country)
    and (p_city         is null or city         = p_city)
    and (p_theme        is null or theme_id     = p_theme)
    and (p_reciter      is null or reciter_code = p_reciter)
    and (p_manufacturer is null or manufacturer = p_manufacturer)
    and (p_notifications   is null or notifications_enabled = p_notifications)
    and (p_physical_device is null or is_physical_device    = p_physical_device)
    and (
      p_language is null
      or coalesce(nullif(app_language, ''), nullif(locale_language, '')) = p_language
    );

  v_total_installs := coalesce(array_length(v_cohort, 1), 0);

  select count(*) into v_new_installs
  from public.app_installations
  where installation_id = any(v_cohort)
    and (first_seen at time zone 'utc')::date between v_from and v_to;

  -- Fixed DAU/WAU/MAU windows, cohort-aware but never range-aware.
  select count(distinct installation_id) into v_active_today
    from public.installation_active_days
    where installation_id = any(v_cohort) and day = v_today;
  select count(distinct installation_id) into v_active_7
    from public.installation_active_days
    where installation_id = any(v_cohort) and day >= v_today - 6;
  select count(distinct installation_id) into v_active_30
    from public.installation_active_days
    where installation_id = any(v_cohort) and day >= v_today - 29;

  select count(distinct installation_id) into v_active_range
    from public.installation_active_days
    where installation_id = any(v_cohort) and day between v_from and v_to;

  select count(*), coalesce(avg(duration_seconds), 0) / 60.0
    into v_total_sessions, v_avg_session_min
  from public.usage_sessions
  where installation_id = any(v_cohort)
    and (started_at at time zone 'utc')::date between v_from and v_to;

  v_sessions_per := case
    when v_total_installs > 0 then v_total_sessions::numeric / v_total_installs
    else 0
  end;

  select coalesce(jsonb_agg(row_to_json(f)), '[]'::jsonb) into v_features
  from (
    select
      coalesce(nullif(feature, ''), 'unknown') as feature,
      count(*) filter (where action <> 'view')  as opens,
      coalesce(avg(duration_seconds) filter (where action = 'view'), 0) / 60.0
        as "avgMin"
    from public.feature_events
    where installation_id = any(v_cohort)
      and (occurred_at at time zone 'utc')::date between v_from and v_to
    group by 1 order by opens desc, feature asc limit 20
  ) f;

  -- Install-attribute breakdowns: cohort only, never range-filtered.
  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_locale_countries
  from (
    select coalesce(nullif(country_code, ''), '—') as key, count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_gps_countries
  from (
    select coalesce(nullif(gps_country, ''), '—') as key, count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_cities
  from (
    select coalesce(nullif(city, ''), '—') as key, count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_platforms
  from (
    select coalesce(nullif(platform, ''), 'unknown') as key, count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_languages
  from (
    select
      coalesce(nullif(app_language, ''), nullif(locale_language, ''), 'unknown')
        as key,
      count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_versions
  from (
    select
      case
        when coalesce(nullif(app_version, ''), '') = '' then 'unknown'
        when coalesce(nullif(app_build, ''), '') = '' then app_version
        else app_version || '+' || app_build
      end as key,
      count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_themes
  from (
    select coalesce(nullif(theme_id, ''), '—') as key, count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_reciters
  from (
    select coalesce(nullif(reciter_code, ''), '—') as key, count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_manufacturers
  from (
    select coalesce(nullif(manufacturer, ''), '—') as key, count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_os_versions
  from (
    select coalesce(nullif(os_version, ''), '—') as key, count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_notif
  from (
    select
      case
        when notifications_enabled is null then '—'
        when notifications_enabled then 'on'
        else 'off'
      end as key,
      count(*) as count
    from public.app_installations where installation_id = any(v_cohort)
    group by 1 order by count desc, key asc
  ) c;

  -- Active installs per day inside the window, most recent first, capped so an
  -- unbounded range cannot return thousands of rows to the browser. The inner
  -- `order by day desc limit 60` picks WHICH days; the outer aggregate ORDER BY
  -- decides how they are presented, and the two must agree or the cap would
  -- silently keep the wrong 60.
  select coalesce(jsonb_agg(row_to_json(d) order by d.key desc), '[]'::jsonb)
    into v_daily
  from (
    select day::text as key, count(distinct installation_id) as count
    from public.installation_active_days
    where installation_id = any(v_cohort) and day between v_from and v_to
    group by day order by day desc limit 60
  ) d;

  return jsonb_build_object(
    -- Unchanged keys, so an older dashboard build keeps rendering.
    'totalInstalls',   v_total_installs,
    'activeToday',     v_active_today,
    'active7',         v_active_7,
    'active30',        v_active_30,
    'totalSessions',   v_total_sessions,
    'avgSessionMin',   v_avg_session_min,
    'features',        v_features,
    'localeCountries', v_locale_countries,
    'gpsCountries',    v_gps_countries,
    'cities',          v_cities,
    'platforms',       v_platforms,
    'languages',       v_languages,
    'versions',        v_versions,
    -- New.
    'newInstalls',     v_new_installs,
    'activeInRange',   v_active_range,
    'sessionsPerInstall', v_sessions_per,
    'themes',          v_themes,
    'reciters',        v_reciters,
    'manufacturers',   v_manufacturers,
    'osVersions',      v_os_versions,
    'notifications',   v_notif,
    'daily',           v_daily
  );
end;
$$;

-- The old zero-argument signature is REPLACED, not overloaded: adding
-- defaulted parameters to `create or replace function` of the same name keeps
-- one function. Re-grant, since replace does not preserve grants when the
-- signature changes.
revoke all on function public.admin_dashboard_stats(
  date, date, text, text, text, text, text, text, text, text, text, boolean, boolean
) from public;
grant execute on function public.admin_dashboard_stats(
  date, date, text, text, text, text, text, text, text, text, text, boolean, boolean
) to authenticated;

-- Drop the old no-arg version if Postgres kept it as a separate overload, so
-- `rpc('admin_dashboard_stats')` cannot resolve ambiguously.
drop function if exists public.admin_dashboard_stats();
