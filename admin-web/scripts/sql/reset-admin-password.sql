-- Reset (set) an existing admin's password — no email needed.
-- Run in: Supabase Dashboard → SQL Editor.
--
-- EDIT the two values below, then run.
--   * email     : the admin's login email (username + "@" + your domain,
--                 e.g. adam@qurani.info)
--   * password  : the new password (min 8 chars to match the app's rule)

create extension if not exists pgcrypto;

update auth.users
set
  encrypted_password = crypt('NEW_PASSWORD_HERE', gen_salt('bf')),
  updated_at         = now()
where email = 'adam@qurani.info';

-- Verify (should return exactly 1 row):
select email, updated_at
from auth.users
where email = 'adam@qurani.info';
