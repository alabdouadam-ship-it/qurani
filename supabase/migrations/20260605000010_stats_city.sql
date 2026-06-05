-- ============================================================================
-- Migration 0010 — Add GPS country + coarse city to app_installations stats
-- ============================================================================
-- Adds two columns and two RPC params:
--   * gps_country : EXACT country (ISO alpha-2) from on-device GPS reverse-
--     geocode, populated only once the user grants location (prayer times /
--     qibla). Distinct from `country_code`, which stays the LOCALE country
--     (device-settings region, always available from first launch).
--   * city       : COARSE town/locality NAME from the same reverse-geocode.
--
-- News targeting uses gps_country when present, else falls back to the locale
-- country (client-side, see news_service.deviceCountryCode). The dashboard
-- shows BOTH country fields.
--
-- Privacy: `gps_country` and `city` are coarse, derived ON-DEVICE from the
-- location the user already granted for prayer times. NO coordinates, NO
-- street address, NO IP are stored. Disclose coarse town in the privacy policy.
--
-- The RPC's parameter list changes, so we DROP the old function (its GRANT is
-- keyed to the exact signature) and recreate it + re-grant EXECUTE to anon.
-- ============================================================================

alter table public.app_installations
  add column if not exists gps_country text,  -- exact country from GPS (ISO alpha-2)
  add column if not exists city        text;  -- coarse locality name (no coordinates)

-- Old signature (16 args) is replaced by an 18-arg one with p_gps_country and
-- p_city inserted right after p_country_code. Drop the old function so the
-- recreate doesn't collide and the stale GRANT is removed with it.
drop function if exists public.record_installation(
  uuid,text,text,text,text,boolean,text,text,text,text,text,text,integer,text,text,boolean
);

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
  p_country_code          text default null,   -- locale country (device region)
  p_gps_country           text default null,   -- exact country from GPS
  p_city                  text default null,   -- coarse town/locality name
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
    country_code, gps_country, city, timezone, tz_offset_minutes, theme_id,
    reciter_code, notifications_enabled, last_seen, updated_at
  ) values (
    p_installation_id, p_platform, p_os_version, p_device_model, p_manufacturer,
    p_is_physical_device, p_app_version, p_app_build, p_app_language, p_locale_language,
    p_country_code, p_gps_country, p_city, p_timezone, p_tz_offset_minutes, p_theme_id,
    p_reciter_code, p_notifications_enabled, now(), now()
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
    gps_country           = coalesce(excluded.gps_country, ai.gps_country),
    city                  = coalesce(excluded.city, ai.city),
    timezone              = coalesce(excluded.timezone, ai.timezone),
    tz_offset_minutes     = coalesce(excluded.tz_offset_minutes, ai.tz_offset_minutes),
    theme_id              = coalesce(excluded.theme_id, ai.theme_id),
    reciter_code          = coalesce(excluded.reciter_code, ai.reciter_code),
    notifications_enabled = coalesce(excluded.notifications_enabled, ai.notifications_enabled),
    last_seen             = now(),
    updated_at            = now();

  insert into public.installation_active_days(installation_id, day, app_version)
  values (p_installation_id, (now() at time zone 'utc')::date, p_app_version)
  on conflict (installation_id, day) do nothing;
end;
$$;

-- Re-grant EXECUTE on the NEW signature (18 args). anon may only execute.
revoke all on function public.record_installation(
  uuid,text,text,text,text,boolean,text,text,text,text,text,text,text,text,integer,text,text,boolean
) from public;
grant execute on function public.record_installation(
  uuid,text,text,text,text,boolean,text,text,text,text,text,text,text,text,integer,text,text,boolean
) to anon, authenticated;
