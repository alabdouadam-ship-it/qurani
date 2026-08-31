/**
 * Grouping and filtering for the news list.
 *
 * `news_items` stores one row per language with no inherent link between the
 * variants of one announcement, so the list used to show three unrelated cards
 * for a single story and a missing translation was invisible. `group_id`
 * (migration 0014) supplies the link; this module turns it into something the
 * list can render, and answers "which languages is this announcement missing".
 *
 * Pure and React-free so the rules can be reasoned about on their own, matching
 * `news-visibility.ts` and `news-validation.ts`.
 */

import { NEWS_LANGS, type NewsLang } from "./news-visibility";

/** The row fields these helpers need. Structural so callers can pass a NewsRow. */
export type GroupableRow = {
  id: string;
  group_id: string | null;
  language: string;
};

export type NewsGroup<T extends GroupableRow> = {
  /** `group_id ?? id` of the first member. */
  key: string;
  rows: T[];
  /** Languages this group already has a row for, in NEWS_LANGS order. */
  present: NewsLang[];
  /** Languages with no row yet — what "Add translation" offers. */
  missing: NewsLang[];
};

/** The group a row belongs to. Null `group_id` means the row stands alone. */
export function groupKeyOf(row: GroupableRow): string {
  const g = row.group_id;
  return g != null && g.trim().length > 0 ? g : row.id;
}

/**
 * Collapses rows into groups, preserving the order in which groups first
 * appear so the caller's sort (publish date, descending) still drives the page.
 *
 * A group can legitimately hold two rows of the same language — nothing stops
 * an editor creating a second Arabic variant — so `present` is de-duplicated
 * while `rows` keeps every row.
 */
export function groupNews<T extends GroupableRow>(rows: T[]): NewsGroup<T>[] {
  const byKey = new Map<string, T[]>();
  const order: string[] = [];

  for (const row of rows) {
    const key = groupKeyOf(row);
    const existing = byKey.get(key);
    if (existing) {
      existing.push(row);
    } else {
      byKey.set(key, [row]);
      order.push(key);
    }
  }

  return order.map((key) => {
    const groupRows = byKey.get(key)!;
    const langs = new Set(
      groupRows.map((r) => r.language.trim().toLowerCase())
    );
    const present = NEWS_LANGS.filter((l) => langs.has(l));
    const missing = NEWS_LANGS.filter((l) => !langs.has(l));
    return { key, rows: groupRows, present, missing };
  });
}

// ── Filtering ──────────────────────────────────────────────────────────────

export type NewsStatus = "live" | "scheduled" | "expired";

export type NewsFilter = {
  /** Matched case-insensitively against title and description. */
  text: string;
  /** "" means any. */
  language: string;
  /** "" means any. */
  type: string;
  /** "" means any. */
  status: "" | NewsStatus;
};

export const EMPTY_FILTER: NewsFilter = {
  text: "",
  language: "",
  type: "",
  status: "",
};

export function isFilterActive(f: NewsFilter): boolean {
  return (
    f.text.trim().length > 0 ||
    f.language !== "" ||
    f.type !== "" ||
    f.status !== ""
  );
}

export type FilterableRow = {
  title: string;
  description: string;
  language: string;
  type: string;
  publish_date: string;
  valid_until: string;
};

/**
 * The item's state at [nowMs].
 *
 * Takes the clock as an argument rather than calling `Date.now()` so callers can
 * pass one shared value — the list's section split and its per-row badge
 * disagreed when they each read the clock separately.
 */
export function statusAt(row: FilterableRow, nowMs: number): NewsStatus {
  if (new Date(row.valid_until).getTime() <= nowMs) return "expired";
  if (new Date(row.publish_date).getTime() > nowMs) return "scheduled";
  return "live";
}

export function matchesFilter(
  row: FilterableRow,
  f: NewsFilter,
  nowMs: number
): boolean {
  const needle = f.text.trim().toLowerCase();
  if (needle.length > 0) {
    const haystack = `${row.title} ${row.description}`.toLowerCase();
    if (!haystack.includes(needle)) return false;
  }
  if (f.language !== "" && row.language !== f.language) return false;
  if (f.type !== "" && row.type !== f.type) return false;
  if (f.status !== "" && statusAt(row, nowMs) !== f.status) return false;
  return true;
}
