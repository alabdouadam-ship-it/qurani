# Admin management — SQL versions

Pure-SQL equivalents of the Node scripts in `../`, for when you'd rather paste
into **Supabase Dashboard → SQL Editor** than run Node with the service-role
key. The SQL editor runs as a privileged role, so it bypasses Row Level
Security — no service key required.

| File | Purpose | Reliability |
|---|---|---|
| `list-admins.sql` | List admins + emails + last sign-in | ✅ solid |
| `reset-admin-password.sql` | Set an existing admin's password | ✅ solid |
| `remove-admin.sql` | Revoke rights (and optionally delete the account) | ✅ solid |
| `add-admin.sql` | Create a brand-new admin | ⚠️ version-sensitive |

## How to use
1. Open the file, **edit the values** marked `EDIT` (email, password, name).
2. Paste the whole file into the SQL Editor and Run.

The login **email** is the username plus your `NEXT_PUBLIC_ADMIN_EMAIL_DOMAIN`
(default `qurani.info`) — e.g. username `adam` → `adam@qurani.info`. Admins log
in with just the username.

## Important caveat on `add-admin.sql`
Creating an auth user in raw SQL means hand-writing `auth.users` **and**
`auth.identities` rows that Supabase Auth (GoTrue) normally manages. It works
today, but Supabase occasionally changes that schema, which can break the
script on a future upgrade. If a freshly-added admin can't sign in, use the
Node script instead — it calls the officially supported Admin API:

```bash
npm run admin:add -- <username> <password> "Display Name"
```

`reset-admin-password.sql`, `list-admins.sql`, and `remove-admin.sql` only
touch stable columns / public tables, so they're safe to rely on.
