'use client';

import { createBrowserClient, createServerClient } from '@supabase/ssr';
import type { ReadonlyRequestCookies } from 'next/dist/server/web/spec-extension/adapters/request-cookies';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
const SUPABASE_ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '';

/** True when Supabase credentials are present. Use to guard auth-dependent features. */
export const isSupabaseConfigured = !!(SUPABASE_URL && SUPABASE_ANON);

// ─── Browser client (singleton) ───────────────────────────────────────────────
let _browserClient: ReturnType<typeof createBrowserClient> | null = null;

/**
 * Returns the Supabase browser client, or null when env vars are not set.
 * Callers must guard: `const sb = getSupabase(); if (!sb) return;`
 */
export function getSupabase(): ReturnType<typeof createBrowserClient> | null {
  if (!isSupabaseConfigured) {
    // Silent — UI still loads, auth and DB features are simply unavailable
    return null;
  }
  if (_browserClient) return _browserClient;
  _browserClient = createBrowserClient(SUPABASE_URL, SUPABASE_ANON);
  return _browserClient;
}

// ─── Server client (per-request) ─────────────────────────────────────────────
/**
 * Returns the Supabase server client, or null when env vars are not set.
 */
export function getServerSupabase(
  cookieStore: ReadonlyRequestCookies,
): ReturnType<typeof createServerClient> | null {
  if (!isSupabaseConfigured) return null;

  return createServerClient(SUPABASE_URL, SUPABASE_ANON, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      // Server components cannot set cookies — noop is intentional
      setAll() {},
    },
  });
}
