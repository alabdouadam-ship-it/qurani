/**
 * Typed schema for the Supabase client.
 *
 * ---------------------------------------------------------------------------
 * Why this is hand-written
 * ---------------------------------------------------------------------------
 * It should be generated:
 *
 *   npx supabase gen types typescript --linked > src/lib/database.types.ts
 *
 * That currently fails with "Your account does not have the necessary
 * privileges to access this endpoint" — the Management API type-generation
 * endpoint needs a token with more privileges than the one this project is
 * linked with. It also works with `--db-url <direct connection string>`, which
 * needs the database password.
 *
 * So this file is maintained by hand from the migrations, and is honest about
 * what that buys and what it does not:
 *
 *   IT DOES catch client-side mistakes that used to be silent runtime failures.
 *   Every query was previously untyped and cast (`data as NewsRow[]`), so
 *   `.eq("titel", …)` or selecting a column that does not exist compiled fine
 *   and failed as a PostgREST error at runtime. Those are now type errors.
 *
 *   IT DOES NOT detect schema drift. If a column is renamed in a migration and
 *   not here, this file simply becomes wrong — exactly the weakness generation
 *   would remove. Until generation is available, a schema change means editing
 *   this file in the same commit as the migration.
 *
 * Columns transcribed from:
 *   news_items → 20260605000002_news.sql, + updated_by (0004), + group_id (0014)
 *   reciters   → 20260605000003_reciters.sql, + updated_by (0004)
 *   admins     → 20260605000004_admin.sql
 *
 * NOT NULL columns with a DEFAULT are optional on Insert (Postgres fills them)
 * but never null on Row — that asymmetry is the whole point of the
 * Row/Insert/Update split.
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

/** news_items — every column is NOT NULL apart from the three categories,
 *  updated_by and group_id. */
type NewsItemsRow = {
  id: string;
  group_id: string | null;
  title: string;
  description: string;
  type: string;
  media_url: string;
  source_url: string;
  publish_date: string;
  valid_until: string;
  language: string;
  category_ar: string | null;
  category_en: string | null;
  category_fr: string | null;
  target_languages: string[];
  target_countries: string[];
  excluded_countries: string[];
  is_featured: boolean;
  send_notification: boolean;
  is_published: boolean;
  created_at: string;
  updated_at: string;
  updated_by: string | null;
};

/** Only `id` and `valid_until` lack a default, so everything else is optional. */
type NewsItemsInsert = Partial<Omit<NewsItemsRow, "id" | "valid_until">> & {
  id: string;
  valid_until: string;
};

type RecitersRow = {
  code: string;
  name_ar: string;
  name_latin: string;
  ayahs_path: string;
  surahs_path: string | null;
  sort_order: number;
  is_enabled: boolean;
  created_at: string;
  updated_at: string;
  updated_by: string | null;
};

/** `code`, `name_ar` and `name_latin` have no default. */
type RecitersInsert = Partial<
  Omit<RecitersRow, "code" | "name_ar" | "name_latin">
> & {
  code: string;
  name_ar: string;
  name_latin: string;
};

type AdminsRow = {
  id: string;
  name: string;
  created_at: string;
};

export type Database = {
  public: {
    Tables: {
      news_items: {
        Row: NewsItemsRow;
        Insert: NewsItemsInsert;
        Update: Partial<NewsItemsRow>;
        Relationships: [];
      };
      reciters: {
        Row: RecitersRow;
        Insert: RecitersInsert;
        Update: Partial<RecitersRow>;
        Relationships: [];
      };
      admins: {
        Row: AdminsRow;
        Insert: { id: string; name: string; created_at?: string };
        Update: Partial<AdminsRow>;
        Relationships: [];
      };
    };
    Views: Record<never, never>;
    Functions: {
      /** Aggregated dashboard payload; shape mirrored by `Stats` in
       *  app/dashboard/page.tsx. Returns jsonb, so typed as Json and narrowed
       *  at the call site. Raises 'not authorized' unless is_admin(). */
      admin_dashboard_stats: {
        Args: Record<PropertyKey, never>;
        Returns: Json;
      };
      /** Anon-safe boolean used by /login to choose login vs first-admin setup. */
      admin_exists: {
        Args: Record<PropertyKey, never>;
        Returns: boolean;
      };
      is_admin: {
        Args: Record<PropertyKey, never>;
        Returns: boolean;
      };
    };
    Enums: Record<never, never>;
    CompositeTypes: Record<never, never>;
  };
};
