"use client";

import { useCallback, useEffect, useState } from "react";
import { AppShell } from "@/components/AppShell";
import { getSupabase } from "@/lib/supabase";
import { useUi } from "@/lib/ui-context";
import { useAuth } from "@/lib/auth-context";
import type { NewsRow } from "@/lib/types";

export default function NewsPage() {
  return (
    <AppShell>
      <NewsBody />
    </AppShell>
  );
}

const EMPTY: NewsRow = {
  id: "",
  title: "",
  description: "",
  type: "text",
  media_url: "",
  source_url: "",
  publish_date: new Date().toISOString(),
  valid_until: new Date(Date.now() + 30 * 864e5).toISOString(),
  language: "ar",
  category_ar: null,
  category_en: null,
  category_fr: null,
  target_languages: [],
  target_countries: [],
  excluded_countries: [],
  is_featured: false,
  send_notification: false,
  is_published: true,
  updated_by: null,
};

function csv(arr: string[]): string {
  return arr.join(", ");
}
function parseCsv(s: string): string[] {
  return s
    .split(",")
    .map((x) => x.trim())
    .filter((x) => x.length > 0);
}
function parseCountries(s: string): string[] {
  return parseCsv(s).map((x) => x.toUpperCase());
}
function toLocalInput(iso: string): string {
  // datetime-local wants "YYYY-MM-DDTHH:mm" in local time.
  const d = new Date(iso);
  const off = d.getTimezoneOffset();
  const local = new Date(d.getTime() - off * 60000);
  return local.toISOString().slice(0, 16);
}
function fromLocalInput(v: string): string {
  return new Date(v).toISOString();
}

function NewsBody() {
  const supabase = getSupabase();
  const { t, lang } = useUi();
  const { admin } = useAuth();

  const [rows, setRows] = useState<NewsRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<NewsRow | null>(null);
  // Computed once per load (not per render) so the render stays pure.
  const [split, setSplit] = useState<{ current: NewsRow[]; history: NewsRow[] }>(
    { current: [], history: [] }
  );

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from("news_items")
      .select("*")
      .order("publish_date", { ascending: false });
    const list = (data as NewsRow[]) ?? [];
    const now = Date.now();
    setRows(list);
    setSplit({
      current: list.filter((r) => new Date(r.valid_until).getTime() > now),
      history: list.filter((r) => new Date(r.valid_until).getTime() <= now),
    });
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    load();
  }, [load]);

  const { current, history } = split;

  async function remove(id: string) {
    if (!confirm(t.confirmDelete)) return;
    await supabase.from("news_items").delete().eq("id", id);
    load();
  }

  function statusOf(r: NewsRow): string {
    const nowMs = Date.now();
    if (new Date(r.valid_until).getTime() <= nowMs) return t.expired;
    if (new Date(r.publish_date).getTime() > nowMs) return t.scheduled;
    return t.live;
  }

  if (editing) {
    return (
      <NewsEditor
        initial={editing}
        adminName={admin?.name ?? ""}
        onClose={() => setEditing(null)}
        onSaved={() => {
          setEditing(null);
          load();
        }}
      />
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">{t.news}</h1>
        <button
          className="btn btn-primary"
          onClick={() => setEditing({ ...EMPTY, id: crypto.randomUUID() })}
        >
          + {t.addNews}
        </button>
      </div>

      {loading ? (
        <p className="muted">{t.loading}</p>
      ) : rows.length === 0 ? (
        <p className="muted">{t.noNews}</p>
      ) : (
        <>
          <Section title={`${t.current} (${current.length})`}>
            <NewsList
              items={current}
              lang={lang}
              t={t}
              statusOf={statusOf}
              onEdit={setEditing}
              onDelete={remove}
            />
          </Section>
          {history.length > 0 && (
            <Section title={`${t.history} (${history.length})`}>
              <NewsList
                items={history}
                lang={lang}
                t={t}
                statusOf={statusOf}
                onEdit={setEditing}
                onDelete={remove}
              />
            </Section>
          )}
        </>
      )}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-2">
      <h2 className="font-bold muted">{title}</h2>
      {children}
    </div>
  );
}

function NewsList({
  items,
  t,
  statusOf,
  onEdit,
  onDelete,
}: {
  items: NewsRow[];
  lang: string;
  t: ReturnType<typeof useUi>["t"];
  statusOf: (r: NewsRow) => string;
  onEdit: (r: NewsRow) => void;
  onDelete: (id: string) => void;
}) {
  return (
    <div className="flex flex-col gap-2">
      {items.map((r) => (
        <div key={r.id} className="card p-3 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-semibold truncate">{r.title}</span>
              <Tag>{r.type}</Tag>
              <Tag>{r.language}</Tag>
              {r.is_featured && <Tag>{t.featured}</Tag>}
              {r.send_notification && <Tag>🔔</Tag>}
              <Tag>{statusOf(r)}</Tag>
            </div>
            <div className="muted text-sm mt-1 truncate">{r.description}</div>
            <div className="muted text-xs mt-1">
              {new Date(r.publish_date).toLocaleString()} →{" "}
              {new Date(r.valid_until).toLocaleDateString()}
              {(r.target_countries?.length || r.excluded_countries?.length) ? (
                <>
                  {"  ·  "}
                  {r.target_countries?.length ? `▷ ${r.target_countries.join(",")}` : ""}
                  {r.excluded_countries?.length ? ` ⊘ ${r.excluded_countries.join(",")}` : ""}
                </>
              ) : null}
              {r.updated_by ? `  ·  ${t.lastEditedBy}: ${r.updated_by}` : ""}
            </div>
          </div>
          <div className="flex flex-col gap-2 shrink-0">
            <button className="btn btn-ghost" onClick={() => onEdit(r)}>
              {t.edit}
            </button>
            <button className="btn btn-danger" onClick={() => onDelete(r.id)}>
              {t.delete}
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}

function Tag({ children }: { children: React.ReactNode }) {
  return (
    <span
      className="text-xs px-2 py-0.5 rounded"
      style={{ background: "var(--surface-2)", color: "var(--muted)" }}
    >
      {children}
    </span>
  );
}

function NewsEditor({
  initial,
  adminName,
  onClose,
  onSaved,
}: {
  initial: NewsRow;
  adminName: string;
  onClose: () => void;
  onSaved: () => void;
}) {
  const supabase = getSupabase();
  const { t } = useUi();
  const [r, setR] = useState<NewsRow>(initial);
  const [tc, setTc] = useState(csv(initial.target_countries ?? []));
  const [ec, setEc] = useState(csv(initial.excluded_countries ?? []));
  const [tl, setTl] = useState(csv(initial.target_languages ?? []));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function set<K extends keyof NewsRow>(k: K, v: NewsRow[K]) {
    setR((p) => ({ ...p, [k]: v }));
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const payload: NewsRow = {
        ...r,
        target_countries: parseCountries(tc),
        excluded_countries: parseCountries(ec),
        target_languages: parseCsv(tl),
        category_ar: emptyToNull(r.category_ar),
        category_en: emptyToNull(r.category_en),
        category_fr: emptyToNull(r.category_fr),
        updated_by: adminName,
      };
      // upsert by primary key id (insert or update).
      const { error: upErr } = await supabase
        .from("news_items")
        .upsert(payload, { onConflict: "id" });
      if (upErr) {
        setError(upErr.message);
        return;
      }
      onSaved();
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={save} className="flex flex-col gap-3 max-w-2xl">
      <h1 className="text-2xl font-bold">{initial.title ? t.editNews : t.addNews}</h1>

      <Field label={t.title}>
        <input className="input" value={r.title} onChange={(e) => set("title", e.target.value)} required />
      </Field>

      <Field label={t.description}>
        <textarea
          className="textarea"
          rows={4}
          value={r.description}
          onChange={(e) => set("description", e.target.value)}
        />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label={t.type}>
          <select className="select" value={r.type} onChange={(e) => set("type", e.target.value as NewsRow["type"])}>
            <option value="text">{t.typeText}</option>
            <option value="image">{t.typeImage}</option>
            <option value="youtube">{t.typeYoutube}</option>
          </select>
        </Field>
        <Field label={t.language}>
          <select className="select" value={r.language} onChange={(e) => set("language", e.target.value)}>
            <option value="ar">ar</option>
            <option value="en">en</option>
            <option value="fr">fr</option>
          </select>
        </Field>
      </div>

      {r.type !== "text" && (
        <Field label={t.mediaUrl}>
          <input className="input" value={r.media_url} onChange={(e) => set("media_url", e.target.value)} />
        </Field>
      )}

      <Field label={t.sourceUrl}>
        <input className="input" value={r.source_url} onChange={(e) => set("source_url", e.target.value)} />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label={t.publishDate}>
          <input
            className="input"
            type="datetime-local"
            value={toLocalInput(r.publish_date)}
            onChange={(e) => set("publish_date", fromLocalInput(e.target.value))}
          />
        </Field>
        <Field label={t.validUntil}>
          <input
            className="input"
            type="datetime-local"
            value={toLocalInput(r.valid_until)}
            onChange={(e) => set("valid_until", fromLocalInput(e.target.value))}
          />
        </Field>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <Field label={t.categoryAr}>
          <input className="input" value={r.category_ar ?? ""} onChange={(e) => set("category_ar", e.target.value)} />
        </Field>
        <Field label={t.categoryEn}>
          <input className="input" value={r.category_en ?? ""} onChange={(e) => set("category_en", e.target.value)} />
        </Field>
        <Field label={t.categoryFr}>
          <input className="input" value={r.category_fr ?? ""} onChange={(e) => set("category_fr", e.target.value)} />
        </Field>
      </div>

      <Field label={t.targetLanguages} hint={t.languagesHint}>
        <input className="input" value={tl} onChange={(e) => setTl(e.target.value)} placeholder="ar, en, fr" />
      </Field>
      <Field label={t.targetCountries} hint={t.countriesHint}>
        <input className="input" value={tc} onChange={(e) => setTc(e.target.value)} placeholder="SA, FR" />
      </Field>
      <Field label={t.excludedCountries} hint={t.countriesHint}>
        <input className="input" value={ec} onChange={(e) => setEc(e.target.value)} placeholder="US" />
      </Field>

      <div className="flex flex-wrap gap-4">
        <Check label={t.featured} checked={r.is_featured} onChange={(v) => set("is_featured", v)} />
        <Check label={t.sendNotification} checked={r.send_notification} onChange={(v) => set("send_notification", v)} />
        <Check label={t.published} checked={r.is_published} onChange={(v) => set("is_published", v)} />
      </div>

      {error && <p className="text-sm" style={{ color: "var(--danger)" }}>{error}</p>}

      <div className="flex gap-2">
        <button className="btn btn-primary" disabled={busy}>
          {t.save}
        </button>
        <button type="button" className="btn btn-ghost" onClick={onClose}>
          {t.cancel}
        </button>
      </div>
    </form>
  );
}

function emptyToNull(s: string | null): string | null {
  if (s == null) return null;
  const v = s.trim();
  return v.length === 0 ? null : v;
}

function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <div>
      <label className="label">{label}</label>
      {children}
      {hint && <div className="muted text-xs mt-1">{hint}</div>}
    </div>
  );
}

function Check({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex items-center gap-2 cursor-pointer">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span>{label}</span>
    </label>
  );
}
