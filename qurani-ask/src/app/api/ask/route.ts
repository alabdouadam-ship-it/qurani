import { NextRequest, NextResponse } from 'next/server';
import type { Citation } from '@/lib/types';

// ─── Mock response data ───────────────────────────────────────────────────────
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

  const tafsirCitation: Citation = isPatience
    ? {
        type: 'tafsir',
        bookId: 'jalalayn',
        bookNameAr: 'تفسير الجلالين',
        bookNameEn: 'Tafsir Al-Jalalayn',
        surahNo: 2,
        ayahNo: 153,
        arabicText:
          'يا أيها الذين آمنوا استعينوا على أمور دينكم ودنياكم بالصبر على الطاعات وعن المعاصي وعلى المصائب والصلاة، إن الله مع الصابرين بالنصر والمعونة.',
        translation:
          'O you who believe! Seek assistance against the affairs of your religion and worldly life through patience in performing acts of obedience, refraining from sins, and enduring trials; and through prayer. Indeed Allah is with the patient through His support and assistance.',
      }
    : {
        type: 'tafsir',
        bookId: 'jalalayn',
        bookNameAr: 'تفسير الجلالين',
        bookNameEn: 'Tafsir Al-Jalalayn',
        surahNo: 2,
        ayahNo: 286,
        arabicText:
          'لا يكلف الله نفسا إلا وسعها أي طاقتها، فلا يأمرها بما لا تطيق. لها ما كسبت من خير وعليها ما اكتسبت من شر.',
        translation:
          'Allah does not charge a soul except with what it can afford, i.e., its capacity. He does not command it with what it cannot bear. It will have what good it earned and upon it will be what evil it acquired.',
      };

  const hadithCitation: Citation = isPatience
    ? {
        type: 'hadith',
        bookId: 'bukhari',
        bookNameAr: 'صحيح البخاري',
        bookNameEn: 'Sahih Al-Bukhari',
        chapterName: 'Book of Faith',
        hadithNo: 1469,
        matnAr:
          'عَنْ أَبِي سَعِيدٍ الْخُدْرِيِّ رَضِيَ اللَّهُ عَنْهُ قَالَ: قَالَ رَسُولُ اللَّهِ ﷺ: وَمَا أُعْطِيَ أَحَدٌ عَطَاءً خَيْرًا وَأَوْسَعَ مِنَ الصَّبْرِ.',
        matnTranslation:
          "Narrated Abu Sa'id Al-Khudri: The Prophet (ﷺ) said: No one has been given a gift better and more comprehensive than patience.",
        isnad:
          'حَدَّثَنَا مُحَمَّدُ بْنُ بَشَّارٍ حَدَّثَنَا غُنْدَرٌ حَدَّثَنَا شُعْبَةُ عَنْ قَتَادَةَ عَنْ أَنَسٍ رَضِيَ اللَّهُ عَنْهُ',
        grade: 'sahih',
      }
    : {
        type: 'hadith',
        bookId: 'bukhari',
        bookNameAr: 'صحيح البخاري',
        bookNameEn: 'Sahih Al-Bukhari',
        chapterName: 'Book of Belief',
        hadithNo: 8,
        matnAr:
          'عَنِ ابْنِ عُمَرَ رَضِيَ اللَّهُ عَنْهُمَا عَنِ النَّبِيِّ ﷺ قَالَ: بُنِيَ الإِسْلاَمُ عَلَى خَمْسٍ: شَهَادَةِ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ، وَإِقَامِ الصَّلاَةِ، وَإِيتَاءِ الزَّكَاةِ، وَالْحَجِّ، وَصَوْمِ رَمَضَانَ.',
        matnTranslation:
          "Narrated Ibn 'Umar: The Prophet (ﷺ) said: Islam is built on five pillars: testifying that there is no god but Allah and that Muhammad is the Messenger of Allah, performing the prayers, paying the Zakat, making the Hajj pilgrimage, and fasting in Ramadan.",
        isnad:
          'حَدَّثَنَا عُبَيْدُ اللَّهِ بْنُ مُوسَى قَالَ أَخْبَرَنَا حَنْظَلَةُ بْنُ أَبِي سُفْيَانَ عَنْ عِكْرِمَةَ بْنِ خَالِدٍ عَنِ ابْنِ عُمَرَ',
        grade: 'sahih',
      };

  return [quranCitation, tafsirCitation, hadithCitation];
}

// ─── POST handler ─────────────────────────────────────────────────────────────
export async function POST(request: NextRequest) {
  try {
    const body = await request.json() as { query: string };
    const { query = '' } = body;

    const isPatience = /patience|sabr|صبر/i.test(query);
    const arabicAnswer = isPatience ? MOCK_PATIENCE_ARABIC : MOCK_GENERAL_ARABIC;
    const translation = isPatience ? MOCK_PATIENCE_TRANSLATION : MOCK_GENERAL_TRANSLATION;
    const citations = getMockCitations(query);

    // Simulate slight delay for realism
    await new Promise<void>((resolve) => setTimeout(resolve, 300));

    return NextResponse.json({ arabicAnswer, translation, citations });
  } catch (err) {
    console.error('[/api/ask] Error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 },
    );
  }
}
