"use client";

import { useEffect, useState } from "react";
import { AppShell } from "@/components/AppShell";
import { getSupabase } from "@/lib/supabase";
import { useUi } from "@/lib/ui-context";

type Stats = {
  totalInstalls: number;
  activeToday: number;
  active7: number;
  active30: number;
  totalSessions: number;
  avgSessionMin: number;
  features: { feature: string; opens: number; avgMin: number }[];
  localeCountries: { key: string; count: number }[];
  gpsCountries: { key: string; count: number }[];
  cities: { key: string; count: number }[];
  platforms: { key: string; count: number }[];
  languages: { key: string; count: number }[];
  versions: { key: string; count: number }[];
};

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

  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        // All aggregation runs server-side in Postgres (admin_dashboard_stats
        // RPC). This avoids PostgREST's ~1000-row response cap that previously
        // made the browser-side counts (sessions, installs, …) under-report
        // once a table grew past 1000 rows.
        const { data, error } = await supabase.rpc("admin_dashboard_stats");
        if (error) {
          console.error("[dashboard] admin_dashboard_stats failed:", error.message);
          setStats(null);
          return;
        }
        setStats((data as Stats) ?? null);
      } finally {
        setLoading(false);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (loading) return <p className="muted">{t.loading}</p>;
  if (!stats) return <p className="muted">{t.noData}</p>;

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-bold">{t.dashboard}</h1>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        <Kpi label={t.totalInstalls} value={stats.totalInstalls} />
        <Kpi label={t.activeToday} value={stats.activeToday} />
        <Kpi label={t.active7} value={stats.active7} />
        <Kpi label={t.active30} value={stats.active30} />
        <Kpi label={t.totalSessions} value={stats.totalSessions} />
        <Kpi label={t.avgSessionMin} value={stats.avgSessionMin.toFixed(1)} />
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
      </div>
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
