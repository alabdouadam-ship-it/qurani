"use client";

import { useCallback, useEffect, useState } from "react";
import { AppShell } from "@/components/AppShell";
import { ConfirmPanel } from "@/components/ConfirmPanel";
import { getSupabase } from "@/lib/supabase";
import { useUi } from "@/lib/ui-context";
import { useAuth } from "@/lib/auth-context";
import type { NewsRow } from "@/lib/types";
import {
  newsVisibility,
  type NewsLang,
  type Visibility,
} from "@/lib/news-visibility";
import { validateNews } from "@/lib/news-validation";
import {
  EMPTY_FILTER,
  groupKeyOf,
  groupNews,
  isFilterActive,
  matchesFilter,
  statusAt,
  type NewsFilter,
  type NewsGroup,
} from "@/lib/news-grouping";

export default function NewsPage() {
  return (
    <AppShell>
      <NewsBody />
    </AppShell>
  );
}

const EMPTY: NewsRow = {
  id: "",
  group_id: null,
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
  if (Number.isNaN(d.getTime())) return ""; // never feed the input "Invalid Date"
  const off = d.getTimezoneOffset();
  const local = new Date(d.getTime() - off * 60000);
  return local.toISOString().slice(0, 16);
}
/** Null when the input is empty or unparseable.
 *
 *  This used to call `new Date(v).toISOString()` unguarded, so clearing a
 *  datetime-local field threw `RangeError: Invalid time value` inside the
 *  onChange handler. Both date columns are NOT NULL, so callers keep the
 *  previous value on null rather than trying to store one. */
function fromLocalInput(v: string): string | null {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function NewsBody() {
  const supabase = getSupabase();
  const { t } = useUi();
  const { admin } = useAuth();

  const [rows, setRows] = useState<NewsRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<NewsRow | null>(null);
  const [isNew, setIsNew] = useState(false);

  // The clock the whole page reasons about, shared by the section split and the
  // per-row status badge.
  //
  // These used to be computed at different moments — the split once when data
  // loaded, the badge fresh on every render — so an item that expired while the
  // page sat open showed an "Expired" badge inside the "Current" section. One
  // shared value makes that disagreement impossible.
  //
  // It lives in state rather than being read during render because render must
  // stay pure (`Date.now()` there trips react-hooks/purity, and the React
  // Compiler is entitled to cache the result). Refreshed on load and on a
  // timer, so a row crossing valid_until moves itself to History instead of
  // lying until the next reload. 0 is safe as the initial value: the lists are
  // not rendered until `loading` turns false, which happens after `load` sets a
  // real timestamp.
  const [nowMs, setNowMs] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from("news_items")
      .select("*")
      .order("publish_date", { ascending: false });
    setRows((data as NewsRow[]) ?? []);
    setNowMs(Date.now());
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    const id = setInterval(() => setNowMs(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);

  const [filter, setFilter] = useState<NewsFilter>(EMPTY_FILTER);
  const [pendingDelete, setPendingDelete] = useState<NewsRow | null>(null);
  const [busy, setBusy] = useState(false);

  const visible = rows.filter((r) => matchesFilter(r, filter, nowMs));
  const expiresAfterNow = (r: NewsRow) =>
    new Date(r.valid_until).getTime() > nowMs;
  // Grouped AFTER filtering, so a filtered-out language simply leaves its group
  // rather than the group disappearing — and "missing" then reflects what is on
  // screen, which is what the Add-translation buttons act on.
  const current = groupNews(visible.filter(expiresAfterNow));
  const history = groupNews(visible.filter((r) => !expiresAfterNow(r)));

  function openForEdit(r: NewsRow) {
    setIsNew(false);
    setEditing(r);
  }

  /** Opens the editor on a copy of [source] for [lang].
   *
   *  Copies the body text rather than blanking it: translating in place beats
   *  retyping dates, targeting and flags, and the author overwrites the text
   *  anyway. New id (the PK), but the SAME group so the variants stay linked.
   *  `target_languages` is narrowed to the one language, matching how the seed
   *  migrations scope each variant. */
  function addTranslation(source: NewsRow, lang: string) {
    setIsNew(true);
    setEditing({
      ...source,
      id: crypto.randomUUID(),
      group_id: groupKeyOf(source),
      language: lang,
      target_languages: [lang],
      updated_by: null,
    });
  }

  async function remove(row: NewsRow) {
    setBusy(true);
    try {
      await supabase.from("news_items").delete().eq("id", row.id);
      setPendingDelete(null);
      await load();
    } finally {
      setBusy(false);
    }
  }

  // Delegates to the same helper the status filter uses, so a row can never be
  // badged "Live" while the "Live" filter hides it.
  function statusOf(r: NewsRow): string {
    const s = statusAt(r, nowMs);
    if (s === "expired") return t.expired;
    if (s === "scheduled") return t.scheduled;
    return t.live;
  }

  if (editing) {
    return (
      <NewsEditor
        initial={editing}
        isNew={isNew}
        adminName={admin?.name ?? ""}
        onClose={() => setEditing(null)}
        onSaved={() => {
          setEditing(null);
          load();
        }}
      />
    );
  }

  if (pendingDelete) {
    return (
      <ConfirmPanel
        title={t.confirmDeleteTitle}
        subject={`${pendingDelete.title} · ${pendingDelete.language}`}
        warning={t.confirmDeleteNewsWarning}
        confirmLabel={t.deletePermanently}
        onConfirm={() => remove(pendingDelete)}
        onCancel={() => setPendingDelete(null)}
        busy={busy}
      />
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">{t.news}</h1>
        <button
          className="btn btn-primary"
          onClick={() => {
            setIsNew(true);
            // group_id defaults to the row's own id so a fresh post is a group
            // of one that later translations can join.
            const id = crypto.randomUUID();
            setEditing({ ...EMPTY, id, group_id: id });
          }}
        >
          + {t.addNews}
        </button>
      </div>

      {rows.length > 0 && (
        <FilterBar filter={filter} onChange={setFilter} t={t} />
      )}

      {loading ? (
        <p className="muted">{t.loading}</p>
      ) : rows.length === 0 ? (
        <p className="muted">{t.noNews}</p>
      ) : visible.length === 0 ? (
        <p className="muted">{t.noMatches}</p>
      ) : (
        <>
          {current.length > 0 && (
            <Section title={`${t.current} (${current.length})`}>
              <NewsGroupList
                groups={current}
                t={t}
                statusOf={statusOf}
                onEdit={openForEdit}
                onDelete={setPendingDelete}
                onAddTranslation={addTranslation}
              />
            </Section>
          )}
          {history.length > 0 && (
            <Section title={`${t.history} (${history.length})`}>
              <NewsGroupList
                groups={history}
                t={t}
                statusOf={statusOf}
                onEdit={openForEdit}
                onDelete={setPendingDelete}
                onAddTranslation={addTranslation}
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

/** Search + language/type/status filters. Purely local to the loaded rows —
 *  the table is small enough that re-querying per keystroke would be worse. */
function FilterBar({
  filter,
  onChange,
  t,
}: {
  filter: NewsFilter;
  onChange: (f: NewsFilter) => void;
  t: ReturnType<typeof useUi>["t"];
}) {
  const sel = { width: "auto", padding: "0.35rem 0.5rem" };
  return (
    <div className="card p-3 flex flex-wrap items-center gap-2">
      <input
        className="input"
        style={{ flex: "1 1 14rem", minWidth: "10rem" }}
        placeholder={t.searchPlaceholder}
        value={filter.text}
        onChange={(e) => onChange({ ...filter, text: e.target.value })}
      />
      <select
        aria-label={t.language}
        className="select"
        style={sel}
        value={filter.language}
        onChange={(e) => onChange({ ...filter, language: e.target.value })}
      >
        <option value="">{t.language}: {t.filterAll}</option>
        <option value="ar">ar</option>
        <option value="en">en</option>
        <option value="fr">fr</option>
      </select>
      <select
        aria-label={t.type}
        className="select"
        style={sel}
        value={filter.type}
        onChange={(e) => onChange({ ...filter, type: e.target.value })}
      >
        <option value="">{t.type}: {t.filterAll}</option>
        <option value="text">{t.typeText}</option>
        <option value="image">{t.typeImage}</option>
        <option value="youtube">{t.typeYoutube}</option>
      </select>
      <select
        aria-label={t.status}
        className="select"
        style={sel}
        value={filter.status}
        onChange={(e) =>
          onChange({ ...filter, status: e.target.value as NewsFilter["status"] })
        }
      >
        <option value="">{t.status}: {t.filterAll}</option>
        <option value="live">{t.live}</option>
        <option value="scheduled">{t.scheduled}</option>
        <option value="expired">{t.expired}</option>
      </select>
      {isFilterActive(filter) && (
        <button
          type="button"
          className="btn btn-ghost"
          onClick={() => onChange(EMPTY_FILTER)}
        >
          {t.clearFilters}
        </button>
      )}
    </div>
  );
}

/** Renders one block per announcement, holding its language variants.
 *
 *  Previously every row was a separate card, so the three language variants of
 *  one announcement looked unrelated and a missing translation was invisible.
 *  The block header names the languages present and offers a button per missing
 *  one. */
function NewsGroupList({
  groups,
  t,
  statusOf,
  onEdit,
  onDelete,
  onAddTranslation,
}: {
  groups: NewsGroup<NewsRow>[];
  t: ReturnType<typeof useUi>["t"];
  statusOf: (r: NewsRow) => string;
  onEdit: (r: NewsRow) => void;
  onDelete: (r: NewsRow) => void;
  onAddTranslation: (source: NewsRow, lang: string) => void;
}) {
  return (
    <div className="flex flex-col gap-3">
      {groups.map((g) => (
        <div key={g.key} className="flex flex-col gap-2">
          <div className="flex items-center gap-2 flex-wrap muted text-xs">
            <span>
              {t.groupLanguages}: {g.present.join(", ") || "—"}
            </span>
            {g.missing.length === 0 ? (
              <Tag>✓ {t.groupComplete}</Tag>
            ) : (
              g.missing.map((lang) => (
                <button
                  key={lang}
                  type="button"
                  className="btn btn-ghost"
                  style={{ padding: "0.15rem 0.5rem", fontSize: "0.75rem" }}
                  onClick={() => onAddTranslation(g.rows[0], lang)}
                >
                  + {t.addTranslation}: {lang}
                </button>
              ))
            )}
          </div>
          <NewsList
            items={g.rows}
            t={t}
            statusOf={statusOf}
            onEdit={onEdit}
            onDelete={onDelete}
          />
        </div>
      ))}
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
  t: ReturnType<typeof useUi>["t"];
  statusOf: (r: NewsRow) => string;
  onEdit: (r: NewsRow) => void;
  onDelete: (r: NewsRow) => void;
}) {
  return (
    <div className="flex flex-col gap-2">
      {items.map((r) => {
        const vis = newsVisibility(r);
        const missingCategory = vis.hidden.filter(
          (h) => h.reason === "missingCategory"
        );
        return (
        <div key={r.id} className="card p-3 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-semibold truncate">{r.title}</span>
              <Tag>{r.type}</Tag>
              <Tag>{r.language}</Tag>
              {r.is_featured && <Tag>{t.featured}</Tag>}
              {r.send_notification && <Tag>🔔</Tag>}
              <Tag>{statusOf(r)}</Tag>
              {/* An item nobody can see is worth shouting about; one hidden
                  only from some languages is worth a quiet marker. */}
              {vis.visible.length === 0 ? (
                <span
                  className="text-xs px-2 py-0.5 rounded"
                  style={{ background: "var(--danger)", color: "#fff" }}
                >
                  ⚠ {t.noLanguageVisible}
                </span>
              ) : (
                missingCategory.length > 0 && (
                  <Tag>
                    ⚠ {t.hiddenFrom}:{" "}
                    {missingCategory.map((h) => h.lang).join(", ")}
                  </Tag>
                )
              )}
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
            <button className="btn btn-danger" onClick={() => onDelete(r)}>
              {t.delete}
            </button>
          </div>
        </div>
        );
      })}
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
  isNew,
  adminName,
  onClose,
  onSaved,
}: {
  initial: NewsRow;
  isNew: boolean;
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
  const [problems, setProblems] = useState<string[]>([]);

  // Live, so the author sees the consequence of a category while typing it
  // rather than after saving. `tl` is the raw CSV box, which is the value the
  // client will end up with once parsed.
  const visibility: Visibility = newsVisibility({
    target_languages: parseCsv(tl),
    category_ar: r.category_ar,
    category_en: r.category_en,
    category_fr: r.category_fr,
  });

  function set<K extends keyof NewsRow>(k: K, v: NewsRow[K]) {
    setR((p) => ({ ...p, [k]: v }));
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const found = validateNews({
      title: r.title,
      type: r.type,
      media_url: r.media_url,
      source_url: r.source_url,
      publish_date: r.publish_date,
      valid_until: r.valid_until,
      language: r.language,
      targetLanguagesCsv: tl,
      targetCountriesCsv: tc,
      excludedCountriesCsv: ec,
    });
    setProblems(found);
    if (found.length > 0) return;

    setBusy(true);
    try {
      const payload: NewsRow = {
        ...r,
        // A media URL typed while the type was image/youtube must not survive a
        // switch back to text — the input is hidden then, so the value would be
        // saved invisibly. Belt and braces: the type select also clears it.
        media_url: r.type === "text" ? "" : r.media_url.trim(),
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
      <h1 className="text-2xl font-bold">{isNew ? t.addNews : t.editNews}</h1>

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

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <Field label={t.type}>
          <select
            className="select"
            value={r.type}
            onChange={(e) => {
              const next = e.target.value as NewsRow["type"];
              // Drop any media URL when switching to text: its input is hidden
              // for text items, so a leftover value would be saved unseen.
              setR((p) => ({
                ...p,
                type: next,
                media_url: next === "text" ? "" : p.media_url,
              }));
            }}
          >
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

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <Field label={t.publishDate}>
          <input
            className="input"
            type="datetime-local"
            value={toLocalInput(r.publish_date)}
            onChange={(e) =>
              // Keep the previous instant when the field is cleared: the column
              // is NOT NULL, and there is nothing better to fall back to.
              set("publish_date", fromLocalInput(e.target.value) ?? r.publish_date)
            }
          />
        </Field>
        <Field label={t.validUntil}>
          <input
            className="input"
            type="datetime-local"
            value={toLocalInput(r.valid_until)}
            onChange={(e) =>
              set("valid_until", fromLocalInput(e.target.value) ?? r.valid_until)
            }
          />
        </Field>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
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
      {/* Shown only when ticked: the delivery rules are surprising (nothing is
          sent from here, and readers who install later never receive it), and
          that only matters once someone opts in. */}
      {r.send_notification && (
        <div className="muted text-xs">{t.sendNotificationHint}</div>
      )}

      <VisibilityNotice visibility={visibility} t={t} />

      {problems.length > 0 && (
        <div
          className="card p-3 text-sm"
          style={{ borderColor: "var(--danger)" }}
        >
          <div className="font-semibold mb-1" style={{ color: "var(--danger)" }}>
            {t.fixBeforeSaving}
          </div>
          <ul className="list-disc ps-5 flex flex-col gap-1">
            {problems.map((key) => (
              <li key={key}>{t[key] ?? key}</li>
            ))}
          </ul>
        </div>
      )}

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

/**
 * Reports which of ar/en/fr will actually be shown this item.
 *
 * This exists because the category-completeness rule is invisible: an author who
 * fills only "Category (Arabic)" gets no feedback that English and French
 * readers have just been excluded. Targeting exclusions are shown too, but
 * quietly — those are deliberate.
 */
function VisibilityNotice({
  visibility,
  t,
}: {
  visibility: Visibility;
  t: ReturnType<typeof useUi>["t"];
}) {
  const missing = visibility.hidden
    .filter((h) => h.reason === "missingCategory")
    .map((h) => h.lang);
  const targeted = visibility.hidden
    .filter((h) => h.reason === "targeting")
    .map((h) => h.lang);
  const nobody = visibility.visible.length === 0;

  // Nothing surprising to report: everyone sees it.
  if (!nobody && missing.length === 0 && targeted.length === 0) return null;

  const fmt = (langs: NewsLang[]) => langs.join(", ");

  return (
    <div
      className="card p-3 text-sm flex flex-col gap-1"
      style={{ borderColor: nobody ? "var(--danger)" : "var(--border)" }}
    >
      <div>
        <span className="font-semibold">{t.visibleTo}:</span>{" "}
        {visibility.visible.length > 0 ? fmt(visibility.visible) : "—"}
      </div>
      {nobody && (
        <div style={{ color: "var(--danger)" }}>⚠ {t.noLanguageVisible}</div>
      )}
      {missing.length > 0 && (
        <div>
          <span className="font-semibold">
            ⚠ {t.hiddenFrom}: {fmt(missing)}
          </span>{" "}
          <span className="muted">{t.hiddenByCategory}</span>
        </div>
      )}
      {targeted.length > 0 && (
        <div className="muted">
          {t.hiddenFrom}: {fmt(targeted)} — {t.hiddenByTargeting}
        </div>
      )}
    </div>
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
