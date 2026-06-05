"use client";

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { dict, type Dict, type Lang } from "./i18n";

export type Theme = "light" | "dark" | "sand";

type UiState = {
  lang: Lang;
  theme: Theme;
  t: Dict;
  dir: "ltr" | "rtl";
  setLang: (l: Lang) => void;
  setTheme: (th: Theme) => void;
};

const UiContext = createContext<UiState | null>(null);

const LANG_KEY = "admin_lang";
const THEME_KEY = "admin_theme";

export function UiProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>("en");
  const [theme, setThemeState] = useState<Theme>("light");

  // Hydrate from localStorage once on mount.
  useEffect(() => {
    const savedLang = localStorage.getItem(LANG_KEY) as Lang | null;
    const savedTheme = localStorage.getItem(THEME_KEY) as Theme | null;
    if (savedLang === "ar" || savedLang === "en") setLangState(savedLang);
    if (savedTheme === "light" || savedTheme === "dark" || savedTheme === "sand") {
      setThemeState(savedTheme);
    }
  }, []);

  // Reflect lang/dir + theme on <html> so CSS + RTL work app-wide.
  useEffect(() => {
    const html = document.documentElement;
    html.lang = lang;
    html.dir = lang === "ar" ? "rtl" : "ltr";
    html.dataset.theme = theme;
  }, [lang, theme]);

  const setLang = (l: Lang) => {
    setLangState(l);
    localStorage.setItem(LANG_KEY, l);
  };
  const setTheme = (th: Theme) => {
    setThemeState(th);
    localStorage.setItem(THEME_KEY, th);
  };

  const value = useMemo<UiState>(
    () => ({
      lang,
      theme,
      t: dict[lang],
      dir: lang === "ar" ? "rtl" : "ltr",
      setLang,
      setTheme,
    }),
    [lang, theme]
  );

  return <UiContext.Provider value={value}>{children}</UiContext.Provider>;
}

export function useUi(): UiState {
  const ctx = useContext(UiContext);
  if (!ctx) throw new Error("useUi must be used within UiProvider");
  return ctx;
}
