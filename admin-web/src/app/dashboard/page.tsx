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
  countries: { key: string; count: number }[];
  platforms: { key: string; count: number }[];
  languages: { key: string; count: number }[];
};

type InstallRow = {
  platform: string | null;
  locale_language: string | null;
  app_language: string | null;
  country_code: string | null;
};
type SessionRow = { duration_seconds: number | null };
type EventRow = {
  feature: string | null;
  action: string | null;
  duration_seconds: number | null;
};
type ActiveDayRow = { installation_id: string; day: string };

function dayStr(d: Date) {
  return d.toISOString().slice(0, 10);
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

  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        const today = new Date();
        const d7 = new Date(today);
        d7.setDate(d7.getDate() - 6);
        const d30 = new Date(today);
        d30.setDate(d30.getDate() - 29);

        // Installations (with platform / language / country breakdowns).
        const { data: installs } = await supabase
          .from("app_installations")
          .select("platform, locale_language, app_language, country_code");

        // Active days (DAU/MAU windows).
        const { data: activeDays } = await supabase
          .from("installation_active_days")
          .select("installation_id, day")
          .gte("day", dayStr(d30));

        // Sessions (count + average duration).
        const { data: sessions } = await supabase
          .from("usage_sessions")
          .select("duration_seconds");

        // Feature events (opens + view durations).
        const { data: events } = await supabase
          .from("feature_events")
          .select("feature, action, duration_seconds");

        const installRows = (installs ?? []) as InstallRow[];
        const sessionRows = (sessions ?? []) as SessionRow[];
        const eventRows = (events ?? []) as EventRow[];
        const activeRows = (activeDays ?? []) as ActiveDayRow[];
        const totalInstalls = installRows.length;

        const platforms = topCounts(
          installRows.map((r) => r.platform || "unknown")
        );
        const languages = topCounts(
          installRows.map(
            (r) => r.app_language || r.locale_language || "unknown"
          )
        );
        const countries = topCounts(
          installRows.map((r) => r.country_code || "—")
        );

        const todayKey = dayStr(today);
        const d7Key = dayStr(d7);
        const setToday = new Set<string>();
        const set7 = new Set<string>();
        const set30 = new Set<string>();
        for (const r of activeRows) {
          const id = r.installation_id;
          const day = r.day;
          set30.add(id);
          if (day >= d7Key) set7.add(id);
          if (day === todayKey) setToday.add(id);
        }

        const totalSessions = sessionRows.length;
        const totalSecs = sessionRows.reduce(
          (a, r) => a + (r.duration_seconds || 0),
          0
        );
        const avgSessionMin =
          totalSessions > 0 ? totalSecs / totalSessions / 60 : 0;

        // Feature aggregation: opens count + average view time.
        const featAgg = new Map<
          string,
          { opens: number; viewSecs: number; views: number }
        >();
        for (const e of eventRows) {
          const f = e.feature || "unknown";
          const cur = featAgg.get(f) ?? { opens: 0, viewSecs: 0, views: 0 };
          if (e.action === "view") {
            cur.viewSecs += e.duration_seconds || 0;
            cur.views += 1;
          } else {
            cur.opens += 1;
          }
          featAgg.set(f, cur);
        }
        const features = Array.from(featAgg.entries())
          .map(([feature, v]) => ({
            feature,
            opens: v.opens,
            avgMin: v.views > 0 ? v.viewSecs / v.views / 60 : 0,
          }))
          .sort((a, b) => b.opens - a.opens)
          .slice(0, 12);

        setStats({
          totalInstalls,
          activeToday: setToday.size,
          active7: set7.size,
          active30: set30.size,
          totalSessions,
          avgSessionMin,
          features,
          countries,
          platforms,
          languages,
        });
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
        <Panel title={t.topCountries}>
          <BreakRows rows={stats.countries} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.platformSplit}>
          <BreakRows rows={stats.platforms} emptyLabel={t.noData} />
        </Panel>
        <Panel title={t.languageSplit}>
          <BreakRows rows={stats.languages} emptyLabel={t.noData} />
        </Panel>
      </div>
    </div>
  );
}

function topCounts(values: string[]): { key: string; count: number }[] {
  const m = new Map<string, number>();
  for (const v of values) m.set(v, (m.get(v) ?? 0) + 1);
  return Array.from(m.entries())
    .map(([key, count]) => ({ key, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 10);
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
    <table className="w-full text-sm">
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
