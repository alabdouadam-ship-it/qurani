import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @quraniSettings.
  ///
  /// In en, this message translates to:
  /// **'Qurani Settings'**
  String get quraniSettings;

  /// No description provided for @customizeYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Customize your experience'**
  String get customizeYourExperience;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appInformation.
  ///
  /// In en, this message translates to:
  /// **'App information'**
  String get appInformation;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @getAssistance.
  ///
  /// In en, this message translates to:
  /// **'Get assistance'**
  String get getAssistance;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @quranPreferences.
  ///
  /// In en, this message translates to:
  /// **'Quran preferences'**
  String get quranPreferences;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// No description provided for @shareAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Discover Qurani on Google Play: {appUrl}'**
  String shareAppMessage(String appUrl);

  /// No description provided for @tellOthers.
  ///
  /// In en, this message translates to:
  /// **'Tell others'**
  String get tellOthers;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version of Qurani is available'**
  String get updateAvailable;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsConditions;

  /// No description provided for @prayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times'**
  String get prayerTimes;

  String get fajr;
  String get sunrise;
  String get dhuhr;
  String get asr;
  String get maghrib;
  String get isha;

  String get adhanEnabledMsg;
  String get adhanDisabledMsg;

  String get adjustTime;
  String get plus10Min;
  String get minus10Min;
  String get plus1Min;
  String get minus1Min;

  String get advancedOptions;
  String get calculationMethod;
  String get methodMWL;
  String get methodUmmAlQura;
  String get methodEgyptian;
  String get apiUnavailableUsingLocal;
  String get prayerTimesSettings;
  String get adhanSound;
  String get adhanSoundOption1;
  String get adhanSoundOption2;
  String get adhanSoundOption3;

  /// No description provided for @dataProtection.
  ///
  /// In en, this message translates to:
  /// **'Data protection'**
  String get dataProtection;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Qurani'**
  String get aboutTitle;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Qurani helps you engage ...'**
  String get aboutDescription;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String appVersionLabel(String version);

  /// No description provided for @optionsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Quran'**
  String get optionsTitle;

  /// No description provided for @quraniFeatures.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do?'**
  String get quraniFeatures;

  /// No description provided for @additionalFeaturesAndTools.
  ///
  /// In en, this message translates to:
  /// **'Additional features and tools'**
  String get additionalFeaturesAndTools;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @savedVerses.
  ///
  /// In en, this message translates to:
  /// **'Saved verses'**
  String get savedVerses;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @likedContent.
  ///
  /// In en, this message translates to:
  /// **'Liked content'**
  String get likedContent;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @offlineContent.
  ///
  /// In en, this message translates to:
  /// **'Offline content'**
  String get offlineContent;

  /// No description provided for @memorizationTest.
  ///
  /// In en, this message translates to:
  /// **'Memorization Test'**
  String get memorizationTest;

  /// No description provided for @memorizationTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Test your memorization'**
  String get memorizationTestSubtitle;

  /// No description provided for @repetitionMemorization.
  ///
  /// In en, this message translates to:
  /// **'Repetition Memorization'**
  String get repetitionMemorization;

  /// No description provided for @searchQuran.
  ///
  /// In en, this message translates to:
  /// **'Search in quran'**
  String get searchQuran;

  /// No description provided for @listenQuran.
  ///
  /// In en, this message translates to:
  /// **'Listen to Quran'**
  String get listenQuran;

  /// No description provided for @readQuran.
  ///
  /// In en, this message translates to:
  /// **'Read the Quran'**
  String get readQuran;

  /// No description provided for @hadith.
  ///
  /// In en, this message translates to:
  /// **'Hadith'**
  String get hadith;

  /// No description provided for @tasbeeh.
  ///
  /// In en, this message translates to:
  /// **'Tasbeeh'**
  String get tasbeeh;

  /// No description provided for @verses.
  ///
  /// In en, this message translates to:
  /// **'verses'**
  String get verses;

  /// No description provided for @pleaseSelectSurah.
  ///
  /// In en, this message translates to:
  /// **'Select a surah'**
  String get pleaseSelectSurah;

  /// No description provided for @surahTranslationsNote.
  ///
  /// In en, this message translates to:
  /// **'Names are shown in your selected language'**
  String get surahTranslationsNote;

  /// No description provided for @searchSurah.
  ///
  /// In en, this message translates to:
  /// **'Search surah...'**
  String get searchSurah;

  /// No description provided for @repeatSurah.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatSurah;

  /// No description provided for @autoAdvance.
  ///
  /// In en, this message translates to:
  /// **'Auto-advance'**
  String get autoAdvance;

  /// No description provided for @references.
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get references;

  /// No description provided for @quranReferences.
  ///
  /// In en, this message translates to:
  /// **'Quran References'**
  String get quranReferences;

  /// No description provided for @customizeYourReadingPreferences.
  ///
  /// In en, this message translates to:
  /// **'Customize your reading preferences'**
  String get customizeYourReadingPreferences;

  /// No description provided for @quranVersion.
  ///
  /// In en, this message translates to:
  /// **'Quran Version'**
  String get quranVersion;

  /// No description provided for @reciter.
  ///
  /// In en, this message translates to:
  /// **'Reciter'**
  String get reciter;

  /// No description provided for @repetitionReciter.
  ///
  /// In en, this message translates to:
  /// **'Repetition Reciter'**
  String get repetitionReciter;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @tafsir.
  ///
  /// In en, this message translates to:
  /// **'Tafsir'**
  String get tafsir;

  /// No description provided for @savePreferences.
  ///
  /// In en, this message translates to:
  /// **'Save Preferences'**
  String get savePreferences;

  /// No description provided for @preferencesSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved successfully!'**
  String get preferencesSavedSuccessfully;

  /// No description provided for @selectQuranVersion.
  ///
  /// In en, this message translates to:
  /// **'Select Quran Version...'**
  String get selectQuranVersion;

  /// No description provided for @selectReciter.
  ///
  /// In en, this message translates to:
  /// **'Select Reciter...'**
  String get selectReciter;

  /// No description provided for @selectRepetitionReciter.
  ///
  /// In en, this message translates to:
  /// **'Select Repetition Reciter...'**
  String get selectRepetitionReciter;

  /// No description provided for @selectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme...'**
  String get selectTheme;

  /// No description provided for @selectTafsir.
  ///
  /// In en, this message translates to:
  /// **'Select Tafsir...'**
  String get selectTafsir;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @uthmani.
  ///
  /// In en, this message translates to:
  /// **'Uthmani'**
  String get uthmani;

  /// No description provided for @simple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get simple;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get playbackSpeed;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimer;

  /// No description provided for @sleepTimerEnded.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer ended'**
  String get sleepTimerEnded;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @buffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering...'**
  String get buffering;

  /// No description provided for @errorLoadingAudio.
  ///
  /// In en, this message translates to:
  /// **'Error loading audio'**
  String get errorLoadingAudio;

  /// No description provided for @verseOutsideRange.
  ///
  /// In en, this message translates to:
  /// **'This verse is outside the selected range.'**
  String get verseOutsideRange;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @bookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get bookmarked;

  /// No description provided for @verseByVerse.
  ///
  /// In en, this message translates to:
  /// **'Verse by Verse'**
  String get verseByVerse;

  /// No description provided for @autoPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Auto Play'**
  String get autoPlayNext;

  /// No description provided for @featureSurah.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get featureSurah;

  /// No description provided for @removeFeatureSurah.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFeatureSurah;

  /// No description provided for @surahFeatured.
  ///
  /// In en, this message translates to:
  /// **'Surah added to favorites'**
  String get surahFeatured;

  /// No description provided for @surahUnfeatured.
  ///
  /// In en, this message translates to:
  /// **'Surah removed from favorites'**
  String get surahUnfeatured;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get queue;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get addToQueue;

  /// No description provided for @clearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear Queue'**
  String get clearQueue;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @selectReciterFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a reciter first.'**
  String get selectReciterFirst;

  /// No description provided for @downloadReciterTitle.
  ///
  /// In en, this message translates to:
  /// **'Download audio'**
  String get downloadReciterTitle;

  /// No description provided for @downloadReciterMessage.
  ///
  /// In en, this message translates to:
  /// **'Download all 114 surahs for this reciter for offline listening?'**
  String get downloadReciterMessage;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get downloadComplete;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @downloadCurrentSurahTitle.
  ///
  /// In en, this message translates to:
  /// **'Download this surah?'**
  String get downloadCurrentSurahTitle;

  /// No description provided for @downloadCurrentSurahMessage.
  ///
  /// In en, this message translates to:
  /// **'Download the current surah for offline listening?'**
  String get downloadCurrentSurahMessage;

  /// No description provided for @downloadingSurah.
  ///
  /// In en, this message translates to:
  /// **'Downloading surah...'**
  String get downloadingSurah;

  /// No description provided for @downloadProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloadProgressTitle;

  /// No description provided for @surahUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audio not available for this surah. Try another reciter.'**
  String get surahUnavailable;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @playPageAudio.
  ///
  /// In en, this message translates to:
  /// **'Play page audio'**
  String get playPageAudio;

  /// No description provided for @playSurahAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get playSurahAudio;

  /// No description provided for @pausePageAudio.
  ///
  /// In en, this message translates to:
  /// **'Pause page audio'**
  String get pausePageAudio;

  /// No description provided for @pauseSurahAudio.
  ///
  /// In en, this message translates to:
  /// **'Pause audio'**
  String get pauseSurahAudio;

  /// No description provided for @stopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get stopPlayback;

  /// No description provided for @previousAyah.
  ///
  /// In en, this message translates to:
  /// **'Previous verse'**
  String get previousAyah;

  /// No description provided for @highlightedAyahs.
  ///
  /// In en, this message translates to:
  /// **'Highlighted verses'**
  String get highlightedAyahs;

  /// No description provided for @noHighlightsYet.
  ///
  /// In en, this message translates to:
  /// **'You have not highlighted any verses yet.'**
  String get noHighlightsYet;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// No description provided for @surah.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get surah;

  /// No description provided for @tapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get tapToChange;

  /// No description provided for @chooseSurah.
  ///
  /// In en, this message translates to:
  /// **'Choose a surah'**
  String get chooseSurah;

  /// No description provided for @chooseJuz.
  ///
  /// In en, this message translates to:
  /// **'Choose a juz'**
  String get chooseJuz;

  /// No description provided for @juzLabel.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get juzLabel;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'Search results: {count}'**
  String searchResultsCount(int count);

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found for your query.'**
  String get noResultsFound;

  /// No description provided for @addHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight verse'**
  String get addHighlight;

  /// No description provided for @removeHighlight.
  ///
  /// In en, this message translates to:
  /// **'Remove highlight'**
  String get removeHighlight;

  /// No description provided for @showEnglishTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show English translation'**
  String get showEnglishTranslation;

  /// No description provided for @showFrenchTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show French translation'**
  String get showFrenchTranslation;

  /// No description provided for @showArabicText.
  ///
  /// In en, this message translates to:
  /// **'Show Arabic text'**
  String get showArabicText;

  /// No description provided for @showTafsir.
  ///
  /// In en, this message translates to:
  /// **'Show tafsir'**
  String get showTafsir;

  /// No description provided for @translationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Translation not available for this verse.'**
  String get translationNotAvailable;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @currentVerse.
  ///
  /// In en, this message translates to:
  /// **'Current Verse'**
  String get currentVerse;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @resumeFromLastPosition.
  ///
  /// In en, this message translates to:
  /// **'Resume from last position'**
  String get resumeFromLastPosition;

  /// No description provided for @searchTooShort.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 2 characters'**
  String get searchTooShort;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get unknownError;

  /// No description provided for @qiblaTitle.
  ///
  /// In en, this message translates to:
  /// **'Qibla Direction'**
  String get qiblaTitle;

  /// No description provided for @qiblaRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get qiblaRetry;

  /// No description provided for @qiblaCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking permissions and sensors...'**
  String get qiblaCheckingStatus;

  /// No description provided for @qiblaTurnUntilArrowUp.
  ///
  /// In en, this message translates to:
  /// **'Turn until the arrow points up'**
  String get qiblaTurnUntilArrowUp;

  /// No description provided for @qiblaPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to determine the Qibla.'**
  String get qiblaPermissionRequired;

  /// No description provided for @qiblaLocationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Please enable location services (GPS) to continue.'**
  String get qiblaLocationDisabled;

  /// No description provided for @qiblaOpenAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings'**
  String get qiblaOpenAppSettings;

  /// No description provided for @qiblaOpenLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Location Settings'**
  String get qiblaOpenLocationSettings;

  /// No description provided for @qiblaSensorNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This device does not support the required sensors for compass mode.'**
  String get qiblaSensorNotSupported;

  /// No description provided for @qiblaAngleLabel.
  ///
  /// In en, this message translates to:
  /// **'Qibla angle: {angle}°'**
  String qiblaAngleLabel(String angle);

  /// No description provided for @qiblaTipGps.
  ///
  /// In en, this message translates to:
  /// **'Enable GPS and High Accuracy'**
  String get qiblaTipGps;

  /// No description provided for @qiblaTipCalibrate.
  ///
  /// In en, this message translates to:
  /// **'Calibrate: move phone ∞'**
  String get qiblaTipCalibrate;

  /// No description provided for @qiblaTipInterference.
  ///
  /// In en, this message translates to:
  /// **'Avoid metal/magnetic interference'**
  String get qiblaTipInterference;

  /// No description provided for @testResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Result'**
  String get testResultTitle;

  /// No description provided for @testCongratsTitle.
  ///
  /// In en, this message translates to:
  /// **'Well done!'**
  String get testCongratsTitle;

  /// No description provided for @correctAnswersLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct answers: {correct} / {total}'**
  String correctAnswersLabel(int correct, int total);

  /// No description provided for @percentageLabel.
  ///
  /// In en, this message translates to:
  /// **'Percentage: {percent}%'**
  String percentageLabel(int percent);

  /// No description provided for @earnedScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Earned score: {score}'**
  String earnedScoreLabel(int score);

  /// No description provided for @totalScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Total score'**
  String get totalScoreLabel;

  /// No description provided for @endLabel.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get endLabel;

  /// No description provided for @newTestLabel.
  ///
  /// In en, this message translates to:
  /// **'New test'**
  String get newTestLabel;

  /// No description provided for @previousLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousLabel;

  /// No description provided for @nextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextLabel;

  /// No description provided for @showResultsLabel.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get showResultsLabel;

  /// No description provided for @confirmAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm answer'**
  String get confirmAnswerLabel;

  /// No description provided for @exitTestTitle.
  ///
  /// In en, this message translates to:
  /// **'End test'**
  String get exitTestTitle;

  /// No description provided for @exitTestConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end the test and show results?'**
  String get exitTestConfirm;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @extraLarge.
  ///
  /// In en, this message translates to:
  /// **'Extra Large'**
  String get extraLarge;

  /// No description provided for @verseRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'Verse repeat count'**
  String get verseRepeatCount;

  /// No description provided for @verseRepeatCountHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat each verse this many times during repetition memorization.'**
  String get verseRepeatCountHint;

  /// No description provided for @arabicFont.
  ///
  /// In en, this message translates to:
  /// **'Arabic font'**
  String get arabicFont;

  /// No description provided for @fontAmiri.
  ///
  /// In en, this message translates to:
  /// **'Amiri Quran'**
  String get fontAmiri;

  /// No description provided for @fontScheherazade.
  ///
  /// In en, this message translates to:
  /// **'Scheherazade New'**
  String get fontScheherazade;

  /// No description provided for @fontLateef.
  ///
  /// In en, this message translates to:
  /// **'Lateef'**
  String get fontLateef;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
