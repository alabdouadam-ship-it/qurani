"use client";

import { useCallback, useEffect, useState } from "react";
import { AppShell } from "@/components/AppShell";
import { getSupabase } from "@/lib/supabase";
import { useUi } from "@/lib/ui-context";
import {
  EMPTY_STATS_FILTER,
  EMPTY_STATS_OPTIONS,
  activeStatsFilterCount,
  isRangeInverted,
  isStatsFilterActive,
  rangePreset,
  toRpcArgs,
  type StatsFilter,
  type StatsFilterOptions,
} from "@/lib/stats-filter";

type Breakdown = { key: string; count: number }[];

/** Mirrors the jsonb built by `admin_dashboard_stats` (migration 0016). */
type Stats = {
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
function normalizeStats(data: unknown): Stats {
  const s = (data ?? {}) as Partial<Stats>;
  const num = (v: number | undefined) => (typeof v === "number" ? v : 0);
  const rows = (v: Breakdown | undefined) => (Array.isArray(v) ? v : []);
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
    features: Array.isArray(s.features) ? s.features : [],
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

export default function DashboardPage() {
  return (
    <AppShell>
      <DashboardBody />
    </AppShell>
  );
}

function DashboardBody() {
  const supabase = getSupabase();
  const { t } = useUi();
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState<Stats | null>(null);
  // Distinguished from "no data": the RPC raises `not authorized` when the
  // signed-in user is not an admin, and previously both that and an empty
  // database rendered the same "No data yet.", so a broken authorization looked
  // like a quiet product.
  const [failure, setFailure] = useState<
    { kind: "unauthorized" | "error"; detail: string } | null
  >(null);
  const [loadedAt, setLoadedAt] = useState<number | null>(null);
  const [filter, setFilter] = useState<StatsFilter>(EMPTY_STATS_FILTER);
  const [options, setOptions] =
    useState<StatsFilterOptions>(EMPTY_STATS_OPTIONS);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      // All aggregation and all filtering run server-side in Postgres
      // (admin_dashboard_stats RPC). This avoids PostgREST's ~1000-row response
      // cap that previously made the browser-side counts (sessions, installs, …)
      // under-report once a table grew past 1000 rows — and filtering in the
      // browser would have reintroduced exactly that, since it would need the
      // raw rows.
      const { data, error } = await supabase.rpc(
        "admin_dashboard_stats",
        toRpcArgs(filter)
      );
      if (error) {
        console.error("[dashboard] admin_dashboard_stats failed:", error.message);
        setStats(null);
        setFailure({
          // The function's own guard is `raise exception 'not authorized'`, so
          // match on that rather than on an HTTP status.
          kind: /not authorized/i.test(error.message) ? "unauthorized" : "error",
          detail: error.message,
        });
        return;
      }
      setFailure(null);
      setStats(normalizeStats(data));
      setLoadedAt(Date.now());
    } finally {
      setLoading(false);
    }
  }, [supabase, filter]);

  useEffect(() => {
    load();
  }, [load]);

  // Option lists are independent of the current selection, so they are fetched
  // once rather than on every filter change.
  useEffect(() => {
    (async () => {
      const { data, error } = await supabase.rpc("admin_stats_filter_options");
      if (error) {
        console.error("[dashboard] filter options failed:", error.message);
        return;
      }
      setOptions({
        ...EMPTY_STATS_OPTIONS,
        ...(data as unknown as Partial<StatsFilterOptions>),
      });
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (loading && !stats) return <p className="muted">{t.loading}</p>;

  if (failure) {
    return (
      <div className="flex flex-col gap-3">
        <h1 className="text-2xl font-bold">{t.dashboard}</h1>
        <div className="card p-4 flex flex-col gap-2">
          <p style={{ color: "var(--danger)" }}>
            {failure.kind === "unauthorized"
              ? t.statsUnauthorized
              : t.statsFailed}
          </p>
          <p className="muted text-xs">{failure.detail}</p>
          <div>
            <button className="btn btn-ghost" onClick={load} disabled={loading}>
              {loading ? t.refreshing : t.refresh}
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (!stats) return <p className="muted">{t.noData}</p>;

  const rangeLabel =
    filter.from || filter.to
      ? `${filter.from || "…"} → ${filter.to || "…"}`
      : "";

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <h1 className="text-2xl font-bold">{t.dashboard}</h1>
        <div className="flex items-center gap-3">
          {loadedAt !== null && (
            <span className="muted text-xs">
              {t.lastUpdated}: {new Date(loadedAt).toLocaleTimeString()}
            </span>
          )}
          <button className="btn btn-ghost" onClick={load} disabled={loading}>
            {loading ? t.refreshing : t.refresh}
          </button>
        </div>
      </div>

      <StatsFilterBar
        filter={filter}
        options={options}
        onChange={setFilter}
        t={t}
      />

      {/* Cohort figures: unaffected by the date range, because an install's
          attributes did not "happen" during a window. */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        <Kpi label={t.totalInstalls} value={stats.totalInstalls} />
        <Kpi label={t.activeToday} value={stats.activeToday} />
        <Kpi label={t.active7} value={stats.active7} />
        <Kpi label={t.active30} value={stats.active30} />
        <Kpi
          label={t.sessionsPerInstall}
          value={stats.sessionsPerInstall.toFixed(1)}
        />
        <Kpi label={t.avgSessionMin} value={stats.avgSessionMin.toFixed(1)} />
      </div>

      {/* Range figures. Labelled separately so it is clear which numbers the
          date pickers move and which they do not. */}
      <div className="card p-3 flex flex-col gap-2">
        <div className="muted text-xs">
          {t.rangeScopedNote}
          {rangeLabel && <> · {rangeLabel}</>}
        </div>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          <Kpi label={t.newInstalls} value={stats.newInstalls} />
          <Kpi label={t.activeInRange} value={stats.activeInRange} />
          <Kpi label={t.totalSessions} value={stats.totalSessions} />
        </div>
      </div>

      <div className="grid md:grid-cols-2 gap-4">
        <Panel title={t.topFeatures}>
          {stats.features.length === 0 ? (
            <p className="muted">{t.noData}</p>
          ) : (
            <Table
              head={[t.feature, t.opens, t.avgTimeMin]}
              rows={stats.features.map((f) => [
                f.feature,
                String(f.opens),
                f.avgMin.toFixed(1),
              ])}
            />
          )}
        </Panel>
        <Panel title={t.activeByDay}>
          <BreakRows rows={stats.daily} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.topCountriesGps}>
          <BreakRows rows={stats.gpsCountries} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.topCountriesLocale}>
          <BreakRows rows={stats.localeCountries} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.topCities}>
          <BreakRows rows={stats.cities} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.platformSplit}>
          <BreakRows rows={stats.platforms} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.languageSplit}>
          <BreakRows rows={stats.languages} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.versionSplit}>
          <BreakRows rows={stats.versions} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.themeSplit}>
          <BreakRows rows={stats.themes} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.reciterSplit}>
          <BreakRows rows={stats.reciters} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.manufacturerSplit}>
          <BreakRows rows={stats.manufacturers} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.osVersionSplit}>
          <BreakRows rows={stats.osVersions} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.notificationSplit}>
          <BreakRows rows={stats.notifications} emptyLabel={t.noData} />
        </Panel>
      </div>
    </div>
  );
}

/**
 * Every filter the stats RPC accepts.
 *
 * Dropdowns are populated from `admin_stats_filter_options`, so they only offer
 * values that occur in the data — picking a combination that returns nothing is
 * still possible, but picking a value that could never match is not.
 */
function StatsFilterBar({
  filter,
  options,
  onChange,
  t,
}: {
  filter: StatsFilter;
  options: StatsFilterOptions;
  onChange: (f: StatsFilter) => void;
  t: ReturnType<typeof useUi>["t"];
}) {
  const set = <K extends keyof StatsFilter>(k: K, v: StatsFilter[K]) =>
    onChange({ ...filter, [k]: v });

  const count = activeStatsFilterCount(filter);
  const inverted = isRangeInverted(filter);

  return (
    <div className="card p-3 flex flex-col gap-3">
      <div className="flex flex-wrap items-end gap-2">
        <div>
          <label className="label">{t.dateFrom}</label>
          <input
            className="input"
            type="date"
            style={{ width: "auto" }}
            value={filter.from}
            min={options.firstDay ?? undefined}
            max={options.lastDay ?? undefined}
            onChange={(e) => set("from", e.target.value)}
          />
        </div>
        <div>
          <label className="label">{t.dateTo}</label>
          <input
            className="input"
            type="date"
            style={{ width: "auto" }}
            value={filter.to}
            min={options.firstDay ?? undefined}
            max={options.lastDay ?? undefined}
            onChange={(e) => set("to", e.target.value)}
          />
        </div>
        {/* Presets, because typing two dates to ask "how did last week look" is
            friction that stops the question being asked. */}
        {[7, 30, 90].map((d) => (
          <button
            key={d}
            type="button"
            className="btn btn-ghost"
            onClick={() => onChange({ ...filter, ...rangePreset(d) })}
          >
            {d}d
          </button>
        ))}
      </div>

      {inverted && (
        <p className="text-sm" style={{ color: "var(--danger)" }}>
          {t.rangeInverted}
        </p>
      )}

      <div className="flex flex-wrap gap-2">
        <Sel
          label={t.platformSplit}
          value={filter.platform}
          options={options.platforms}
          onChange={(v) => set("platform", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.versionSplit}
          value={filter.version}
          options={options.versions}
          onChange={(v) => set("version", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.topCountriesLocale}
          value={filter.country}
          options={options.countries}
          onChange={(v) => set("country", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.topCountriesGps}
          value={filter.gpsCountry}
          options={options.gpsCountries}
          onChange={(v) => set("gpsCountry", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.topCities}
          value={filter.city}
          options={options.cities}
          onChange={(v) => set("city", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.languageSplit}
          value={filter.language}
          options={options.languages}
          onChange={(v) => set("language", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.themeSplit}
          value={filter.theme}
          options={options.themes}
          onChange={(v) => set("theme", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.reciterSplit}
          value={filter.reciter}
          options={options.reciters}
          onChange={(v) => set("reciter", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.manufacturerSplit}
          value={filter.manufacturer}
          options={options.manufacturers}
          onChange={(v) => set("manufacturer", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.notificationSplit}
          value={filter.notifications}
          options={["on", "off"]}
          onChange={(v) => set("notifications", v)}
          allLabel={t.filterAll}
        />
        <Sel
          label={t.deviceType}
          value={filter.device}
          options={["physical", "emulator"]}
          onChange={(v) => set("device", v)}
          allLabel={t.filterAll}
        />
      </div>

      {isStatsFilterActive(filter) && (
        <div className="flex items-center gap-3">
          <span className="muted text-xs">
            {t.filtersActive}: {count}
          </span>
          <button
            type="button"
            className="btn btn-ghost"
            onClick={() => onChange(EMPTY_STATS_FILTER)}
          >
            {t.clearFilters}
          </button>
        </div>
      )}
    </div>
  );
}

/** Labelled single-select whose blank option means "no filter". */
function Sel({
  label,
  value,
  options,
  onChange,
  allLabel,
}: {
  label: string;
  value: string;
  options: string[];
  onChange: (v: string) => void;
  allLabel: string;
}) {
  return (
    <div>
      <label className="label">{label}</label>
      <select
        className="select"
        style={{ width: "auto", padding: "0.35rem 0.5rem" }}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        <option value="">{allLabel}</option>
        {options.map((o) => (
          <option key={o} value={o}>
            {o}
          </option>
        ))}
      </select>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="card p-4">
      <div className="muted text-sm">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="card p-4">
      <h2 className="font-bold mb-3">{title}</h2>
      {children}
    </div>
  );
}

function Table({ head, rows }: { head: string[]; rows: string[][] }) {
  return (
    <div className="overflow-x-auto -mx-1 px-1">
      <table className="w-full text-sm min-w-[360px]">
        <thead>
          <tr className="muted text-start">
            {head.map((h, i) => (
              <th key={i} className="py-1 text-start font-semibold">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} style={{ borderTop: "1px solid var(--border)" }}>
              {r.map((c, j) => (
                <td key={j} className="py-1.5">
                  {c}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function BreakRows({
  rows,
  emptyLabel,
}: {
  rows: { key: string; count: number }[];
  emptyLabel: string;
}) {
  if (rows.length === 0) return <p className="muted">{emptyLabel}</p>;
  const max = Math.max(...rows.map((r) => r.count), 1);
  return (
    <div className="flex flex-col gap-2">
      {rows.map((r, i) => (
        <div key={i} className="flex items-center gap-2 text-sm">
          <span style={{ minWidth: 90 }}>{r.key}</span>
          <div
            className="flex-1 rounded"
            style={{ background: "var(--surface-2)", height: 8 }}
          >
            <div
              style={{
                width: `${(r.count / max) * 100}%`,
                background: "var(--primary)",
                height: 8,
                borderRadius: 6,
              }}
            />
          </div>
          <span className="muted" style={{ minWidth: 32, textAlign: "end" }}>
            {r.count}
          </span>
        </div>
      ))}
    </div>
  );
}
