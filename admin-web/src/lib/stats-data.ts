type Breakdown = { key: string; count: number }[];

/** Mirrors the jsonb built by `admin_dashboard_stats` (migration 0016). */
export type Stats = {
  totalInstalls: number;
  /** Installs whose first_seen falls inside the selected range. */
  newInstalls: number;
  activeToday: number;
  active7: number;
  active30: number;
  /** Distinct installs active inside the selected range. */
  activeInRange: number;
  totalSessions: number;
  avgSessionMin: number;
  sessionsPerInstall: number;
  features: { feature: string; opens: number; avgMin: number }[];
  localeCountries: Breakdown;
  gpsCountries: Breakdown;
  cities: Breakdown;
  platforms: Breakdown;
  languages: Breakdown;
  versions: Breakdown;
  themes: Breakdown;
  reciters: Breakdown;
  manufacturers: Breakdown;
  osVersions: Breakdown;
  notifications: Breakdown;
  /** Active installs per calendar day inside the range, most recent first. */
  daily: Breakdown;
};

/**
 * Fills in any key the RPC did not return.
 *
 * The filters and the extra breakdowns arrive with migration 0016. If this build
 * is deployed against a database that has not been migrated yet, the older
 * function returns the original payload and every new key is undefined —
 * `stats.sessionsPerInstall.toFixed(1)` would then throw and white-screen the
 * page. Defaulting degrades to "the numbers I used to show" instead, which is a
 * far better failure than a blank dashboard.
 */
export function normalizeStats(data: unknown): Stats {
  const s = (data && typeof data === "object" ? data : {}) as Partial<Stats>;
  const num = (v: number | undefined) => (typeof v === "number" && Number.isFinite(v) ? v : 0);
  const rows = (v: Breakdown | undefined): Breakdown => Array.isArray(v)
    ? v.filter(r => r && typeof r.key === "string")
        .map(r => ({ key: r.key, count: num(r.count) })) : [];
  return {
    totalInstalls: num(s.totalInstalls),
    newInstalls: num(s.newInstalls),
    activeToday: num(s.activeToday),
    active7: num(s.active7),
    active30: num(s.active30),
    activeInRange: num(s.activeInRange),
    totalSessions: num(s.totalSessions),
    avgSessionMin: num(s.avgSessionMin),
    sessionsPerInstall: num(s.sessionsPerInstall),
    features: Array.isArray(s.features)
      ? s.features.filter(f => f && typeof f.feature === "string")
          .map(f => ({ feature: f.feature, opens: num(f.opens), avgMin: num(f.avgMin) })) : [],
    localeCountries: rows(s.localeCountries),
    gpsCountries: rows(s.gpsCountries),
    cities: rows(s.cities),
    platforms: rows(s.platforms),
    languages: rows(s.languages),
    versions: rows(s.versions),
    themes: rows(s.themes),
    reciters: rows(s.reciters),
    manufacturers: rows(s.manufacturers),
    osVersions: rows(s.osVersions),
    notifications: rows(s.notifications),
    daily: rows(s.daily),
  };
}
