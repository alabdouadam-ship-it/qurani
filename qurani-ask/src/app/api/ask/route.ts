import { NextRequest, NextResponse } from 'next/server';
import type { Citation, SourceSelection } from '@/lib/types';

// This route runs on the Node.js runtime (it calls an external LLM API with a
// server-only secret) and must never be statically cached.
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

// ─── LLM configuration (server-only env; never exposed to the browser) ────────
// Provider-agnostic: any OpenAI-compatible Chat Completions endpoint works
// (OpenAI, Groq, OpenRouter, Together, Azure OpenAI, a local server, …).
//   LLM_API_KEY    – required to enable the real AI. When absent, we fall back
//                    to the built-in mock so the app still runs in demo mode.
//   LLM_BASE_URL   – default https://api.openai.com/v1
//   LLM_MODEL      – default gpt-4o-mini
const LLM_API_KEY = process.env.LLM_API_KEY ?? process.env.OPENAI_API_KEY ?? '';
const LLM_BASE_URL =
  process.env.LLM_BASE_URL ?? process.env.OPENAI_BASE_URL ?? 'https://api.openai.com/v1';
const LLM_MODEL = process.env.LLM_MODEL ?? process.env.OPENAI_MODEL ?? 'gpt-4o-mini';

// Allowed citation book ids (must match src/lib/constants.ts).
const TAFSIR_IDS = ['muyassar', 'jalalayn', 'qurtubi', 'ibnabbas', 'wasit', 'baghawi'];
const HADITH_IDS = [
  'bukhari', 'muslim', 'abudawud', 'tirmidhi', 'nasai',
  'ibnmajah', 'malik', 'nawawi', 'qudsi', 'dehlawi',
];

interface AskBody {
  query?: string;
  sourceSelection?: SourceSelection;
  lang?: 'ar' | 'en' | 'fr';
}

/** Human-readable summary of which sources the user enabled, for the prompt. */
function describeSources(sel?: SourceSelection): string {
  if (!sel) return 'Quran, Tafsir, and Hadith';
  const parts: string[] = [];
  if (sel.quran) parts.push('the Quran');
  if (sel.tafsir?.enabled) {
    const books = Object.entries(sel.tafsir.books)
      .filter(([, on]) => on)
      .map(([id]) => id);
    if (books.length) parts.push(`Tafsir (only these books: ${books.join(', ')})`);
  }
  if (sel.hadith?.enabled) {
    const books = Object.entries(sel.hadith.books)
      .filter(([, on]) => on)
      .map(([id]) => id);
    if (books.length) parts.push(`Hadith (only these collections: ${books.join(', ')})`);
  }
  return parts.length ? parts.join('; ') : 'the Quran';
}

function buildSystemPrompt(sel: SourceSelection | undefined, lang: string): string {
  const translationLang = lang === 'fr' ? 'French' : lang === 'ar' ? 'Arabic' : 'English';
  return `You are "Qurani AI", a knowledgeable and humble assistant that answers questions about Islam, grounded strictly in the Quran, authentic Hadith, and classical Tafsir. You are NOT a mufti and your answer is NOT a fatwa.

ANSWER POLICY
- Answer ONLY from the sources the user enabled: ${describeSources(sel)}.
- Write the main answer (arabicAnswer) in clear, classical-but-accessible Arabic.
- Provide a faithful ${translationLang} translation (translation).
- Be balanced and mention scholarly differences when relevant. Do not issue rulings as if final; encourage consulting qualified scholars for personal rulings.

CITATION POLICY — CRITICAL FOR TRUST
- Provide citations ONLY for texts you are confident are authentic and verbatim-accurate. It is far better to give FEWER or NO citations than to fabricate or misquote.
- NEVER invent a verse, hadith number, isnad, or tafsir passage. If unsure of an exact reference, omit it.
- Quran citations are the most verifiable — prefer them. For Hadith, include the grade and only cite well-known authenticated narrations from the enabled collections.
- Allowed tafsir bookId values: ${TAFSIR_IDS.join(', ')}. Allowed hadith bookId values: ${HADITH_IDS.join(', ')}.

OUTPUT FORMAT — return a SINGLE valid JSON object, no markdown, with this exact shape:
{
  "arabicAnswer": string,
  "translation": string,
  "citations": Citation[]
}
where each Citation is one of:
  { "type":"quran", "surahNo":number, "surahNameAr":string, "surahNameEn":string, "ayahNo":number, "arabicText":string, "translation":string, "revelationType":"meccan"|"medinan" }
  { "type":"tafsir", "bookId":string, "bookNameAr":string, "bookNameEn":string, "surahNo":number, "ayahNo":number, "arabicText":string, "translation":string }
  { "type":"hadith", "bookId":string, "bookNameAr":string, "bookNameEn":string, "chapterName":string, "hadithNo":number, "matnAr":string, "matnTranslation":string, "isnad":string, "grade":"sahih"|"hasan"|"daif"|"unknown" }
Return citations as an array (possibly empty). Output ONLY the JSON object.`;
}

/** Extract a JSON object from a model response that may be wrapped in fences. */
function parseModelJson(content: string): {
  arabicAnswer: string;
  translation: string;
  citations: Citation[];
} | null {
  let text = content.trim();
  // Strip ```json ... ``` fences if present.
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) text = fence[1].trim();
  // Fall back to the outermost braces.
  if (!text.startsWith('{')) {
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start === -1 || end === -1) return null;
    text = text.slice(start, end + 1);
  }
  try {
    const obj = JSON.parse(text);
    return {
      arabicAnswer: typeof obj.arabicAnswer === 'string' ? obj.arabicAnswer : '',
      translation: typeof obj.translation === 'string' ? obj.translation : '',
      citations: Array.isArray(obj.citations) ? (obj.citations as Citation[]) : [],
    };
  } catch {
    return null;
  }
}

async function callLlm(body: AskBody): Promise<{
  arabicAnswer: string;
  translation: string;
  citations: Citation[];
}> {
  const system = buildSystemPrompt(body.sourceSelection, body.lang ?? 'en');
  const res = await fetch(`${LLM_BASE_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${LLM_API_KEY}`,
    },
    body: JSON.stringify({
      model: LLM_MODEL,
      temperature: 0.2,
      // Ask for JSON; providers that don't support this simply ignore it and
      // our parser handles fenced/raw JSON anyway.
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: (body.query ?? '').slice(0, 4000) },
      ],
    }),
  });

  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`LLM ${res.status}: ${detail.slice(0, 300)}`);
  }

  const data = (await res.json()) as {
    choices?: { message?: { content?: string } }[];
  };
  const content = data.choices?.[0]?.message?.content ?? '';
  const parsed = parseModelJson(content);
  if (!parsed || (!parsed.arabicAnswer && !parsed.translation)) {
    throw new Error('LLM returned an unparseable or empty response');
  }
  return parsed;
}

// ─── POST handler ─────────────────────────────────────────────────────────────
export async function POST(request: NextRequest) {
  let body: AskBody = {};
  try {
    body = (await request.json()) as AskBody;
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const query = (body.query ?? '').trim();
  if (!query) {
    return NextResponse.json({ error: 'Empty query' }, { status: 400 });
  }

  // Demo mode: no API key configured → return the built-in mock so the UI works.
  if (!LLM_API_KEY) {
    const mock = buildMockResponse(query);
    return NextResponse.json({ ...mock, mock: true });
  }

  try {
    const answer = await callLlm(body);
    return NextResponse.json(answer);
  } catch (err) {
    console.error('[/api/ask] LLM error:', err);
    // Don't fabricate religious content on failure — return a safe message
    // (no citations) rather than a misleading canned answer.
    return NextResponse.json(
      {
        arabicAnswer: 'تعذّر توليد إجابة في الوقت الحالي. يُرجى المحاولة مرة أخرى.',
        translation:
          'Sorry, an answer could not be generated right now. Please try again in a moment.',
        citations: [],
        error: 'llm_unavailable',
      },
      { status: 200 },
    );
  }
}

// ─── Mock fallback (demo mode only — used when LLM_API_KEY is unset) ──────────
function buildMockResponse(query: string): {
  arabicAnswer: string;
  translation: string;
  citations: Citation[];
} {
  const isPatience = /patience|sabr|صبر/i.test(query);
  const arabicAnswer = isPatience ? MOCK_PATIENCE_ARABIC : MOCK_GENERAL_ARABIC;
  const translation = isPatience ? MOCK_PATIENCE_TRANSLATION : MOCK_GENERAL_TRANSLATION;
  return { arabicAnswer, translation, citations: getMockCitations(query) };
}

const MOCK_PATIENCE_ARABIC = `الصبرُ من أعظم الفضائل في الإسلام، وقد أثنى الله تعالى على الصابرين في مواضع كثيرة من القرآن الكريم. قال تعالى: ﴿يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ إِنَّ اللَّهَ مَعَ الصَّابِرِينَ﴾. فالصبر سلاح المؤمن في مواجهة الشدائد والمحن، وهو مفتاح الفرج والخروج من الضيق إلى السعة.`;
const MOCK_PATIENCE_TRANSLATION = `Patience (Sabr) is one of the greatest virtues in Islam. Allah the Exalted has praised the patient ones in numerous places in the Quran. Allah says: "O you who have believed, seek help through patience and prayer. Indeed, Allah is with the patient." (Al-Baqarah 2:153). Patience is the believer's weapon in facing hardships and tribulations, and it is the key to relief and the transition from hardship to ease.`;
const MOCK_GENERAL_ARABIC = `لا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا. هذا المبدأ القرآني العظيم يُبيّن أنَّ الله تعالى بحكمته ورحمته لا يُلزم عباده بما لا يطيقون، وهذا من تمام عدله وكمال رحمته بعباده.`;
const MOCK_GENERAL_TRANSLATION = `Allah does not burden a soul beyond what it can bear. This great Quranic principle demonstrates that Allah, in His wisdom and mercy, does not obligate His servants beyond their capacity. This is from the perfection of His justice and the completeness of His mercy toward His servants.`;

function getMockCitations(query: string): Citation[] {
  const isPatience = /patience|sabr|صبر/i.test(query);

  const quranCitation: Citation = isPatience
    ? {
        type: 'quran',
        surahNo: 2,
        surahNameAr: 'البقرة',
        surahNameEn: 'Al-Baqarah',
        ayahNo: 153,
        arabicText:
          'يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
        translation:
          'O you who have believed, seek help through patience and prayer. Indeed, Allah is with the patient.',
        revelationType: 'medinan',
      }
    : {
        type: 'quran',
        surahNo: 2,
        surahNameAr: 'البقرة',
        surahNameEn: 'Al-Baqarah',
        ayahNo: 286,
        arabicText:
          'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا ۚ لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ',
        translation:
          'Allah does not burden a soul beyond that it can bear. It will have [the consequence of] what [good] it has gained, and it will bear [the consequence of] what [evil] it has earned.',
        revelationType: 'medinan',
      };

  const tafsirCitation: Citation = {
    type: 'tafsir',
    bookId: 'jalalayn',
    bookNameAr: 'تفسير الجلالين',
    bookNameEn: 'Tafsir Al-Jalalayn',
    surahNo: 2,
    ayahNo: isPatience ? 153 : 286,
    arabicText: isPatience
      ? 'يا أيها الذين آمنوا استعينوا على أمور دينكم ودنياكم بالصبر على الطاعات وعن المعاصي وعلى المصائب والصلاة، إن الله مع الصابرين بالنصر والمعونة.'
      : 'لا يكلف الله نفسا إلا وسعها أي طاقتها، فلا يأمرها بما لا تطيق. لها ما كسبت من خير وعليها ما اكتسبت من شر.',
    translation: isPatience
      ? 'O you who believe! Seek assistance through patience in obedience and prayer. Indeed Allah is with the patient through His support.'
      : 'Allah does not charge a soul except with what it can afford. It will have what good it earned and upon it what evil it acquired.',
  };

  const hadithCitation: Citation = {
    type: 'hadith',
    bookId: 'bukhari',
    bookNameAr: 'صحيح البخاري',
    bookNameEn: 'Sahih Al-Bukhari',
    chapterName: isPatience ? 'Book of Faith' : 'Book of Belief',
    hadithNo: isPatience ? 1469 : 8,
    matnAr: isPatience
      ? 'عَنْ أَبِي سَعِيدٍ الْخُدْرِيِّ رَضِيَ اللَّهُ عَنْهُ قَالَ: قَالَ رَسُولُ اللَّهِ ﷺ: وَمَا أُعْطِيَ أَحَدٌ عَطَاءً خَيْرًا وَأَوْسَعَ مِنَ الصَّبْرِ.'
      : 'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا عَنِ النَّبِيِّ ﷺ قَالَ: بُنِيَ الإِسْلاَمُ عَلَى خَمْسٍ.',
    matnTranslation: isPatience
      ? "The Prophet (ﷺ) said: No one has been given a gift better and more comprehensive than patience."
      : "The Prophet (ﷺ) said: Islam is built on five pillars.",
    grade: 'sahih',
  };

  return [quranCitation, tafsirCitation, hadithCitation];
}
