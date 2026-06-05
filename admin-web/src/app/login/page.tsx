"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabase, usernameToEmail } from "@/lib/supabase";
import { useAuth } from "@/lib/auth-context";
import { useUi } from "@/lib/ui-context";
import { Controls } from "@/components/Controls";

export default function LoginPage() {
  const supabase = getSupabase();
  const { t } = useUi();
  const { admin, loading, refreshAdmin } = useAuth();
  const router = useRouter();

  const [adminExists, setAdminExists] = useState<boolean | null>(null);
  const [username, setUsername] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  // Already signed in as an admin → go to dashboard.
  useEffect(() => {
    if (!loading && admin) router.replace("/dashboard");
  }, [loading, admin, router]);

  // Decide login vs first-admin setup.
  useEffect(() => {
    (async () => {
      const { data, error } = await supabase.rpc("admin_exists");
      if (error) {
        // If the RPC isn't reachable, default to the login form.
        setAdminExists(true);
      } else {
        setAdminExists(Boolean(data));
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const email = usernameToEmail(username);
      const { error: signErr } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (signErr) {
        setError(t.loginFailed);
        return;
      }
      // Confirm the signed-in user is actually an admin.
      const { data: sess } = await supabase.auth.getSession();
      const uid = sess.session?.user.id;
      const { data: adminRow } = await supabase
        .from("admins")
        .select("id")
        .eq("id", uid as string)
        .maybeSingle();
      if (!adminRow) {
        await supabase.auth.signOut();
        setError(t.notAdmin);
        return;
      }
      await refreshAdmin();
      router.replace("/dashboard");
    } finally {
      setBusy(false);
    }
  }

  async function handleSetup(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    if (password.length < 8) {
      setError(t.passwordTooShort);
      return;
    }
    if (password !== confirm) {
      setError(t.passwordsMismatch);
      return;
    }
    setBusy(true);
    try {
      const email = usernameToEmail(username);

      // 1. Create the auth user. If a previous setup attempt already created
      //    it (e.g. the admins INSERT failed afterwards, leaving an orphaned
      //    auth user), fall back to signing in with the same credentials so we
      //    can finish registration. This makes setup safely retryable.
      const { error: signUpErr } = await supabase.auth.signUp({
        email,
        password,
      });
      if (signUpErr) {
        const msg = signUpErr.message.toLowerCase();
        const alreadyExists =
          msg.includes("already registered") ||
          msg.includes("already been registered") ||
          msg.includes("user already");
        if (!alreadyExists) {
          setError(signUpErr.message);
          return;
        }
      }

      // 2. Ensure we have a session. If signUp didn't return one (email
      //    confirmation enabled) or the user already existed, sign in.
      let { data: sess } = await supabase.auth.getSession();
      if (!sess.session) {
        const { error: inErr } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (inErr) {
          // The user exists but this password doesn't match the one used when
          // it was first created — tell the user plainly.
          setError(t.loginFailed);
          return;
        }
        sess = (await supabase.auth.getSession()).data;
      }
      const uid = sess.session?.user.id;
      if (!uid) {
        setError(t.loginFailed);
        return;
      }

      // 3. Insert the first admin row (RLS allows this only while empty). If a
      //    row somehow already exists for this user, treat it as success.
      const { error: insErr } = await supabase
        .from("admins")
        .insert({ id: uid, name: displayName.trim() || username.trim() });
      if (insErr && !insErr.message.toLowerCase().includes("duplicate")) {
        setError(insErr.message);
        return;
      }
      await refreshAdmin();
      router.replace("/dashboard");
    } finally {
      setBusy(false);
    }
  }

  const isSetup = adminExists === false;

  return (
    <div className="min-h-screen flex flex-col">
      <div className="flex justify-end p-4">
        <Controls />
      </div>
      <div className="flex-1 flex items-center justify-center p-4">
        <div className="card p-6 w-full" style={{ maxWidth: 420 }}>
          <h1 className="text-xl font-bold mb-1">{t.appTitle}</h1>
          <p className="muted text-sm mb-5">
            {isSetup ? t.setupIntro : t.login}
          </p>

          <form onSubmit={isSetup ? handleSetup : handleLogin}>
            <div className="mb-3">
              <label className="label">{t.username}</label>
              <input
                className="input"
                value={username}
                autoComplete="username"
                onChange={(e) => setUsername(e.target.value)}
                required
              />
            </div>

            {isSetup && (
              <div className="mb-3">
                <label className="label">{t.displayName}</label>
                <input
                  className="input"
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  required
                />
              </div>
            )}

            <div className="mb-3">
              <label className="label">{t.password}</label>
              <input
                className="input"
                type="password"
                value={password}
                autoComplete={isSetup ? "new-password" : "current-password"}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>

            {isSetup && (
              <div className="mb-3">
                <label className="label">{t.confirmPassword}</label>
                <input
                  className="input"
                  type="password"
                  value={confirm}
                  autoComplete="new-password"
                  onChange={(e) => setConfirm(e.target.value)}
                  required
                />
              </div>
            )}

            {error && (
              <p className="text-sm mb-3" style={{ color: "var(--danger)" }}>
                {error}
              </p>
            )}
            {info && (
              <p className="text-sm mb-3" style={{ color: "var(--success)" }}>
                {info}
              </p>
            )}

            <button
              className="btn btn-primary w-full"
              disabled={busy || adminExists === null}
            >
              {busy
                ? t.signingIn
                : isSetup
                ? t.createAdmin
                : t.login}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
