// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String passageVerseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verses',
      one: '1 verse',
    );
    return '$_temp0';
  }

  @override
  String get passageStartSurah => 'Starting surah';

  @override
  String get passageStartVerse => 'Starting verse';

  @override
  String get passageEndSurah => 'Ending surah';

  @override
  String get passageEndVerse => 'Ending verse';

  @override
  String get rememberPassage => 'Remember last passage';

  @override
  String get rememberPassageHint => 'Open this passage next time';

  @override
  String get applyPassage => 'Apply';

  @override
  String get passageLoadError => 'Unable to load this passage';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get help => 'Help';

  @override
  String get preferences => 'Preferences';

  @override
  String get shareApp => 'Share App';

  @override
  String shareAppMessage(Object appUrl) {
    return 'Discover Qurani, the app that helps you engage with the Holy Quran: listening, reading, repetition-based memorization, digital tasbeeh, Qibla direction, memorization tests, and more. The app supports Arabic, English and French, with multiple color themes. Get it on Google Play: $appUrl';
  }

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
  String get prayerMethodSectionTitle => 'Prayer Time Calculation Method';

  @override
  String get prayerMethodSectionDesc => 'Choose your preferred method or leave it automatic based on your location';

  @override
  String get prayerMethodAuto => 'Automatic (based on location)';

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
  String get adhanSound => 'Adhan sound';

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
  String get bookmarks => 'Bookmarks';

  @override
  String get history => 'History';

  @override
  String get downloads => 'Downloads';

  @override
  String get memorizationTest => 'Memorization Test';

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
  String get searchSurah => 'Search surah...';

  @override
  String get repeatSurah => 'Repeat';

  @override
  String get reciter => 'Reciter';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get tafsir => 'Tafsir';

  @override
  String get selectReciter => 'Select Reciter...';

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
  String get firstAyah => 'First ayah';

  @override
  String get reciterRotationTitle => 'Multi-reciter rotation';

  @override
  String get reciterRotationDesc => 'Play each repeat of a verse with a different reciter, in order, looping back to the first.';

  @override
  String get reciterRotationAddReciter => 'Add reciter';

  @override
  String get reciterRotationEmpty => 'Add reciters to rotate through.';

  @override
  String get reciterRotationRemove => 'Remove';

  @override
  String reciterRotationPreview(int count, String sequence) {
    return '$count repeats → $sequence';
  }

  @override
  String get shareUsageStatsTitle => 'Share anonymous usage statistics';

  @override
  String get shareUsageStatsSubtitle => 'Help improve the app by sharing anonymous data (device type, language, approximate area — country and town, and which features are used). No personal information, precise location (coordinates or address), or account data is collected. You can turn this off anytime.';

  @override
  String get arabicFont => 'Arabic font';

  @override
  String get fontAmiri => 'Amiri Quran';

  @override
  String get offlineAudioTitle => 'Offline audio';

  @override
  String reciterLabel(String name) {
    return 'Reciter: $name';
  }

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
  String get timeFormatTitle => 'Time format';

  @override
  String get twelveHour => '12h';

  @override
  String get twentyFourHour => '24h';

  @override
  String get hijriHeader => 'Hijri';

  @override
  String get gregorianHeader => 'Gregorian';

  @override
  String get audioInternetRequired => 'No internet connection. Please connect to play audio or download offline files.';

  @override
  String get editionArabicTajweed => 'Quran Tajweed';

  @override
  String get readAutoFlip => 'Auto flip page';

  @override
  String get readAutoFlipDesc => 'Automatically turn the page when audio ends.';

  @override
  String get chooseReciter => 'Choose reciter';

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
  String get shareHadithFooter => 'Shared from Qurani App\nhttps://www.qurani.info/';

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
  String get allChapters => 'All Chapters';

  @override
  String get goButton => 'Go';

  @override
  String get newsAndNotifications => 'News and Notifications';

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

  @override
  String get fileSize => 'File Size';

  @override
  String get showMore => 'Show More';

  @override
  String get showLess => 'Show Less';

  @override
  String get noNewsYet => 'There\'s no notifications or news yet';

  @override
  String get newsTabAll => 'All';

  @override
  String get newsTabSaved => 'Saved';

  @override
  String get noSavedNews => 'No saved news';

  @override
  String get noNewsAtTheMoment => 'No news at the moment';

  @override
  String get newsSource => 'Source';

  @override
  String get newItemBadge => 'NEW';

  @override
  String get editionIrab => 'Quran I\'rab (Grammar)';

  @override
  String get irabDataNotAvailable => 'I\'rab data is not available locally. Would you like to download it?';

  @override
  String get irabDownloading => 'Downloading I\'rab data...';

  @override
  String get irabLoading => 'Loading I\'rab data...';

  @override
  String get noSurahsAvailable => 'No surahs available';

  @override
  String get noQuestionsAvailable => 'No questions available';

  @override
  String testErrorGeneric(Object error) {
    return 'Error: $error';
  }

  @override
  String get startTestButton => 'Start Test';

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get juzTabarak => 'Juz Tabarak';

  @override
  String get juzAmma => 'Juz Amma';

  @override
  String deleteAzkarConfirmation(Object text) {
    return 'Do you want to delete this azkar?\n$text';
  }

  @override
  String get resetAllConfirmation => 'All counters across all groups will be reset.';

  @override
  String get noAzkarInGroup => 'No azkar in this group. Tap the menu to add one.';

  @override
  String get sessionLabel => 'Session';

  @override
  String get totalLabel => 'Total';

  @override
  String get resetSessionTooltip => 'Reset session';

  @override
  String get memorizationStatsTitle => 'Test Statistics';

  @override
  String get clearStatsTitle => 'Clear Statistics';

  @override
  String get clearStatsConfirmation => 'Are you sure you want to clear all statistics?';

  @override
  String get noStats => 'No statistics available';

  @override
  String get totalScoreHeader => 'Accumulated Score';

  @override
  String get totalTestsLabel => 'Total Tests';

  @override
  String get surahTab => 'Surahs';

  @override
  String get juzTab => 'Juz';

  @override
  String get surahMasteryHeader => 'Mastery per Surah';

  @override
  String get recentTestsHeader => 'Recent Tests';

  @override
  String pointsSuffix(int n) {
    return '$n points';
  }

  @override
  String get statsNoDataYet => 'No tests yet';

  @override
  String get statsMixedSelection => 'Mixed selection';

  @override
  String get statsAggLegend => '× tests · % last score';

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String daysAgo(int n) {
    return '$n d ago';
  }

  @override
  String get refreshList => 'Refresh list';

  @override
  String get memorizationTestDescription => 'Choose surahs or ajza and start your memorization test in a calmer, more organised interface.';

  @override
  String get tasbeehDescription => 'Your adhkar and daily groups in a calmer, clearer interface.';

  @override
  String get searchQuranDescription => 'Search the Quran quickly with language filters and ayah audio preview.';

  @override
  String memorizationQNextAyah(Object surahName, Object ayahText) {
    return 'In $surahName\nWhich ayah comes after the following one?\n$ayahText';
  }

  @override
  String memorizationQCompleteAyah(Object surahName, Object ayahPrefix) {
    return 'In $surahName\nComplete the verse:\n$ayahPrefix...';
  }

  @override
  String memorizationQSurahNumber(Object surahName) {
    return 'What is the number of $surahName in the Holy Quran?';
  }

  @override
  String memorizationQSurahAyahCount(Object surahName) {
    return 'How many verses does $surahName have?';
  }

  @override
  String get surahMasteryHelp => 'Mastery is the average percentage of correct answers across every test you have taken for this surah.';

  @override
  String get surahMasteryHelpTooltip => 'What does Mastery mean?';

  @override
  String surahNamePrefix(int number) {
    return 'Surah $number';
  }

  @override
  String get surahLongPressHint => 'Long-press for more actions';

  @override
  String get exactAlarmNeededTitle => 'Exact alarms disabled';

  @override
  String get exactAlarmNeededBody => 'Adhan may be delayed by up to 15 minutes. Enable exact alarms in Settings for precise playback.';

  @override
  String get openSettingsAction => 'Open Settings';

  @override
  String get testResultHeadlineExcellent => 'Excellent!';

  @override
  String get testResultSubExcellent => 'Masterful — keep it up at this level.';

  @override
  String get testResultHeadlineGood => 'Well done!';

  @override
  String get testResultSubGood => 'Great result — a few reviews and you will reach mastery.';

  @override
  String get testResultHeadlineOk => 'Good!';

  @override
  String get testResultSubOk => 'Keep reviewing — your progress is clear.';

  @override
  String get testResultHeadlineEffort => 'Keep trying!';

  @override
  String get testResultSubEffort => 'Effort makes the difference — retake the test after reviewing the mistakes.';

  @override
  String get currentTestResult => 'Current test result';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get downloadPaused => 'Download paused';

  @override
  String integrityVerified(int count, int total) {
    return '$count of $total verified';
  }

  @override
  String integrityCorrupt(int count) {
    return '$count corrupt';
  }

  @override
  String integrityMissing(int count) {
    return '$count missing';
  }

  @override
  String get repairCorruptFiles => 'Repair';

  @override
  String get repairing => 'Repairing…';

  @override
  String repairCompleted(int count) {
    return 'Repaired $count file(s). Resume the download to fetch them again.';
  }

  @override
  String integrityAllVerified(int total) {
    return 'All $total surahs verified';
  }

  @override
  String errorLoadingBook(String error) {
    return 'Failed to load book: $error';
  }

  @override
  String get noChaptersAvailable => 'No chapters available';

  @override
  String get tasbeehTabLabel => 'Tasbeeh';

  @override
  String get wirdTabLabel => 'Wird';

  @override
  String get wirdAddTitle => 'Add Wird';

  @override
  String get wirdEditTitle => 'Edit Wird';

  @override
  String get wirdFieldTitle => 'Title';

  @override
  String get wirdFieldDhikrText => 'Dhikr';

  @override
  String get wirdFieldTargetCount => 'Target count';

  @override
  String get wirdFieldDaysOfWeek => 'Days';

  @override
  String get wirdAllDays => 'Every day';

  @override
  String get dayMonday => 'Monday';

  @override
  String get dayTuesday => 'Tuesday';

  @override
  String get dayWednesday => 'Wednesday';

  @override
  String get dayThursday => 'Thursday';

  @override
  String get dayFriday => 'Friday';

  @override
  String get daySaturday => 'Saturday';

  @override
  String get daySunday => 'Sunday';

  @override
  String get wirdRemindMe => 'Remind me';

  @override
  String get wirdReminderTime => 'Reminder time';

  @override
  String get wirdDeleteConfirm => 'Delete this wird?';

  @override
  String get wirdStart => 'Start';

  @override
  String get wirdResume => 'Resume';

  @override
  String get wirdAllScreenTitle => 'All wirds';

  @override
  String get wirdAllEmptyTitle => 'No wirds created yet';

  @override
  String get wirdFilterToday => 'Today';

  @override
  String get wirdFilterAll => 'All';

  @override
  String get wirdSendTest => 'Send test';

  @override
  String get wirdTestSent => 'Test notification sent. If you don\'t see it, check your system notification settings for this app.';

  @override
  String get wirdTestPermissionDenied => 'Notifications aren\'t allowed for this app. Please enable them in system settings.';

  @override
  String get wirdTestFailed => 'Couldn\'t send the test notification. Please try again.';

  @override
  String get wirdExactAlarmDenied => 'Reminders are enabled but may be delayed. For on-time delivery, allow \"Alarms & reminders\" for this app in system settings.';

  @override
  String wirdProgressFraction(int current, int target) {
    return '$current / $target';
  }

  @override
  String get wirdCompletedToast => 'MashaAllah — completed!';

  @override
  String get wirdCompletedBadge => 'Done';

  @override
  String get wirdTodayEmptyTitle => 'No wird scheduled for today';

  @override
  String get wirdTodayEmptyHint => 'Add one with the + button, or edit an existing wird\'s days.';

  @override
  String get wirdSectionTitle => 'Today\'s Wird';

  @override
  String get wirdTabSubtitle => 'Daily adhkar with gentle reminders.';

  @override
  String get wirdValidationTitleRequired => 'Please enter a title';

  @override
  String get wirdValidationDaysRequired => 'Pick at least one day';

  @override
  String get wirdValidationTargetInvalid => 'Target must be between 1 and 9999';

  @override
  String get wirdExitFocus => 'End session';

  @override
  String get wirdFocusHintTap => 'Tap anywhere to count';

  @override
  String get wirdResetProgress => 'Reset today\'s progress';

  @override
  String get hadithSearchHint => 'Enter text to search or select a chapter';

  @override
  String get hadithNoMatches => 'No matches found';

  @override
  String get editionTitle => 'Edition';

  @override
  String get editionTranslationsCategory => 'Translations';

  @override
  String get editionTafsirCategory => 'Tafsir';

  @override
  String get editionTurkish => 'Turkish';

  @override
  String get editionGerman => 'German';

  @override
  String get secondaryEditionTitle => 'Secondary edition';

  @override
  String get secondaryEditionDesc => 'Add an arrow to each ayah that opens a second edition.';

  @override
  String get secondaryEditionChoose => 'Which edition';

  @override
  String get secondaryEditionFallback => 'Alternative edition';

  @override
  String get secondaryEditionFallbackDesc => 'used when the secondary edition is the one you are reading';

  @override
  String get secondaryEditionShow => 'Show secondary edition';

  @override
  String get secondaryEditionHide => 'Hide secondary edition';

  @override
  String get memorizationIncompleteData => 'The passage could not be fully loaded. Check your connection and try again.';

  @override
  String downloadIncomplete(int completed, int total, int failed) {
    return 'Download incomplete: $completed/$total files verified; $failed failed. Retry to download missing files.';
  }

  @override
  String get downloadCancelled => 'Download cancelled. Completed files have been kept.';

  @override
  String get aboutWebDescription => 'Qurani Web offers Quran reading, online audio, search, repetition-based memorization, tests and bookmarks in Arabic, English and French. Prayer times, adhan, Qibla, tasbeeh, Wird reminders and offline audio downloads are available in the mobile app.';

  @override
  String get backupTitle => 'Backup and restore';

  @override
  String get backupDescription => 'Export bookmarks, settings, statistics, reviews, tasbeeh and Wird. Audio files and phone permissions are not included.';

  @override
  String get backupExport => 'Export backup';

  @override
  String get backupImport => 'Choose backup file';

  @override
  String backupConfirm(String date, int count) {
    return 'This backup from $date contains $count entries. It will replace the backed-up bookmarks, settings and progress on this device. Continue?';
  }

  @override
  String get backupRestore => 'Restore';

  @override
  String get backupDone => 'Backup restored.';

  @override
  String get backupInvalid => 'Invalid or incompatible file. No data was imported.';

  @override
  String get backupFailed => 'The operation failed. Please try again.';

  @override
  String get backupScheduleWarning => 'Data restored. Check prayer times and permissions in Adhan diagnostics.';

  @override
  String get adhanDiagnosticTitle => 'Adhan diagnostics';

  @override
  String get adhanNextExpected => 'Next expected adhan';

  @override
  String get adhanNoNext => 'No future time available for enabled prayers.';

  @override
  String get adhanDiagnosticNote => 'The expected time uses saved prayer times and your settings. The system may restrict background alarms. The sound test checks immediate playback only.';

  @override
  String get diagnosticNotifications => 'Notification permission';

  @override
  String get diagnosticSound => 'iPhone notification sound';

  @override
  String get diagnosticExact => 'Android exact alarms';

  @override
  String get diagnosticBattery => 'Battery optimization exemption';

  @override
  String get diagnosticLocation => 'Location permission';

  @override
  String get diagnosticLocationService => 'Location services enabled';

  @override
  String get diagnosticCalendar => 'Matching prayer times available';

  @override
  String get diagnosticPending => 'iPhone notification scheduled';

  @override
  String diagnosticEnabled(int count) {
    return 'Enabled prayers: $count';
  }

  @override
  String diagnosticVolume(int percent) {
    return 'Adhan volume: $percent%';
  }

  @override
  String get diagnosticYes => 'Yes';

  @override
  String get diagnosticNo => 'No';

  @override
  String get diagnosticUnknown => 'Unavailable';

  @override
  String get diagnosticSettings => 'Open device settings';

  @override
  String get diagnosticTest => 'Test sound';

  @override
  String get diagnosticStop => 'Stop test';

  @override
  String get diagnosticRefresh => 'Refresh';

  @override
  String get downloadIssuesTitle => 'Downloads to resume';

  @override
  String get downloadIssuesEmpty => 'No failed or interrupted downloads.';

  @override
  String get downloadRetryAll => 'Resume all items';

  @override
  String get downloadRetry => 'Resume';

  @override
  String get downloadIssueFailed => 'Failed';

  @override
  String get downloadIssueCancelled => 'Cancelled';

  @override
  String get downloadIssueInterrupted => 'Interrupted';

  @override
  String get downloadIssueActive => 'In progress';

  @override
  String downloadIssueAttempts(int count) {
    return 'Attempts: $count';
  }

  @override
  String get downloadReasonNetwork => 'Connection unavailable or timed out';

  @override
  String get downloadReasonServer => 'The server did not provide the file';

  @override
  String get downloadReasonFile => 'File unavailable, invalid or could not be saved';

  @override
  String get reviewTitle => 'Spaced review';

  @override
  String get reviewDescription => 'Add memorized passages. Review them, then rate your recall to schedule the next review.';

  @override
  String get reviewAdd => 'Add passage';

  @override
  String get reviewAddCurrent => 'Add this passage to reviews';

  @override
  String get reviewAdded => 'Passage added to reviews.';

  @override
  String get reviewEmpty => 'No review passages yet.';

  @override
  String get reviewDue => 'Due for review';

  @override
  String reviewNext(String date) {
    return 'Next review: $date';
  }

  @override
  String get reviewOpen => 'Open passage';

  @override
  String get reviewRate => 'Rate my review';

  @override
  String get reviewAgain => 'Again';

  @override
  String get reviewHard => 'Hard';

  @override
  String get reviewGood => 'Good';

  @override
  String get reviewEasy => 'Easy';

  @override
  String get reviewRemove => 'Remove this passage from reviews?';

  @override
  String reviewPassage(int startSurah, int startVerse, int endSurah, int endVerse) {
    return 'Surah $startSurah, verse $startVerse → surah $endSurah, verse $endVerse';
  }

  @override
  String get downloadBatchLabel => 'Full download';
}
