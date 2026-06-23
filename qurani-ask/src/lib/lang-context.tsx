'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import type { Lang, Translations } from './i18n';
import { translations } from './i18n';

// ─── Context ──────────────────────────────────────────────────────────────────
interface LangContextValue {
  lang: Lang;
  dir: 'rtl' | 'ltr';
  t: Translations;
  setLang: (lang: Lang) => void;
}

const LangContext = createContext<LangContextValue>({
  lang: 'ar',
  dir: 'rtl',
  t: translations.ar,
  setLang: () => {},
});

// ─── Storage key ──────────────────────────────────────────────────────────────
const STORAGE_KEY = 'qurani-lang';

function getInitialLang(): Lang {
  if (typeof window === 'undefined') return 'ar';
  const stored = localStorage.getItem(STORAGE_KEY);
  if (stored === 'ar' || stored === 'en') return stored;
  return 'ar'; // Arabic-first default
}

// ─── Provider ─────────────────────────────────────────────────────────────────
export function LangProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>('ar'); // SSR default

  // Hydrate from localStorage after mount
  useEffect(() => {
    const saved = getInitialLang();
    setLangState(saved);
  }, []);

  // Sync html element dir + lang whenever language changes
  useEffect(() => {
    const dir = lang === 'ar' ? 'rtl' : 'ltr';
    document.documentElement.lang = lang;
    document.documentElement.dir = dir;
  }, [lang]);

  const setLang = (newLang: Lang) => {
    setLangState(newLang);
    localStorage.setItem(STORAGE_KEY, newLang);
  };

  const dir = lang === 'ar' ? 'rtl' : 'ltr';

  return (
    <LangContext.Provider value={{ lang, dir, t: translations[lang], setLang }}>
      {children}
    </LangContext.Provider>
  );
}

// ─── Hook ─────────────────────────────────────────────────────────────────────
export function useLang() {
  return useContext(LangContext);
}
