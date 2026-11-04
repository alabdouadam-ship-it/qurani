-- Serialize membership changes using a single, private counter row.
-- AFTER triggers count actual inserts only (including INSERT ... ON CONFLICT).
-- Updating the guard row serializes concurrent transactions; at stronger
-- isolation levels PostgreSQL aborts a stale writer instead of losing a count.
begin;

lock table public.admins in access exclusive mode;

create table public.admin_membership_guard (
  singleton boolean primary key default true check (singleton),
  members bigint not null check (members >= 0)
);
alter table public.admin_membership_guard enable row level security;
revoke all on public.admin_membership_guard from public, anon, authenticated, service_role;
insert into public.admin_membership_guard (singleton, members)
select true, count(*) from public.admins;

create function public.guard_admin_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  remaining bigint;
begin
  if tg_op = 'TRUNCATE' then
    raise exception 'Administrators cannot be truncated';
  elsif tg_op = 'INSERT' then
    update public.admin_membership_guard set members = members + 1
      where singleton returning members into remaining;
    if remaining is null then
      raise exception 'Administrator membership guard is missing';
    end if;
    if auth.role() = 'authenticated' and remaining > 1 then
      raise exception 'The first administrator has already been registered';
    end if;
    return new;
  else
    update public.admin_membership_guard set members = members - 1
      where singleton and members > 1 returning members into remaining;
    if remaining is null then
      raise exception 'Refusing to delete the last administrator';
    end if;
    return old;
  end if;
end;
$$;
revoke all on function public.guard_admin_membership() from public, anon, authenticated, service_role;

drop trigger if exists trg_admins_prevent_last_delete on public.admins;
drop function public.prevent_last_admin_delete();
create trigger trg_admins_membership
  after insert or delete on public.admins
  for each row execute function public.guard_admin_membership();
create trigger trg_admins_no_truncate
  before truncate on public.admins
  for each statement execute function public.guard_admin_membership();

-- NOT VALID preserves any legacy malformed rows for explicit review. It still
-- rejects new malformed writes. Do not silently remove targeting: [] means all.
alter table public.news_items add constraint news_targeting_no_null_elements
  check (
    array_position(target_languages, null) is null and
    array_position(target_countries, null) is null and
    array_position(excluded_countries, null) is null
  ) not valid;

commit;
