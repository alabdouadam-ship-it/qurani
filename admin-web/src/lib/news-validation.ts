/**
 * Pre-save checks for a news item.
 *
 * Before this existed the only validation was `required` on the title, so the
 * first feedback on anything else was a raw PostgREST error string — or worse,
 * no error at all and a row that silently misbehaves in the app (a
 * `valid_until` before `publish_date` is accepted by the database and simply
 * never becomes visible).
 *
 * Returns i18n KEYS rather than sentences so the messages stay translatable;
 * the caller looks each one up in its dictionary. Typed as `DictKey`, so a key
 * that does not exist in the dictionary is a compile error here rather than a
 * blank line in the UI.
 *
 * Deliberately not a schema library — the rules are few and specific, and the
 * point is to catch the mistakes that are silent, not to restate the column
 * types.
 */

import type { DictKey } from "./i18n";
import { NEWS_LANGS } from "./news-visibility";

export type ValidationInput = {
  title: string;
  type: string;
  media_url: string;
  source_url: string;
  publish_date: string;
  valid_until: string;
  language: string;
  /** Raw CSV text as typed, not the parsed arrays — so a malformed entry can be
   *  reported before it is silently dropped by the parser. */
  targetLanguagesCsv: string;
  targetCountriesCsv: string;
  excludedCountriesCsv: string;
};

/** ISO 3166-1 alpha-2: exactly two ASCII letters. */
const COUNTRY_RE = /^[A-Za-z]{2}$/;

function splitCsv(s: string): string[] {
  return s
    .split(",")
    .map((x) => x.trim())
    .filter((x) => x.length > 0);
}

function isHttpUrl(v: string): boolean {
  try {
    const u = new URL(v);
    return u.protocol === "http:" || u.protocol === "https:";
  } catch {
    return false;
  }
}

/** Returns the i18n keys of every problem found, in display order. Empty means
 *  the row is safe to save. */
export function validateNews(v: ValidationInput): DictKey[] {
  const errors: DictKey[] = [];

  if (v.title.trim().length === 0) errors.push("errTitleRequired");

  // The database accepts an inverted window and the app then filters the row
  // out for its whole lifetime, so this mistake is invisible without a check.
  const from = new Date(v.publish_date).getTime();
  const to = new Date(v.valid_until).getTime();
  if (Number.isNaN(from) || Number.isNaN(to)) {
    errors.push("errDatesInvalid");
  } else if (to <= from) {
    errors.push("errValidUntilBeforePublish");
  }

  // An image/youtube item with no media URL renders as a broken card.
  if (v.type !== "text") {
    if (v.media_url.trim().length === 0) {
      errors.push("errMediaUrlRequired");
    } else if (!isHttpUrl(v.media_url.trim())) {
      errors.push("errMediaUrlInvalid");
    }
  }

  if (v.source_url.trim().length > 0 && !isHttpUrl(v.source_url.trim())) {
    errors.push("errSourceUrlInvalid");
  }

  // Anything outside ar/en/fr in target_languages can never match a reader, so
  // it silently hides the item from everyone.
  const langs = splitCsv(v.targetLanguagesCsv).map((l) => l.toLowerCase());
  if (langs.some((l) => !(NEWS_LANGS as readonly string[]).includes(l))) {
    errors.push("errTargetLanguagesInvalid");
  }

  // Same failure mode for country codes: a typo like "SAU" or "Saudi" matches
  // no device locale, so a targeted item disappears instead of erroring.
  const bad = (csv: string) => splitCsv(csv).some((c) => !COUNTRY_RE.test(c));
  if (bad(v.targetCountriesCsv)) errors.push("errTargetCountriesInvalid");
  if (bad(v.excludedCountriesCsv)) errors.push("errExcludedCountriesInvalid");

  // A country in both lists is contradictory; the client lets excluded win, so
  // the target entry is dead config worth flagging.
  const target = new Set(
    splitCsv(v.targetCountriesCsv).map((c) => c.toUpperCase())
  );
  const overlap = splitCsv(v.excludedCountriesCsv)
    .map((c) => c.toUpperCase())
    .some((c) => target.has(c));
  if (overlap) errors.push("errCountriesOverlap");

  return errors;
}
