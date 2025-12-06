// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get settings => 'الإعدادات';

  @override
  String get quraniSettings => 'إعدادات قراني';

  @override
  String get customizeYourExperience => 'خصص تجربتك';

  @override
  String get about => 'حول';

  @override
  String get appInformation => 'معلومات التطبيق';

  @override
  String get help => 'مساعدة';

  @override
  String get getAssistance => 'احصل على المساعدة';

  @override
  String get preferences => 'التفضيلات';

  @override
  String get quranPreferences => 'تفضيلات القرآن';

  @override
  String get shareApp => 'مشاركة التطبيق';

  @override
  String shareAppMessage(Object appUrl) {
    return 'اكتشف تطبيق قرآني الذي يساعدك على التفاعل مع القرآن الكريم: استماع وقراءة وحفظ بالتكرار، مسبحة إلكترونية، تحديد اتجاه القبلة، اختبار الحفظ والمزيد. يدعم التطبيق العربية والإنجليزية والفرنسية ويتيح واجهات بألوان متعددة حسب الرغبة. حمّله الآن من جوجل بلاي: $appUrl';
  }

  @override
  String get tellOthers => 'أخبر الآخرين';

  @override
  String get updateAvailable => 'إصدار جديد من قرآني متوفر';

  @override
  String get updateNow => 'تحديث';

  @override
  String get later => 'لاحقًا';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsConditions => 'الشروط والأحكام';

  @override
  String get supportUs => 'ادعمنا';

  @override
  String get contactUs => 'تواصل معنا';

  @override
  String get supportIntro => 'نعتمد على الاستضافة وخدمات خارجية لضمان استمرار تطبيق قرآني. دعمكم الاختياري يساعدنا على الاستمرار وتطوير التطبيق.';

  @override
  String get donateViaPayPal => 'التبرع عبر باي بال';

  @override
  String get paypalEmail => 'بريد باي بال';

  @override
  String get donateViaCrypto => 'التبرع عبر USDT';

  @override
  String get usdtAddress => 'عنوان USDT';

  @override
  String get watchAd => 'ادعمنا بمشاهدة إعلان (قريبًا)';

  @override
  String get contactViaWhatsApp => 'واتساب';

  @override
  String get contactViaEmail => 'البريد الإلكتروني';

  @override
  String get copy => 'نسخ';

  @override
  String get copied => 'تم النسخ';

  @override
  String get prayerTimes => 'أوقات الصلاة';

  @override
  String get fajr => 'الفجر';

  @override
  String get sunrise => 'الشروق';

  @override
  String get dhuhr => 'الظهر';

  @override
  String get asr => 'العصر';

  @override
  String get maghrib => 'المغرب';

  @override
  String get isha => 'العشاء';

  @override
  String get adhanEnabledMsg => 'سيتم تشغيل الأذان في وقت هذه الصلاة.';

  @override
  String get adhanDisabledMsg => 'لن يتم تشغيل الأذان في وقت هذه الصلاة.';

  @override
  String get stopAdhan => 'إيقاف الأذان';

  @override
  String get adhanStoppedMsg => 'تم إيقاف الأذان';

  @override
  String get adjustTime => 'تصحيح الوقت';

  @override
  String get prayerAdjustmentTooltip => 'معايرة وقت الصلاة';

  @override
  String prayerAdjustmentTitle(Object prayerName) {
    return 'معايرة وقت $prayerName';
  }

  @override
  String get prayerAdjustmentOriginal => 'الوقت الأصلي';

  @override
  String prayerAdjustmentChange(Object value) {
    return 'التعديل: $value';
  }

  @override
  String prayerAdjustmentAfter(Object time) {
    return 'بعد التعديل: $time';
  }

  @override
  String get prayerAdjustmentNoChange => 'لا يوجد تعديل';

  @override
  String get prayerAdjustmentReset => 'إعادة تعيين التعديل';

  @override
  String get plus10Min => '+10 دقائق';

  @override
  String get minus10Min => '-10 دقائق';

  @override
  String get plus1Min => '+1 دقيقة';

  @override
  String get minus1Min => '-1 دقيقة';

  @override
  String get advancedOptions => 'خيارات متقدمة';

  @override
  String get calculationMethod => 'طريقة الحساب';

  @override
  String get methodMWL => 'رابطة العالم الإسلامي';

  @override
  String get methodUmmAlQura => 'أم القرى (مكة)';

  @override
  String get methodEgyptian => 'الهيئة العامة المصرية';

  @override
  String get apiUnavailableUsingLocal => 'الخدمة عبر الإنترنت غير متاحة. سيتم استخدام الحساب المحلي.';

  @override
  String get prayerTimesSettings => 'إعدادات أوقات الصلاة';

  @override
  String get adhanSound => 'صوت الأذان';

  @override
  String get adhanSoundOption1 => 'أذان 1';

  @override
  String get adhanSoundOption2 => 'أذان 2';

  @override
  String get adhanSoundOption3 => 'أذان 3';

  @override
  String get dataProtection => 'حماية البيانات';

  @override
  String get aboutTitle => 'حول قرآني';

  @override
  String get aboutDescription => 'يساعدك تطبيق قرآني على التفاعل مع القرآن الكريم: الاستماع والقراءة والحفظ بالتكرار، مسبحة إلكترونية، تحديد اتجاه القبلة، اختبارات الحفظ، العلامات، الآيات المميزة والمزيد. يدعم التطبيق العربية والإنجليزية والفرنسية مع إمكانية تخصيص الألوان والخطوط.';

  @override
  String appVersionLabel(Object version) {
    return 'الإصدار: $version';
  }

  @override
  String get optionsTitle => 'قرآني';

  @override
  String get quraniFeatures => 'ماذا تريد أن تفعل؟';

  @override
  String get additionalFeaturesAndTools => 'ميزات وأدوات إضافية';

  @override
  String get bookmarks => 'الإشارات المرجعية';

  @override
  String get savedVerses => 'الآيات المحفوظة';

  @override
  String get history => 'السجل';

  @override
  String get recentActivity => 'النشاط الأخير';

  @override
  String get favorites => 'المفضلة';

  @override
  String get likedContent => 'المحتوى المفضل';

  @override
  String get downloads => 'التحميلات';

  @override
  String get offlineContent => 'المحتوى دون اتصال';

  @override
  String get memorizationTest => 'اختبار الحفظ';

  @override
  String get memorizationTestSubtitle => 'اختبر حفظك';

  @override
  String get repetitionMemorization => 'الحفظ بالتكرار';

  @override
  String get searchQuran => 'البحث في القرآن';

  @override
  String get listenQuran => 'استمع إلى القرآن';

  @override
  String get readQuran => 'اقرأ القرآن';

  @override
  String get hadith => 'الحديث';

  @override
  String get tasbeeh => 'المسبحة';

  @override
  String get verses => 'آيات';

  @override
  String get pleaseSelectSurah => 'اختر سورة';

  @override
  String get surahTranslationsNote => 'يتم عرض الأسماء باللغة المختارة';

  @override
  String get searchSurah => 'ابحث عن سورة...';

  @override
  String get repeatSurah => 'تكرار';

  @override
  String get autoAdvance => 'التقدم التلقائي';

  @override
  String get references => 'المراجع';

  @override
  String get quranReferences => 'مراجع القرآن';

  @override
  String get customizeYourReadingPreferences => 'خصص تفضيلات القراءة الخاصة بك';

  @override
  String get quranVersion => 'نسخة القرآن';

  @override
  String get reciter => 'القارئ';

  @override
  String get repetitionReciter => 'قارئ التكرار';

  @override
  String get theme => 'المظهر';

  @override
  String get language => 'اللغة';

  @override
  String get tafsir => 'التفسير';

  @override
  String get savePreferences => 'حفظ التفضيلات';

  @override
  String get preferencesSavedSuccessfully => 'تم حفظ التفضيلات بنجاح!';

  @override
  String get selectQuranVersion => 'اختر نسخة القرآن...';

  @override
  String get selectReciter => 'اختر القارئ...';

  @override
  String get selectRepetitionReciter => 'اختر قارئ التكرار...';

  @override
  String get selectTheme => 'اختر المظهر...';

  @override
  String get selectTafsir => 'اختر التفسير...';

  @override
  String get arabic => 'العربية';

  @override
  String get uthmani => 'عثماني';

  @override
  String get simple => 'بسيط';

  @override
  String get english => 'الإنجليزية';

  @override
  String get french => 'الفرنسية';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get sleepTimer => 'مؤقت النوم';

  @override
  String get sleepTimerEnded => 'انتهى مؤقت النوم';

  @override
  String get minutes => 'دقائق';

  @override
  String minutesShort(int minutes) {
    return '$minutes د';
  }

  @override
  String get off => 'إيقاف';

  @override
  String get buffering => 'جاري التحميل...';

  @override
  String get errorLoadingAudio => 'خطأ في تحميل الصوت';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get bookmark => 'إشارة مرجعية';

  @override
  String get bookmarked => 'تمت الإضافة للإشارات';

  @override
  String get verseByVerse => 'آية بآية';

  @override
  String get autoPlayNext => 'تشغيل تلقائي';

  @override
  String get featureSurah => 'تمييز السورة';

  @override
  String get removeFeatureSurah => 'إزالة تمييز السورة';

  @override
  String get surahFeatured => 'تمت إضافة السورة إلى المفضلة';

  @override
  String get surahUnfeatured => 'تمت إزالة السورة من المفضلة';

  @override
  String get queue => 'قائمة التشغيل';

  @override
  String get addToQueue => 'إضافة إلى القائمة';

  @override
  String get clearQueue => 'مسح القائمة';

  @override
  String get download => 'تحميل';

  @override
  String get downloaded => 'تم التحميل';

  @override
  String get selectReciterFirst => 'يرجى اختيار قارئ أولاً.';

  @override
  String get downloadReciterTitle => 'تحميل الصوت';

  @override
  String get downloadReciterMessage => 'تحميل جميع السور الـ 114 لهذا القارئ للاستماع دون اتصال؟';

  @override
  String get downloadComplete => 'اكتمل التحميل';

  @override
  String get downloadFailed => 'فشل التحميل';

  @override
  String get downloadCurrentSurahTitle => 'تحميل هذه السورة؟';

  @override
  String get downloadCurrentSurahMessage => 'هل تريد تنزيل هذه السورة لتعمل لاحقًا دون اتصال؟';

  @override
  String get downloadingSurah => 'جاري تنزيل السورة...';

  @override
  String get downloadProgressTitle => 'جاري التحميل...';

  @override
  String get surahUnavailable => 'الصوت غير متوفر لهذه السورة. جرب قارئاً آخر.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get go => 'اذهب';

  @override
  String get playPageAudio => 'تشغيل تلاوة الصفحة';

  @override
  String get playSurahAudio => 'تشغيل التلاوة';

  @override
  String get pausePageAudio => 'إيقاف مؤقت لتلاوة الصفحة';

  @override
  String get pauseSurahAudio => 'إيقاف مؤقت للتلاوة';

  @override
  String get stopPlayback => 'إيقاف التشغيل';

  @override
  String get previousAyah => 'الآية السابقة';

  @override
  String get highlightedAyahs => 'الآيات المميزة';

  @override
  String get noHighlightsYet => 'لا توجد آيات مميزة بعد.';

  @override
  String get goToPage => 'انتقل إلى الصفحة';

  @override
  String get pageNumber => 'رقم الصفحة';

  @override
  String get previousPage => 'السابقة';

  @override
  String get nextPage => 'التالية';

  @override
  String get page => 'الصفحة';

  @override
  String get surah => 'السورة';

  @override
  String get tapToChange => 'انقر للتغيير';

  @override
  String get chooseSurah => 'اختر سورة';

  @override
  String get chooseJuz => 'اختر جزء';

  @override
  String get juzLabel => 'جزء';

  @override
  String get search => 'ابحث...';

  @override
  String searchResultsCount(int count) {
    return 'نتائج البحث: $count';
  }

  @override
  String searchResultsDetailed(int occurrences, int ayahs) {
    return '$occurrences نتيجة في $ayahs آية';
  }

  @override
  String get noResultsFound => 'لم يتم العثور على نتائج للبحث.';

  @override
  String get addHighlight => 'تمييز الآية';

  @override
  String get removeHighlight => 'إزالة التمييز';

  @override
  String get showEnglishTranslation => 'عرض الترجمة الإنجليزية';

  @override
  String get showFrenchTranslation => 'عرض الترجمة الفرنسية';

  @override
  String get showArabicText => 'عرض النص العربي';

  @override
  String get showTafsir => 'عرض التفسير';

  @override
  String get translationNotAvailable => 'الترجمة غير متوفرة لهذه الآية.';

  @override
  String get close => 'إغلاق';

  @override
  String get selectLabel => 'اختر';

  @override
  String get selectedLabel => 'تم الاختيار';

  @override
  String get refresh => 'تحديث';

  @override
  String get prayerInternetGpsRequired => 'يلزم الاتصال بالإنترنت وتفعيل GPS لعرض أوقات الصلاة.';

  @override
  String get dayColumn => 'اليوم';

  @override
  String get imsak => 'الإمساك';

  @override
  String get currentVerse => 'الآية الحالية';

  @override
  String get share => 'مشاركة';

  @override
  String get copiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get resumeFromLastPosition => 'استئناف من آخر موضع';

  @override
  String get searchTooShort => 'أدخل حرفين على الأقل';

  @override
  String get unknownError => 'حدث خطأ ما';

  @override
  String get qiblaTitle => 'اتجاه القبلة';

  @override
  String get qiblaRetry => 'إعادة المحاولة';

  @override
  String get qiblaCheckingStatus => 'جاري التحقق من الصلاحيات والمستشعرات...';

  @override
  String get qiblaTurnUntilArrowUp => 'اتجه حتى يشير السهم إلى الأعلى';

  @override
  String get qiblaPermissionRequired => 'يلزم منح صلاحية الموقع لتحديد اتجاه القبلة.';

  @override
  String get qiblaLocationDisabled => 'يرجى تفعيل خدمات الموقع (GPS) للمتابعة.';

  @override
  String get qiblaOpenAppSettings => 'فتح إعدادات التطبيق';

  @override
  String get qiblaOpenLocationSettings => 'فتح إعدادات الموقع';

  @override
  String get qiblaSensorNotSupported => 'هذا الجهاز لا يدعم الحساسات المطلوبة لوضع البوصلة.';

  @override
  String get verseOutsideRange => 'هذه الآية خارج النطاق المحدد.';

  @override
  String qiblaAngleLabel(String angle) {
    return 'زاوية القبلة: $angle°';
  }

  @override
  String get qiblaTipGps => 'فعّل GPS ودقة عالية';

  @override
  String get qiblaTipCalibrate => 'حرّك الهاتف بشكل ∞ للمعايرة';

  @override
  String get qiblaTipInterference => 'أبعد الجهاز عن المعادن/المغناطيس';

  @override
  String get testResultTitle => 'نتيجة الاختبار';

  @override
  String get testCongratsTitle => 'أحسنت!';

  @override
  String correctAnswersLabel(int correct, int total) {
    return 'الإجابات الصحيحة: $correct / $total';
  }

  @override
  String percentageLabel(int percent) {
    return 'النسبة المئوية: $percent%';
  }

  @override
  String earnedScoreLabel(int score) {
    return 'العلامات المكتسبة: $score';
  }

  @override
  String get totalScoreLabel => 'العلامات المتراكمة';

  @override
  String get endLabel => 'إنهاء';

  @override
  String get newTestLabel => 'اختبار جديد';

  @override
  String get previousLabel => 'السابق';

  @override
  String get nextLabel => 'التالي';

  @override
  String get showResultsLabel => 'عرض النتائج';

  @override
  String get confirmAnswerLabel => 'تأكيد الإجابة';

  @override
  String get exitTestTitle => 'إنهاء الاختبار';

  @override
  String get exitTestConfirm => 'هل أنت متأكد أنك تريد إنهاء الاختبار وعرض النتائج؟';

  @override
  String get fontSize => 'حجم الخط';

  @override
  String get small => 'صغير';

  @override
  String get medium => 'متوسط';

  @override
  String get large => 'كبير';

  @override
  String get extraLarge => 'كبير جداً';

  @override
  String get verseRepeatCount => 'عدد تكرار الآية';

  @override
  String get verseRepeatCountHint => 'كرر كل آية هذا العدد من المرات أثناء الحفظ بالتكرار.';

  @override
  String get arabicFont => 'الخط العربي';

  @override
  String get fontAmiri => 'أميري قرآن';

  @override
  String get fontScheherazade => 'شهرزاد الجديدة';

  @override
  String get fontLateef => 'لطيف';

  @override
  String get offlineAudioTitle => 'الصوت دون اتصال';

  @override
  String reciterLabel(String name) {
    return 'القارئ: $name';
  }

  @override
  String verseAudiosDownloaded(int count) {
    return 'تلاوات الآيات المحمّلة: $count (الإجمالي ~6236)';
  }

  @override
  String fullSurahsDownloaded(int count) {
    return 'السور الكاملة المحمّلة: $count / 114';
  }

  @override
  String get downloadWhy => 'لماذا التحميل؟ لتستمع بدون إنترنت.';

  @override
  String downloadingProgress(int current, int total) {
    return 'جاري التنزيل $current / $total';
  }

  @override
  String get downloadVerseAudios => 'تنزيل تلاوات الآيات';

  @override
  String get deleteVerseAudios => 'حذف تلاوات الآيات';

  @override
  String get downloadFullSurahs => 'تنزيل السور الكاملة';

  @override
  String get deleteFullSurahs => 'حذف السور الكاملة';

  @override
  String get fullSurahLabel => 'السور الكاملة';

  @override
  String get downloadFullSurahNote => 'ملاحظة: يمكن تنزيل تلاوة السورة كاملة من شاشة الاستماع للقرآن.';

  @override
  String get name => 'الاسم';

  @override
  String get enterYourName => 'أدخل اسمك';

  @override
  String get timeFormatTitle => 'تنسيق الوقت';

  @override
  String get twelveHour => '‏12 ساعة';

  @override
  String get twentyFourHour => '‏24 ساعة';

  @override
  String get homeGreetingGeneric => 'أهلا، ماذا تريد أن تفعل؟';

  @override
  String homeGreetingNamed(String name) {
    return 'أهلا $name، ماذا تريد أن تفعل؟';
  }

  @override
  String get hijriHeader => 'هجري';

  @override
  String get gregorianHeader => 'ميلادي';

  @override
  String get audioInternetRequired => 'لا يوجد اتصال بالإنترنت. يرجى الاتصال لتشغيل الصوت أو تنزيل الملفات.';

  @override
  String get editionArabicSimple => 'العربية (بسيط)';

  @override
  String get editionArabicUthmani => 'العربية (عثماني)';

  @override
  String get editionArabicTajweed => 'القرآن المجود';

  @override
  String get editionEnglish => 'الإنجليزية';

  @override
  String get editionFrench => 'الفرنسية';

  @override
  String get editionTafsir => 'التفسير (الميسّر)';

  @override
  String get whyContactUs => 'لماذا تتصل بنا؟';

  @override
  String get reportBugTitle => 'الإبلاغ عن الأخطاء و طلب الميزات';

  @override
  String get reportBugDesc => 'أخبرنا عن الأخطاء والمشاكل أو الميزات التي تريد إضافتها في الإصدارات القادمة';

  @override
  String get supportUsTitle => 'ادعم مشروعنا';

  @override
  String get supportUsDesc => 'دعمك يساعد التطبيق على الاستمرار في العمل والعمل لصالح المسلمين حول العالم';

  @override
  String get shareIdeaTitle => 'شارك أفكارك';

  @override
  String get shareIdeaDesc => 'هل لديك فكرة لموقع إلكتروني أو تطبيق جوال أو أي مشروع تقني؟ شاركنا فكرتك، وسنساعدك في تحويلها إلى مشروع حقيقي';

  @override
  String get getInTouch => 'تواصل معنا';
}
