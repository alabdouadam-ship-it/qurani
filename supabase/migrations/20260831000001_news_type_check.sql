-- ============================================================================
-- Migration 0013 — constrain news_items.type to the values the clients handle
-- ============================================================================
-- `type` has always been a bare `text not null default 'text'` with no CHECK,
-- while every consumer treats it as a closed set of three values:
--
--   * admin-web/src/lib/types.ts narrows it to "text" | "image" | "youtube"
--     and casts query results to that type, so an out-of-set value makes the
--     TypeScript a lie at runtime.
--   * The Flutter client's NewsItem._parseType maps anything unrecognised to
--     NewsType.text, so a bad value renders as a plain text card rather than
--     failing loudly.
--
-- The result is a value that can be wrong without anything reporting it: a row
-- typed 'video' from the Supabase dashboard displays as text on mobile and
-- type-lies in the admin. This adds the missing constraint so the database
-- rejects it at the source.
--
-- ---------------------------------------------------------------------------
-- Why NOT VALID
-- ---------------------------------------------------------------------------
-- A plain `add constraint ... check (...)` validates every existing row and
-- fails the whole migration if any row is out of set. Since this DB is live and
-- its current contents are unknown from here, that would turn a safety
-- improvement into a failed deploy.
--
-- NOT VALID applies the check to all INSERTs and UPDATEs from now on while
-- leaving existing rows untouched. That is exactly the useful half: new bad
-- values become impossible, and any historical row keeps rendering as text
-- (which is what the app already shows for it today), so nothing changes for
-- readers.
--
-- To tighten it fully once you have confirmed the existing data is clean:
--
--   select type, count(*) from public.news_items group by type;   -- inspect
--   update public.news_items set type = 'text'
--     where type not in ('text','image','youtube');               -- coerce
--   alter table public.news_items validate constraint news_items_type_check;
--
-- The coercion is not lossy in effect: the mobile client already displays those
-- rows as text, so it makes the stored value agree with what users see.
-- Deliberately left as a manual follow-up rather than run here, because it
-- writes to live rows and should be reviewed against real counts first.
-- ============================================================================

alter table public.news_items
  drop constraint if exists news_items_type_check;

alter table public.news_items
  add constraint news_items_type_check
  check (type in ('text', 'image', 'youtube'))
  not valid;
