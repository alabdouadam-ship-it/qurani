-- Add a new admin in pure SQL. Run in: Supabase Dashboard → SQL Editor.
-- EDIT email / password / display name below, then run.
--
-- ⚠️ VERSION-SENSITIVE. Supabase Auth (GoTrue) normally creates users itself
-- and owns the `auth.users` + `auth.identities` schema. Hand-writing those
-- rows works, but a future Supabase upgrade can add/rename required columns and
-- break this. If login fails after running it, prefer the Node script
-- (`npm run admin:add ...`), which uses the officially supported Admin API.
--
-- This inserts:
--   1) auth.users        — the account + bcrypt password, email pre-confirmed
--   2) auth.identities   — the email identity GoTrue expects (provider_id, sub)
--   3) public.admins     — grants dashboard admin rights

create extension if not exists pgcrypto;

do $$
declare
  v_email    text := 'editor@qurani.info';   -- EDIT (username + @ + your domain)
  v_password text := 'CHANGE_ME_12345';       -- EDIT (min 8 chars)
  v_name     text := 'Site Editor';            -- EDIT (display name)
  v_uid      uuid := gen_random_uuid();
begin
  if exists (select 1 from auth.users where email = v_email) then
    raise exception 'A user with email % already exists.', v_email;
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated',
    v_email, crypt(v_password, gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    '', '', '', ''
  );

  insert into auth.identities (
    provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    v_uid::text, v_uid,
    jsonb_build_object(
      'sub', v_uid::text,
      'email', v_email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email', now(), now(), now()
  );

  insert into public.admins (id, name) values (v_uid, v_name);

  raise notice 'Admin created: % (login email %, id %)', v_name, v_email, v_uid;
end $$;
