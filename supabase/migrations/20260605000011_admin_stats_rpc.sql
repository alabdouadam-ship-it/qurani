-- ============================================================================
-- Migration 0011 — Server-side dashboard aggregation RPC
-- ============================================================================
-- WHY: the admin dashboard used to `select` whole tables and aggregate in the
-- browser. PostgREST caps every response at ~1000 rows, so once a table grew
-- past 1000 rows the dashboard silently under-counted (e.g. "1000 sessions"
-- while the DB held 2000+). Aggregation must run in Postgres and return a
-- compact result instead of shipping every row to the client.
--
-- This adds ONE admin-only `SECURITY DEFINER` function that computes all the
-- dashboard numbers in SQL and returns a single jsonb object whose shape
-- matches the dashboard's `Stats` type exactly. Raw rows never leave the DB.
--
-- Security: the function is admin-gated via public.is_admin() and granted only
-- to `authenticated`. anon cannot execute it. It runs as owner (SECURITY
-- DEFINER) so it reads the RLS-locked stats tables without per-row checks.
--
-- Apply AFTER 0001/0004/0010.
-- ============================================================================

create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_today            date := (now() at time zone 'utc')::date;
  v_total_installs   bigint;
  v_active_today     bigint;
  v_active_7         bigint;
  v_active_30        bigint;
  v_total_sessions   bigint;
  v_avg_session_min  numeric;
  v_features         jsonb;
  v_locale_countries jsonb;
  v_gps_countries    jsonb;
  v_cities           jsonb;
  v_platforms        jsonb;
  v_languages        jsonb;
begin
  -- Admin-only. A non-admin authenticated user gets a hard error.
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  select count(*) into v_total_installs from public.app_installations;

  -- DAU / MAU windows (distinct installs active in each window).
  select count(distinct installation_id) into v_active_today
    from public.installation_active_days
    where day = v_today;
  select count(distinct installation_id) into v_active_7
    from public.installation_active_days
    where day >= v_today - 6;
  select count(distinct installation_id) into v_active_30
    from public.installation_active_days
    where day >= v_today - 29;

  -- Sessions: total count + average duration in minutes.
  select count(*), coalesce(avg(duration_seconds), 0) / 60.0
    into v_total_sessions, v_avg_session_min
    from public.usage_sessions;

  -- Top features: opens = non-'view' actions; avgMin = avg view-time minutes.
  select coalesce(jsonb_agg(row_to_json(f)), '[]'::jsonb) into v_features
  from (
    select
      coalesce(nullif(feature, ''), 'unknown') as feature,
      count(*) filter (where action <> 'view')  as opens,
      coalesce(avg(duration_seconds) filter (where action = 'view'), 0) / 60.0
        as "avgMin"
    from public.feature_events
    group by 1
    order by opens desc, feature asc
    limit 12
  ) f;

  -- Top countries by device-locale country code.
  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_locale_countries
  from (
    select coalesce(nullif(country_code, ''), '—') as key, count(*) as count
    from public.app_installations
    group by 1 order by count desc, key asc limit 10
  ) c;

  -- Top countries by GPS-derived country.
  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_gps_countries
  from (
    select coalesce(nullif(gps_country, ''), '—') as key, count(*) as count
    from public.app_installations
    group by 1 order by count desc, key asc limit 10
  ) c;

  -- Top cities.
  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_cities
  from (
    select coalesce(nullif(city, ''), '—') as key, count(*) as count
    from public.app_installations
    group by 1 order by count desc, key asc limit 10
  ) c;

  -- Platform split.
  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_platforms
  from (
    select coalesce(nullif(platform, ''), 'unknown') as key, count(*) as count
    from public.app_installations
    group by 1 order by count desc, key asc limit 10
  ) c;

  -- Language split (selected app language, falling back to locale language).
  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_languages
  from (
    select
      coalesce(nullif(app_language, ''), nullif(locale_language, ''), 'unknown')
        as key,
      count(*) as count
    from public.app_installations
    group by 1 order by count desc, key asc limit 10
  ) c;

  return jsonb_build_object(
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
    'languages',       v_languages
  );
end;
$$;

-- Only authenticated admins may call it (the body re-checks is_admin()).
revoke all on function public.admin_dashboard_stats() from public;
grant execute on function public.admin_dashboard_stats() to authenticated;
