'use client';

import React, { useState, useRef, useEffect } from 'react';
import {
  ThumbsUp,
  ThumbsDown,
  AlertTriangle,
  Copy,
  Share2,
  ChevronDown,
  Check,
  Loader2,
} from 'lucide-react';
import type { AiMessage } from '@/lib/types';
import { CitationCard } from './CitationCard';
import { useLang } from '@/lib/lang-context';

// ─── Copy button ──────────────────────────────────────────────────────────────
function CopyBtn({ text, label }: { text: string; label?: string }) {
  const [copied, setCopied] = useState(false);
  const { t } = useLang();

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const el = document.createElement('textarea');
      el.value = text;
      document.body.appendChild(el);
      el.select();
      document.execCommand('copy');
      document.body.removeChild(el);
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <button
      onClick={handleCopy}
      className="flex items-center gap-1 text-xs btn btn-ghost px-2 py-1"
    >
      {copied ? (
        <Check size={12} className="text-green-600" />
      ) : (
        <Copy size={12} />
      )}
      {label && <span>{copied ? t.copied : label}</span>}
    </button>
  );
}

// ─── Copy dropdown ────────────────────────────────────────────────────────────
function CopyDropdown({ message }: { message: AiMessage }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [open]);

  const arabicOnly = message.arabicAnswer ?? '';
  const translationOnly = message.translation ?? message.content;

  const buildFullText = () => {
    let text = '';
    if (message.arabicAnswer) text += `${message.arabicAnswer}\n\n`;
    if (message.translation) text += `${message.translation}\n\n`;
    if (message.citations && message.citations.length > 0) {
      text += '── Sources ──\n\n';
      for (const c of message.citations) {
        if (c.type === 'quran') {
          text += `Quran ${c.surahNameEn} (${c.surahNo}:${c.ayahNo})\n${c.arabicText}\n${c.translation}\n\n`;
        } else if (c.type === 'tafsir') {
          text += `Tafsir ${c.bookNameEn} on ${c.surahNo}:${c.ayahNo}\n${c.translation}\n\n`;
        } else if (c.type === 'hadith') {
          text += `Hadith ${c.bookNameEn} #${c.hadithNo}\n${c.matnTranslation}\n\n`;
        }
      }
    }
    return text.trim();
  };

  const buildWhatsApp = () => {
    let text = '🕌 *Qurani AI*\n\n';
    if (message.arabicAnswer) text += `${message.arabicAnswer}\n\n`;
    if (message.translation) text += `_${message.translation}_\n\n`;
    text += '_Shared from Qurani AI_';
    return text;
  };

  const options = [
    { label: 'Arabic only', getText: () => arabicOnly },
    { label: 'Translation only', getText: () => translationOnly },
    { label: 'Answer + Citations', getText: buildFullText },
    { label: 'WhatsApp format', getText: buildWhatsApp },
  ];

  const handleOption = async (getText: () => string) => {
    const text = getText();
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      /* fallback */
    }
    setOpen(false);
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((v) => !v)}
        className="btn btn-ghost px-2 py-1 text-xs flex items-center gap-1"
      >
        <Copy size={12} />
        Copy
        <ChevronDown size={11} />
      </button>
      {open && (
        <div
          className="absolute right-0 top-full mt-1 z-50 min-w-[180px] rounded-md border shadow-lg overflow-hidden"
          style={{ backgroundColor: 'var(--surface)', borderColor: 'var(--border)' }}
        >
          {options.map((opt) => (
            <button
              key={opt.label}
              onClick={() => handleOption(opt.getText)}
              className="w-full text-left px-3 py-2 text-sm hover:bg-surface-2 text-text"
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Skeleton rows ─────────────────────────────────────────────────────────────
function SkeletonRows() {
  return (
    <div className="space-y-3 py-4">
      {[80, 95, 70, 85, 60].map((w, i) => (
        <div key={i} className="skeleton h-4 rounded" style={{ width: `${w}%` }} />
      ))}
    </div>
  );
}

// ─── AiAnswer ─────────────────────────────────────────────────────────────────
export function AiAnswer({ message }: { message: AiMessage }) {
  const { arabicAnswer, translation, citations, isStreaming, content } = message;

  const handleShare = async () => {
    if (navigator.share) {
      await navigator.share({
        title: 'Qurani AI Answer',
        text: translation ?? content,
        url: window.location.href,
      });
    } else {
      await navigator.clipboard.writeText(window.location.href);
    }
  };

  return (
    <article className="w-full">
      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <span className="text-lg">🤖</span>
          <span className="font-semibold text-sm text-text">Qurani AI</span>
        </div>
        <div className="flex items-center gap-1">
          <CopyDropdown message={message} />
          <button
            onClick={handleShare}
            className="btn btn-ghost px-2 py-1 text-xs flex items-center gap-1"
          >
            <Share2 size={12} />
            Share
          </button>
        </div>
      </div>

      {/* ── Arabic answer ───────────────────────────────────────────────────── */}
      {isStreaming && !arabicAnswer ? (
        <SkeletonRows />
      ) : arabicAnswer ? (
        <div
          className="rounded-xl p-4 mb-4"
          style={{ backgroundColor: 'var(--surface-2)', border: '1px solid var(--border)' }}
        >
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-semibold text-muted uppercase tracking-wide">
              Arabic Answer
            </span>
            <CopyBtn text={arabicAnswer} label="Copy Arabic" />
          </div>
          <p
            className={`font-arabic-lg text-text leading-loose${isStreaming ? ' streaming-cursor' : ''}`}
          >
            {arabicAnswer}
          </p>
        </div>
      ) : null}

      {/* ── Translation ─────────────────────────────────────────────────────── */}
      {isStreaming && !translation ? null : translation ? (
        <div
          className="rounded-xl p-4 mb-4"
          style={{ backgroundColor: 'var(--surface-2)', border: '1px solid var(--border)' }}
        >
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-semibold text-muted uppercase tracking-wide">
              Translation
            </span>
            <CopyBtn text={translation} label="Copy Translation" />
          </div>
          <p className="text-sm leading-relaxed text-text">{translation}</p>
        </div>
      ) : null}

      {/* ── Fallback plain content ───────────────────────────────────────────── */}
      {!arabicAnswer && !translation && (
        <p className={`text-sm leading-relaxed text-text mb-4${isStreaming ? ' streaming-cursor' : ''}`}>
          {content}
        </p>
      )}

      {/* ── Sources divider ─────────────────────────────────────────────────── */}
      {citations && citations.length > 0 && (
        <>
          <div className="flex items-center gap-3 my-5">
            <div className="flex-1 h-px" style={{ backgroundColor: 'var(--border)' }} />
            <span className="text-xs text-muted font-arabic px-2">
              المصادر (Sources)
            </span>
            <div className="flex-1 h-px" style={{ backgroundColor: 'var(--border)' }} />
          </div>

          {/* Citations */}
          <div className="space-y-2">
            {citations.map((citation, i) => (
              <CitationCard key={i} citation={citation} />
            ))}
          </div>
        </>
      )}

      {/* ── Loading indicator ────────────────────────────────────────────────── */}
      {isStreaming && (
        <div className="flex items-center gap-2 text-xs text-muted mt-3">
          <Loader2 size={12} className="animate-spin" />
          Generating answer…
        </div>
      )}

      {/* ── Action row ──────────────────────────────────────────────────────── */}
      {!isStreaming && (arabicAnswer || translation || content) && (
        <div className="flex items-center gap-2 mt-5 pt-4 border-t border-default flex-wrap">
          <button className="btn btn-ghost px-2 py-1 text-xs flex items-center gap-1 text-muted hover:text-primary">
            <ThumbsUp size={13} />
            Helpful
          </button>
          <button className="btn btn-ghost px-2 py-1 text-xs flex items-center gap-1 text-muted hover:text-danger">
            <ThumbsDown size={13} />
          </button>
          <button className="btn btn-ghost px-2 py-1 text-xs flex items-center gap-1 text-muted">
            <AlertTriangle size={13} />
            Report inaccuracy
          </button>
          <div className="ml-auto">
            {arabicAnswer || translation ? (
              <CopyBtn
                text={[arabicAnswer, translation].filter(Boolean).join('\n\n')}
                label="Copy All"
              />
            ) : null}
          </div>
        </div>
      )}
    </article>
  );
}
