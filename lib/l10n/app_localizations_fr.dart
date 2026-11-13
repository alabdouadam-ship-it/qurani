// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String passageVerseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versets',
      one: '1 verset',
    );
    return '$_temp0';
  }

  @override
  String get passageStartSurah => 'Sourate de début';

  @override
  String get passageStartVerse => 'Verset de début';

  @override
  String get passageEndSurah => 'Sourate de fin';

  @override
  String get passageEndVerse => 'Verset de fin';

  @override
  String get rememberPassage => 'Mémoriser le dernier passage';

  @override
  String get rememberPassageHint => 'Rouvrir ce passage la prochaine fois';

  @override
  String get applyPassage => 'Appliquer';

  @override
  String get passageLoadError => 'Impossible de charger ce passage';

  @override
  String get settings => 'Paramètres';

  @override
  String get about => 'À propos';

  @override
  String get help => 'Aide';

  @override
  String get preferences => 'Préférences';

  @override
  String get shareApp => 'Partager l\'application';

  @override
  String shareAppMessage(Object appUrl) {
    return 'Découvrez Qurani, l’application qui vous aide à interagir avec le Coran : écoute, lecture, mémorisation par répétition, tasbih numérique, direction de la qibla, tests de mémorisation et plus encore. L’application prend en charge l’arabe, l’anglais et le français, avec plusieurs thèmes de couleurs. Téléchargez-la sur Google Play : $appUrl';
  }

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
  String get prayerAdjustmentTooltip => 'Ajuster l\'heure de la prière';

  @override
  String prayerAdjustmentTitle(Object prayerName) {
    return 'Ajuster l\'heure de $prayerName';
  }

  @override
  String get prayerAdjustmentOriginal => 'Heure d\'origine';

  @override
  String shareSurahMessage(String surahName, String reciterName, String url) {
    return 'Écoutez la sourate $surahName par $reciterName : $url';
  }

  @override
  String get shareAyah => 'Partager le verset';

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
  String get prayerMethodSectionTitle => 'Méthode de calcul des heures de prière';

  @override
  String get prayerMethodSectionDesc => 'Choisissez votre méthode préférée ou laissez-la automatique selon votre emplacement';

  @override
  String get prayerMethodAuto => 'Automatique (selon l\'emplacement)';

  @override
  String get prayerMethodChangedDesc => 'Méthode de calcul modifiée, mise à jour des heures';

  @override
  String get method0 => 'Chiite Ithna-Ashari, Institut Leva, Qom';

  @override
  String get method1 => 'Université des Sciences Islamiques, Karachi';

  @override
  String get method2 => 'Société Islamique d\'Amérique du Nord (ISNA)';

  @override
  String get method3 => 'Ligue du Monde Musulman';

  @override
  String get method4 => 'Université Oumm al-Qura, La Mecque';

  @override
  String get method5 => 'Autorité Générale Égyptienne d\'Arpentage';

  @override
  String get method7 => 'Institut de Géophysique, Université de Téhéran';

  @override
  String get method8 => 'Région du Golfe';

  @override
  String get method9 => 'Koweït';

  @override
  String get method10 => 'Qatar';

  @override
  String get method11 => 'Majlis Ugama Islam Singapura, Singapour';

  @override
  String get method12 => 'Union des Organisations Islamiques de France';

  @override
  String get method13 => 'Diyanet İşleri Başkanlığı, Turquie';

  @override
  String get method14 => 'Administration Spirituelle des Musulmans de Russie';

  @override
  String get method15 => 'Comité Mondial d\'Observation du Croissant';

  @override
  String get method16 => 'Dubaï';

  @override
  String get method17 => 'Jabatan Kemajuan Islam Malaysia (JAKIM)';

  @override
  String get method18 => 'Tunisie';

  @override
  String get method19 => 'Algérie';

  @override
  String get method20 => 'Ministère des Affaires Religieuses, Indonésie';

  @override
  String get method21 => 'Maroc';

  @override
  String get method22 => 'Communauté Islamique de Lisbonne';

  @override
  String get method23 => 'Ministère des Waqfs et des Affaires Islamiques, Jordanie';

  @override
  String get adhanSound => 'Son de l\'adhan';

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
  String get bookmarks => 'Marque-pages';

  @override
  String get history => 'Historique';

  @override
  String get downloads => 'Téléchargements';

  @override
  String get memorizationTest => 'Test de mémorisation';

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
  String get searchSurah => 'Rechercher une sourate...';

  @override
  String get repeatSurah => 'Répéter';

  @override
  String get reciter => 'Récitateur';

  @override
  String get theme => 'Thème';

  @override
  String get language => 'Langue';

  @override
  String get tafsir => 'Tafsir';

  @override
  String get selectReciter => 'Sélectionner un récitateur...';

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
  String get pageNumber => 'Numéro de page';

  @override
  String get previousPage => 'Précédente';

  @override
  String get nextPage => 'Suivante';

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
  String searchResultsDetailed(int occurrences, int ayahs) {
    return '$occurrences résultats dans $ayahs versets';
  }

  @override
  String get noResultsFound => 'Aucun résultat pour votre recherche.';

  @override
  String get addHighlight => 'Mettre en surbrillance le verset';

  @override
  String get removeHighlight => 'Retirer la surbrillance';

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
  String get firstAyah => 'Premier verset';

  @override
  String get reciterRotationTitle => 'Rotation de récitateurs';

  @override
  String get reciterRotationDesc => 'Lire chaque répétition d\'un verset avec un récitateur différent, dans l\'ordre, en revenant au premier.';

  @override
  String get reciterRotationAddReciter => 'Ajouter un récitateur';

  @override
  String get reciterRotationEmpty => 'Ajoutez des récitateurs à alterner.';

  @override
  String get reciterRotationRemove => 'Retirer';

  @override
  String reciterRotationPreview(int count, String sequence) {
    return '$count répétitions → $sequence';
  }

  @override
  String get shareUsageStatsTitle => 'Partager des statistiques d\'utilisation anonymes';

  @override
  String get shareUsageStatsSubtitle => 'Aidez à améliorer l\'application en partageant des données anonymes (type d\'appareil, langue, zone approximative — pays et ville, et fonctionnalités utilisées). Aucune information personnelle, localisation précise (coordonnées ou adresse) ni donnée de compte n\'est collectée. Vous pouvez désactiver cela à tout moment.';

  @override
  String get arabicFont => 'Police arabe';

  @override
  String get fontAmiri => 'Amiri Quran';

  @override
  String get offlineAudioTitle => 'Audio hors ligne';

  @override
  String reciterLabel(String name) {
    return 'Récitateur : $name';
  }

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
  String get timeFormatTitle => 'Format de l\'heure';

  @override
  String get twelveHour => '12h';

  @override
  String get twentyFourHour => '24h';

  @override
  String get hijriHeader => 'Hégirien';

  @override
  String get gregorianHeader => 'Grégorien';

  @override
  String get audioInternetRequired => 'Pas de connexion Internet. Veuillez vous connecter pour lire l’audio ou télécharger les fichiers.';

  @override
  String get editionArabicTajweed => 'Quran Tajweed';

  @override
  String get readAutoFlip => 'Tourner automatiquement la page';

  @override
  String get readAutoFlipDesc => 'Tourner automatiquement la page lorsque l\'audio se termine.';

  @override
  String get chooseReciter => 'Choisir le récitateur';

  @override
  String get reciterNotCompatible => 'Récitateur non compatible';

  @override
  String get reciterNotAvailableForFullSurahs => 'Les fichiers audio des sourates complètes ne sont pas disponibles pour ce récitateur. Veuillez choisir un autre récitateur.';

  @override
  String reciterNotAvailableForVerses(Object reciterName) {
    return 'Les fichiers audio verset par verset ne sont pas disponibles pour le récitateur $reciterName. Veuillez choisir un autre récitateur.';
  }

  @override
  String get rangeRepeatCount => 'Nombre de répétitions de la plage';

  @override
  String get startAtLastPage => 'Commencer à la dernière page';

  @override
  String get startAtLastPageDesc => 'Si activé, reprendre la lecture à la dernière page visitée.';

  @override
  String get alwaysStartFromBeginning => 'Toujours commencer au début';

  @override
  String get alwaysStartFromBeginningDesc => 'Si activé, la lecture commence toujours au premier verset. Si désactivé, elle reprend à la dernière position.';

  @override
  String get downloadingMushaf => 'Téléchargement du Mushaf...';

  @override
  String get downloadMushafPdf => 'Télécharger le PDF du Mushaf';

  @override
  String get chooseStyleToDownload => 'Choisissez un style à télécharger :';

  @override
  String get returnToTextView => 'Retour à la vue texte';

  @override
  String get errorLoadingPdf => 'Erreur de chargement du fichier PDF';

  @override
  String get deleteAndRetry => 'Supprimer et réessayer';

  @override
  String get mushafTypeBlue => 'Mushaf Bleu (Shamarly)';

  @override
  String get mushafTypeGreen => 'Mushaf Vert';

  @override
  String get mushafTypeTajweed => 'Mushaf Tajwid';

  @override
  String get mushafStyle => 'Style de Mushaf';

  @override
  String get allQuran => 'Tout le Coran';

  @override
  String get filterBySurah => 'Sourate';

  @override
  String get downloadConfirmation => 'Confirmation de téléchargement';

  @override
  String downloadConfirmationMsg(String mushafName) {
    return 'Voulez-vous télécharger le $mushafName ?';
  }

  @override
  String get downloadFailedReverting => 'Le téléchargement a échoué, retour à l\'édition précédente.';

  @override
  String get bookmarkPage => 'Marquer la page';

  @override
  String get removeBookmark => 'Retirer le marque-page';

  @override
  String get noBookmarks => 'Aucun marque-page';

  @override
  String get colorDefault => 'Défaut (Crème)';

  @override
  String get colorRed => 'Rouge';

  @override
  String get colorBlue => 'Bleu';

  @override
  String get colorGreen => 'Vert';

  @override
  String get groupMyAzkar => 'Mes Adhkar';

  @override
  String get groupMorning => 'Adhkar du Matin';

  @override
  String get groupEvening => 'Adhkar du Soir';

  @override
  String get groupPostPrayerGeneral => 'Adhkar après la prière (Général)';

  @override
  String get groupPostPrayerFajrMaghrib => 'Adhkar Fajr et Maghrib';

  @override
  String get groupFriday => 'Adhkar du Vendredi';

  @override
  String get groupSleep => 'Adhkar du Sommeil';

  @override
  String get groupWaking => 'Adhkar du Réveil';

  @override
  String get createNewGroup => 'Créer un nouveau groupe';

  @override
  String get enterGroupName => 'Entrez le nom du groupe';

  @override
  String get addGroup => 'Ajouter un groupe';

  @override
  String get deleteGroup => 'Supprimer le groupe';

  @override
  String get deleteGroupConfirmation => 'Voulez-vous vraiment supprimer ce groupe et tous ses adhkars ?';

  @override
  String get resetGroup => 'Réinitialiser le groupe';

  @override
  String get addAzkar => 'Ajouter un Adhkar';

  @override
  String get enterAzkar => 'Entrez le texte de l\'Adhkar';

  @override
  String get resetAll => 'Tout réinitialiser';

  @override
  String get delete => 'Supprimer';

  @override
  String get resetGroupConfirmation => 'Voulez-vous vraiment réinitialiser les compteurs de ce groupe ?';

  @override
  String get bookmarkSaved => 'Marque-page enregistré';

  @override
  String get hadithLibrary => 'Bibliothèque Hadith';

  @override
  String get sahihain => 'Les Deux Sahihs';

  @override
  String get sunan => 'Les Sunan';

  @override
  String get others => 'Autres Livres';

  @override
  String get downloadBook => 'Télécharger le livre';

  @override
  String get bookNotAvailable => 'Ce livre n\'est pas disponible localement. Voulez-vous le télécharger ?';

  @override
  String get downloading => 'Téléchargement...';

  @override
  String get open => 'Ouvrir';

  @override
  String get booksInArabic => 'Livres en arabe';

  @override
  String get booksInEnglish => 'Livres en anglais';

  @override
  String get booksInFrench => 'Livres en français';

  @override
  String get shareHadithFooter => 'Partagé depuis l\'application Qurani\nhttps://www.qurani.info/';

  @override
  String get loadingBook => 'Chargement du contenu du livre...';

  @override
  String get book => 'Livre';

  @override
  String get grade => 'Grade';

  @override
  String get enterHadithNumber => 'Entrez le numéro du Hadith';

  @override
  String get hadithHiddenOrNotFound => 'Hadith caché ou introuvable';

  @override
  String get noReadableContent => 'Aucun contenu lisible trouvé dans ce livre.';

  @override
  String get chapterStartNotFound => 'Début du chapitre introuvable dans les hadiths visibles';

  @override
  String get generalHadiths => 'Hadiths Généraux';

  @override
  String get chapters => 'Chapitres';

  @override
  String get allChapters => 'Tous les Chapitres';

  @override
  String get goButton => 'Aller';

  @override
  String get newsAndNotifications => 'Actualités et Notifications';

  @override
  String get bookUnavailableMessage => 'Il semble que le livre ne soit pas disponible pour le moment, veuillez revenir plus tard, nous nous efforcerons de le rendre disponible.';

  @override
  String get downloadOurApp => 'Téléchargez notre application';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get appStore => 'App Store';

  @override
  String get searchLanguageArabic => 'Texte Arabe';

  @override
  String get searchLanguageEnglish => 'Texte Anglais';

  @override
  String get searchLanguageFrench => 'Texte Français';

  @override
  String get save => 'Enregistrer';

  @override
  String get testSettingsTitle => 'Paramètres du test';

  @override
  String get maxQuestionsLabel => 'Questions maximum';

  @override
  String get fileSize => 'Taille du fichier';

  @override
  String get showMore => 'Voir plus';

  @override
  String get showLess => 'Voir moins';

  @override
  String get noNewsYet => 'Il n\'y a pas encore de notifications ou de nouvelles';

  @override
  String get newsTabAll => 'Tout';

  @override
  String get newsTabSaved => 'Enregistré';

  @override
  String get noSavedNews => 'Aucune nouvelle enregistrée';

  @override
  String get noNewsAtTheMoment => 'Aucune nouvelle pour le moment';

  @override
  String get newsSource => 'Source';

  @override
  String get newItemBadge => 'NOUVEAU';

  @override
  String get editionIrab => 'I\'rab du Coran (Grammaire)';

  @override
  String get irabDataNotAvailable => 'Les données I\'rab ne sont pas disponibles localement. Voulez-vous les télécharger ?';

  @override
  String get irabDownloading => 'Téléchargement des données I\'rab...';

  @override
  String get irabLoading => 'Chargement des données I\'rab...';

  @override
  String get noSurahsAvailable => 'Aucune sourate disponible';

  @override
  String get noQuestionsAvailable => 'Aucune question disponible';

  @override
  String testErrorGeneric(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get startTestButton => 'Démarrer le test';

  @override
  String get statisticsTitle => 'Statistiques';

  @override
  String get juzTabarak => 'Juz Tabarak';

  @override
  String get juzAmma => 'Juz Amma';

  @override
  String deleteAzkarConfirmation(Object text) {
    return 'Voulez-vous supprimer cet adhkar ?\n$text';
  }

  @override
  String get resetAllConfirmation => 'Tous les compteurs de tous les groupes seront réinitialisés.';

  @override
  String get noAzkarInGroup => 'Aucun adhkar dans ce groupe. Touchez le menu pour en ajouter un.';

  @override
  String get sessionLabel => 'Session';

  @override
  String get totalLabel => 'Total';

  @override
  String get resetSessionTooltip => 'Réinitialiser la session';

  @override
  String get memorizationStatsTitle => 'Statistiques des tests';

  @override
  String get clearStatsTitle => 'Effacer les statistiques';

  @override
  String get clearStatsConfirmation => 'Voulez-vous vraiment effacer toutes les statistiques ?';

  @override
  String get noStats => 'Aucune statistique disponible';

  @override
  String get totalScoreHeader => 'Score cumulé';

  @override
  String get totalTestsLabel => 'Nombre de tests';

  @override
  String get surahTab => 'Sourates';

  @override
  String get juzTab => 'Juz';

  @override
  String get surahMasteryHeader => 'Maîtrise par sourate';

  @override
  String get recentTestsHeader => 'Tests récents';

  @override
  String pointsSuffix(int n) {
    return '$n points';
  }

  @override
  String get statsNoDataYet => 'Aucun test pour l\'instant';

  @override
  String get statsMixedSelection => 'Sélection mixte';

  @override
  String get statsAggLegend => '× tests · % dernier score';

  @override
  String minutesAgo(int n) {
    return 'il y a $n min';
  }

  @override
  String hoursAgo(int n) {
    return 'il y a $n h';
  }

  @override
  String daysAgo(int n) {
    return 'il y a $n j';
  }

  @override
  String get refreshList => 'Actualiser la liste';

  @override
  String get memorizationTestDescription => 'Choisissez les sourates ou les juz et lancez votre test dans une interface plus claire et mieux organisée.';

  @override
  String get tasbeehDescription => 'Vos adhkar et groupes quotidiens dans une interface plus sereine et plus claire.';

  @override
  String get searchQuranDescription => 'Recherchez rapidement dans le Coran avec aperçu audio et filtres par langue.';

  @override
  String memorizationQNextAyah(Object surahName, Object ayahText) {
    return 'Dans $surahName\nQuel verset vient après le suivant ?\n$ayahText';
  }

  @override
  String memorizationQCompleteAyah(Object surahName, Object ayahPrefix) {
    return 'Dans $surahName\nComplétez la parole divine :\n$ayahPrefix...';
  }

  @override
  String memorizationQSurahNumber(Object surahName) {
    return 'Quel est le numéro de $surahName dans le Saint Coran ?';
  }

  @override
  String memorizationQSurahAyahCount(Object surahName) {
    return 'Combien de versets contient $surahName ?';
  }

  @override
  String get surahMasteryHelp => 'La maîtrise correspond au pourcentage moyen de bonnes réponses à tous les tests que vous avez passés pour cette sourate.';

  @override
  String get surahMasteryHelpTooltip => 'Que signifie la maîtrise ?';

  @override
  String surahNamePrefix(int number) {
    return 'Sourate $number';
  }

  @override
  String get surahLongPressHint => 'Appui long pour plus d\'actions';

  @override
  String get exactAlarmNeededTitle => 'Alarmes exactes désactivées';

  @override
  String get exactAlarmNeededBody => 'L\'adhan peut être retardé jusqu\'à 15 minutes. Activez les alarmes exactes dans les paramètres pour une lecture précise.';

  @override
  String get openSettingsAction => 'Ouvrir les paramètres';

  @override
  String get testResultHeadlineExcellent => 'Excellent !';

  @override
  String get testResultSubExcellent => 'Maîtrise remarquable — continuez à ce niveau.';

  @override
  String get testResultHeadlineGood => 'Bien joué !';

  @override
  String get testResultSubGood => 'Excellent résultat — quelques révisions et ce sera parfait.';

  @override
  String get testResultHeadlineOk => 'Bien !';

  @override
  String get testResultSubOk => 'Continuez à réviser — vos progrès sont évidents.';

  @override
  String get testResultHeadlineEffort => 'Continuez !';

  @override
  String get testResultSubEffort => 'L\'effort fait la différence — refaites le test après avoir révisé les erreurs.';

  @override
  String get currentTestResult => 'Résultat du test actuel';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get downloadPaused => 'Téléchargement en pause';

  @override
  String integrityVerified(int count, int total) {
    return '$count sur $total vérifiés';
  }

  @override
  String integrityCorrupt(int count) {
    return '$count corrompu(s)';
  }

  @override
  String integrityMissing(int count) {
    return '$count manquant(s)';
  }

  @override
  String get repairCorruptFiles => 'Réparer';

  @override
  String get repairing => 'Réparation…';

  @override
  String repairCompleted(int count) {
    return '$count fichier(s) réparé(s). Reprenez le téléchargement pour les retélécharger.';
  }

  @override
  String integrityAllVerified(int total) {
    return 'Les $total sourates sont vérifiées';
  }

  @override
  String errorLoadingBook(String error) {
    return 'Échec du chargement du livre : $error';
  }

  @override
  String get noChaptersAvailable => 'Aucun chapitre disponible';

  @override
  String get tasbeehTabLabel => 'Tasbih';

  @override
  String get wirdTabLabel => 'Wird';

  @override
  String get wirdAddTitle => 'Ajouter un wird';

  @override
  String get wirdEditTitle => 'Modifier le wird';

  @override
  String get wirdFieldTitle => 'Titre';

  @override
  String get wirdFieldDhikrText => 'Dhikr';

  @override
  String get wirdFieldTargetCount => 'Objectif';

  @override
  String get wirdFieldDaysOfWeek => 'Jours';

  @override
  String get wirdAllDays => 'Tous les jours';

  @override
  String get dayMonday => 'Lundi';

  @override
  String get dayTuesday => 'Mardi';

  @override
  String get dayWednesday => 'Mercredi';

  @override
  String get dayThursday => 'Jeudi';

  @override
  String get dayFriday => 'Vendredi';

  @override
  String get daySaturday => 'Samedi';

  @override
  String get daySunday => 'Dimanche';

  @override
  String get wirdRemindMe => 'Me rappeler';

  @override
  String get wirdReminderTime => 'Heure du rappel';

  @override
  String get wirdDeleteConfirm => 'Supprimer ce wird ?';

  @override
  String get wirdStart => 'Commencer';

  @override
  String get wirdResume => 'Reprendre';

  @override
  String get wirdAllScreenTitle => 'Tous les wirds';

  @override
  String get wirdAllEmptyTitle => 'Aucun wird créé pour l’instant';

  @override
  String get wirdFilterToday => 'Du jour';

  @override
  String get wirdFilterAll => 'Tous';

  @override
  String get wirdSendTest => 'Tester';

  @override
  String get wirdTestSent => 'Notification de test envoyée. Si vous ne la voyez pas, vérifiez les paramètres de notification système pour cette application.';

  @override
  String get wirdTestPermissionDenied => 'Les notifications ne sont pas autorisées pour cette application. Activez-les dans les paramètres système.';

  @override
  String get wirdTestFailed => 'Impossible d\'envoyer la notification de test. Veuillez réessayer.';

  @override
  String get wirdExactAlarmDenied => 'Les rappels sont activés mais peuvent être retardés. Pour une livraison à l\'heure, autorisez « Alarmes et rappels » pour cette application dans les paramètres système.';

  @override
  String wirdProgressFraction(int current, int target) {
    return '$current / $target';
  }

  @override
  String get wirdCompletedToast => 'MashaAllah — wird terminé !';

  @override
  String get wirdCompletedBadge => 'Fait';

  @override
  String get wirdTodayEmptyTitle => 'Aucun wird prévu aujourd\'hui';

  @override
  String get wirdTodayEmptyHint => 'Ajoutez-en un avec le bouton +, ou modifiez les jours d\'un wird existant.';

  @override
  String get wirdSectionTitle => 'Wird du jour';

  @override
  String get wirdTabSubtitle => 'Vos adhkar quotidiens avec de doux rappels.';

  @override
  String get wirdValidationTitleRequired => 'Veuillez saisir un titre';

  @override
  String get wirdValidationDaysRequired => 'Choisissez au moins un jour';

  @override
  String get wirdValidationTargetInvalid => 'L\'objectif doit être entre 1 et 9999';

  @override
  String get wirdExitFocus => 'Terminer la session';

  @override
  String get wirdFocusHintTap => 'Touchez n\'importe où pour compter';

  @override
  String get wirdResetProgress => 'Réinitialiser la progression';

  @override
  String get hadithSearchHint => 'Entrez du texte pour rechercher ou sélectionnez un chapitre';

  @override
  String get hadithNoMatches => 'Aucun résultat trouvé';

  @override
  String get editionTitle => 'Édition';

  @override
  String get editionTranslationsCategory => 'Traductions';

  @override
  String get editionTafsirCategory => 'Tafsir';

  @override
  String get editionTurkish => 'Turc';

  @override
  String get editionGerman => 'Allemand';

  @override
  String get secondaryEditionTitle => 'Édition secondaire';

  @override
  String get secondaryEditionDesc => 'Ajouter à chaque verset une flèche qui ouvre une seconde édition.';

  @override
  String get secondaryEditionChoose => 'Choisir l\'édition';

  @override
  String get secondaryEditionFallback => 'Édition de remplacement';

  @override
  String get secondaryEditionFallbackDesc => 'utilisée lorsque l\'édition secondaire est celle que vous lisez';

  @override
  String get secondaryEditionShow => 'Afficher l\'édition secondaire';

  @override
  String get secondaryEditionHide => 'Masquer l\'édition secondaire';

  @override
  String get memorizationIncompleteData => 'Le passage n’a pas pu être chargé entièrement. Vérifiez votre connexion et réessayez.';

  @override
  String downloadIncomplete(int completed, int total, int failed) {
    return 'Téléchargement incomplet : $completed/$total fichiers vérifiés ; $failed échecs. Relancez pour récupérer les fichiers manquants.';
  }

  @override
  String get downloadCancelled => 'Téléchargement annulé. Les fichiers terminés ont été conservés.';

  @override
  String get aboutWebDescription => 'Qurani Web propose la lecture du Coran, l’écoute en ligne, la recherche, la mémorisation par répétition, les tests, les horaires de prière et les favoris en arabe, anglais et français. L’adhan en arrière-plan, la qibla, le tasbih, les rappels du Wird et les téléchargements audio hors ligne sont disponibles dans l’application mobile.';

  @override
  String get backupTitle => 'Sauvegarde et restauration';

  @override
  String get backupDescription => 'Exportez vos favoris, paramètres, statistiques, révisions, tasbih et Wird. Les fichiers audio et les autorisations du téléphone ne sont pas inclus.';

  @override
  String get backupExport => 'Exporter une sauvegarde';

  @override
  String get backupImport => 'Choisir un fichier à restaurer';

  @override
  String backupConfirm(String date, int count) {
    return 'Cette sauvegarde du $date contient $count éléments. Elle remplacera les favoris, paramètres et progressions sauvegardés sur cet appareil. Continuer ?';
  }

  @override
  String get backupRestore => 'Restaurer';

  @override
  String get backupDone => 'Sauvegarde restaurée.';

  @override
  String get backupInvalid => 'Fichier incompatible ou invalide. Aucune donnée n’a été importée.';

  @override
  String get backupFailed => 'L’opération a échoué. Réessayez.';

  @override
  String get backupScheduleWarning => 'Données restaurées. Vérifiez les horaires et autorisations dans le diagnostic de l’adhan.';

  @override
  String get adhanDiagnosticTitle => 'Diagnostic de l’adhan';

  @override
  String get adhanNextExpected => 'Prochain adhan prévu';

  @override
  String get adhanNoNext => 'Aucun horaire futur disponible pour les prières activées.';

  @override
  String get adhanDiagnosticNote => 'L’heure prévue utilise les horaires enregistrés et vos réglages. Le système peut limiter les alarmes en arrière-plan. Le test sonore vérifie uniquement la lecture immédiate.';

  @override
  String get diagnosticNotifications => 'Autorisation des notifications';

  @override
  String get diagnosticSound => 'Son des notifications iPhone';

  @override
  String get diagnosticExact => 'Alarmes exactes Android';

  @override
  String get diagnosticBattery => 'Exemption d’optimisation de batterie';

  @override
  String get diagnosticLocation => 'Autorisation de localisation';

  @override
  String get diagnosticLocationService => 'Service de localisation activé';

  @override
  String get diagnosticCalendar => 'Horaires compatibles disponibles';

  @override
  String get diagnosticPending => 'Notification iPhone programmée';

  @override
  String diagnosticEnabled(int count) {
    return 'Prières activées : $count';
  }

  @override
  String diagnosticVolume(int percent) {
    return 'Volume de l’adhan : $percent %';
  }

  @override
  String get diagnosticYes => 'Oui';

  @override
  String get diagnosticNo => 'Non';

  @override
  String get diagnosticUnknown => 'Non disponible';

  @override
  String get diagnosticSettings => 'Ouvrir les réglages du téléphone';

  @override
  String get diagnosticTest => 'Tester le son';

  @override
  String get diagnosticStop => 'Arrêter le test';

  @override
  String get diagnosticRefresh => 'Actualiser';

  @override
  String get downloadIssuesTitle => 'Téléchargements à reprendre';

  @override
  String get downloadIssuesEmpty => 'Aucun téléchargement en échec ou interrompu.';

  @override
  String get downloadRetryAll => 'Reprendre tous les éléments';

  @override
  String get downloadRetry => 'Reprendre';

  @override
  String get downloadIssueFailed => 'Échec';

  @override
  String get downloadIssueCancelled => 'Annulé';

  @override
  String get downloadIssueInterrupted => 'Interrompu';

  @override
  String get downloadIssueActive => 'En cours';

  @override
  String downloadIssueAttempts(int count) {
    return 'Tentatives : $count';
  }

  @override
  String get downloadReasonNetwork => 'Connexion indisponible ou délai dépassé';

  @override
  String get downloadReasonServer => 'Le serveur n’a pas fourni le fichier';

  @override
  String get downloadReasonFile => 'Fichier indisponible, invalide ou impossible à enregistrer';

  @override
  String get reviewTitle => 'Révision espacée';

  @override
  String get reviewDescription => 'Ajoutez les passages mémorisés. Révisez-les, puis évaluez votre rappel pour programmer la prochaine révision.';

  @override
  String get reviewAdd => 'Ajouter un passage';

  @override
  String get reviewAddCurrent => 'Ajouter ce passage aux révisions';

  @override
  String get reviewAdded => 'Passage ajouté aux révisions.';

  @override
  String get reviewEmpty => 'Aucun passage à réviser pour le moment.';

  @override
  String get reviewDue => 'À réviser';

  @override
  String reviewNext(String date) {
    return 'Prochaine révision : $date';
  }

  @override
  String get reviewOpen => 'Ouvrir le passage';

  @override
  String get reviewRate => 'Évaluer ma révision';

  @override
  String get reviewAgain => 'À revoir';

  @override
  String get reviewHard => 'Difficile';

  @override
  String get reviewGood => 'Bien';

  @override
  String get reviewEasy => 'Facile';

  @override
  String get reviewRemove => 'Retirer ce passage des révisions ?';

  @override
  String reviewPassage(int startSurah, int startVerse, int endSurah, int endVerse) {
    return 'Sourate $startSurah, verset $startVerse → sourate $endSurah, verset $endVerse';
  }

  @override
  String get downloadBatchLabel => 'Téléchargement complet';
}
