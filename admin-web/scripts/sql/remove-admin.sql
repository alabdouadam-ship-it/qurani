-- Remove an admin. Run in: Supabase Dashboard → SQL Editor.
-- EDIT the email below first.
--
-- Two levels:
--   A) Revoke admin rights only  → delete the public.admins row. The auth
--      account stays but has no data access (a powerless user).
--   B) Full removal              → also delete the auth user.
--
-- SAFETY: do NOT remove the last remaining admin or you lock yourself out of
-- the dashboard (the login page would re-open the first-admin setup flow).
-- The guard below refuses to proceed if only one admin exists.

do $$
declare
  v_email text := 'editor@qurani.info';   -- EDIT
  v_full_removal boolean := false;          -- set true to also delete auth user
  v_uid uuid;
  v_admin_count int;
begin
  select id into v_uid from auth.users where email = v_email;
  if v_uid is null then
    raise exception 'No auth user found for %', v_email;
  end if;

  select count(*) into v_admin_count from public.admins;

  if exists (select 1 from public.admins where id = v_uid) then
    if v_admin_count <= 1 then
      raise exception
        'Refusing to remove the only admin (%) — you would be locked out.', v_email;
    end if;
    delete from public.admins where id = v_uid;
    raise notice 'Revoked admin rights for %', v_email;
  else
    raise notice '% is not an admin (no admins row).', v_email;
  end if;

  if v_full_removal then
    delete from auth.users where id = v_uid;  -- cascades to identities + admins
    raise notice 'Deleted auth user %', v_email;
  end if;
end $$;
