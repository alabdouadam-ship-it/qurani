// Add a new admin: creates a confirmed auth user and inserts the matching
// row into public.admins (which the client cannot do after the first admin,
// because RLS only allows the very first insert).
//
// Usage:
//   node scripts/add-admin.mjs <username> <password> ["Display Name"]
//
// Examples:
//   node scripts/add-admin.mjs adam "S3cret!pass"
//   node scripts/add-admin.mjs adam "S3cret!pass" "Adam (Editor)"
//   node scripts/add-admin.mjs me@gmail.com "S3cret!pass" "Adam"
//
// Notes:
//   * <username> may be a plain username (→ username@<domain>) or a full email.
//   * Password must be at least 8 characters (matches the app's own rule).
//   * Re-runnable: if the auth user already exists it is reused, and the admins
//     row is upserted, so a half-finished run can be repeated safely.

import {
  admin,
  usernameToEmail,
  findUserByEmail,
  requireArg,
  ok,
  fail,
} from "./_lib.mjs";

const USAGE =
  'Usage: node scripts/add-admin.mjs <username> <password> ["Display Name"]';

const username = requireArg(process.argv[2], "username", USAGE);
const password = requireArg(process.argv[3], "password", USAGE);
const displayName = (process.argv[4] || username).trim();

if (password.length < 8) fail("Password must be at least 8 characters.");

const email = usernameToEmail(username);

// 1) Create (or find) the confirmed auth user.
let user = await findUserByEmail(email);
if (user) {
  ok(`Auth user already exists: ${email} (${user.id}) — reusing.`);
} else {
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true, // no confirmation email; admin can sign in immediately
  });
  if (error) fail(`Could not create auth user: ${error.message}`);
  user = data.user;
  ok(`Created auth user: ${email} (${user.id})`);
}

// 2) Insert/Upsert the admins row (display name shown in "last edited by").
const { error: upErr } = await admin
  .from("admins")
  .upsert({ id: user.id, name: displayName }, { onConflict: "id" });
if (upErr) fail(`Could not write admins row: ${upErr.message}`);

ok(`Admin ready. Login username: "${username}"  ·  display name: "${displayName}"`);
console.log("  They can sign in now and change their password from Account.");
