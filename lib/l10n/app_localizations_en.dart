// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get quraniSettings => 'Qurani Settings';

  @override
  String get customizeYourExperience => 'Customize your experience';

  @override
  String get about => 'About';

  @override
  String get appInformation => 'App information';

  @override
  String get help => 'Help';

  @override
  String get getAssistance => 'Get assistance';

  @override
  String get preferences => 'Preferences';

  @override
  String get quranPreferences => 'Quran preferences';

  @override
  String get shareApp => 'Share App';

  @override
  String shareAppMessage(Object appUrl) {
    return 'Discover Qurani, the app that helps you engage with the Holy Quran: listening, reading, repetition-based memorization, digital tasbeeh, Qibla direction, memorization tests, and more. The app supports Arabic, English and French, with multiple color themes. Get it on Google Play: $appUrl';
  }

  @override
  String get tellOthers => 'Tell others';

  @override
  String get updateAvailable => 'A new version of Qurani is available';

  @override
  String get updateNow => 'Update';

  @override
  String get later => 'Later';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsConditions => 'Terms & Conditions';

  @override
  String get supportUs => 'Support us';

  @override
  String get contactUs => 'Contact us';

  @override
  String get supportIntro => 'We rely on hosting and third‑party services to keep Qurani running. Your optional support helps sustain and improve the app.';

  @override
  String get donateViaPayPal => 'Donate via PayPal';

  @override
  String get paypalEmail => 'PayPal email';

  @override
  String get donateViaCrypto => 'Donate via USDT';

  @override
  String get usdtAddress => 'USDT address';

  @override
  String get watchAd => 'Support by watching an ad (coming soon)';

  @override
  String get contactViaWhatsApp => 'WhatsApp';

  @override
  String get contactViaEmail => 'Email';

  @override
  String get contactViaWhatsAppGroup => 'WhatsApp Group';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get prayerTimes => 'Prayer Times';

  @override
  String get fajr => 'Fajr';

  @override
  String get sunrise => 'Sunrise';

  @override
  String get dhuhr => 'Dhuhr';

  @override
  String get asr => 'Asr';

  @override
  String get maghrib => 'Maghrib';

  @override
  String get isha => 'Isha';

  @override
  String get adhanEnabledMsg => 'Adhan will play at this prayer time.';

  @override
  String get adhanDisabledMsg => 'Adhan will not play at this prayer time.';

  @override
  String get stopAdhan => 'Stop Adhan';

  @override
  String get adhanStoppedMsg => 'Adhan stopped';

  @override
  String get adjustTime => 'Adjust time';

  @override
  String get prayerAdjustmentTooltip => 'Adjust prayer time';

  @override
  String prayerAdjustmentTitle(Object prayerName) {
    return 'Adjust $prayerName time';
  }

  @override
  String get prayerAdjustmentOriginal => 'Original time';

  @override
  String shareSurahMessage(String surahName, String reciterName, String url) {
    return 'Listen to $surahName by $reciterName: $url';
  }

  @override
  String get shareAyah => 'Share Ayah';

  @override
  String get shareAudio => 'Share Audio Link';

  @override
  String get shareText => 'Share Text';

  @override
  String get shareImage => 'Share Image';

  @override
  String prayerAdjustmentChange(Object value) {
    return 'Adjustment: $value';
  }

  @override
  String prayerAdjustmentAfter(Object time) {
    return 'After adjustment: $time';
  }

  @override
  String get prayerAdjustmentNoChange => 'No adjustment';

  @override
  String get prayerAdjustmentReset => 'Reset adjustment';

  @override
  String get plus10Min => '+10 min';

  @override
  String get minus10Min => '-10 min';

  @override
  String get plus1Min => '+1 min';

  @override
  String get minus1Min => '-1 min';

  @override
  String get advancedOptions => 'Advanced options';

  @override
  String get calculationMethod => 'Calculation method';

  @override
  String get methodMWL => 'Muslim World League';

  @override
  String get methodUmmAlQura => 'Umm Al-Qura (Makkah)';

  @override
  String get methodEgyptian => 'Egyptian General Authority';

  @override
  String get apiUnavailableUsingLocal => 'Online service unavailable. Using local calculation.';

  @override
  String get prayerMethodSectionTitle => 'Prayer Time Calculation Method';

  @override
  String get prayerMethodSectionDesc => 'Choose your preferred method or leave it automatic based on your location';

  @override
  String get prayerMethodAuto => 'Automatic (based on location)';

  @override
  String get prayerMethodChanged => 'Updating prayer times...';

  @override
  String get prayerMethodChangedDesc => 'Calculation method changed, updating times';

  @override
  String get method0 => 'Shia Ithna-Ashari, Leva Institute, Qum';

  @override
  String get method1 => 'University of Islamic Sciences, Karachi';

  @override
  String get method2 => 'Islamic Society of North America (ISNA)';

  @override
  String get method3 => 'Muslim World League';

  @override
  String get method4 => 'Umm Al-Qura University, Makkah';

  @override
  String get method5 => 'Egyptian General Authority of Survey';

  @override
  String get method7 => 'Institute of Geophysics, University of Tehran';

  @override
  String get method8 => 'Gulf Region';

  @override
  String get method9 => 'Kuwait';

  @override
  String get method10 => 'Qatar';

  @override
  String get method11 => 'Majlis Ugama Islam Singapura, Singapore';

  @override
  String get method12 => 'Union Organization Islamic de France';

  @override
  String get method13 => 'Diyanet İşleri Başkanlığı, Turkey';

  @override
  String get method14 => 'Spiritual Administration of Muslims of Russia';

  @override
  String get method15 => 'Moonsighting Committee Worldwide';

  @override
  String get method16 => 'Dubai';

  @override
  String get method17 => 'Jabatan Kemajuan Islam Malaysia (JAKIM)';

  @override
  String get method18 => 'Tunisia';

  @override
  String get method19 => 'Algeria';

  @override
  String get method20 => 'Kementerian Agama Republik Indonesia';

  @override
  String get method21 => 'Morocco';

  @override
  String get method22 => 'Comunidade Islamica de Lisboa';

  @override
  String get method23 => 'Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan';

  @override
  String get prayerTimesSettings => 'Prayer times settings';

  @override
  String get adhanSound => 'Adhan sound';

  @override
  String get adhanSoundOption1 => 'Adhan 1';

  @override
  String get adhanSoundOption2 => 'Adhan 2';

  @override
  String get adhanSoundOption3 => 'Adhan 3';

  @override
  String get dataProtection => 'Data protection';

  @override
  String get aboutTitle => 'About Qurani';

  @override
  String get aboutDescription => 'Qurani helps you engage with the Holy Quran: listening, reading, repetition-based memorization, digital tasbeeh, Qibla direction, memorization tests, bookmarks, featured verses, and more. Supports Arabic, English, and French, with customizable themes and fonts.';

  @override
  String appVersionLabel(Object version) {
    return 'Version: $version';
  }

  @override
  String get optionsTitle => 'My Quran';

  @override
  String get quraniFeatures => 'What do you want to do?';

  @override
  String get additionalFeaturesAndTools => 'Additional features and tools';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get savedVerses => 'Saved verses';

  @override
  String get history => 'History';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get favorites => 'Favorites';

  @override
  String get likedContent => 'Liked content';

  @override
  String get downloads => 'Downloads';

  @override
  String get offlineContent => 'Offline content';

  @override
  String get memorizationTest => 'Memorization Test';

  @override
  String get memorizationTestSubtitle => 'Test your memorization';

  @override
  String get repetitionMemorization => 'Repetition Memorization';

  @override
  String get searchQuran => 'Search in quran';

  @override
  String get listenQuran => 'Listen to Quran';

  @override
  String get readQuran => 'Read the Quran';

  @override
  String get hadith => 'Hadith';

  @override
  String get tasbeeh => 'Tasbeeh';

  @override
  String get verses => 'verses';

  @override
  String get pleaseSelectSurah => 'Select a surah';

  @override
  String get surahTranslationsNote => 'Names are shown in your selected language';

  @override
  String get searchSurah => 'Search surah...';

  @override
  String get repeatSurah => 'Repeat';

  @override
  String get autoAdvance => 'Auto-advance';

  @override
  String get references => 'References';

  @override
  String get quranReferences => 'Quran References';

  @override
  String get customizeYourReadingPreferences => 'Customize your reading preferences';

  @override
  String get quranVersion => 'Quran Version';

  @override
  String get reciter => 'Reciter';

  @override
  String get repetitionReciter => 'Repetition Reciter';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get tafsir => 'Tafsir';

  @override
  String get savePreferences => 'Save Preferences';

  @override
  String get preferencesSavedSuccessfully => 'Preferences saved successfully!';

  @override
  String get selectQuranVersion => 'Select Quran Version...';

  @override
  String get selectReciter => 'Select Reciter...';

  @override
  String get selectRepetitionReciter => 'Select Repetition Reciter...';

  @override
  String get selectTheme => 'Select Theme...';

  @override
  String get selectTafsir => 'Select Tafsir...';

  @override
  String get arabic => 'Arabic';

  @override
  String get uthmani => 'Uthmani';

  @override
  String get simple => 'Simple';

  @override
  String get english => 'English';

  @override
  String get french => 'French';

  @override
  String get playbackSpeed => 'Playback Speed';

  @override
  String get sleepTimer => 'Sleep Timer';

  @override
  String get sleepTimerEnded => 'Sleep timer ended';

  @override
  String get minutes => 'minutes';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get off => 'Off';

  @override
  String get buffering => 'Buffering...';

  @override
  String get errorLoadingAudio => 'Error loading audio';

  @override
  String get retry => 'Retry';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get bookmarked => 'Bookmarked';

  @override
  String get verseByVerse => 'Verse by Verse';

  @override
  String get autoPlayNext => 'Auto Play';

  @override
  String get featureSurah => 'Favorite';

  @override
  String get removeFeatureSurah => 'Remove from favorites';

  @override
  String get surahFeatured => 'Surah added to favorites';

  @override
  String get surahUnfeatured => 'Surah removed from favorites';

  @override
  String get queue => 'Playlist';

  @override
  String get addToQueue => 'Add to Queue';

  @override
  String get clearQueue => 'Clear Queue';

  @override
  String get download => 'Download';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get selectReciterFirst => 'Please select a reciter first.';

  @override
  String get downloadReciterTitle => 'Download audio';

  @override
  String get downloadReciterMessage => 'Download all 114 surahs for this reciter for offline listening?';

  @override
  String get downloadComplete => 'Download complete';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadCurrentSurahTitle => 'Download this surah?';

  @override
  String get downloadCurrentSurahMessage => 'Download the current surah for offline listening?';

  @override
  String get downloadingSurah => 'Downloading surah...';

  @override
  String get downloadProgressTitle => 'Downloading...';

  @override
  String get surahUnavailable => 'Audio not available for this surah. Try another reciter.';

  @override
  String get cancel => 'Cancel';

  @override
  String get go => 'Go';

  @override
  String get playPageAudio => 'Play page audio';

  @override
  String get playSurahAudio => 'Play audio';

  @override
  String get pausePageAudio => 'Pause page audio';

  @override
  String get pauseSurahAudio => 'Pause audio';

  @override
  String get stopPlayback => 'Stop playback';

  @override
  String get previousAyah => 'Previous verse';

  @override
  String get highlightedAyahs => 'Highlighted verses';

  @override
  String get noHighlightsYet => 'You have not highlighted any verses yet.';

  @override
  String get goToPage => 'Go to page';

  @override
  String get pageNumber => 'Page Number';

  @override
  String get previousPage => 'Previous';

  @override
  String get nextPage => 'Next';

  @override
  String get page => 'Page';

  @override
  String get surah => 'Surah';

  @override
  String get tapToChange => 'Tap to change';

  @override
  String get chooseSurah => 'Choose a surah';

  @override
  String get chooseJuz => 'Choose a juz';

  @override
  String get juzLabel => 'Juz';

  @override
  String get search => 'Search...';

  @override
  String searchResultsCount(int count) {
    return 'Search results: $count';
  }

  @override
  String searchResultsDetailed(int occurrences, int ayahs) {
    return '$occurrences results in $ayahs ayahs';
  }

  @override
  String get noResultsFound => 'No results found for your query.';

  @override
  String get addHighlight => 'Highlight verse';

  @override
  String get removeHighlight => 'Remove highlight';

  @override
  String get showEnglishTranslation => 'Show English translation';

  @override
  String get showFrenchTranslation => 'Show French translation';

  @override
  String get showArabicText => 'Show Arabic text';

  @override
  String get showTafsir => 'Show tafsir';

  @override
  String get translationNotAvailable => 'Translation not available for this verse.';

  @override
  String get close => 'Close';

  @override
  String get selectLabel => 'Choose';

  @override
  String get selectedLabel => 'Selected';

  @override
  String get refresh => 'Refresh';

  @override
  String get prayerInternetGpsRequired => 'Internet and GPS are required to show prayer times.';

  @override
  String get dayColumn => 'Day';

  @override
  String get imsak => 'Imsak';

  @override
  String get currentVerse => 'Current Verse';

  @override
  String get share => 'Share';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get resumeFromLastPosition => 'Resume from last position';

  @override
  String get searchTooShort => 'Enter at least 2 characters';

  @override
  String get unknownError => 'An error occurred';

  @override
  String get qiblaTitle => 'Qibla Direction';

  @override
  String get qiblaRetry => 'Retry';

  @override
  String get qiblaCheckingStatus => 'Checking permissions and sensors...';

  @override
  String get qiblaTurnUntilArrowUp => 'Turn until the arrow points up';

  @override
  String get qiblaPermissionRequired => 'Location permission is required to determine the Qibla.';

  @override
  String get qiblaLocationDisabled => 'Please enable location services (GPS) to continue.';

  @override
  String get qiblaOpenAppSettings => 'Open App Settings';

  @override
  String get qiblaOpenLocationSettings => 'Open Location Settings';

  @override
  String get qiblaSensorNotSupported => 'This device does not support the required sensors for compass mode.';

  @override
  String get verseOutsideRange => 'This verse is outside the selected range.';

  @override
  String qiblaAngleLabel(String angle) {
    return 'Qibla angle: $angle°';
  }

  @override
  String get qiblaTipGps => 'Enable GPS and High Accuracy';

  @override
  String get qiblaTipCalibrate => 'Calibrate: move phone ∞';

  @override
  String get qiblaTipInterference => 'Avoid metal/magnetic interference';

  @override
  String get testResultTitle => 'Test Result';

  @override
  String get testCongratsTitle => 'Well done!';

  @override
  String correctAnswersLabel(int correct, int total) {
    return 'Correct answers: $correct / $total';
  }

  @override
  String percentageLabel(int percent) {
    return 'Percentage: $percent%';
  }

  @override
  String earnedScoreLabel(int score) {
    return 'Earned score: $score';
  }

  @override
  String get totalScoreLabel => 'Total score';

  @override
  String get endLabel => 'Finish';

  @override
  String get newTestLabel => 'New test';

  @override
  String get previousLabel => 'Previous';

  @override
  String get nextLabel => 'Next';

  @override
  String get showResultsLabel => 'Show results';

  @override
  String get confirmAnswerLabel => 'Confirm answer';

  @override
  String get exitTestTitle => 'End test';

  @override
  String get exitTestConfirm => 'Are you sure you want to end the test and show results?';

  @override
  String get fontSize => 'Font size';

  @override
  String get small => 'Small';

  @override
  String get medium => 'Medium';

  @override
  String get large => 'Large';

  @override
  String get extraLarge => 'Extra Large';

  @override
  String get verseRepeatCount => 'Verse repeat count';

  @override
  String get verseRepeatCountHint => 'Repeat each verse this many times during repetition memorization.';

  @override
  String get arabicFont => 'Arabic font';

  @override
  String get fontAmiri => 'Amiri Quran';

  @override
  String get fontScheherazade => 'Scheherazade New';

  @override
  String get fontLateef => 'Lateef';

  @override
  String get offlineAudioTitle => 'Offline audio';

  @override
  String reciterLabel(String name) {
    return 'Reciter: $name';
  }

  @override
  String verseAudiosDownloaded(int count) {
    return 'Verse audios downloaded: $count (total ~6236)';
  }

  @override
  String fullSurahsDownloaded(int count) {
    return 'Full surahs downloaded: $count / 114';
  }

  @override
  String get downloadWhy => 'Why download? You can listen without internet.';

  @override
  String downloadingProgress(int current, int total) {
    return 'Downloading $current / $total';
  }

  @override
  String get downloadVerseAudios => 'Download verse audios';

  @override
  String get deleteVerseAudios => 'Delete verse audios';

  @override
  String get downloadFullSurahs => 'Download full surahs';

  @override
  String get deleteFullSurahs => 'Delete full surahs';

  @override
  String get fullSurahLabel => 'Full surahs';

  @override
  String get downloadFullSurahNote => 'Note: Full surah audio can be downloaded from Listen to Quran screen.';

  @override
  String get name => 'Name';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get timeFormatTitle => 'Time format';

  @override
  String get twelveHour => '12h';

  @override
  String get twentyFourHour => '24h';

  @override
  String get homeGreetingGeneric => 'Welcome to Qurani App';

  @override
  String homeGreetingNamed(String userName) {
    return 'Welcome $userName to Qurani App';
  }

  @override
  String get hijriHeader => 'Hijri';

  @override
  String get gregorianHeader => 'Gregorian';

  @override
  String get audioInternetRequired => 'No internet connection. Please connect to play audio or download offline files.';

  @override
  String get editionArabicSimple => 'Arabic (Simple)';

  @override
  String get editionArabicUthmani => 'Arabic (Uthmani)';

  @override
  String get editionArabicTajweed => 'Quran Tajweed';

  @override
  String get editionEnglish => 'English';

  @override
  String get editionFrench => 'French';

  @override
  String get editionTafsir => 'Tafsir (Muyassar)';

  @override
  String get whyContactUs => 'Why contact us?';

  @override
  String get reportBugTitle => 'Report bugs & request features';

  @override
  String get reportBugDesc => 'Tell us about bugs, problems, or features you\'d like us to add in future versions';

  @override
  String get supportUsTitle => 'Support our project';

  @override
  String get supportUsDesc => 'Your support helps the application continue to work and benefit the Muslim community worldwide';

  @override
  String get shareIdeaTitle => 'Share your ideas';

  @override
  String get shareIdeaDesc => 'Do you have an idea for a website, mobile app, or any tech project? Share your idea with us, and we will help you turn it into a real project.';

  @override
  String get getInTouch => 'Get in touch';

  @override
  String get readAutoFlip => 'Auto flip page';

  @override
  String get readAutoFlipDesc => 'Automatically turn the page when audio ends.';

  @override
  String get chooseReciter => 'Choose reciter';

  @override
  String get chooseReciterDesc => 'Select your preferred reciter.';

  @override
  String get reciterNotCompatible => 'Reciter not compatible';

  @override
  String get reciterNotAvailableForFullSurahs => 'Full surah audio files are not available for this reciter. Please choose another reciter.';

  @override
  String reciterNotAvailableForVerses(Object reciterName) {
    return 'Verse-by-verse audio files are not available for reciter $reciterName. Please choose another reciter.';
  }

  @override
  String get rangeRepeatCount => 'Range repeat count';

  @override
  String get startAtLastPage => 'Start at last page';

  @override
  String get startAtLastPageDesc => 'If enabled, resume reading from the last page you visited.';

  @override
  String get alwaysStartFromBeginning => 'Always Start from Beginning';

  @override
  String get alwaysStartFromBeginningDesc => 'When enabled, always start playing from the first verse. When disabled, resume from last position.';

  @override
  String get downloadingMushaf => 'Downloading Mushaf...';

  @override
  String get downloadMushafPdf => 'Download Mushaf PDF';

  @override
  String get chooseStyleToDownload => 'Choose a style to download:';

  @override
  String get returnToTextView => 'Return to Text View';

  @override
  String get errorLoadingPdf => 'Error loading PDF file';

  @override
  String get deleteAndRetry => 'Delete and Retry';

  @override
  String get mushafTypeBlue => 'Blue Mushaf (Shamarly)';

  @override
  String get mushafTypeGreen => 'Green Mushaf';

  @override
  String get mushafTypeTajweed => 'Tajweed Mushaf';

  @override
  String get mushafStyle => 'Mushaf Style';

  @override
  String get allQuran => 'All Quran';

  @override
  String get filterBySurah => 'Surah';

  @override
  String get downloadConfirmation => 'Download Confirmation';

  @override
  String downloadConfirmationMsg(String mushafName) {
    return 'Do you want to download $mushafName?';
  }

  @override
  String get downloadFailedReverting => 'Download failed, reverting to previous edition.';

  @override
  String get bookmarkPage => 'Bookmark page';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get noBookmarks => 'No bookmarks yet';

  @override
  String get colorDefault => 'Default (Cream)';

  @override
  String get colorRed => 'Red';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get groupMyAzkar => 'My Azkar';

  @override
  String get groupMorning => 'Morning Azkar';

  @override
  String get groupEvening => 'Evening Azkar';

  @override
  String get groupPostPrayerGeneral => 'Post-Prayer Azkar (General)';

  @override
  String get groupPostPrayerFajrMaghrib => 'Post-Prayer Azkar (Fajr & Maghrib)';

  @override
  String get groupFriday => 'Friday Azkar';

  @override
  String get groupSleep => 'Sleep Azkar';

  @override
  String get groupWaking => 'Waking Azkar';

  @override
  String get createNewGroup => 'Create New Group';

  @override
  String get enterGroupName => 'Enter group name';

  @override
  String get addGroup => 'Add Group';

  @override
  String get deleteGroup => 'Delete Group';

  @override
  String get deleteGroupConfirmation => 'Are you sure you want to delete this group and all its azkar?';

  @override
  String get resetGroup => 'Reset Group';

  @override
  String get addAzkar => 'Add Azkar';

  @override
  String get enterAzkar => 'Enter Azkar text';

  @override
  String get resetAll => 'Reset All';

  @override
  String get delete => 'Delete';

  @override
  String get resetGroupConfirmation => 'Are you sure you want to reset counters for this group?';

  @override
  String get bookmarkSaved => 'Bookmark saved';

  @override
  String get hadithLibrary => 'Hadith Library';

  @override
  String get sahihain => 'Sahihain (The Two Sahihs)';

  @override
  String get sunan => 'The Sunan';

  @override
  String get others => 'Other Books';

  @override
  String get downloadBook => 'Download Book';

  @override
  String get bookNotAvailable => 'This book is not available locally. Do you want to download it?';

  @override
  String get downloading => 'Downloading...';

  @override
  String get open => 'Open';

  @override
  String get booksInArabic => 'Books in Arabic';

  @override
  String get booksInEnglish => 'Books in English';

  @override
  String get booksInFrench => 'Books in French';

  @override
  String get shareHadithFooter => 'Shared from Qurani App\nhttps://www.qurani.botsify.app/';

  @override
  String get loadingBook => 'Loading book content...';

  @override
  String get book => 'Book';

  @override
  String get grade => 'Grade';

  @override
  String get enterHadithNumber => 'Enter Hadith number';

  @override
  String get hadithHiddenOrNotFound => 'Hadith hidden or not found';

  @override
  String get noReadableContent => 'No readable content found in this book.';

  @override
  String get chapterStartNotFound => 'Chapter start not found in visible hadiths';

  @override
  String get generalHadiths => 'General Hadiths';

  @override
  String get chapters => 'Chapters';

  @override
  String get searchButton => 'Go';

  @override
  String get allChapters => 'All Chapters';

  @override
  String get goButton => 'Go';

  @override
  String get newsAndNotifications => 'News and Notifications';

  @override
  String get noNewsMessage => 'No current news or notifications';

  @override
  String get bookUnavailableMessage => 'It seems the book is not currently available, please check back later and we will work on providing it.';

  @override
  String get downloadOurApp => 'Download Our App';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get appStore => 'App Store';

  @override
  String get searchLanguageArabic => 'Arabic Text';

  @override
  String get searchLanguageEnglish => 'English Text';

  @override
  String get searchLanguageFrench => 'French Text';

  @override
  String get save => 'Save';

  @override
  String get testSettingsTitle => 'Test Settings';

  @override
  String get maxQuestionsLabel => 'Max Questions';
}
