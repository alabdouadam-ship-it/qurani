-- ============================================================================
-- Migration 0014 — link the language variants of one announcement
-- ============================================================================
-- `news_items` is deliberately flat: one row per language, with no notion of a
-- translation group (see 0002, and the seed pairs in 0007/0008). That keeps the
-- mobile read path trivial — it filters by language and never has to resolve a
-- group — but it leaves the admin with no way to tell that three rows are the
-- same announcement. They appear as three unrelated cards, and a missing French
-- translation is invisible.
--
-- ---------------------------------------------------------------------------
-- Why a column rather than an id convention
-- ---------------------------------------------------------------------------
-- The seeded rows already encode the relationship in their ids
-- (`news_tafsir_books_2026` / `_en` / `_fr`), so grouping could be derived by
-- stripping the suffix with no schema change at all. Rejected because it only
-- holds for rows created by migration: the admin's "+ Add news" button assigns
-- `crypto.randomUUID()`, so every row created through the UI — i.e. every row
-- from now on — would silently fail to group, and the feature would appear to
-- work only on historical data. An explicit column cannot drift that way.
--
-- ---------------------------------------------------------------------------
-- Shape
-- ---------------------------------------------------------------------------
-- Nullable rather than NOT NULL: a sensible default is "this row's own id",
-- which a column DEFAULT cannot express, and adding a trigger for it would be
-- more machinery than the problem deserves. Readers treat null as "a group of
-- one" (`group_id ?? id`), and the admin writes an explicit value on create, so
-- null only ever appears on rows that predate this migration and were not
-- caught by the backfill below.
--
-- No foreign key: the group key is not a row reference. Pointing it at a
-- "primary" translation would make deleting that row orphan its siblings.
--
-- The mobile client is unaffected. `NewsService` selects all columns and then
-- maps an explicit key list in `_mapRow`, so an extra column is ignored rather
-- than breaking parsing.
-- ============================================================================

alter table public.news_items
  add column if not exists group_id text;

comment on column public.news_items.group_id is
  'Groups the language variants of one announcement. Null means "a group of '
  'one"; readers should use coalesce(group_id, id).';

-- Grouping is a per-request lookup in the admin list, and the table is small,
-- but the index costs nothing and keeps it honest as history grows.
create index if not exists news_items_group_id_idx
  on public.news_items (group_id);

-- Backfill using the seed convention: `<base>`, `<base>_en`, `<base>_fr` all
-- collapse to `<base>`. Rows whose id carries no language suffix — including
-- every UUID row — map to their own id and so form a group of one, which is
-- exactly right. Guarded by `is null` so re-running never overwrites a group
-- someone has since set from the dashboard.
update public.news_items
   set group_id = regexp_replace(id, '_(en|fr)$', '')
 where group_id is null;
