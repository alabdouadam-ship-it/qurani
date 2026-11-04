/**
 * Row shapes used across the admin UI.
 *
 * These were hand-written duplicates of the database columns; they are now
 * derived from `database.types.ts`, so the schema is described in exactly one
 * place and a mismatch becomes a compile error rather than a runtime PostgREST
 * failure. The names are unchanged so call sites read the same.
 *
 * `created_at` / `updated_at` are optional here even though they are NOT NULL in
 * the database. The editors build a draft row before it exists — `EMPTY` plus a
 * generated id — and those two columns are filled by the DEFAULT and the
 * `touch_updated_at` triggers, so the UI neither sets nor needs them. Making
 * them required would force the drafts to invent timestamps the database is
 * about to overwrite.
 */

import type { Database } from "./database.types";

/** Columns the database maintains; never written by the admin. */
type DbManaged = "created_at" | "updated_at";

type Editable<T extends { created_at: string; updated_at: string }> = Omit<
  T,
  DbManaged
> &
  Partial<Pick<T, DbManaged>>;

export type NewsRow = Editable<Database["public"]["Tables"]["news_items"]["Row"]>;
export type ReciterRow = Editable<
  Database["public"]["Tables"]["reciters"]["Row"]
>;
