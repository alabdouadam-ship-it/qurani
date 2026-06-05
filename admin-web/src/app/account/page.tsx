"use client";

import { useState } from "react";
import { AppShell } from "@/components/AppShell";
import { getSupabase } from "@/lib/supabase";
import { useUi } from "@/lib/ui-context";
import { useAuth } from "@/lib/auth-context";

export default function AccountPage() {
  return (
    <AppShell>
      <AccountBody />
    </AppShell>
  );
}

function AccountBody() {
  const supabase = getSupabase();
  const { t } = useUi();
  const { admin, refreshAdmin } = useAuth();

  const [name, setName] = useState(admin?.name ?? "");
  const [nameBusy, setNameBusy] = useState(false);
  const [nameMsg, setNameMsg] = useState<string | null>(null);

  const [newPass, setNewPass] = useState("");
  const [confirmPass, setConfirmPass] = useState("");
  const [passBusy, setPassBusy] = useState(false);
  const [passMsg, setPassMsg] = useState<string | null>(null);
  const [passErr, setPassErr] = useState<string | null>(null);

  async function saveName(e: React.FormEvent) {
    e.preventDefault();
    setNameMsg(null);
    setNameBusy(true);
    try {
      const { error } = await supabase
        .from("admins")
        .update({ name: name.trim() })
        .eq("id", admin!.id);
      setNameMsg(error ? t.saveFailed : t.nameUpdated);
      if (!error) await refreshAdmin();
    } finally {
      setNameBusy(false);
    }
  }

  async function savePassword(e: React.FormEvent) {
    e.preventDefault();
    setPassErr(null);
    setPassMsg(null);
    if (newPass.length < 8) {
      setPassErr(t.passwordTooShort);
      return;
    }
    if (newPass !== confirmPass) {
      setPassErr(t.passwordsMismatch);
      return;
    }
    setPassBusy(true);
    try {
      const { error } = await supabase.auth.updateUser({ password: newPass });
      if (error) {
        setPassErr(error.message);
        return;
      }
      setNewPass("");
      setConfirmPass("");
      setPassMsg(t.passwordChanged);
    } finally {
      setPassBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-4 max-w-xl">
      <h1 className="text-2xl font-bold">{t.account}</h1>

      <form className="card p-4 flex flex-col gap-3" onSubmit={saveName}>
        <h2 className="font-bold">{t.updateName}</h2>
        <div>
          <label className="label">{t.displayName}</label>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} required />
        </div>
        {nameMsg && <p className="text-sm" style={{ color: "var(--success)" }}>{nameMsg}</p>}
        <div>
          <button className="btn btn-primary" disabled={nameBusy}>
            {t.save}
          </button>
        </div>
      </form>

      <form className="card p-4 flex flex-col gap-3" onSubmit={savePassword}>
        <h2 className="font-bold">{t.changePassword}</h2>
        <div>
          <label className="label">{t.newPassword}</label>
          <input
            className="input"
            type="password"
            value={newPass}
            autoComplete="new-password"
            onChange={(e) => setNewPass(e.target.value)}
            required
          />
        </div>
        <div>
          <label className="label">{t.confirmPassword}</label>
          <input
            className="input"
            type="password"
            value={confirmPass}
            autoComplete="new-password"
            onChange={(e) => setConfirmPass(e.target.value)}
            required
          />
        </div>
        {passErr && <p className="text-sm" style={{ color: "var(--danger)" }}>{passErr}</p>}
        {passMsg && <p className="text-sm" style={{ color: "var(--success)" }}>{passMsg}</p>}
        <div>
          <button className="btn btn-primary" disabled={passBusy}>
            {t.changePassword}
          </button>
        </div>
      </form>
    </div>
  );
}
