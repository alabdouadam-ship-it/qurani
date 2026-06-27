// Shared helpers for the admin-management scripts.
//
// These scripts use the Supabase SERVICE-ROLE key and the Admin API. That key
// bypasses Row Level Security and can create/update/delete any auth user, so it
// MUST stay secret: keep it only in `.env.local` (gitignored) or your shell —
// never commit it and never expose it to the browser/Next.js public env.
//
// Required env (read from process.env or admin-web/.env.local):
//   NEXT_PUBLIC_SUPABASE_URL          your project URL
//   SUPABASE_SERVICE_ROLE_KEY         Project Settings → API → service_role key
//   NEXT_PUBLIC_ADMIN_EMAIL_DOMAIN    (optional) defaults to "qurani.info"

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { createClient } from "@supabase/supabase-js";

const __dirname = dirname(fileURLToPath(import.meta.url));

/** Minimal .env.local parser (no extra dependency). Values already present in
 *  process.env take precedence over the file. */
function loadEnvLocal() {
  const path = resolve(__dirname, "..", ".env.local");
  let text = "";
  try {
    text = readFileSync(path, "utf8");
  } catch {
    return; // no .env.local — rely on process.env
  }
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1).trim();
    // strip optional surrounding quotes
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = val;
  }
}

loadEnvLocal();

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
export const EMAIL_DOMAIN =
  process.env.NEXT_PUBLIC_ADMIN_EMAIL_DOMAIN || "qurani.info";

if (!URL || !SERVICE_KEY) {
  console.error(
    "\nMissing config. Set these in admin-web/.env.local (or your shell):\n" +
      "  NEXT_PUBLIC_SUPABASE_URL=...\n" +
      "  SUPABASE_SERVICE_ROLE_KEY=...   (Project Settings → API → service_role)\n"
  );
  process.exit(1);
}

/** Service-role client: bypasses RLS, can use auth.admin.* . Never ship this
 *  key to the browser. */
export const admin = createClient(URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

/** Map a login username to its Supabase Auth email, mirroring the app's
 *  usernameToEmail(): a value containing "@" is treated as a full email. */
export function usernameToEmail(input) {
  const v = String(input || "").trim().toLowerCase();
  if (!v) return v;
  if (v.includes("@")) return v;
  return `${v}@${EMAIL_DOMAIN}`;
}

/** Find an auth user by exact email (paginates the admin user list). */
export async function findUserByEmail(email) {
  const target = email.toLowerCase();
  const perPage = 1000;
  for (let page = 1; page <= 100; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) throw new Error(error.message);
    const users = data?.users ?? [];
    const hit = users.find((u) => (u.email || "").toLowerCase() === target);
    if (hit) return hit;
    if (users.length < perPage) break; // last page
  }
  return null;
}

/** Read a required positional CLI arg or exit with the usage message. */
export function requireArg(value, name, usage) {
  if (!value) {
    console.error(`Missing <${name}>.\n${usage}`);
    process.exit(1);
  }
  return value;
}

export function ok(msg) {
  console.log(`✓ ${msg}`);
}
export function fail(msg) {
  console.error(`✗ ${msg}`);
  process.exit(1);
}
