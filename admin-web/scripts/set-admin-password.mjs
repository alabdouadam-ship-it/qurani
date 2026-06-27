// Reset/set an existing admin's password (no email needed — uses the Admin
// API directly). Useful when an admin is locked out and the synthetic
// @<domain> address can't receive a recovery email.
//
// Usage:
//   node scripts/set-admin-password.mjs <username> <newPassword>
//
// Examples:
//   node scripts/set-admin-password.mjs adam "N3wP@ssword"
//   node scripts/set-admin-password.mjs me@gmail.com "N3wP@ssword"

import {
  admin,
  usernameToEmail,
  findUserByEmail,
  requireArg,
  ok,
  fail,
} from "./_lib.mjs";

const USAGE = "Usage: node scripts/set-admin-password.mjs <username> <newPassword>";

const username = requireArg(process.argv[2], "username", USAGE);
const newPassword = requireArg(process.argv[3], "newPassword", USAGE);

if (newPassword.length < 8) fail("Password must be at least 8 characters.");

const email = usernameToEmail(username);

const user = await findUserByEmail(email);
if (!user) fail(`No auth user found for "${email}".`);

const { error } = await admin.auth.admin.updateUserById(user.id, {
  password: newPassword,
});
if (error) fail(`Could not update password: ${error.message}`);

ok(`Password updated for "${username}" (${email}).`);
console.log("  They can sign in now with the new password.");
