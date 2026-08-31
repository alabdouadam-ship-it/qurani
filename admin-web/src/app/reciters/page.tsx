"use client";

import { useCallback, useEffect, useState } from "react";
import { AppShell } from "@/components/AppShell";
import { ConfirmPanel } from "@/components/ConfirmPanel";
import { getSupabase } from "@/lib/supabase";
import { useUi } from "@/lib/ui-context";
import { useAuth } from "@/lib/auth-context";
import type { ReciterRow } from "@/lib/types";

export default function RecitersPage() {
  return (
    <AppShell>
      <RecitersBody />
    </AppShell>
  );
}

const EMPTY: ReciterRow = {
  code: "",
  name_ar: "",
  name_latin: "",
  ayahs_path: "",
  surahs_path: null,
  sort_order: 0,
  is_enabled: true,
  updated_by: null,
};

function RecitersBody() {
  const supabase = getSupabase();
  const { t } = useUi();
  const { admin } = useAuth();

  const [rows, setRows] = useState<ReciterRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<ReciterRow | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [pendingDelete, setPendingDelete] = useState<ReciterRow | null>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from("reciters")
      .select("*")
      .order("sort_order", { ascending: true });
    setRows((data as ReciterRow[]) ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    load();
  }, [load]);

  async function remove(row: ReciterRow) {
    setBusy(true);
    try {
      await supabase.from("reciters").delete().eq("code", row.code);
      setPendingDelete(null);
      await load();
    } finally {
      setBusy(false);
    }
  }

  /** The safer answer to "remove this reciter".
   *
   *  There is no foreign key from a reader's saved preference to this table —
   *  the selected code lives in SharedPreferences on the device — so deleting a
   *  row silently strands everyone who chose it. Disabling takes it out of the
   *  pickers (the mobile read policy filters on is_enabled) while the audio
   *  paths stay resolvable for anyone already on it. */
  async function disable(row: ReciterRow) {
    setBusy(true);
    try {
      await supabase
        .from("reciters")
        .update({ is_enabled: false })
        .eq("code", row.code);
      setPendingDelete(null);
      setNotice(t.reciterDisabled);
      await load();
    } finally {
      setBusy(false);
    }
  }

  if (editing) {
    return (
      <ReciterEditor
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
        subject={`${pendingDelete.name_latin} · ${pendingDelete.code}`}
        warning={t.confirmDeleteReciterWarning}
        confirmLabel={t.deletePermanently}
        // Only offered when it would change anything.
        altLabel={pendingDelete.is_enabled ? t.disableInstead : undefined}
        onAlt={
          pendingDelete.is_enabled ? () => disable(pendingDelete) : undefined
        }
        onConfirm={() => remove(pendingDelete)}
        onCancel={() => setPendingDelete(null)}
        busy={busy}
      />
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">{t.reciters}</h1>
        <button
          className="btn btn-primary"
          onClick={() => {
            setIsNew(true);
            setEditing({ ...EMPTY });
          }}
        >
          + {t.addReciter}
        </button>
      </div>

      {notice && (
        <p className="text-sm" style={{ color: "var(--success)" }}>
          {notice}
        </p>
      )}

      {loading ? (
        <p className="muted">{t.loading}</p>
      ) : rows.length === 0 ? (
        <p className="muted">{t.noReciters}</p>
      ) : (
        <div className="flex flex-col gap-2">
          {rows.map((r) => (
            <div key={r.code} className="card p-3 flex items-start justify-between gap-3">
              <div className="min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="font-semibold">{r.name_latin}</span>
                  <span className="muted">· {r.name_ar}</span>
                  <Tag>{r.code}</Tag>
                  <Tag>{r.is_enabled ? t.enabled : t.disabled}</Tag>
                  {r.surahs_path ? <Tag>surahs</Tag> : null}
                  {r.ayahs_path ? <Tag>ayahs</Tag> : null}
                </div>
                <div className="muted text-xs mt-1 truncate">
                  #{r.sort_order}
                  {r.updated_by ? `  ·  ${t.lastEditedBy}: ${r.updated_by}` : ""}
                </div>
              </div>
              <div className="flex flex-col gap-2 shrink-0">
                <button
                  className="btn btn-ghost"
                  onClick={() => {
                    setIsNew(false);
                    setEditing(r);
                  }}
                >
                  {t.edit}
                </button>
                <button className="btn btn-danger" onClick={() => setPendingDelete(r)}>
                  {t.delete}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
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

function ReciterEditor({
  initial,
  isNew,
  adminName,
  onClose,
  onSaved,
}: {
  initial: ReciterRow;
  isNew: boolean;
  adminName: string;
  onClose: () => void;
  onSaved: () => void;
}) {
  const supabase = getSupabase();
  const { t } = useUi();
  const [r, setR] = useState<ReciterRow>(initial);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function set<K extends keyof ReciterRow>(k: K, v: ReciterRow[K]) {
    setR((p) => ({ ...p, [k]: v }));
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const payload: ReciterRow = {
        ...r,
        code: r.code.trim(),
        surahs_path:
          r.surahs_path && r.surahs_path.trim().length > 0
            ? r.surahs_path.trim()
            : null,
        updated_by: adminName,
      };
      const { error: upErr } = await supabase
        .from("reciters")
        .upsert(payload, { onConflict: "code" });
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
      <h1 className="text-2xl font-bold">{isNew ? t.addReciter : t.editReciter}</h1>

      <Field label={t.code}>
        <input
          className="input"
          value={r.code}
          onChange={(e) => set("code", e.target.value)}
          required
          disabled={!isNew}
        />
      </Field>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <Field label={t.nameAr}>
          <input className="input" dir="rtl" value={r.name_ar} onChange={(e) => set("name_ar", e.target.value)} required />
        </Field>
        <Field label={t.nameLatin}>
          <input className="input" value={r.name_latin} onChange={(e) => set("name_latin", e.target.value)} required />
        </Field>
      </div>

      <Field label={t.ayahsPath}>
        <input className="input" value={r.ayahs_path} onChange={(e) => set("ayahs_path", e.target.value)} />
      </Field>
      <Field label={t.surahsPath}>
        <input
          className="input"
          value={r.surahs_path ?? ""}
          onChange={(e) => set("surahs_path", e.target.value)}
        />
      </Field>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 items-end">
        <Field label={t.sortOrder}>
          <input
            className="input"
            type="number"
            value={r.sort_order}
            onChange={(e) => set("sort_order", Number(e.target.value) || 0)}
          />
        </Field>
        <label className="flex items-center gap-2 cursor-pointer pb-2">
          <input
            type="checkbox"
            checked={r.is_enabled}
            onChange={(e) => set("is_enabled", e.target.checked)}
          />
          <span>{t.enabled}</span>
        </label>
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

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="label">{label}</label>
      {children}
    </div>
  );
}
