'use client';

import { useEffect, useState } from 'react';
import { useLang } from '@/lib/lang-context';

type Phase = 1 | 2 | 3;

interface StreamingIndicatorProps {
  passageCount?: number;
}

export function StreamingIndicator({ passageCount = 7 }: StreamingIndicatorProps) {
  const [phase, setPhase] = useState<Phase>(1);
  const { t } = useLang();

  useEffect(() => {
    const t1 = setTimeout(() => setPhase(2), 1000);
    const t2 = setTimeout(() => setPhase(3), 1800);
    return () => { clearTimeout(t1); clearTimeout(t2); };
  }, []);

  return (
    <div className="flex items-center gap-2 py-2 text-sm" style={{ color: 'var(--muted)' }}>
      {phase === 1 && (
        <>
          <span className="w-4 h-4 rounded-full border-2 border-t-transparent animate-spin flex-shrink-0" style={{ borderColor: 'var(--primary)' }} />
          <span className="dot-pulse">{t.searchingPhase}</span>
        </>
      )}
      {phase === 2 && (
        <>
          <span style={{ color: 'var(--quran)' }}>✓</span>
          <span>{t.foundPhase(passageCount)}</span>
          <span className="mx-1">·</span>
          <span className="dot-pulse">{t.generatingPhase}</span>
        </>
      )}
      {phase === 3 && (
        <>
          <span style={{ color: 'var(--primary)' }}>✍</span>
          <span className="streaming-cursor">{t.generatingPhase}</span>
        </>
      )}
    </div>
  );
}
