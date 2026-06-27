// List all admins: display name + login email + last sign-in.
//
// Usage:
//   node scripts/list-admins.mjs

import { admin, fail } from "./_lib.mjs";

const { data: rows, error } = await admin
  .from("admins")
  .select("id, name, created_at")
  .order("created_at", { ascending: true });
if (error) fail(`Could not read admins: ${error.message}`);

if (!rows || rows.length === 0) {
  console.log("No admins yet. Create one with: node scripts/add-admin.mjs <username> <password>");
  process.exit(0);
}

// Build an id -> auth-user map so we can show emails + last sign-in.
const byId = new Map();
for (let page = 1; page <= 100; page++) {
  const { data, error: e } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
  if (e) fail(e.message);
  const users = data?.users ?? [];
  for (const u of users) byId.set(u.id, u);
  if (users.length < 1000) break;
}

console.log(`\n${rows.length} admin(s):\n`);
for (const r of rows) {
  const u = byId.get(r.id);
  const email = u?.email ?? "(no auth user!)";
  const last = u?.last_sign_in_at
    ? new Date(u.last_sign_in_at).toISOString().slice(0, 16).replace("T", " ")
    : "never";
  console.log(`  • ${r.name}`);
  console.log(`      email: ${email}`);
  console.log(`      id:    ${r.id}`);
  console.log(`      last sign-in: ${last}\n`);
}
