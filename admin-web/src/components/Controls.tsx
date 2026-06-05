"use client";

import { useUi, type Theme } from "@/lib/ui-context";
import type { Lang } from "@/lib/i18n";

/** Language + theme switchers, used on the login screen and in the app shell. */
export function Controls() {
  const { lang, theme, setLang, setTheme, t } = useUi();

  return (
    <div className="flex items-center gap-2">
      <select
        aria-label="language"
        className="select"
        style={{ width: "auto", padding: "0.35rem 0.5rem" }}
        value={lang}
        onChange={(e) => setLang(e.target.value as Lang)}
      >
        <option value="en">English</option>
        <option value="ar">العربية</option>
      </select>
      <select
        aria-label={t.theme}
        className="select"
        style={{ width: "auto", padding: "0.35rem 0.5rem" }}
        value={theme}
        onChange={(e) => setTheme(e.target.value as Theme)}
      >
        <option value="light">{t.themeLight}</option>
        <option value="dark">{t.themeDark}</option>
        <option value="sand">{t.themeSand}</option>
      </select>
    </div>
  );
}
