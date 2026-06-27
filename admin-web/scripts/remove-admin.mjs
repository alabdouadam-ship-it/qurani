// Remove an admin. By default this only revokes admin rights (deletes the
// public.admins row) and leaves a powerless auth user behind. Pass
// --delete-user to also delete the underlying auth account entirely.
//
// Usage:
//   node scripts/remove-admin.mjs <username>
//   node scripts/remove-admin.mjs <username> --delete-user
//
// Safety: refuses to remove the LAST remaining admin (that would lock you out
// of the dashboard and re-open the first-admin setup flow). Delete the auth
// user manually in the Supabase dashboard if you really intend that.

import {
  admin,
  usernameToEmail,
  findUserByEmail,
  requireArg,
  ok,
  fail,
} from "./_lib.mjs";

const USAGE =
  "Usage: node scripts/remove-admin.mjs <username> [--delete-user]";

const username = requireArg(process.argv[2], "username", USAGE);
const alsoDeleteUser = process.argv.includes("--delete-user");
const email = usernameToEmail(username);

const user = await findUserByEmail(email);
if (!user) fail(`No auth user found for "${email}".`);

// Guard: don't strip the last admin.
const { count, error: cErr } = await admin
  .from("admins")
  .select("id", { count: "exact", head: true });
if (cErr) fail(`Could not count admins: ${cErr.message}`);

const { data: thisAdmin } = await admin
  .from("admins")
  .select("id")
  .eq("id", user.id)
  .maybeSingle();

if (!thisAdmin) {
  ok(`"${username}" is not an admin (no admins row). Nothing to revoke.`);
} else {
  if ((count ?? 0) <= 1) {
    fail(
      `"${username}" is the only admin — refusing to remove (you'd be locked out).`
    );
  }
  const { error: delErr } = await admin.from("admins").delete().eq("id", user.id);
  if (delErr) fail(`Could not delete admins row: ${delErr.message}`);
  ok(`Revoked admin rights for "${username}".`);
}

if (alsoDeleteUser) {
  const { error: auErr } = await admin.auth.admin.deleteUser(user.id);
  if (auErr) fail(`Could not delete auth user: ${auErr.message}`);
  ok(`Deleted auth user "${email}" (${user.id}).`);
}
