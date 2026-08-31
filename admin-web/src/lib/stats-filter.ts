/**
 * Dashboard filter state, and the mapping to the RPC's arguments.
 *
 * Kept out of the page for the usual reason in this codebase: it is pure, so it
 * can be reasoned about without React, and the "which of these two kinds of
 * filter am I?" distinction has somewhere to be written down once.
 *
 * There are two kinds, and the difference decides what a number means:
 *
 *   COHORT filters pick a set of installations — platform, version, country,
 *   city, language, theme, reciter, manufacturer, notifications, device type.
 *   They are properties of an install.
 *
 *   The DATE RANGE bounds events — sessions, feature opens, active days, and
 *   first-seen.
 *
 * So "installs by platform" ignores the date range (an install's platform did
 * not happen during a week), while "sessions" and "new installs" respect it.
 * Migration 0016 carries the same explanation on the SQL side.
 */

/** Empty string means "no filter" throughout, because that is what an unselected
 *  `<select>` yields — it is converted to null at the RPC boundary. */
export type StatsFilter = {
  from: string; // yyyy-mm-dd
  to: string; // yyyy-mm-dd
  platform: string;
  version: string;
  country: string;
  gpsCountry: string;
  city: string;
  language: string;
  theme: string;
  reciter: string;
  manufacturer: string;
  /** "" | "on" | "off" */
  notifications: string;
  /** "" | "physical" | "emulator" */
  device: string;
};

export const EMPTY_STATS_FILTER: StatsFilter = {
  from: "",
  to: "",
  platform: "",
  version: "",
  country: "",
  gpsCountry: "",
  city: "",
  language: "",
  theme: "",
  reciter: "",
  manufacturer: "",
  notifications: "",
  device: "",
};

/** Distinct values offered by the option-list RPC. */
export type StatsFilterOptions = {
  platforms: string[];
  versions: string[];
  countries: string[];
  gpsCountries: string[];
  cities: string[];
  languages: string[];
  themes: string[];
  reciters: string[];
  manufacturers: string[];
  features: string[];
  firstDay: string | null;
  lastDay: string | null;
};

export const EMPTY_STATS_OPTIONS: StatsFilterOptions = {
  platforms: [],
  versions: [],
  countries: [],
  gpsCountries: [],
  cities: [],
  languages: [],
  themes: [],
  reciters: [],
  manufacturers: [],
  features: [],
  firstDay: null,
  lastDay: null,
};

export function isStatsFilterActive(f: StatsFilter): boolean {
  return Object.values(f).some((v) => v !== "");
}

/** How many dimensions are constrained — shown next to "Clear" so it is obvious
 *  at a glance that a surprising number is the result of a filter. */
export function activeStatsFilterCount(f: StatsFilter): number {
  return Object.values(f).filter((v) => v !== "").length;
}

/** True when the date range is set and inverted, which would silently yield
 *  zeroes for every event-based figure. */
export function isRangeInverted(f: StatsFilter): boolean {
  return f.from !== "" && f.to !== "" && f.from > f.to;
}

const emptyToNull = (v: string): string | null => (v === "" ? null : v);

/** Maps UI state onto the RPC parameters. Tri-state values ("", "on", "off")
 *  become true/false/null, since the SQL treats null as "no filter". */
export function toRpcArgs(f: StatsFilter) {
  return {
    p_from: emptyToNull(f.from),
    p_to: emptyToNull(f.to),
    p_platform: emptyToNull(f.platform),
    p_app_version: emptyToNull(f.version),
    p_country: emptyToNull(f.country),
    p_gps_country: emptyToNull(f.gpsCountry),
    p_city: emptyToNull(f.city),
    p_language: emptyToNull(f.language),
    p_theme: emptyToNull(f.theme),
    p_reciter: emptyToNull(f.reciter),
    p_manufacturer: emptyToNull(f.manufacturer),
    p_notifications:
      f.notifications === "" ? null : f.notifications === "on",
    p_physical_device: f.device === "" ? null : f.device === "physical",
  };
}

/** Convenience presets for the date range, since typing two dates to answer
 *  "how did last week look" is friction that stops people asking. */
export function rangePreset(days: number): { from: string; to: string } {
  const today = new Date();
  const to = today.toISOString().slice(0, 10);
  const fromDate = new Date(today.getTime() - (days - 1) * 864e5);
  return { from: fromDate.toISOString().slice(0, 10), to };
}
