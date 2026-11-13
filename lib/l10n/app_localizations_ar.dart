// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String passageVerseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get passageStartSurah => 'سورة البداية';

  @override
  String get passageStartVerse => 'آية البداية';

  @override
  String get passageEndSurah => 'سورة النهاية';

  @override
  String get passageEndVerse => 'آية النهاية';

  @override
  String get rememberPassage => 'تذكّر آخر مقطع';

  @override
  String get rememberPassageHint => 'فتح هذا المقطع في المرة القادمة';

  @override
  String get applyPassage => 'تطبيق';

  @override
  String get passageLoadError => 'تعذّر تحميل هذا المقطع';

  @override
  String get settings => 'الإعدادات';

  @override
  String get about => 'حول';

  @override
  String get help => 'مساعدة';

  @override
  String get preferences => 'التفضيلات';

  @override
  String get shareApp => 'مشاركة التطبيق';

  @override
  String shareAppMessage(Object appUrl) {
    return 'اكتشف تطبيق قرآني الذي يساعدك على التفاعل مع القرآن الكريم: استماع وقراءة وحفظ بالتكرار، مسبحة إلكترونية، تحديد اتجاه القبلة، اختبار الحفظ والمزيد. يدعم التطبيق العربية والإنجليزية والفرنسية ويتيح واجهات بألوان متعددة حسب الرغبة. حمّله الآن من جوجل بلاي: $appUrl';
  }

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
  String get copy => 'نسخ';

  @override
  String get copied => 'تم النسخ';

  @override
  String get prayerTimes => 'أوقات الأذان';

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
  String get prayerAdjustmentTooltip => 'معايرة وقت الصلاة';

  @override
  String prayerAdjustmentTitle(Object prayerName) {
    return 'معايرة وقت $prayerName';
  }

  @override
  String get prayerAdjustmentOriginal => 'الوقت الأصلي';

  @override
  String shareSurahMessage(String surahName, String reciterName, String url) {
    return 'استمع إلى $surahName بصوت $reciterName: $url';
  }

  @override
  String get shareAyah => 'مشاركة الآية';

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
  String get prayerMethodSectionTitle => 'طريقة حساب أوقات الصلاة';

  @override
  String get prayerMethodSectionDesc => 'اختر الطريقة المفضلة لديك أو اترك الخيار التلقائي حسب موقعك';

  @override
  String get prayerMethodAuto => 'تلقائي (حسب الموقع)';

  @override
  String get prayerMethodChangedDesc => 'تم تغيير طريقة الحساب، جاري تحديث الأوقات';

  @override
  String get method0 => 'الشيعة الإثنا عشرية - معهد ليفا، قم';

  @override
  String get method1 => 'جامعة العلوم الإسلامية، كراتشي';

  @override
  String get method2 => 'الجمعية الإسلامية لأمريكا الشمالية';

  @override
  String get method3 => 'رابطة العالم الإسلامي';

  @override
  String get method4 => 'جامعة أم القرى، مكة المكرمة';

  @override
  String get method5 => 'الهيئة المصرية العامة للمساحة';

  @override
  String get method7 => 'معهد الجيوفيزياء، جامعة طهران';

  @override
  String get method8 => 'منطقة الخليج';

  @override
  String get method9 => 'الكويت';

  @override
  String get method10 => 'قطر';

  @override
  String get method11 => 'مجلس الشؤون الإسلامية، سنغافورة';

  @override
  String get method12 => 'الاتحاد الإسلامي لفرنسا';

  @override
  String get method13 => 'رئاسة الشؤون الدينية، تركيا';

  @override
  String get method14 => 'الإدارة الروحية لمسلمي روسيا';

  @override
  String get method15 => 'لجنة رؤية الهلال العالمية';

  @override
  String get method16 => 'دبي';

  @override
  String get method17 => 'دائرة التقدم الإسلامي، ماليزيا';

  @override
  String get method18 => 'تونس';

  @override
  String get method19 => 'الجزائر';

  @override
  String get method20 => 'وزارة الشؤون الدينية، إندونيسيا';

  @override
  String get method21 => 'المغرب';

  @override
  String get method22 => 'الجالية الإسلامية في لشبونة';

  @override
  String get method23 => 'وزارة الأوقاف والشؤون الإسلامية، الأردن';

  @override
  String get adhanSound => 'صوت الأذان';

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
  String get bookmarks => 'الإشارات المرجعية';

  @override
  String get history => 'السجل';

  @override
  String get downloads => 'التحميلات';

  @override
  String get memorizationTest => 'اختبار الحفظ';

  @override
  String get repetitionMemorization => 'الحفظ بالتكرار';

  @override
  String get searchQuran => 'البحث في القرآن';

  @override
  String get listenQuran => 'استمع إلى القرآن';

  @override
  String get readQuran => 'اقرأ القرآن';

  @override
  String get hadith => 'حديث';

  @override
  String get tasbeeh => 'المسبحة';

  @override
  String get verses => 'آيات';

  @override
  String get pleaseSelectSurah => 'اختر سورة';

  @override
  String get searchSurah => 'ابحث عن سورة...';

  @override
  String get repeatSurah => 'تكرار';

  @override
  String get reciter => 'القارئ';

  @override
  String get theme => 'المظهر';

  @override
  String get language => 'اللغة';

  @override
  String get tafsir => 'التفسير';

  @override
  String get selectReciter => 'اختر القارئ...';

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
  String get firstAyah => 'الآية الأولى';

  @override
  String get reciterRotationTitle => 'تناوب القرّاء';

  @override
  String get reciterRotationDesc => 'تشغيل كل تكرار للآية بصوت قارئ مختلف بالترتيب، مع العودة إلى الأول عند الانتهاء.';

  @override
  String get reciterRotationAddReciter => 'إضافة قارئ';

  @override
  String get reciterRotationEmpty => 'أضف قرّاءً للتناوب بينهم.';

  @override
  String get reciterRotationRemove => 'إزالة';

  @override
  String reciterRotationPreview(int count, String sequence) {
    return '$count تكرارات ← $sequence';
  }

  @override
  String get shareUsageStatsTitle => 'مشاركة إحصائيات استخدام مجهولة';

  @override
  String get shareUsageStatsSubtitle => 'ساعد في تحسين التطبيق بمشاركة بيانات مجهولة (نوع الجهاز واللغة والمنطقة التقريبية — الدولة والمدينة والميزات المستخدمة). لا يتم جمع أي معلومات شخصية أو موقع دقيق (إحداثيات أو عنوان) أو بيانات حساب. يمكنك إيقاف ذلك في أي وقت.';

  @override
  String get arabicFont => 'الخط العربي';

  @override
  String get fontAmiri => 'أميري قرآن';

  @override
  String get offlineAudioTitle => 'الصوت دون اتصال';

  @override
  String reciterLabel(String name) {
    return 'القارئ: $name';
  }

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
  String get timeFormatTitle => 'تنسيق الوقت';

  @override
  String get twelveHour => '‏12 ساعة';

  @override
  String get twentyFourHour => '‏24 ساعة';

  @override
  String get hijriHeader => 'هجري';

  @override
  String get gregorianHeader => 'ميلادي';

  @override
  String get audioInternetRequired => 'لا يوجد اتصال بالإنترنت. يرجى الاتصال لتشغيل الصوت أو تنزيل الملفات.';

  @override
  String get editionArabicTajweed => 'القرآن المجود';

  @override
  String get readAutoFlip => 'قلب الصفحة تلقائياً';

  @override
  String get readAutoFlipDesc => 'الانتقال للصفحة التالية عند انتهاء التلاوة.';

  @override
  String get chooseReciter => 'اختر القارئ';

  @override
  String get reciterNotCompatible => 'القارئ غير متوافق';

  @override
  String get reciterNotAvailableForFullSurahs => 'الملفات الصوتية للسور الكاملة غير متوفرة لهذا القارئ. يرجى اختيار قارئ آخر.';

  @override
  String reciterNotAvailableForVerses(Object reciterName) {
    return 'الملفات الصوتية (آية بآية) غير متوفرة للقارئ $reciterName. يرجى اختيار قارئ آخر.';
  }

  @override
  String get rangeRepeatCount => 'عدد تكرار النطاق';

  @override
  String get startAtLastPage => 'البدء من آخر صفحة';

  @override
  String get startAtLastPageDesc => 'عند التفعيل، يتم استئناف القراءة من آخر صفحة تم الوصول إليها.';

  @override
  String get alwaysStartFromBeginning => 'ابدأ دائماً من البداية';

  @override
  String get alwaysStartFromBeginningDesc => 'عند التفعيل، يبدأ التشغيل دائماً من أول آية. عند التعطيل، يستأنف من آخر موضع.';

  @override
  String get downloadingMushaf => 'جاري تنزيل المصحف...';

  @override
  String get downloadMushafPdf => 'تنزيل مصحف PDF';

  @override
  String get chooseStyleToDownload => 'اختر نمطًا للتنزيل:';

  @override
  String get returnToTextView => 'العودة للعرض النصي';

  @override
  String get errorLoadingPdf => 'خطأ في تحميل ملف PDF';

  @override
  String get deleteAndRetry => 'حذف وإعادة المحاولة';

  @override
  String get mushafTypeBlue => 'النسخة الزرقاء';

  @override
  String get mushafTypeGreen => 'النسخة الخضراء';

  @override
  String get mushafTypeTajweed => 'النسخة المجودة';

  @override
  String get mushafStyle => 'نوع المصحف';

  @override
  String get allQuran => 'كل القرآن';

  @override
  String get filterBySurah => 'السورة';

  @override
  String get downloadConfirmation => 'تأكيد التحميل';

  @override
  String downloadConfirmationMsg(String mushafName) {
    return 'هل تريد تحميل $mushafName؟';
  }

  @override
  String get downloadFailedReverting => 'فشل التحميل، جاري العودة للنسخة السابقة.';

  @override
  String get bookmarkPage => 'حفظ الصفحة';

  @override
  String get removeBookmark => 'إزالة الحفظ';

  @override
  String get noBookmarks => 'لا توجد إشارات مرجعية بعد';

  @override
  String get colorDefault => 'افتراضي (كريمي)';

  @override
  String get colorRed => 'أحمر';

  @override
  String get colorBlue => 'أزرق';

  @override
  String get colorGreen => 'أخضر';

  @override
  String get groupMyAzkar => 'أذكاري';

  @override
  String get groupMorning => 'أذكار الصباح';

  @override
  String get groupEvening => 'أذكار المساء';

  @override
  String get groupPostPrayerGeneral => 'أذكار ما بعد الصلاة (عامة)';

  @override
  String get groupPostPrayerFajrMaghrib => 'أذكار الفجر والمغرب';

  @override
  String get groupFriday => 'أذكار يوم الجمعة';

  @override
  String get groupSleep => 'أذكار النوم';

  @override
  String get groupWaking => 'أذكار الاستيقاظ';

  @override
  String get createNewGroup => 'إنشاء مجموعة جديدة';

  @override
  String get enterGroupName => 'أدخل اسم المجموعة';

  @override
  String get addGroup => 'إضافة مجموعة';

  @override
  String get deleteGroup => 'حذف المجموعة';

  @override
  String get deleteGroupConfirmation => 'هل أنت متأكد من حذف هذه المجموعة وجميع الأذكار بداخلها؟';

  @override
  String get resetGroup => 'تصفير المجموعة';

  @override
  String get addAzkar => 'إضافة ذكر';

  @override
  String get enterAzkar => 'أدخل نص الذكر';

  @override
  String get resetAll => 'تصفير الكل';

  @override
  String get delete => 'حذف';

  @override
  String get resetGroupConfirmation => 'هل أنت متأكد من تصفير عدادات هذه المجموعة؟';

  @override
  String get bookmarkSaved => 'تم حفظ الإشارة';

  @override
  String get hadithLibrary => 'مكتبة الحديث';

  @override
  String get sahihain => 'الصحيحان';

  @override
  String get sunan => 'السنن';

  @override
  String get others => 'كتب أخرى';

  @override
  String get downloadBook => 'تحميل الكتاب';

  @override
  String get bookNotAvailable => 'هذا الكتاب غير موجود محلياً. هل تريد تحميله؟';

  @override
  String get downloading => 'جاري التحميل...';

  @override
  String get open => 'فتح';

  @override
  String get booksInArabic => 'الكتب بالعربية';

  @override
  String get booksInEnglish => 'الكتب بالإنجليزية';

  @override
  String get booksInFrench => 'الكتب بالفرنسية';

  @override
  String get shareHadithFooter => 'تمت المشاركة من تطبيق قرآني\nhttps://www.qurani.info/';

  @override
  String get loadingBook => 'جاري تحميل محتوى الكتاب...';

  @override
  String get book => 'كتاب';

  @override
  String get grade => 'الدرجة';

  @override
  String get enterHadithNumber => 'أدخل رقم الحديث';

  @override
  String get hadithHiddenOrNotFound => 'الحديث مخفي أو غير موجود';

  @override
  String get noReadableContent => 'لا يوجد محتوى قابل للقراءة في هذا الكتاب.';

  @override
  String get chapterStartNotFound => 'بداية الفصل غير موجودة في الأحاديث الظاهرة';

  @override
  String get generalHadiths => 'أحاديث عامة';

  @override
  String get chapters => 'الفصول';

  @override
  String get allChapters => 'كل الفصول';

  @override
  String get goButton => 'اذهب';

  @override
  String get newsAndNotifications => 'أخبار وإشعارات';

  @override
  String get bookUnavailableMessage => 'يبدو أن الكتاب غير متوفر حاليا، عد لاحقا وسنحرص على توفره ان شاء الله';

  @override
  String get downloadOurApp => 'حمل تطبيقنا';

  @override
  String get googlePlay => 'جوجل بلاي';

  @override
  String get appStore => 'آب ستور';

  @override
  String get searchLanguageArabic => 'النص العربي';

  @override
  String get searchLanguageEnglish => 'النص الإنجليزي';

  @override
  String get searchLanguageFrench => 'النص الفرنسي';

  @override
  String get save => 'حفظ';

  @override
  String get testSettingsTitle => 'إعدادات الاختبار';

  @override
  String get maxQuestionsLabel => 'عدد الأسئلة الأقصى';

  @override
  String get fileSize => 'حجم الملف';

  @override
  String get showMore => 'عرض المزيد';

  @override
  String get showLess => 'عرض أقل';

  @override
  String get noNewsYet => 'لا توجد إشعارات أو أخبار بعد';

  @override
  String get newsTabAll => 'الكل';

  @override
  String get newsTabSaved => 'المحفوظة';

  @override
  String get noSavedNews => 'لا يوجد أخبار محفوظة';

  @override
  String get noNewsAtTheMoment => 'لا يوجد أخبار حالياً';

  @override
  String get newsSource => 'المصدر';

  @override
  String get newItemBadge => 'جديد';

  @override
  String get editionIrab => 'إعراب القرآن';

  @override
  String get irabDataNotAvailable => 'بيانات الإعراب غير متوفرة محلياً. هل تريد تحميلها؟';

  @override
  String get irabDownloading => 'جاري تحميل بيانات الإعراب...';

  @override
  String get irabLoading => 'جاري تحميل بيانات الإعراب...';

  @override
  String get noSurahsAvailable => 'لا توجد سور';

  @override
  String get noQuestionsAvailable => 'لا توجد أسئلة متاحة';

  @override
  String testErrorGeneric(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get startTestButton => 'بدء الاختبار';

  @override
  String get statisticsTitle => 'إحصائيات';

  @override
  String get juzTabarak => 'جزء تبارك';

  @override
  String get juzAmma => 'جزء عم';

  @override
  String deleteAzkarConfirmation(Object text) {
    return 'هل تريد حذف هذا الذكر؟\n$text';
  }

  @override
  String get resetAllConfirmation => 'سيتم تصفير جميع العدادات لجميع المجموعات.';

  @override
  String get noAzkarInGroup => 'لا توجد أذكار في هذه المجموعة. اضغط على القائمة لإضافة ذكر.';

  @override
  String get sessionLabel => 'الجلسة';

  @override
  String get totalLabel => 'الكل';

  @override
  String get resetSessionTooltip => 'تصفير الجلسة';

  @override
  String get memorizationStatsTitle => 'إحصائيات الاختبارات';

  @override
  String get clearStatsTitle => 'حذف الإحصائيات';

  @override
  String get clearStatsConfirmation => 'هل أنت متأكد أنك تريد حذف جميع الإحصائيات؟';

  @override
  String get noStats => 'لا توجد إحصائيات';

  @override
  String get totalScoreHeader => 'العلامات المتراكمة';

  @override
  String get totalTestsLabel => 'عدد الاختبارات';

  @override
  String get surahTab => 'سور';

  @override
  String get juzTab => 'أجزاء';

  @override
  String get surahMasteryHeader => 'نسبة الإتقان لكل سورة';

  @override
  String get recentTestsHeader => 'الاختبارات الأخيرة';

  @override
  String pointsSuffix(int n) {
    return '$n علامة';
  }

  @override
  String get statsNoDataYet => 'لا توجد اختبارات بعد';

  @override
  String get statsMixedSelection => 'اختيار متعدد';

  @override
  String get statsAggLegend => '× اختبارات · % آخر نتيجة';

  @override
  String minutesAgo(int n) {
    return 'منذ $n دقيقة';
  }

  @override
  String hoursAgo(int n) {
    return 'منذ $n ساعة';
  }

  @override
  String daysAgo(int n) {
    return 'منذ $n يوم';
  }

  @override
  String get refreshList => 'تحديث القائمة';

  @override
  String get memorizationTestDescription => 'اختر السور أو الأجزاء وابدأ اختبار حفظك في واجهة أكثر هدوءًا وتنظيمًا.';

  @override
  String get tasbeehDescription => 'أذكارك ومجموعاتك اليومية في واجهة أكثر سكينة ووضوحًا.';

  @override
  String get searchQuranDescription => 'ابحث في القرآن بسرعة مع دعم العربية والإنجليزية والفرنسية ومعاينة صوتية للآية.';

  @override
  String memorizationQNextAyah(Object surahName, Object ayahText) {
    return 'في $surahName\nما هي الآية التي تأتي بعد الآية التالية؟\n$ayahText';
  }

  @override
  String memorizationQCompleteAyah(Object surahName, Object ayahPrefix) {
    return 'في $surahName\nأكمل قوله تعالى:\n$ayahPrefix...';
  }

  @override
  String memorizationQSurahNumber(Object surahName) {
    return 'ما هو رقم $surahName في القرآن الكريم؟';
  }

  @override
  String memorizationQSurahAyahCount(Object surahName) {
    return 'كم عدد آيات $surahName؟';
  }

  @override
  String get surahMasteryHelp => 'الإتقان هو متوسط نسبة إجاباتك الصحيحة عبر جميع اختباراتك لهذه السورة.';

  @override
  String get surahMasteryHelpTooltip => 'ماذا يعني الإتقان؟';

  @override
  String surahNamePrefix(int number) {
    return 'سورة $number';
  }

  @override
  String get surahLongPressHint => 'اضغط مطوّلًا لخيارات أخرى';

  @override
  String get exactAlarmNeededTitle => 'الإنذارات الدقيقة معطّلة';

  @override
  String get exactAlarmNeededBody => 'قد يتأخر الأذان حتى 15 دقيقة. فعّل الإنذارات الدقيقة من الإعدادات للحصول على تشغيل دقيق.';

  @override
  String get openSettingsAction => 'فتح الإعدادات';

  @override
  String get testResultHeadlineExcellent => 'ما شاء الله!';

  @override
  String get testResultSubExcellent => 'إتقان رائع! استمر على هذا المستوى.';

  @override
  String get testResultHeadlineGood => 'أحسنت!';

  @override
  String get testResultSubGood => 'نتيجة ممتازة، بضع مراجعات وستصل للكمال.';

  @override
  String get testResultHeadlineOk => 'جيّد!';

  @override
  String get testResultSubOk => 'تابع المراجعة، التقدم واضح.';

  @override
  String get testResultHeadlineEffort => 'لا بأس!';

  @override
  String get testResultSubEffort => 'المحاولة تصنع الفرق — أعد الاختبار بعد مراجعة الأخطاء.';

  @override
  String get currentTestResult => 'نتيجة الاختبار الحالي';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get resume => 'استئناف';

  @override
  String get downloadPaused => 'تم إيقاف التنزيل مؤقتًا';

  @override
  String integrityVerified(int count, int total) {
    return '$count من $total متحقق منها';
  }

  @override
  String integrityCorrupt(int count) {
    return '$count تالف';
  }

  @override
  String integrityMissing(int count) {
    return '$count ناقص';
  }

  @override
  String get repairCorruptFiles => 'إصلاح';

  @override
  String get repairing => 'جاري الإصلاح…';

  @override
  String repairCompleted(int count) {
    return 'تم إصلاح $count ملف. استأنف التنزيل لإعادة جلبها.';
  }

  @override
  String integrityAllVerified(int total) {
    return 'تم التحقق من جميع السور الـ $total';
  }

  @override
  String errorLoadingBook(String error) {
    return 'تعذّر تحميل الكتاب: $error';
  }

  @override
  String get noChaptersAvailable => 'لا توجد فصول متاحة';

  @override
  String get tasbeehTabLabel => 'المسبحة';

  @override
  String get wirdTabLabel => 'الورد';

  @override
  String get wirdAddTitle => 'إضافة ورد';

  @override
  String get wirdEditTitle => 'تعديل الورد';

  @override
  String get wirdFieldTitle => 'العنوان';

  @override
  String get wirdFieldDhikrText => 'نص الذكر';

  @override
  String get wirdFieldTargetCount => 'العدد المطلوب';

  @override
  String get wirdFieldDaysOfWeek => 'الأيام';

  @override
  String get wirdAllDays => 'كل يوم';

  @override
  String get dayMonday => 'الاثنين';

  @override
  String get dayTuesday => 'الثلاثاء';

  @override
  String get dayWednesday => 'الأربعاء';

  @override
  String get dayThursday => 'الخميس';

  @override
  String get dayFriday => 'الجمعة';

  @override
  String get daySaturday => 'السبت';

  @override
  String get daySunday => 'الأحد';

  @override
  String get wirdRemindMe => 'ذكّرني بهذا الورد';

  @override
  String get wirdReminderTime => 'وقت التذكير';

  @override
  String get wirdDeleteConfirm => 'حذف هذا الورد؟';

  @override
  String get wirdStart => 'ابدأ';

  @override
  String get wirdResume => 'متابعة';

  @override
  String get wirdAllScreenTitle => 'كل الأوراد';

  @override
  String get wirdAllEmptyTitle => 'لم تُنشئ أي ورد بعد';

  @override
  String get wirdFilterToday => 'اليوم';

  @override
  String get wirdFilterAll => 'الكل';

  @override
  String get wirdSendTest => 'إرسال اختبار';

  @override
  String get wirdTestSent => 'تم إرسال إشعار الاختبار. إن لم يظهر، راجع إعدادات الإشعارات للتطبيق في النظام.';

  @override
  String get wirdTestPermissionDenied => 'الإشعارات غير مسموحة لهذا التطبيق. فعّلها من إعدادات النظام.';

  @override
  String get wirdTestFailed => 'تعذّر إرسال إشعار الاختبار. يرجى المحاولة مرة أخرى.';

  @override
  String get wirdExactAlarmDenied => 'التذكيرات مفعّلة لكنها قد تتأخر. لضمان وصولها في الموعد، فعّل \"المنبهات والتذكيرات\" لهذا التطبيق من إعدادات النظام.';

  @override
  String wirdProgressFraction(int current, int target) {
    return '$current / $target';
  }

  @override
  String get wirdCompletedToast => 'ما شاء الله — أتممت الورد!';

  @override
  String get wirdCompletedBadge => 'تم';

  @override
  String get wirdTodayEmptyTitle => 'لا يوجد ورد لهذا اليوم';

  @override
  String get wirdTodayEmptyHint => 'أضف ورداً جديداً بزر +، أو عدّل أيام ورد موجود.';

  @override
  String get wirdSectionTitle => 'ورد اليوم';

  @override
  String get wirdTabSubtitle => 'أذكارك اليومية مع تذكيرات هادئة.';

  @override
  String get wirdValidationTitleRequired => 'الرجاء إدخال عنوان';

  @override
  String get wirdValidationDaysRequired => 'اختر يوماً واحداً على الأقل';

  @override
  String get wirdValidationTargetInvalid => 'العدد يجب أن يكون بين 1 و 9999';

  @override
  String get wirdExitFocus => 'إنهاء الجلسة';

  @override
  String get wirdFocusHintTap => 'اضغط في أي مكان للعدّ';

  @override
  String get wirdResetProgress => 'إعادة تصفير اليوم';

  @override
  String get hadithSearchHint => 'أدخل نصاً للبحث أو اختر فصلاً';

  @override
  String get hadithNoMatches => 'لا توجد نتائج مطابقة';

  @override
  String get editionTitle => 'النسخة';

  @override
  String get editionTranslationsCategory => 'الترجمات';

  @override
  String get editionTafsirCategory => 'التفسير';

  @override
  String get editionTurkish => 'التركية';

  @override
  String get editionGerman => 'الألمانية';

  @override
  String get secondaryEditionTitle => 'النسخة الثانوية';

  @override
  String get secondaryEditionDesc => 'إضافة سهم لكل آية يفتح نسخة ثانية.';

  @override
  String get secondaryEditionChoose => 'اختيار النسخة';

  @override
  String get secondaryEditionFallback => 'النسخة البديلة';

  @override
  String get secondaryEditionFallbackDesc => 'تُستخدم عندما تكون النسخة الثانوية هي النسخة التي تقرأها';

  @override
  String get secondaryEditionShow => 'إظهار النسخة الثانوية';

  @override
  String get secondaryEditionHide => 'إخفاء النسخة الثانوية';

  @override
  String get memorizationIncompleteData => 'تعذر تحميل المقطع بالكامل. تحقق من اتصالك وأعد المحاولة.';

  @override
  String downloadIncomplete(int completed, int total, int failed) {
    return 'التنزيل غير مكتمل: تم التحقق من $completed/$total ملفًا؛ تعذر تنزيل $failed. أعد المحاولة لتنزيل الملفات الناقصة.';
  }

  @override
  String get downloadCancelled => 'تم إلغاء التنزيل. تم الاحتفاظ بالملفات المكتملة.';

  @override
  String get aboutWebDescription => 'يوفر قرآني على الويب قراءة القرآن والاستماع عبر الإنترنت والبحث والحفظ بالتكرار والاختبارات ومواقيت الصلاة والعلامات المرجعية بالعربية والإنجليزية والفرنسية. يتوفر الأذان في الخلفية والقبلة والتسبيح وتذكيرات الورد وتنزيل الصوت دون اتصال في تطبيق الهاتف.';

  @override
  String get backupTitle => 'النسخ الاحتياطي والاستعادة';

  @override
  String get backupDescription => 'صدّر العلامات والإعدادات والإحصاءات والمراجعات والتسبيح والورد. لا تشمل النسخة الملفات الصوتية أو أذونات الهاتف.';

  @override
  String get backupExport => 'تصدير نسخة احتياطية';

  @override
  String get backupImport => 'اختيار ملف للاستعادة';

  @override
  String backupConfirm(String date, int count) {
    return 'تحتوي هذه النسخة المؤرخة في $date على $count عنصرًا. ستستبدل العلامات والإعدادات والتقدم المحفوظ على هذا الجهاز. هل تريد المتابعة؟';
  }

  @override
  String get backupRestore => 'استعادة';

  @override
  String get backupDone => 'تمت استعادة النسخة الاحتياطية.';

  @override
  String get backupInvalid => 'الملف غير صالح أو غير متوافق. لم يتم استيراد أي بيانات.';

  @override
  String get backupFailed => 'تعذرت العملية. أعد المحاولة.';

  @override
  String get backupScheduleWarning => 'تمت استعادة البيانات. تحقق من المواقيت والأذونات في تشخيص الأذان.';

  @override
  String get adhanDiagnosticTitle => 'تشخيص الأذان';

  @override
  String get adhanNextExpected => 'الأذان القادم المتوقع';

  @override
  String get adhanNoNext => 'لا يتوفر موعد قادم للصلوات المفعلة.';

  @override
  String get adhanDiagnosticNote => 'يعتمد الموعد المتوقع على المواقيت المحفوظة وإعداداتك. قد يقيّد النظام التنبيهات في الخلفية. يختبر الصوت التشغيل الفوري فقط.';

  @override
  String get diagnosticNotifications => 'إذن الإشعارات';

  @override
  String get diagnosticSound => 'صوت إشعارات آيفون';

  @override
  String get diagnosticExact => 'منبهات أندرويد الدقيقة';

  @override
  String get diagnosticBattery => 'الإعفاء من تحسين البطارية';

  @override
  String get diagnosticLocation => 'إذن الموقع';

  @override
  String get diagnosticLocationService => 'خدمات الموقع مفعلة';

  @override
  String get diagnosticCalendar => 'تتوفر مواقيت متوافقة';

  @override
  String get diagnosticPending => 'إشعار آيفون مجدول';

  @override
  String diagnosticEnabled(int count) {
    return 'الصلوات المفعلة: $count';
  }

  @override
  String diagnosticVolume(int percent) {
    return 'مستوى صوت الأذان: $percent٪';
  }

  @override
  String get diagnosticYes => 'نعم';

  @override
  String get diagnosticNo => 'لا';

  @override
  String get diagnosticUnknown => 'غير متاح';

  @override
  String get diagnosticSettings => 'فتح إعدادات الجهاز';

  @override
  String get diagnosticTest => 'اختبار الصوت';

  @override
  String get diagnosticStop => 'إيقاف الاختبار';

  @override
  String get diagnosticRefresh => 'تحديث';

  @override
  String get downloadIssuesTitle => 'تنزيلات للاستئناف';

  @override
  String get downloadIssuesEmpty => 'لا توجد تنزيلات فاشلة أو منقطعة.';

  @override
  String get downloadRetryAll => 'استئناف جميع العناصر';

  @override
  String get downloadRetry => 'استئناف';

  @override
  String get downloadIssueFailed => 'فشل';

  @override
  String get downloadIssueCancelled => 'ملغى';

  @override
  String get downloadIssueInterrupted => 'منقطع';

  @override
  String get downloadIssueActive => 'جارٍ التنزيل';

  @override
  String downloadIssueAttempts(int count) {
    return 'المحاولات: $count';
  }

  @override
  String get downloadReasonNetwork => 'الاتصال غير متاح أو انتهت المهلة';

  @override
  String get downloadReasonServer => 'لم يوفر الخادم الملف';

  @override
  String get downloadReasonFile => 'الملف غير متاح أو غير صالح أو تعذر حفظه';

  @override
  String get reviewTitle => 'المراجعة المتباعدة';

  @override
  String get reviewDescription => 'أضف المقاطع المحفوظة وراجعها، ثم قيّم تذكرك لتحديد موعد المراجعة القادمة.';

  @override
  String get reviewAdd => 'إضافة مقطع';

  @override
  String get reviewAddCurrent => 'إضافة هذا المقطع للمراجعات';

  @override
  String get reviewAdded => 'تمت إضافة المقطع للمراجعات.';

  @override
  String get reviewEmpty => 'لم تضف مقاطع للمراجعة بعد.';

  @override
  String get reviewDue => 'حان وقت المراجعة';

  @override
  String reviewNext(String date) {
    return 'المراجعة القادمة: $date';
  }

  @override
  String get reviewOpen => 'فتح المقطع';

  @override
  String get reviewRate => 'تقييم مراجعتي';

  @override
  String get reviewAgain => 'إعادة';

  @override
  String get reviewHard => 'صعب';

  @override
  String get reviewGood => 'جيد';

  @override
  String get reviewEasy => 'سهل';

  @override
  String get reviewRemove => 'هل تريد إزالة هذا المقطع من المراجعات؟';

  @override
  String reviewPassage(int startSurah, int startVerse, int endSurah, int endVerse) {
    return 'سورة $startSurah، آية $startVerse ← سورة $endSurah، آية $endVerse';
  }

  @override
  String get downloadBatchLabel => 'تنزيل كامل';
}
