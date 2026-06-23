'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Send, Square, Filter, ChevronDown } from 'lucide-react';
import { useAppStore } from '@/lib/store';
import { useAuth } from '@/lib/auth-context';
import { useLang } from '@/lib/lang-context';
import { GUEST_DAILY_LIMIT, TAFSIR_BOOKS, HADITH_BOOKS } from '@/lib/constants';
import type { AiMessage, Citation } from '@/lib/types';

interface ChatInputProps {
  onSend?: (query: string) => void;
  prefilled?: string;
}

export function ChatInput({ onSend, prefilled }: ChatInputProps) {
  const [value, setValue] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const { t, lang } = useLang();

  const isStreaming = useAppStore((s) => s.isStreaming);
  const setStreaming = useAppStore((s) => s.setStreaming);
  const addMessage = useAppStore((s) => s.addMessage);
  const updateLastMessage = useAppStore((s) => s.updateLastMessage);
  const sourceSelection = useAppStore((s) => s.sourceSelection);
  const setSourceSelection = useAppStore((s) => s.setSourceSelection);
  const queryCountToday = useAppStore((s) => s.queryCountToday);
  const incrementQueryCount = useAppStore((s) => s.incrementQueryCount);
  const startNewConversation = useAppStore((s) => s.startNewConversation);
  const currentConversationId = useAppStore((s) => s.currentConversationId);

  const { user } = useAuth();
  const isGuest = !user;
  const remaining = GUEST_DAILY_LIMIT - queryCountToday;
  const limitReached = isGuest && remaining <= 0;

  // Dropdown states
  const [tafsirOpen, setTafsirOpen] = useState(false);
  const [hadithOpen, setHadithOpen] = useState(false);

  const tafsirRef = useRef<HTMLDivElement>(null);
  const hadithRef = useRef<HTMLDivElement>(null);

  // Click outside listener for popovers
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (tafsirRef.current && !tafsirRef.current.contains(e.target as Node)) {
        setTafsirOpen(false);
      }
      if (hadithRef.current && !hadithRef.current.contains(e.target as Node)) {
        setHadithOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const activeTafsirCount = TAFSIR_BOOKS.filter((b) => sourceSelection.tafsir.books[b.id]).length;
  const activeHadithCount = HADITH_BOOKS.filter((b) => sourceSelection.hadith.books[b.id]).length;

  // Fill from landing state example question
  useEffect(() => {
    if (prefilled) {
      setValue(prefilled);
      textareaRef.current?.focus();
    }
  }, [prefilled]);

  // Auto-resize textarea
  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = Math.min(el.scrollHeight, 160) + 'px';
  }, [value]);

  // Active source chips (language-aware labels)
  const activeChips: string[] = [];
  if (sourceSelection.quran) activeChips.push(lang === 'ar' ? 'القرآن' : 'Quran');
  const activeTafsir = TAFSIR_BOOKS.filter((b) => sourceSelection.tafsir.books[b.id]);
  if (activeTafsir.length > 0)
    activeChips.push(lang === 'ar' ? `${activeTafsir.length} تفسير` : `${activeTafsir.length} Tafsir`);
  const activeHadith = HADITH_BOOKS.filter((b) => sourceSelection.hadith.books[b.id]);
  if (activeHadith.length > 0)
    activeChips.push(lang === 'ar' ? `${activeHadith.length} حديث` : `${activeHadith.length} Hadith`);

  const handleStop = () => setStreaming(false);

  const handleSend = useCallback(async () => {
    const query = value.trim();
    if (!query || isStreaming || limitReached) return;

    setValue('');
    if (textareaRef.current) textareaRef.current.style.height = 'auto';

    if (!currentConversationId) startNewConversation();

    const userMessage: AiMessage = {
      id: crypto.randomUUID(),
      role: 'user',
      content: query,
      createdAt: new Date(),
    };
    addMessage(userMessage);

    const assistantId = crypto.randomUUID();
    const aiPlaceholder: AiMessage = {
      id: assistantId,
      role: 'assistant',
      content: '',
      createdAt: new Date(),
      isStreaming: true,
    };
    addMessage(aiPlaceholder);
    setStreaming(true);

    if (isGuest) incrementQueryCount();
    if (onSend) onSend(query);

    try {
      const res = await fetch('/api/ask', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, sourceSelection }),
      });

      if (!res.ok) throw new Error('API error');

      const data = await res.json() as {
        arabicAnswer: string;
        translation: string;
        citations: Citation[];
      };

      updateLastMessage({
        content: data.translation,
        arabicAnswer: data.arabicAnswer,
        translation: data.translation,
        citations: data.citations,
        isStreaming: false,
      });
    } catch (err) {
      console.error('[ChatInput] API error:', err);
      updateLastMessage({
        content: lang === 'ar' ? 'حدث خطأ ما. حاول مجدداً.' : 'An error occurred. Please try again.',
        isStreaming: false,
      });
    } finally {
      setStreaming(false);
    }
  }, [
    value, isStreaming, limitReached, currentConversationId, addMessage,
    updateLastMessage, setStreaming, incrementQueryCount, isGuest,
    onSend, sourceSelection, startNewConversation, lang,
  ]);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div
      className="border-t pt-2 pb-4 flex-shrink-0"
      style={{ backgroundColor: 'var(--surface)', borderColor: 'var(--border)' }}
    >
      <div className="max-w-3xl w-full mx-auto px-4 flex flex-col">
        {/* Disclaimer */}
        <p className="text-center text-[10px] mb-2" style={{ color: 'var(--muted)' }}>
          {t.disclaimer}
        </p>

        {/* Inline Source Selector Row */}
        <div className="flex items-center gap-2 mb-2.5 flex-wrap">
          {/* Quran Checkbox */}
          <label className="flex items-center gap-1.5 px-3 py-1.5 rounded-full cursor-pointer border transition-colors select-none font-medium text-[11px] bg-surface-2 border-default hover:bg-surface-3">
            <input
              type="checkbox"
              checked={sourceSelection.quran}
              onChange={(e) => {
                setSourceSelection({
                  ...sourceSelection,
                  quran: e.target.checked,
                });
              }}
              className="rounded text-green-600 focus:ring-green-500 w-3.5 h-3.5 cursor-pointer accent-green-600"
            />
            <span className={sourceSelection.quran ? 'text-green-600 font-semibold' : 'text-muted'}>
              📖 {lang === 'ar' ? 'القرآن الكريم' : 'Quran'}
            </span>
          </label>

          {/* Tafsir Popover Dropdown */}
          <div className="relative" ref={tafsirRef}>
            <button
              type="button"
              onClick={() => {
                setTafsirOpen(!tafsirOpen);
                setHadithOpen(false);
              }}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full border transition-colors font-medium text-[11px] select-none ${
                activeTafsirCount > 0
                  ? 'bg-amber-50 text-amber-700 border-amber-300 dark:bg-amber-950/20 dark:text-amber-400 dark:border-amber-900'
                  : 'bg-surface-2 text-muted border-default hover:bg-surface-3'
              }`}
            >
              <span>📚 {lang === 'ar' ? 'التفاسير' : 'Tafsir'} ({activeTafsirCount})</span>
              <ChevronDown size={12} className={`transition-transform ${tafsirOpen ? 'rotate-180' : ''}`} />
            </button>

            {tafsirOpen && (
              <div
                className="absolute start-0 bottom-full mb-2 z-50 min-w-[210px] max-h-[260px] overflow-y-auto rounded-lg border shadow-xl p-2"
                style={{ backgroundColor: 'var(--surface)', borderColor: 'var(--border)' }}
              >
                {/* Select All */}
                <label className="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-surface-2 cursor-pointer text-[11px] font-semibold border-b border-default mb-1 pb-1.5 text-text">
                  <input
                    type="checkbox"
                    checked={activeTafsirCount === TAFSIR_BOOKS.length}
                    onChange={(e) => {
                      const newBooks = { ...sourceSelection.tafsir.books };
                      TAFSIR_BOOKS.forEach((b) => {
                        newBooks[b.id] = e.target.checked;
                      });
                      setSourceSelection({
                        ...sourceSelection,
                        tafsir: {
                          enabled: e.target.checked || activeTafsirCount > 0,
                          books: newBooks,
                        },
                      });
                    }}
                    className="rounded text-amber-600 focus:ring-amber-500 w-3.5 h-3.5 cursor-pointer accent-amber-600"
                  />
                  <span>{lang === 'ar' ? 'تحديد الكل' : 'Select All'}</span>
                </label>

                {TAFSIR_BOOKS.map((book) => {
                  const checked = !!sourceSelection.tafsir.books[book.id];
                  return (
                    <label
                      key={book.id}
                      className="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-surface-2 cursor-pointer text-[11px] text-text"
                    >
                      <input
                        type="checkbox"
                        checked={checked}
                        onChange={(e) => {
                          const newBooks = {
                            ...sourceSelection.tafsir.books,
                            [book.id]: e.target.checked,
                          };
                          const anyChecked = Object.values(newBooks).some(Boolean);
                          setSourceSelection({
                            ...sourceSelection,
                            tafsir: {
                              enabled: anyChecked,
                              books: newBooks,
                            },
                          });
                        }}
                        className="rounded text-amber-600 focus:ring-amber-500 w-3.5 h-3.5 cursor-pointer accent-amber-600"
                      />
                      <span className="truncate">{lang === 'ar' ? book.nameAr : book.nameEn}</span>
                    </label>
                  );
                })}
              </div>
            )}
          </div>

          {/* Hadith Popover Dropdown */}
          <div className="relative" ref={hadithRef}>
            <button
              type="button"
              onClick={() => {
                setHadithOpen(!hadithOpen);
                setTafsirOpen(false);
              }}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full border transition-colors font-medium text-[11px] select-none ${
                activeHadithCount > 0
                  ? 'bg-blue-50 text-blue-700 border-blue-300 dark:bg-blue-950/20 dark:text-blue-400 dark:border-blue-900'
                  : 'bg-surface-2 text-muted border-default hover:bg-surface-3'
              }`}
            >
              <span>📜 {lang === 'ar' ? 'الحديث الشريف' : 'Hadith'} ({activeHadithCount})</span>
              <ChevronDown size={12} className={`transition-transform ${hadithOpen ? 'rotate-180' : ''}`} />
            </button>

            {hadithOpen && (
              <div
                className="absolute start-0 bottom-full mb-2 z-50 min-w-[210px] max-h-[260px] overflow-y-auto rounded-lg border shadow-xl p-2"
                style={{ backgroundColor: 'var(--surface)', borderColor: 'var(--border)' }}
              >
                {/* Select All */}
                <label className="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-surface-2 cursor-pointer text-[11px] font-semibold border-b border-default mb-1 pb-1.5 text-text">
                  <input
                    type="checkbox"
                    checked={activeHadithCount === HADITH_BOOKS.length}
                    onChange={(e) => {
                      const newBooks = { ...sourceSelection.hadith.books };
                      HADITH_BOOKS.forEach((b) => {
                        newBooks[b.id] = e.target.checked;
                      });
                      setSourceSelection({
                        ...sourceSelection,
                        hadith: {
                          enabled: e.target.checked || activeHadithCount > 0,
                          books: newBooks,
                        },
                      });
                    }}
                    className="rounded text-blue-600 focus:ring-blue-500 w-3.5 h-3.5 cursor-pointer accent-blue-600"
                  />
                  <span>{lang === 'ar' ? 'تحديد الكل' : 'Select All'}</span>
                </label>

                {HADITH_BOOKS.map((book) => {
                  const checked = !!sourceSelection.hadith.books[book.id];
                  return (
                    <label
                      key={book.id}
                      className="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-surface-2 cursor-pointer text-[11px] text-text"
                    >
                      <input
                        type="checkbox"
                        checked={checked}
                        onChange={(e) => {
                          const newBooks = {
                            ...sourceSelection.hadith.books,
                            [book.id]: e.target.checked,
                          };
                          const anyChecked = Object.values(newBooks).some(Boolean);
                          setSourceSelection({
                            ...sourceSelection,
                            hadith: {
                              enabled: anyChecked,
                              books: newBooks,
                            },
                          });
                        }}
                        className="rounded text-blue-600 focus:ring-blue-500 w-3.5 h-3.5 cursor-pointer accent-blue-600"
                      />
                      <span className="truncate">{lang === 'ar' ? book.nameAr : book.nameEn}</span>
                    </label>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Main input row */}
        <div
          className="flex items-end gap-2 rounded-xl border p-2"
          style={{ backgroundColor: 'var(--surface-2)', borderColor: 'var(--border)' }}
        >
          <textarea
            ref={textareaRef}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={t.inputPlaceholder}
            dir="auto"
            rows={1}
            disabled={isStreaming || limitReached}
            className="flex-1 bg-transparent resize-none outline-none text-sm leading-relaxed disabled:opacity-50 textarea"
            style={{
              minHeight: '36px',
              maxHeight: '160px',
              color: 'var(--text)',
              fontFamily: lang === 'ar' ? "'Amiri', serif" : "inherit",
            }}
            aria-label={t.inputPlaceholder}
          />

          {isStreaming ? (
            <button
              onClick={handleStop}
              className="btn flex-shrink-0 w-9 h-9 p-0 rounded-lg"
              style={{ backgroundColor: '#DC2626', color: '#fff' }}
              aria-label={t.stop}
            >
              <Square size={14} fill="currentColor" />
            </button>
          ) : (
            <button
              onClick={handleSend}
              disabled={!value.trim() || limitReached}
              className="btn btn-primary flex-shrink-0 w-9 h-9 p-0 rounded-lg text-white"
              aria-label={t.send}
            >
              <Send size={15} />
            </button>
          )}
        </div>

        {/* Guest counter */}
        {isGuest && (
          <p className="text-center text-[10px] mt-2" style={{ color: 'var(--muted)' }}>
            {limitReached ? (
              <span>
                {lang === 'ar' ? 'وصلت إلى الحد اليومي · ' : 'Daily limit reached · '}
                <a href="/login" className="underline" style={{ color: 'var(--primary)' }}>
                  {t.signInForUnlimited}
                </a>
              </span>
            ) : (
              <span>
                {t.freeQueriesRemaining(remaining)}
                {' · '}
                <a href="/login" className="underline" style={{ color: 'var(--primary)' }}>
                  {t.signInForUnlimited}
                </a>
              </span>
            )}
          </p>
        )}
      </div>
    </div>
  );
}
