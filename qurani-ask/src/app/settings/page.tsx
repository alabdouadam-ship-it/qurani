'use client';

import React, { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Loader2, Save, Moon, Sun, Monitor } from 'lucide-react';
import { useTheme } from 'next-themes';
import { useAuth } from '@/lib/auth-context';
import { getSupabase } from '@/lib/supabase';
import { Sidebar } from '@/components/Sidebar';
import { TAFSIR_BOOKS, HADITH_BOOKS, DEFAULT_SOURCE_SELECTION } from '@/lib/constants';
import { useAppStore } from '@/lib/store';
import type { SourceSelection } from '@/lib/types';

type Language = 'en' | 'ar' | 'fr';

export default function SettingsPage() {
  const router = useRouter();
  const { user, profile, loading, refreshProfile } = useAuth();
  const { theme, setTheme } = useTheme();
  const sourceSelection = useAppStore((s) => s.sourceSelection);
  const setSourceSelection = useAppStore((s) => s.setSourceSelection);

  const [displayName, setDisplayName] = useState('');
  const [language, setLanguage] = useState<Language>('en');
  const [arabicSize, setArabicSize] = useState(20);
  const [analyticsOptOut, setAnalyticsOptOut] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [draft, setDraft] = useState<SourceSelection>(sourceSelection);

  useEffect(() => {
    if (!loading && !user) {
      router.replace('/login');
    }
  }, [user, loading, router]);

  useEffect(() => {
    if (profile?.display_name) {
      setDisplayName(profile.display_name);
    }
  }, [profile]);

  const handleSave = useCallback(async () => {
    if (!user) return;
    setSaving(true);
    setError(null);

    try {
      const supabase = getSupabase();
      if (!supabase) { setSourceSelection(draft); setSaved(true); setTimeout(() => setSaved(false), 2000); setSaving(false); return; }
      const { error: updateError } = await supabase
        .from('profiles')
        .upsert({
          id: user.id,
          display_name: displayName || null,
        });

      if (updateError) throw updateError;

      setSourceSelection(draft);
      await refreshProfile();
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to save settings';
      setError(msg);
    } finally {
      setSaving(false);
    }
  }, [user, displayName, draft, setSourceSelection, refreshProfile]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <Loader2 className="animate-spin text-primary" size={28} />
      </div>
    );
  }

  return (
    <div className="flex h-screen overflow-hidden" style={{ backgroundColor: 'var(--surface)' }}>
      <Sidebar />

      <main className="flex-1 overflow-y-auto">
        <div className="max-w-2xl mx-auto px-6 py-10">
          <div className="flex items-center justify-between mb-8">
            <h1 className="text-2xl font-bold text-text">Settings</h1>
            <Link href="/chat" className="btn btn-ghost text-sm text-muted">
              ← Back to chat
            </Link>
          </div>

          {/* ── Account ───────────────────────────────────────────────────────── */}
          <section className="mb-8">
            <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-4">
              Account
            </h2>
            <div
              className="rounded-xl border border-default p-6 space-y-4"
              style={{ backgroundColor: 'var(--surface-2)' }}
            >
              <div>
                <label className="block text-sm font-medium text-text mb-1">
                  Email
                </label>
                <p className="text-sm text-muted">{user?.email}</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-text mb-1">
                  Display name
                </label>
                <input
                  type="text"
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  className="input"
                  placeholder="Your name"
                />
              </div>

              <button className="text-sm text-primary hover:underline">
                Change password →
              </button>
            </div>
          </section>

          {/* ── Appearance ────────────────────────────────────────────────────── */}
          <section className="mb-8">
            <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-4">
              Appearance
            </h2>
            <div
              className="rounded-xl border border-default p-6 space-y-5"
              style={{ backgroundColor: 'var(--surface-2)' }}
            >
              {/* Dark mode */}
              <div>
                <p className="text-sm font-medium text-text mb-3">Theme</p>
                <div className="flex gap-3">
                  {(['light', 'dark', 'system'] as const).map((t) => (
                    <button
                      key={t}
                      onClick={() => setTheme(t)}
                      className={`flex items-center gap-2 px-4 py-2 rounded-lg border text-sm transition-colors ${
                        theme === t
                          ? 'border-primary text-primary bg-primary/10'
                          : 'border-default text-muted hover:bg-surface-3'
                      }`}
                    >
                      {t === 'light' && <Sun size={14} />}
                      {t === 'dark' && <Moon size={14} />}
                      {t === 'system' && <Monitor size={14} />}
                      {t.charAt(0).toUpperCase() + t.slice(1)}
                    </button>
                  ))}
                </div>
              </div>

              {/* Arabic text size */}
              <div>
                <label className="block text-sm font-medium text-text mb-2">
                  Arabic text size:{' '}
                  <span className="text-primary font-mono">{arabicSize}px</span>
                </label>
                <input
                  type="range"
                  min={14}
                  max={32}
                  value={arabicSize}
                  onChange={(e) => setArabicSize(Number(e.target.value))}
                  className="w-full accent-[var(--primary)]"
                />
                <p
                  className="font-arabic mt-3 text-muted"
                  style={{ fontSize: arabicSize + 'px', lineHeight: '2' }}
                >
                  بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ
                </p>
              </div>
            </div>
          </section>

          {/* ── Language ──────────────────────────────────────────────────────── */}
          <section className="mb-8">
            <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-4">
              Language
            </h2>
            <div
              className="rounded-xl border border-default p-6"
              style={{ backgroundColor: 'var(--surface-2)' }}
            >
              <div className="flex gap-3">
                {(['en', 'ar', 'fr'] as Language[]).map((lang) => {
                  const labels: Record<Language, string> = {
                    en: 'English',
                    ar: 'العربية',
                    fr: 'Français',
                  };
                  return (
                    <label key={lang} className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="radio"
                        name="language"
                        value={lang}
                        checked={language === lang}
                        onChange={() => setLanguage(lang)}
                        className="accent-[var(--primary)]"
                      />
                      <span className="text-sm text-text">{labels[lang]}</span>
                    </label>
                  );
                })}
              </div>
            </div>
          </section>

          {/* ── Default sources ───────────────────────────────────────────────── */}
          <section className="mb-8">
            <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-4">
              Default Sources
            </h2>
            <div
              className="rounded-xl border border-default p-6 space-y-3"
              style={{ backgroundColor: 'var(--surface-2)' }}
            >
              {/* Quran */}
              <label className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={draft.quran}
                  onChange={(e) => setDraft((d) => ({ ...d, quran: e.target.checked }))}
                  className="w-4 h-4 accent-[var(--primary)]"
                />
                <span className="text-sm font-medium text-text">📖 Quran</span>
              </label>

              {/* Tafsir */}
              <div>
                <label className="flex items-center gap-3 cursor-pointer mb-2">
                  <input
                    type="checkbox"
                    checked={draft.tafsir.enabled}
                    onChange={(e) =>
                      setDraft((d) => ({
                        ...d,
                        tafsir: { ...d.tafsir, enabled: e.target.checked },
                      }))
                    }
                    className="w-4 h-4 accent-[var(--primary)]"
                  />
                  <span className="text-sm font-medium text-text">📚 Tafsir</span>
                </label>
                {draft.tafsir.enabled && (
                  <div className="ml-7 grid grid-cols-2 gap-2">
                    {TAFSIR_BOOKS.map((b) => (
                      <label key={b.id} className="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={!!draft.tafsir.books[b.id]}
                          onChange={(e) =>
                            setDraft((d) => ({
                              ...d,
                              tafsir: {
                                ...d.tafsir,
                                books: { ...d.tafsir.books, [b.id]: e.target.checked },
                              },
                            }))
                          }
                          className="w-3.5 h-3.5 accent-[var(--primary)]"
                        />
                        <span className="text-xs text-muted">{b.nameEn}</span>
                      </label>
                    ))}
                  </div>
                )}
              </div>

              {/* Hadith */}
              <div>
                <label className="flex items-center gap-3 cursor-pointer mb-2">
                  <input
                    type="checkbox"
                    checked={draft.hadith.enabled}
                    onChange={(e) =>
                      setDraft((d) => ({
                        ...d,
                        hadith: { ...d.hadith, enabled: e.target.checked },
                      }))
                    }
                    className="w-4 h-4 accent-[var(--primary)]"
                  />
                  <span className="text-sm font-medium text-text">📜 Hadith</span>
                </label>
                {draft.hadith.enabled && (
                  <div className="ml-7 grid grid-cols-2 gap-2">
                    {HADITH_BOOKS.map((b) => (
                      <label key={b.id} className="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={!!draft.hadith.books[b.id]}
                          onChange={(e) =>
                            setDraft((d) => ({
                              ...d,
                              hadith: {
                                ...d.hadith,
                                books: { ...d.hadith.books, [b.id]: e.target.checked },
                              },
                            }))
                          }
                          className="w-3.5 h-3.5 accent-[var(--primary)]"
                        />
                        <span className="text-xs text-muted">{b.nameEn}</span>
                      </label>
                    ))}
                  </div>
                )}
              </div>

              <button
                className="text-xs text-muted hover:text-primary"
                onClick={() => setDraft(DEFAULT_SOURCE_SELECTION)}
              >
                Reset to defaults
              </button>
            </div>
          </section>

          {/* ── Privacy ───────────────────────────────────────────────────────── */}
          <section className="mb-10">
            <h2 className="text-sm font-semibold text-muted uppercase tracking-wide mb-4">
              Privacy
            </h2>
            <div
              className="rounded-xl border border-default p-6"
              style={{ backgroundColor: 'var(--surface-2)' }}
            >
              <label className="flex items-center justify-between cursor-pointer">
                <div>
                  <p className="text-sm font-medium text-text">Opt out of analytics</p>
                  <p className="text-xs text-muted mt-0.5">
                    Disable anonymous usage tracking
                  </p>
                </div>
                <div
                  onClick={() => setAnalyticsOptOut((v) => !v)}
                  className={`relative w-10 h-5 rounded-full transition-colors cursor-pointer ${
                    analyticsOptOut ? 'bg-primary' : 'bg-surface-3'
                  }`}
                  role="switch"
                  aria-checked={analyticsOptOut}
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && setAnalyticsOptOut((v) => !v)}
                >
                  <div
                    className={`absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform ${
                      analyticsOptOut ? 'translate-x-5' : 'translate-x-0.5'
                    }`}
                  />
                </div>
              </label>
            </div>
          </section>

          {/* Error */}
          {error && (
            <div
              className="mb-4 px-4 py-3 rounded-lg text-sm"
              style={{ backgroundColor: '#FEE2E2', color: '#DC2626' }}
            >
              {error}
            </div>
          )}

          {/* Save button */}
          <div className="flex justify-end pt-4">
            <button
              onClick={handleSave}
              disabled={saving}
              className="btn btn-primary px-8 py-2.5 text-sm font-semibold"
            >
              {saving ? (
                <>
                  <Loader2 size={15} className="animate-spin" />
                  Saving…
                </>
              ) : saved ? (
                <>✓ Saved</>
              ) : (
                <>
                  <Save size={15} />
                  Save settings
                </>
              )}
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}
