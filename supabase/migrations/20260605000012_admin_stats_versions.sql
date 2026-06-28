-- ============================================================================
-- Migration 0012 — Add "installs by app version" to the dashboard stats RPC
-- ============================================================================
-- Adds a `versions` breakdown (top app_version values + counts) to the
-- existing admin_dashboard_stats() JSON. No new data is collected — app_version
-- is already stored per install by record_installation(). Admin-side only.
--
-- Self-contained: this `create or replace` redefines the whole function and
-- (re)applies the grant, so it is safe to run whether or not 0011 was applied.
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
  v_versions         jsonb;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  select count(*) into v_total_installs from public.app_installations;

  select count(distinct installation_id) into v_active_today
    from public.installation_active_days where day = v_today;
  select count(distinct installation_id) into v_active_7
    from public.installation_active_days where day >= v_today - 6;
  select count(distinct installation_id) into v_active_30
    from public.installation_active_days where day >= v_today - 29;

  select count(*), coalesce(avg(duration_seconds), 0) / 60.0
    into v_total_sessions, v_avg_session_min
    from public.usage_sessions;

  select coalesce(jsonb_agg(row_to_json(f)), '[]'::jsonb) into v_features
  from (
    select
      coalesce(nullif(feature, ''), 'unknown') as feature,
      count(*) filter (where action <> 'view')  as opens,
      coalesce(avg(duration_seconds) filter (where action = 'view'), 0) / 60.0
        as "avgMin"
    from public.feature_events
    group by 1 order by opens desc, feature asc limit 12
  ) f;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_locale_countries
  from (
    select coalesce(nullif(country_code, ''), '—') as key, count(*) as count
    from public.app_installations group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_gps_countries
  from (
    select coalesce(nullif(gps_country, ''), '—') as key, count(*) as count
    from public.app_installations group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_cities
  from (
    select coalesce(nullif(city, ''), '—') as key, count(*) as count
    from public.app_installations group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_platforms
  from (
    select coalesce(nullif(platform, ''), 'unknown') as key, count(*) as count
    from public.app_installations group by 1 order by count desc, key asc limit 10
  ) c;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_languages
  from (
    select
      coalesce(nullif(app_language, ''), nullif(locale_language, ''), 'unknown')
        as key,
      count(*) as count
    from public.app_installations group by 1 order by count desc, key asc limit 10
  ) c;

  -- NEW: installs by app version (build appended when present).
  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb) into v_versions
  from (
    select
      case
        when coalesce(nullif(app_version, ''), '') = '' then 'unknown'
        when coalesce(nullif(app_build, ''), '') = '' then app_version
        else app_version || '+' || app_build
      end as key,
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
    'languages',       v_languages,
    'versions',        v_versions
  );
end;
$$;

revoke all on function public.admin_dashboard_stats() from public;
grant execute on function public.admin_dashboard_stats() to authenticated;
