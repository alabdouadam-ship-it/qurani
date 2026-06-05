"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import type { AuthChangeEvent, Session } from "@supabase/supabase-js";
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

  async function loadAdmin(currentSession: Session | null) {
    if (!currentSession) {
      setAdmin(null);
      return;
    }
    // Read this admin's own row. RLS allows admins to read `admins`; a
    // non-admin authenticated user simply gets no row.
    const { data } = await supabase
      .from("admins")
      .select("id, name")
      .eq("id", currentSession.user.id)
      .maybeSingle();
    setAdmin(data ? { id: data.id as string, name: data.name as string } : null);
  }

  useEffect(() => {
    let active = true;
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!active) return;
      setSession(data.session);
      await loadAdmin(data.session);
      setLoading(false);
    })();

    const { data: sub } = supabase.auth.onAuthStateChange(
      (_event: AuthChangeEvent, s: Session | null) => {
        setSession(s);
        loadAdmin(s);
      }
    );
    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const refreshAdmin = async () => {
    const { data } = await supabase.auth.getSession();
    setSession(data.session);
    await loadAdmin(data.session);
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setSession(null);
    setAdmin(null);
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
