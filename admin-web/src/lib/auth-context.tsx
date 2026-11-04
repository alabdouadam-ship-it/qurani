"use client";

import {
  createContext,
  useContext,
  useCallback,
  useRef,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import type { AuthChangeEvent, Session } from "@supabase/supabase-js";
import { LatestRequest } from "./latest-request";
import { getSupabase } from "./supabase";

export type AdminProfile = { id: string; name: string };

type AuthState = {
  loading: boolean;
  session: Session | null;
  admin: AdminProfile | null; // non-null only if the user is a registered admin
  refreshAdmin: () => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const supabase = getSupabase();
  const [loading, setLoading] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [admin, setAdmin] = useState<AdminProfile | null>(null);

  const requests = useRef(new LatestRequest());
  const validatedUser = useRef<string | null>(null);

  const loadAdmin = useCallback(async (s: Session | null, current: () => boolean) => {
    try {
      if (!current() || !s) return;
      const { data, error } = await supabase.from("admins")
        .select("id, name").eq("id", s.user.id).maybeSingle();
      if (!current()) return;
      if (error) throw error;
      validatedUser.current = data?.id === s.user.id ? data.id : null;
      setAdmin(validatedUser.current ? data : null);
    } catch {
      if (current()) { validatedUser.current = null; setAdmin(null); }
    } finally {
      if (current()) setLoading(false);
    }
  }, [supabase]);

  const acceptSession = useCallback((s: Session | null) => {
    const current = requests.current.begin();
    const sameUser = Boolean(s && validatedUser.current === s.user.id);
    if (!sameUser) validatedUser.current = null;
    setSession(s);
    setAdmin(previous => previous?.id === s?.user.id ? previous : null);
    setLoading(Boolean(s) && !sameUser);
    return current;
  }, []);

  useEffect(() => {
    const gate = requests.current;
    const initial = gate.begin();
    void (async () => {
      try {
        const { data, error } = await supabase.auth.getSession();
        if (!initial()) return;
        if (error) throw error;
        await loadAdmin(data.session, acceptSession(data.session));
      } catch {
        if (initial()) acceptSession(null);
      }
    })();
    const { data: sub } = supabase.auth.onAuthStateChange(
      (_event: AuthChangeEvent, s: Session | null) => {
        const current = acceptSession(s);
        // Leave the auth callback before querying with the same client.
        setTimeout(() => { void loadAdmin(s, current); }, 0);
      }
    );
    return () => {
      gate.invalidate();
      sub.subscription.unsubscribe();
    };
  }, [supabase, loadAdmin, acceptSession]);

  const refreshAdmin = async () => {
    const current = requests.current.begin();
    try {
      const { data, error } = await supabase.auth.getSession();
      if (!current()) return;
      if (error) throw error;
      await loadAdmin(data.session, acceptSession(data.session));
    } catch {
      if (current()) acceptSession(null);
      throw new Error("Unable to refresh session");
    }
  };

  const signOut = async () => {
    // Invalidate old profile reads immediately. Keep the current UI if the
    // service rejects sign-out so the account page can show the failure.
    const current = requests.current.begin();
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    if (current()) acceptSession(null);
  };

  return (
    <AuthContext.Provider
      value={{ loading, session, admin, refreshAdmin, signOut }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
