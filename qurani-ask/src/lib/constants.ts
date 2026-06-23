import type { TafsirBook, HadithBook, SourceSelection } from './types';

// ─── Tafsir Books ─────────────────────────────────────────────────────────────
export const TAFSIR_BOOKS: TafsirBook[] = [
  { id: 'muyassar', nameAr: 'التفسير الميسر', nameEn: 'Al-Tafsir Al-Muyassar' },
  { id: 'jalalayn', nameAr: 'تفسير الجلالين', nameEn: 'Tafsir Al-Jalalayn' },
  { id: 'qurtubi', nameAr: 'تفسير القرطبي', nameEn: 'Tafsir Al-Qurtubi' },
  { id: 'ibnabbas', nameAr: 'تفسير ابن عباس', nameEn: "Tafsir Ibn 'Abbas" },
  { id: 'wasit', nameAr: 'التفسير الوسيط', nameEn: 'Al-Tafsir Al-Wasit' },
  { id: 'baghawi', nameAr: 'تفسير البغوي', nameEn: 'Tafsir Al-Baghawi' },
];

// ─── Hadith Books ─────────────────────────────────────────────────────────────
export const HADITH_BOOKS: HadithBook[] = [
  { id: 'bukhari', nameAr: 'صحيح البخاري', nameEn: 'Sahih Al-Bukhari' },
  { id: 'muslim', nameAr: 'صحيح مسلم', nameEn: 'Sahih Muslim' },
  { id: 'abudawud', nameAr: 'سنن أبي داود', nameEn: 'Sunan Abu Dawud' },
  { id: 'tirmidhi', nameAr: 'سنن الترمذي', nameEn: 'Jami Al-Tirmidhi' },
  { id: 'nasai', nameAr: 'سنن النسائي', nameEn: "Sunan An-Nasa'i" },
  { id: 'ibnmajah', nameAr: 'سنن ابن ماجه', nameEn: 'Sunan Ibn Majah' },
  { id: 'malik', nameAr: 'موطأ مالك', nameEn: 'Muwatta Malik' },
  { id: 'nawawi', nameAr: 'رياض الصالحين', nameEn: 'Riyad As-Salihin' },
  { id: 'qudsi', nameAr: 'الأحاديث القدسية', nameEn: 'Hadith Qudsi' },
  { id: 'dehlawi', nameAr: 'مشكاة المصابيح', nameEn: 'Mishkat Al-Masabih' },
];

// ─── Default source selection (all enabled) ───────────────────────────────────
function buildDefaultTafsirBooks(): Record<string, boolean> {
  return Object.fromEntries(TAFSIR_BOOKS.map((b) => [b.id, true]));
}

function buildDefaultHadithBooks(): Record<string, boolean> {
  return Object.fromEntries(HADITH_BOOKS.map((b) => [b.id, true]));
}

export const DEFAULT_SOURCE_SELECTION: SourceSelection = {
  quran: true,
  tafsir: {
    enabled: true,
    books: buildDefaultTafsirBooks(),
  },
  hadith: {
    enabled: true,
    books: buildDefaultHadithBooks(),
  },
};

// ─── Example questions ─────────────────────────────────────────────────────────
export const EXAMPLE_QUESTIONS: string[] = [
  'What does the Quran say about patience?',
  'What is the ruling on Friday prayer?',
  'Summarize the tafsirs for Ayat al-Kursi',
  'What did the Prophet ﷺ say about honesty?',
  'What does Islam say about treating parents?',
  'What is the Islamic view on seeking knowledge?',
];

// ─── Guest limits ─────────────────────────────────────────────────────────────
export const GUEST_DAILY_LIMIT = 10;
