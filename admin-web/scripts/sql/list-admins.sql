-- List all admins with their login email + last sign-in.
-- Run in: Supabase Dashboard → SQL Editor.

select
  a.name              as display_name,
  u.email             as login_email,
  u.last_sign_in_at,
  u.created_at,
  a.id
from public.admins a
join auth.users u on u.id = a.id
order by a.created_at;
