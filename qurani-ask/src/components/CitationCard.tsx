'use client';

import React, { useState } from 'react';
import { Check, Clipboard, ChevronDown, ChevronUp, ExternalLink } from 'lucide-react';
import type { Citation, QuranCitation, TafsirCitation, HadithCitation } from '@/lib/types';

// ─── Copy hook ────────────────────────────────────────────────────────────────
function useCopy() {
  const [copied, setCopied] = useState(false);
  const copy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Fallback for older browsers
      const el = document.createElement('textarea');
      el.value = text;
      document.body.appendChild(el);
      el.select();
      document.execCommand('copy');
      document.body.removeChild(el);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    }
  };
  return { copied, copy };
}

// ─── Copy button ──────────────────────────────────────────────────────────────
function CopyButton({ text }: { text: string }) {
  const { copied, copy } = useCopy();
  return (
    <button
      onClick={() => copy(text)}
      className="btn btn-ghost p-1 rounded text-muted hover:text-primary"
      title="Copy"
      aria-label="Copy to clipboard"
    >
      {copied ? (
        <Check size={13} className="text-green-600" />
      ) : (
        <Clipboard size={13} />
      )}
    </button>
  );
}

// ─── Grade badge ─────────────────────────────────────────────────────────────
function GradeBadge({ grade }: { grade: string }) {
  const styles: Record<string, { dot: string; label: string; bg: string; text: string }> = {
    sahih: { dot: '●', label: 'Sahih', bg: '#DCFCE7', text: '#16A34A' },
    hasan: { dot: '●', label: 'Hasan', bg: '#FEF3C7', text: '#D97706' },
    daif: { dot: '●', label: "Da'if", bg: '#FEE2E2', text: '#DC2626' },
    unknown: { dot: '●', label: 'Unknown', bg: 'var(--surface-3)', text: 'var(--muted)' },
  };
  const s = styles[grade] ?? styles.unknown;
  return (
    <span
      className="badge"
      style={{ backgroundColor: s.bg, color: s.text }}
    >
      <span>{s.dot}</span>
      {s.label}
    </span>
  );
}

// ─── Quran card ───────────────────────────────────────────────────────────────
function QuranCard({ c }: { c: QuranCitation }) {
  const copyText = `﴾ ${c.arabicText} ﴿\n— ${c.surahNameEn} (${c.surahNo}:${c.ayahNo})\n\nTranslation: ${c.translation}`;

  return (
    <div className="citation-card citation-quran">
      {/* Header */}
      <div
        className="flex items-center justify-between px-4 py-2.5"
        style={{ backgroundColor: 'var(--quran-bg)' }}
      >
        <div className="flex items-center gap-2 flex-wrap">
          <span className="badge" style={{ backgroundColor: 'var(--quran)', color: '#fff' }}>
            📖 QURAN
          </span>
          <span className="font-arabic text-sm" style={{ color: 'var(--quran)' }}>
            {c.surahNameAr}
          </span>
          <span className="text-xs text-muted">·</span>
          <span className="text-xs text-muted font-medium">{c.surahNameEn}</span>
          <span
            className="badge"
            style={{ backgroundColor: 'var(--quran)', color: '#fff', fontSize: '0.65rem' }}
          >
            {c.surahNo}:{c.ayahNo}
          </span>
          {c.revelationType && (
            <span className="badge" style={{ backgroundColor: 'var(--surface-3)', color: 'var(--muted)' }}>
              {c.revelationType === 'meccan' ? 'Meccan' : 'Medinan'}
            </span>
          )}
        </div>
        <CopyButton text={copyText} />
      </div>

      <div className="px-5 py-4">
        {/* Arabic verse */}
        <p className="font-arabic-xl mb-3" style={{ color: 'var(--text)' }}>
          <span style={{ color: 'var(--quran)', fontWeight: 700 }}>﴾</span>
          {' '}{c.arabicText}{' '}
          <span style={{ color: 'var(--quran)', fontWeight: 700 }}>﴿</span>
        </p>

        {/* Divider */}
        <hr className="border-default my-3" />

        {/* Translation */}
        <p className="text-sm text-muted italic leading-relaxed">&ldquo;{c.translation}&rdquo;</p>
      </div>

      {/* Footer */}
      <div
        className="flex items-center justify-between px-4 py-2 border-t border-default"
        style={{ backgroundColor: 'var(--surface-2)' }}
      >
        <a
          href={`https://quran.com/${c.surahNo}/${c.ayahNo}`}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-1 text-xs text-primary hover:underline"
        >
          Open in Quran.com <ExternalLink size={11} />
        </a>
      </div>
    </div>
  );
}

// ─── Tafsir card ──────────────────────────────────────────────────────────────
function TafsirCard({ c }: { c: TafsirCitation }) {
  const copyText = `${c.bookNameEn} — Commentary on ${c.surahNo}:${c.ayahNo}\n\n${c.arabicText}\n\nTranslation: ${c.translation}`;

  return (
    <div className="citation-card citation-tafsir">
      {/* Header */}
      <div
        className="flex items-center justify-between px-4 py-2.5"
        style={{ backgroundColor: 'var(--tafsir-bg)' }}
      >
        <div className="flex items-center gap-2 flex-wrap">
          <span className="badge" style={{ backgroundColor: 'var(--tafsir)', color: '#fff' }}>
            📚 TAFSIR
          </span>
          <span className="font-arabic text-sm" style={{ color: 'var(--tafsir)' }}>
            {c.bookNameAr}
          </span>
          <span className="text-xs text-muted">·</span>
          <span className="text-xs text-muted font-medium">{c.bookNameEn}</span>
          <span className="text-xs text-muted">
            Commentary on {c.surahNo}:{c.ayahNo}
          </span>
        </div>
        <CopyButton text={copyText} />
      </div>

      <div className="px-5 py-4">
        {/* Arabic text */}
        <p className="font-arabic-lg mb-3" style={{ color: 'var(--text)' }}>
          {c.arabicText}
        </p>

        <hr className="border-default my-3" />

        {/* Translation */}
        <p className="text-sm text-muted leading-relaxed">{c.translation}</p>
      </div>
    </div>
  );
}

// ─── Hadith card ──────────────────────────────────────────────────────────────
function HadithCard({ c }: { c: HadithCitation }) {
  const [isnadOpen, setIsnadOpen] = useState(false);
  const copyText = `${c.bookNameEn} #${c.hadithNo}${c.chapterName ? ` — ${c.chapterName}` : ''}\n\n${c.matnAr}\n\nTranslation: ${c.matnTranslation}\n\nGrade: ${c.grade}`;

  return (
    <div className="citation-card citation-hadith">
      {/* Header */}
      <div
        className="flex items-center justify-between px-4 py-2.5"
        style={{ backgroundColor: 'var(--hadith-bg)' }}
      >
        <div className="flex items-center gap-2 flex-wrap">
          <span className="badge" style={{ backgroundColor: 'var(--hadith)', color: '#fff' }}>
            📜 HADITH
          </span>
          <span className="font-arabic text-sm" style={{ color: 'var(--hadith)' }}>
            {c.bookNameAr}
          </span>
          <span className="text-xs text-muted">·</span>
          <span className="text-xs text-muted font-medium">{c.bookNameEn}</span>
          {c.chapterName && (
            <>
              <span className="text-xs text-muted">·</span>
              <span className="text-xs text-muted">{c.chapterName}</span>
            </>
          )}
          <span
            className="badge"
            style={{ backgroundColor: 'var(--hadith)', color: '#fff', fontSize: '0.65rem' }}
          >
            #{c.hadithNo}
          </span>
          <GradeBadge grade={c.grade} />
        </div>
        <CopyButton text={copyText} />
      </div>

      <div className="px-5 py-4">
        {/* Arabic matn */}
        <p className="font-arabic-lg mb-3" style={{ color: 'var(--text)' }}>
          {c.matnAr}
        </p>

        <hr className="border-default my-3" />

        {/* Translation */}
        <p className="text-sm text-muted leading-relaxed">{c.matnTranslation}</p>

        {/* Isnad toggle */}
        {c.isnad && (
          <div className="mt-3">
            <button
              onClick={() => setIsnadOpen((v) => !v)}
              className="flex items-center gap-1 text-xs text-primary hover:underline"
            >
              {isnadOpen ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
              {isnadOpen ? 'Hide' : 'Show'} narrator chain
            </button>
            {isnadOpen && (
              <p className="font-arabic text-sm mt-2 p-3 rounded-md border border-default" style={{ backgroundColor: 'var(--surface-2)', color: 'var(--muted)' }}>
                {c.isnad}
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// ─── CitationCard (dispatcher) ────────────────────────────────────────────────
export function CitationCard({ citation }: { citation: Citation }) {
  if (citation.type === 'quran') return <QuranCard c={citation} />;
  if (citation.type === 'tafsir') return <TafsirCard c={citation} />;
  return <HadithCard c={citation} />;
}
