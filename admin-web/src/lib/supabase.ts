"use client";

import { createBrowserClient } from "@supabase/ssr";

/**
 * Single shared Supabase browser client.
 *
 * This admin dashboard is a pure client-side SPA — there is NO custom backend.
 * All data access goes directly to Supabase from the browser, governed by the
 * Row Level Security policies in `supabase/migrations/0004_admin.sql`:
 *   - Only authenticated users listed in `public.admins` can read stats and
 *     read/write news + reciters.
 *   - The anon key is public-by-design; RLS is what protects the data.
 */
let _client: ReturnType<typeof createBrowserClient> | null = null;

export function getSupabase() {
  if (_client) return _client;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) {
    throw new Error(
      "Missing NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY. " +
        "Copy .env.example to .env.local and fill them in."
    );
  }
  _client = createBrowserClient(url, anon);
  return _client;
}

/** Maps the login identifier to a Supabase Auth email.
 *
 * The username field accepts EITHER a plain username (e.g. `adamna`) — which
 * becomes `adamna@<domain>` — OR a full email (e.g. `me@gmail.com`), which is
 * used verbatim. This avoids the classic mistake of typing a full email into a
 * username field and getting `me@gmail.com@<domain>` ("invalid format").
 *
 * The domain MUST be a real domain with valid DNS (we default to the project's
 * own `qurani.info`); Supabase Auth rejects non-resolving domains as invalid.
 * No mail is ever sent — confirmation is off and the address is only an id. */
export function usernameToEmail(input: string): string {
  const v = input.trim().toLowerCase();
  if (v.includes("@")) return v; // already an email — use as-is
  const domain = process.env.NEXT_PUBLIC_ADMIN_EMAIL_DOMAIN || "qurani.info";
  return `${v}@${domain}`;
}
