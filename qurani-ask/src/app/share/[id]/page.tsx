import { notFound } from 'next/navigation';
import Link from 'next/link';
import { MessageSquare } from 'lucide-react';
import type { AiMessage } from '@/lib/types';

// In production this fetches from Supabase using a service role server client.
// For now it returns mock data so the route renders.
async function getSharedConversation(id: string): Promise<{ title: string; messages: AiMessage[] } | null> {
  // TODO: Replace with real Supabase fetch once DB tables are created
  // const supabase = await getServerSupabase();
  // const { data } = await supabase
  //   .from('shared_conversations')
  //   .select('*, messages(*)')
  //   .eq('share_id', id)
  //   .single();
  // if (!data) return null;
  // return data;

  // Mock: only the demo share ID works
  if (id === 'demo') {
    return {
      title: 'What does the Quran say about patience?',
      messages: [
        {
          id: '1',
          role: 'user',
          content: 'What does the Quran say about patience?',
          createdAt: new Date('2026-06-12T10:00:00Z'),
        },
        {
          id: '2',
          role: 'assistant',
          content: '',
          arabicAnswer:
            'الصبر من أعظم الأخلاق التي أمر الله تعالى بها عباده، وقد ورد ذكره في القرآن الكريم في مواضع كثيرة.',
          translation:
            'Patience is one of the greatest virtues that Allah commanded His servants to adopt, and it is mentioned in the Quran in many places.',
          citations: [
            {
              type: 'quran',
              surahNo: 2,
              surahNameAr: 'البقرة',
              surahNameEn: 'Al-Baqarah',
              ayahNo: 153,
              arabicText:
                'يَٰٓأَيُّهَا ٱلَّذِينَ ءَامَنُوا۟ ٱسْتَعِينُوا۟ بِٱلصَّبْرِ وَٱلصَّلَوٰةِ ۚ إِنَّ ٱللَّهَ مَعَ ٱلصَّٰبِرِينَ',
              translation:
                'O you who believe, seek help through patience and prayer. Indeed, Allah is with the patient.',
              revelationType: 'medinan',
            },
          ],
          createdAt: new Date('2026-06-12T10:00:05Z'),
        },
      ],
    };
  }

  return null;
}

export default async function SharePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const conversation = await getSharedConversation(id);

  if (!conversation) notFound();

  return (
    <div className="min-h-screen" style={{ backgroundColor: 'var(--surface)', color: 'var(--text)' }}>
      {/* Header */}
      <header
        className="sticky top-0 z-10 flex items-center justify-between px-6 py-4 border-b"
        style={{ backgroundColor: 'var(--surface-2)', borderColor: 'var(--border)' }}
      >
        <Link href="/chat" className="flex items-center gap-2 font-semibold" style={{ color: 'var(--primary)' }}>
          🕌 Qurani AI
        </Link>
        <div className="flex items-center gap-3">
          <span className="text-xs hidden sm:block" style={{ color: 'var(--muted)' }}>
            Read-only shared conversation
          </span>
          <Link href="/chat" className="btn btn-primary text-sm">
            Try Qurani AI →
          </Link>
        </div>
      </header>

      {/* Conversation */}
      <main className="max-w-2xl mx-auto px-6 py-10 space-y-6">
        <h1 className="text-xl font-semibold">{conversation.title}</h1>

        {conversation.messages.map((msg) => (
          <div key={msg.id}>
            {msg.role === 'user' ? (
              /* User bubble */
              <div className="flex justify-end">
                <div
                  className="max-w-md rounded-2xl px-4 py-3 text-sm leading-relaxed"
                  style={{ backgroundColor: 'var(--surface-2)', border: '1px solid var(--border)' }}
                >
                  {msg.content}
                </div>
              </div>
            ) : (
              /* AI answer */
              <div className="space-y-4">
                <div className="flex items-center gap-2 text-sm font-semibold" style={{ color: 'var(--primary)' }}>
                  🤖 Qurani AI
                </div>

                {msg.arabicAnswer && (
                  <div className="space-y-1">
                    <p className="text-xs uppercase tracking-wide font-semibold" style={{ color: 'var(--muted)' }}>الجواب</p>
                    <p className="font-arabic text-lg leading-loose" dir="rtl">{msg.arabicAnswer}</p>
                  </div>
                )}

                {msg.translation && (
                  <div className="space-y-1">
                    <p className="text-xs uppercase tracking-wide font-semibold" style={{ color: 'var(--muted)' }}>Translation</p>
                    <p className="text-sm leading-relaxed" style={{ color: 'var(--muted)' }}>{msg.translation}</p>
                  </div>
                )}

                {msg.citations && msg.citations.length > 0 && (
                  <div className="space-y-3">
                    <p className="text-xs uppercase tracking-wide font-semibold" style={{ color: 'var(--muted)' }}>
                      المصادر · Sources
                    </p>
                    {msg.citations.map((cite, i) => (
                      <div key={i} className="citation-card" style={{
                        borderLeft: `4px solid var(--${cite.type === 'quran' ? 'quran' : cite.type === 'tafsir' ? 'tafsir' : 'hadith'})`,
                      }}>
                        <div
                          className="px-4 py-2 text-xs font-semibold uppercase tracking-wide"
                          style={{
                            backgroundColor: `var(--${cite.type}-bg)`,
                            color: `var(--${cite.type})`,
                          }}
                        >
                          {cite.type === 'quran' && `📖 ${(cite as {surahNameEn:string}).surahNameEn} ${(cite as {surahNo:number}).surahNo}:${(cite as {ayahNo:number}).ayahNo}`}
                          {cite.type === 'tafsir' && `📚 Tafsir`}
                          {cite.type === 'hadith' && `📜 Hadith`}
                        </div>
                        <div className="px-4 py-3 space-y-2">
                          {'arabicText' in cite && (
                            <p className="font-arabic text-base" dir="rtl">
                              {cite.type === 'quran' ? `﴾${cite.arabicText}﴿` : cite.arabicText}
                            </p>
                          )}
                          {'matnAr' in cite && (
                            <p className="font-arabic text-base" dir="rtl">{cite.matnAr}</p>
                          )}
                          {'translation' in cite && (
                            <p className="text-sm" style={{ color: 'var(--muted)' }}>{cite.translation}</p>
                          )}
                          {'matnTranslation' in cite && (
                            <p className="text-sm" style={{ color: 'var(--muted)' }}>{cite.matnTranslation}</p>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
      </main>

      {/* Footer CTA */}
      <footer className="border-t py-10 text-center space-y-4" style={{ borderColor: 'var(--border)', backgroundColor: 'var(--surface-2)' }}>
        <div className="flex items-center justify-center gap-2 text-sm" style={{ color: 'var(--muted)' }}>
          <MessageSquare size={16} />
          Want to ask your own questions grounded in Quran, Tafsir and Hadith?
        </div>
        <Link href="/chat" className="btn btn-primary">
          Try Qurani AI — it&apos;s free →
        </Link>
        <p className="text-xs" style={{ color: 'var(--muted)' }}>
          ⚠️ This is not a fatwa service. Always verify with qualified scholars.
        </p>
      </footer>
    </div>
  );
}
