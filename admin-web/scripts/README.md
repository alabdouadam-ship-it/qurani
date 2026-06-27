# Admin management scripts

Local Node scripts to manage dashboard admins **without SQL or email**, using
the Supabase **service-role** key + Admin API. They are meant to be run from
your machine — never deployed, never shipped to the browser.

## Why these exist

The dashboard is single-admin-by-design: RLS only allows creating the *first*
admin row from the client. Adding more admins, or resetting a locked-out
admin's password (the synthetic `@qurani.info` emails can't receive recovery
mail), requires elevated access — that's what these scripts provide.

## One-time setup

Add the **service-role** key to `admin-web/.env.local` (it's gitignored):

```
SUPABASE_SERVICE_ROLE_KEY=<Project Settings → API → service_role key>
```

`NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_ADMIN_EMAIL_DOMAIN` are already read
from the same file.

> ⚠️ The service-role key bypasses all Row Level Security. Treat it like a root
> password: keep it only in `.env.local` or your shell, never commit it.

## Commands

Run from the `admin-web/` folder.

| Action | npm script | direct |
|---|---|---|
| List admins | `npm run admin:list` | `node scripts/list-admins.mjs` |
| Add an admin | `npm run admin:add -- <username> <password> ["Name"]` | `node scripts/add-admin.mjs ...` |
| Reset a password | `npm run admin:password -- <username> <newPassword>` | `node scripts/set-admin-password.mjs ...` |
| Remove an admin | `npm run admin:remove -- <username> [--delete-user]` | `node scripts/remove-admin.mjs ...` |

`<username>` may be a plain username (mapped to `username@<domain>`) or a full
email. Passwords must be at least 8 characters.

### Examples

```bash
# create a second admin
npm run admin:add -- editor "Str0ngPass!" "Site Editor"

# reset a locked-out admin's password
npm run admin:password -- adam "N3wP@ssword"

# see who has access
npm run admin:list

# revoke admin rights (keeps the auth account)
npm run admin:remove -- editor

# revoke AND delete the auth account
npm run admin:remove -- editor --delete-user
```

Notes:
- `add-admin` is safely re-runnable (reuses an existing auth user, upserts the
  admins row).
- `remove-admin` refuses to remove the **last** admin so you can't lock
  yourself out.

npm run admin:add -- editor "Str0ngPass!" "Site Editor"
npm run admin:password -- adam "N3wP@ssword"
npm run admin:list
npm run admin:remove -- editor              # revoke rights
npm run admin:remove -- editor --delete-user # also delete account
