'use client';

import { useLang } from '@/lib/lang-context';

export function LandingState({ onQuestion }: { onQuestion: (q: string) => void }) {
  const { t } = useLang();

  return (
    <div className="flex flex-col items-center justify-center h-full px-6 py-12 text-center">
      {/* Bismillah */}
      <p
        className="font-arabic text-xl mb-6"
        dir="rtl"
        style={{ color: 'var(--muted)', lineHeight: 2.4 }}
      >
        {t.bismillah}
      </p>

      {/* App name */}
      <h1 className="text-3xl font-bold mb-2" style={{ color: 'var(--primary)' }}>
        {t.landingTitle}
      </h1>
      <p className="text-base mb-10" style={{ color: 'var(--muted)' }}>
        {t.landingSubtitle}
      </p>

      {/* Example question cards */}
      <div className="w-full max-w-xl">
        <p className="text-xs uppercase tracking-wide font-semibold mb-3" style={{ color: 'var(--muted)' }}>
          {t.tryAsking}
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {(t.exampleQuestions as string[]).slice(0, 4).map((q: string, i: number) => (
            <button
              key={i}
              onClick={() => onQuestion(q)}
              className="card card-hover text-sm leading-relaxed text-start p-4 cursor-pointer transition-all duration-150 hover:-translate-y-0.5"
              style={{
                textAlign: 'start',
                color: 'var(--text)',
              }}
            >
              {q}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
