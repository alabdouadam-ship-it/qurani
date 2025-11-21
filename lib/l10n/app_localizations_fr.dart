// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settings => 'Paramètres';

  @override
  String get quraniSettings => 'Paramètres Qurani';

  @override
  String get customizeYourExperience => 'Personnalisez votre expérience';

  @override
  String get about => 'À propos';

  @override
  String get appInformation => 'Informations sur l\'application';

  @override
  String get help => 'Aide';

  @override
  String get getAssistance => 'Obtenir de l\'assistance';

  @override
  String get preferences => 'Préférences';

  @override
  String get quranPreferences => 'Préférences du Coran';

  @override
  String get shareApp => 'Partager l\'application';

  @override
  String shareAppMessage(Object appUrl) {
    return 'Découvrez Qurani, l’application qui vous aide à interagir avec le Coran : écoute, lecture, mémorisation par répétition, tasbih numérique, direction de la qibla, tests de mémorisation et plus encore. L’application prend en charge l’arabe, l’anglais et le français, avec plusieurs thèmes de couleurs. Téléchargez-la sur Google Play : $appUrl';
  }

  @override
  String get tellOthers => 'Parlez-en aux autres';

  @override
  String get updateAvailable => 'Une nouvelle version de Qurani est disponible';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get later => 'Plus tard';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsConditions => 'Conditions générales';

  @override
  String get supportUs => 'Soutenez-nous';

  @override
  String get contactUs => 'Contactez-nous';

  @override
  String get supportIntro => 'Nous dépendons de l’hébergement et de services tiers pour assurer la disponibilité de Qurani. Votre soutien facultatif nous aide à maintenir et améliorer l’application.';

  @override
  String get donateViaPayPal => 'Don via PayPal';

  @override
  String get paypalEmail => 'Email PayPal';

  @override
  String get donateViaCrypto => 'Don via USDT';

  @override
  String get usdtAddress => 'Adresse USDT';

  @override
  String get watchAd => 'Soutenir en regardant une publicité (bientôt)';

  @override
  String get contactViaWhatsApp => 'WhatsApp';

  @override
  String get contactViaEmail => 'Email';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get prayerTimes => 'Heures de prière';

  @override
  String get fajr => 'Fajr';

  @override
  String get sunrise => 'Lever du soleil';

  @override
  String get dhuhr => 'Dhuhr';

  @override
  String get asr => 'Asr';

  @override
  String get maghrib => 'Maghrib';

  @override
  String get isha => 'Isha';

  @override
  String get adhanEnabledMsg => 'L\'adhan sera diffusé à cette heure de prière.';

  @override
  String get adhanDisabledMsg => 'L\'adhan ne sera pas diffusé à cette heure de prière.';

  @override
  String get stopAdhan => 'Arrêter l\'adhan';

  @override
  String get adhanStoppedMsg => 'Adhan arrêté';

  @override
  String get adjustTime => 'Ajuster l\'heure';

  @override
  String get prayerAdjustmentTooltip => 'Ajuster l\'heure de la prière';

  @override
  String prayerAdjustmentTitle(Object prayerName) {
    return 'Ajuster l\'heure de $prayerName';
  }

  @override
  String get prayerAdjustmentOriginal => 'Heure d\'origine';

  @override
  String prayerAdjustmentChange(Object value) {
    return 'Ajustement : $value';
  }

  @override
  String prayerAdjustmentAfter(Object time) {
    return 'Après ajustement : $time';
  }

  @override
  String get prayerAdjustmentNoChange => 'Aucun ajustement';

  @override
  String get prayerAdjustmentReset => 'Réinitialiser l\'ajustement';

  @override
  String get plus10Min => '+10 min';

  @override
  String get minus10Min => '-10 min';

  @override
  String get plus1Min => '+1 min';

  @override
  String get minus1Min => '-1 min';

  @override
  String get advancedOptions => 'Options avancées';

  @override
  String get calculationMethod => 'Méthode de calcul';

  @override
  String get methodMWL => 'Ligue du Monde Musulman';

  @override
  String get methodUmmAlQura => 'Oumm al-Qura (La Mecque)';

  @override
  String get methodEgyptian => 'Autorité générale égyptienne';

  @override
  String get apiUnavailableUsingLocal => 'Service en ligne indisponible. Utilisation du calcul local.';

  @override
  String get prayerTimesSettings => 'Paramètres des heures de prière';

  @override
  String get adhanSound => 'Son de l\'adhan';

  @override
  String get adhanSoundOption1 => 'Adhan 1';

  @override
  String get adhanSoundOption2 => 'Adhan 2';

  @override
  String get adhanSoundOption3 => 'Adhan 3';

  @override
  String get dataProtection => 'Protection des données';

  @override
  String get aboutTitle => 'À propos de Qurani';

  @override
  String get aboutDescription => 'Qurani vous aide à interagir avec le Coran : écoute, lecture, mémorisation par répétition, tasbih numérique, direction de la qibla, tests de mémorisation, favoris, versets mis en avant et plus encore. L’application prend en charge l’arabe, l’anglais et le français, avec des thèmes et polices personnalisables.';

  @override
  String appVersionLabel(Object version) {
    return 'Version : $version';
  }

  @override
  String get optionsTitle => 'Mon coran';

  @override
  String get quraniFeatures => 'Que voulez vous faire?';

  @override
  String get additionalFeaturesAndTools => 'Fonctionnalités et outils supplémentaires';

  @override
  String get bookmarks => 'Marque-pages';

  @override
  String get savedVerses => 'Versets sauvegardés';

  @override
  String get history => 'Historique';

  @override
  String get recentActivity => 'Activité récente';

  @override
  String get favorites => 'Favoris';

  @override
  String get likedContent => 'Contenu aimé';

  @override
  String get downloads => 'Téléchargements';

  @override
  String get offlineContent => 'Contenu hors ligne';

  @override
  String get memorizationTest => 'Test de mémorisation';

  @override
  String get memorizationTestSubtitle => 'Testez votre mémorisation';

  @override
  String get repetitionMemorization => 'Mémorisation par répétition';

  @override
  String get searchQuran => 'ٌRechercher dans le Coran';

  @override
  String get listenQuran => 'Écouter le Coran';

  @override
  String get readQuran => 'Lire le Coran';

  @override
  String get hadith => 'Hadith';

  @override
  String get tasbeeh => 'Tasbeeh';

  @override
  String get verses => 'versets';

  @override
  String get pleaseSelectSurah => 'Sélectionner une sourate';

  @override
  String get surahTranslationsNote => 'Les noms sont affichés dans votre langue sélectionnée';

  @override
  String get searchSurah => 'Rechercher une sourate...';

  @override
  String get repeatSurah => 'Répéter';

  @override
  String get autoAdvance => 'Avance automatique';

  @override
  String get references => 'Références';

  @override
  String get quranReferences => 'Références du Coran';

  @override
  String get customizeYourReadingPreferences => 'Personnalisez vos préférences de lecture';

  @override
  String get quranVersion => 'Version du Coran';

  @override
  String get reciter => 'Récitateur';

  @override
  String get repetitionReciter => 'Récitateur de répétition';

  @override
  String get theme => 'Thème';

  @override
  String get language => 'Langue';

  @override
  String get tafsir => 'Tafsir';

  @override
  String get savePreferences => 'Enregistrer les préférences';

  @override
  String get preferencesSavedSuccessfully => 'Préférences enregistrées avec succès !';

  @override
  String get selectQuranVersion => 'Sélectionner la version du Coran...';

  @override
  String get selectReciter => 'Sélectionner un récitateur...';

  @override
  String get selectRepetitionReciter => 'Sélectionner un récitateur de répétition...';

  @override
  String get selectTheme => 'Sélectionner un thème...';

  @override
  String get selectTafsir => 'Sélectionner un Tafsir...';

  @override
  String get arabic => 'Arabe';

  @override
  String get uthmani => 'Uthmani';

  @override
  String get simple => 'Simple';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get playbackSpeed => 'Vitesse de lecture';

  @override
  String get sleepTimer => 'Minuterie de veille';

  @override
  String get sleepTimerEnded => 'La minuterie de veille est terminée';

  @override
  String get minutes => 'minutes';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get off => 'Désactivé';

  @override
  String get buffering => 'Mise en mémoire tampon...';

  @override
  String get errorLoadingAudio => 'Erreur lors du chargement de l\'audio';

  @override
  String get retry => 'Réessayer';

  @override
  String get bookmark => 'Marque-page';

  @override
  String get bookmarked => 'Ajouté aux marque-pages';

  @override
  String get verseByVerse => 'Verset par verset';

  @override
  String get autoPlayNext => 'Lecture automatique';

  @override
  String get featureSurah => 'Mettre en favori';

  @override
  String get removeFeatureSurah => 'Retirer des favoris';

  @override
  String get surahFeatured => 'Sourate ajoutée aux favoris';

  @override
  String get surahUnfeatured => 'Sourate retirée des favoris';

  @override
  String get queue => 'Liste de lecture';

  @override
  String get addToQueue => 'Ajouter à la file d\'attente';

  @override
  String get clearQueue => 'Vider la file d\'attente';

  @override
  String get download => 'Télécharger';

  @override
  String get downloaded => 'Téléchargé';

  @override
  String get selectReciterFirst => 'Veuillez d\'abord sélectionner un récitateur.';

  @override
  String get downloadReciterTitle => 'Télécharger l\'audio';

  @override
  String get downloadReciterMessage => 'Télécharger les 114 sourates de ce récitateur pour une écoute hors ligne ?';

  @override
  String get downloadComplete => 'Téléchargement terminé';

  @override
  String get downloadFailed => 'Échec du téléchargement';

  @override
  String get downloadCurrentSurahTitle => 'Télécharger cette sourate ?';

  @override
  String get downloadCurrentSurahMessage => 'Télécharger la sourate actuelle pour une écoute hors ligne ?';

  @override
  String get downloadingSurah => 'Téléchargement de la sourate...';

  @override
  String get downloadProgressTitle => 'Téléchargement en cours...';

  @override
  String get surahUnavailable => 'Audio non disponible pour cette sourate. Essayez un autre récitateur.';

  @override
  String get cancel => 'Annuler';

  @override
  String get go => 'Aller';

  @override
  String get playPageAudio => 'Lecture audio de la page';

  @override
  String get playSurahAudio => 'Lecture audio';

  @override
  String get pausePageAudio => 'Mettre en pause l\'audio de la page';

  @override
  String get pauseSurahAudio => 'Mettre en pause l\'audio';

  @override
  String get stopPlayback => 'Arrêter la lecture';

  @override
  String get previousAyah => 'Verset précédent';

  @override
  String get highlightedAyahs => 'Versets surlignés';

  @override
  String get noHighlightsYet => 'Vous n\'avez pas encore mis de verset en évidence.';

  @override
  String get goToPage => 'Aller à la page';

  @override
  String get page => 'Page';

  @override
  String get surah => 'Sourate';

  @override
  String get tapToChange => 'Touchez pour changer';

  @override
  String get chooseSurah => 'Choisir une sourate';

  @override
  String get chooseJuz => 'Choisir un juz';

  @override
  String get juzLabel => 'Juz';

  @override
  String get search => 'Rechercher...';

  @override
  String searchResultsCount(int count) {
    return 'Résultats de recherche : $count';
  }

  @override
  String get noResultsFound => 'Aucun résultat pour votre recherche.';

  @override
  String get addHighlight => 'Mettre en surbrillance le verset';

  @override
  String get removeHighlight => 'Retirer la surbrillance';

  @override
  String get showEnglishTranslation => 'Afficher la traduction anglaise';

  @override
  String get showFrenchTranslation => 'Afficher la traduction française';

  @override
  String get showArabicText => 'Afficher le texte arabe';

  @override
  String get showTafsir => 'Afficher le tafsir';

  @override
  String get translationNotAvailable => 'Traduction indisponible pour ce verset.';

  @override
  String get close => 'Fermer';

  @override
  String get selectLabel => 'Choisir';

  @override
  String get selectedLabel => 'Sélectionné';

  @override
  String get refresh => 'Actualiser';

  @override
  String get prayerInternetGpsRequired => 'Internet et GPS sont requis pour afficher les heures de prière.';

  @override
  String get dayColumn => 'Jour';

  @override
  String get imsak => 'Imsak';

  @override
  String get currentVerse => 'Verset actuel';

  @override
  String get share => 'Partager';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get resumeFromLastPosition => 'Reprendre à partir de la dernière position';

  @override
  String get searchTooShort => 'Entrez au moins 2 caractères';

  @override
  String get unknownError => 'Une erreur s\'est produite';

  @override
  String get qiblaTitle => 'Direction de la Qibla';

  @override
  String get qiblaRetry => 'Réessayer';

  @override
  String get qiblaCheckingStatus => 'Vérification des autorisations et capteurs...';

  @override
  String get qiblaTurnUntilArrowUp => 'Tournez jusqu\'à ce que la flèche pointe vers le haut';

  @override
  String get qiblaPermissionRequired => 'L\'autorisation de localisation est requise pour déterminer la qibla.';

  @override
  String get qiblaLocationDisabled => 'Veuillez activer les services de localisation (GPS) pour continuer.';

  @override
  String get qiblaOpenAppSettings => 'Ouvrir les paramètres de l\'application';

  @override
  String get qiblaOpenLocationSettings => 'Ouvrir les paramètres de localisation';

  @override
  String get qiblaSensorNotSupported => 'Cet appareil ne prend pas en charge les capteurs nécessaires au mode boussole.';

  @override
  String get verseOutsideRange => 'Ce verset est en dehors de la plage sélectionnée.';

  @override
  String qiblaAngleLabel(String angle) {
    return 'Angle de la Qibla : $angle°';
  }

  @override
  String get qiblaTipGps => 'Activez le GPS et la haute précision';

  @override
  String get qiblaTipCalibrate => 'Calibrez : mouvement ∞ du téléphone';

  @override
  String get qiblaTipInterference => 'Évitez les interférences métalliques/magnétiques';

  @override
  String get testResultTitle => 'Résultat du test';

  @override
  String get testCongratsTitle => 'Bien joué !';

  @override
  String correctAnswersLabel(int correct, int total) {
    return 'Bonnes réponses : $correct / $total';
  }

  @override
  String percentageLabel(int percent) {
    return 'Pourcentage : $percent%';
  }

  @override
  String earnedScoreLabel(int score) {
    return 'Score obtenu : $score';
  }

  @override
  String get totalScoreLabel => 'Score total';

  @override
  String get endLabel => 'Terminer';

  @override
  String get newTestLabel => 'Nouveau test';

  @override
  String get previousLabel => 'Précédent';

  @override
  String get nextLabel => 'Suivant';

  @override
  String get showResultsLabel => 'Afficher les résultats';

  @override
  String get confirmAnswerLabel => 'Confirmer la réponse';

  @override
  String get exitTestTitle => 'Terminer le test';

  @override
  String get exitTestConfirm => 'Voulez-vous vraiment terminer le test et afficher les résultats ?';

  @override
  String get fontSize => 'Taille de police';

  @override
  String get small => 'Petit';

  @override
  String get medium => 'Moyen';

  @override
  String get large => 'Grand';

  @override
  String get extraLarge => 'Très grand';

  @override
  String get verseRepeatCount => 'Nombre de répétitions du verset';

  @override
  String get verseRepeatCountHint => 'Répétez chaque verset ce nombre de fois pendant la mémorisation.';

  @override
  String get arabicFont => 'Police arabe';

  @override
  String get fontAmiri => 'Amiri Quran';

  @override
  String get fontScheherazade => 'Scheherazade New';

  @override
  String get fontLateef => 'Lateef';

  @override
  String get offlineAudioTitle => 'Audio hors ligne';

  @override
  String reciterLabel(String name) {
    return 'Récitateur : $name';
  }

  @override
  String verseAudiosDownloaded(int count) {
    return 'Audios des versets téléchargés : $count (total ~6236)';
  }

  @override
  String fullSurahsDownloaded(int count) {
    return 'Sourates complètes téléchargées : $count / 114';
  }

  @override
  String get downloadWhy => 'Pourquoi télécharger ? Pour écouter sans internet.';

  @override
  String downloadingProgress(int current, int total) {
    return 'Téléchargement $current / $total';
  }

  @override
  String get downloadVerseAudios => 'Télécharger les audios des versets';

  @override
  String get deleteVerseAudios => 'Supprimer les audios des versets';

  @override
  String get downloadFullSurahs => 'Télécharger les sourates complètes';

  @override
  String get deleteFullSurahs => 'Supprimer les sourates complètes';

  @override
  String get fullSurahLabel => 'Sourates complètes';

  @override
  String get downloadFullSurahNote => 'Note : L\'audio des sourates complètes peut être téléchargé depuis l\'écran Écouter le Coran.';

  @override
  String get name => 'Nom';

  @override
  String get enterYourName => 'Entrez votre nom';

  @override
  String get timeFormatTitle => 'Format de l\'heure';

  @override
  String get twelveHour => '12h';

  @override
  String get twentyFourHour => '24h';

  @override
  String get homeGreetingGeneric => 'Bonjour, que voulez-vous faire ?';

  @override
  String homeGreetingNamed(String name) {
    return 'Bonjour $name, que voulez-vous faire ?';
  }

  @override
  String get hijriHeader => 'Hégirien';

  @override
  String get gregorianHeader => 'Grégorien';

  @override
  String get audioInternetRequired => 'Pas de connexion Internet. Veuillez vous connecter pour lire l’audio ou télécharger les fichiers.';

  @override
  String get editionArabicSimple => 'Arabe (Simple)';

  @override
  String get editionArabicUthmani => 'Arabe (Othmani)';

  @override
  String get editionArabicTajweed => 'Quran Tajweed';

  @override
  String get editionEnglish => 'Anglais';

  @override
  String get editionFrench => 'Français';

  @override
  String get editionTafsir => 'Tafsir (Muyassar)';
}
