// ─── Source types ────────────────────────────────────────────────────────────
export type SourceType = 'quran' | 'tafsir' | 'hadith';

export type HadithGrade = 'sahih' | 'hasan' | 'daif' | 'unknown';

// ─── Citations ────────────────────────────────────────────────────────────────
export interface QuranCitation {
  type: 'quran';
  surahNo: number;
  surahNameAr: string;
  surahNameEn: string;
  ayahNo: number;
  arabicText: string;
  translation: string;
  revelationType?: 'meccan' | 'medinan';
}

export interface TafsirCitation {
  type: 'tafsir';
  bookId: string;
  bookNameAr: string;
  bookNameEn: string;
  surahNo: number;
  ayahNo: number;
  arabicText: string;
  translation: string;
}

export interface HadithCitation {
  type: 'hadith';
  bookId: string;
  bookNameAr: string;
  bookNameEn: string;
  chapterName?: string;
  hadithNo: number;
  matnAr: string;
  matnTranslation: string;
  isnad?: string;
  grade: HadithGrade;
}

export type Citation = QuranCitation | TafsirCitation | HadithCitation;

// ─── Messages & Conversations ────────────────────────────────────────────────
export interface AiMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  arabicAnswer?: string;
  translation?: string;
  citations?: Citation[];
  createdAt: Date;
  isStreaming?: boolean;
}

export interface Conversation {
  id: string;
  title: string;
  messages: AiMessage[];
  createdAt: Date;
  updatedAt: Date;
}

// ─── Source selection ─────────────────────────────────────────────────────────
export interface SourceSelection {
  quran: boolean;
  tafsir: {
    enabled: boolean;
    books: Record<string, boolean>;
  };
  hadith: {
    enabled: boolean;
    books: Record<string, boolean>;
  };
}

// ─── Book references ──────────────────────────────────────────────────────────
export interface TafsirBook {
  id: string;
  nameAr: string;
  nameEn: string;
}

export interface HadithBook {
  id: string;
  nameAr: string;
  nameEn: string;
}

// ─── Waqf ─────────────────────────────────────────────────────────────────────
export interface WaqfApplication {
  userId: string;
  reason?: string;
  country?: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: Date;
}

// ─── User profile ─────────────────────────────────────────────────────────────
export interface UserProfile {
  id: string;
  display_name: string | null;
  waqf_sponsored: boolean;
  query_count_today: number;
  query_count_date: string | null;
}
