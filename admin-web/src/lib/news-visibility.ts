/**
 * Who will actually see a news item, and why not.
 *
 * The mobile client decides per-language visibility in
 * `lib/models/news_item.dart` → `isVisibleForLanguage`, and one of its rules is
 * easy to trip and impossible to notice from the admin UI:
 *
 *   if ANY of category_ar/en/fr is set, then a language whose own category is
 *   null is excluded.
 *
 * So filling in only "Category (Arabic)" silently hides the post from English
 * and French readers — no error, no empty state, the row just never appears for
 * them. This module reproduces that rule so the editor can say so up front.
 *
 * Kept as pure functions with no React or Supabase imports so the logic can be
 * reasoned about (and tested) on its own, and so the list and the editor can
 * never disagree about what they are reporting.
 *
 * MUST stay in sync with `isVisibleForLanguage` in
 * `lib/models/news_item.dart`. Country targeting is deliberately NOT modelled
 * here: it depends on the reader's device locale, so there is no useful
 * "who is excluded" answer to show at authoring time.
 */

/** The languages the mobile app ships a UI for. */
export const NEWS_LANGS = ["ar", "en", "fr"] as const;
export type NewsLang = (typeof NEWS_LANGS)[number];

/** Why a language cannot see an item. */
export type HiddenReason =
  /** `target_languages` is non-empty and does not list this language. */
  | "targeting"
  /** Some category is set, but not the one for this language. */
  | "missingCategory";

/** Only the fields that affect language visibility. */
export type VisibilityInput = {
  target_languages: string[] | null;
  category_ar: string | null;
  category_en: string | null;
  category_fr: string | null;
};

export type Visibility = {
  visible: NewsLang[];
  hidden: { lang: NewsLang; reason: HiddenReason }[];
};

/** The category column belonging to [lang]. */
export function categoryFor(row: VisibilityInput, lang: NewsLang): string | null {
  if (lang === "ar") return row.category_ar;
  if (lang === "fr") return row.category_fr;
  return row.category_en;
}

/** True when at least one category is filled in — the condition that turns the
 *  completeness rule on. With every category empty, categories are ignored
 *  entirely and the item is visible to all languages. */
export function hasAnyCategory(row: VisibilityInput): boolean {
  return NEWS_LANGS.some((l) => {
    const c = categoryFor(row, l);
    return c != null && c.trim().length > 0;
  });
}

/**
 * Splits [NEWS_LANGS] into those that will see the item and those that will
 * not, mirroring the client's rule evaluation order: targeting first, then
 * category completeness.
 *
 * Treats an empty-string category as absent, because the editor writes `null`
 * for a blank input only on save — before that the in-memory row still holds
 * `""`, and the warning has to be right while typing.
 */
export function newsVisibility(row: VisibilityInput): Visibility {
  const targeted = (row.target_languages ?? [])
    .map((l) => l.trim().toLowerCase())
    .filter((l) => l.length > 0);
  const categoriesActive = hasAnyCategory(row);

  const visible: NewsLang[] = [];
  const hidden: { lang: NewsLang; reason: HiddenReason }[] = [];

  for (const lang of NEWS_LANGS) {
    if (targeted.length > 0 && !targeted.includes(lang)) {
      hidden.push({ lang, reason: "targeting" });
      continue;
    }
    if (categoriesActive) {
      const own = categoryFor(row, lang);
      if (own == null || own.trim().length === 0) {
        hidden.push({ lang, reason: "missingCategory" });
        continue;
      }
    }
    visible.push(lang);
  }

  return { visible, hidden };
}

/** Languages hidden specifically by the category-completeness rule — the
 *  surprising case worth warning about. Exclusions caused by `target_languages`
 *  are intentional, so they are reported separately and more quietly. */
export function hiddenByMissingCategory(row: VisibilityInput): NewsLang[] {
  return newsVisibility(row)
    .hidden.filter((h) => h.reason === "missingCategory")
    .map((h) => h.lang);
}
