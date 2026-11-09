# Ajouts fonctionnels — 5 novembre 2026

Les quatre fonctions sont accessibles dans les paramètres. Tous les nouveaux contrôles et messages sont traduits en arabe, anglais et français.

## Sauvegarde et restauration

- Export d'un fichier JSON portable via la feuille de partage (avec téléchargement de secours sur Web) ; import via le sélecteur de fichiers.
- Favoris audio, ayahs et pages PDF, sourates favorites, actualités sauvegardées, préférences de lecture/répétition, positions, statistiques des tests et révisions espacées.
- Sur mobile, export transactionnel des compteurs de tasbih et du Wird. Ces données restent conservées dans une sauvegarde passée par le Web, même si ces modules n'y sont pas affichés.
- Aperçu de la date et du nombre d'éléments, puis confirmation de remplacement des données sauvegardées. Les identifiants d'installation, jetons, caches GPS/calendriers, fichiers audio et autorisations système ne sont pas transférés.
- Validation du format/version, taille maximale de 10 Mo, types, références coraniques et relations des compteurs avant écriture. Journal de retour arrière et récupération au démarrage après interruption.
- Après restauration, rechargement des préférences, actualisation des notifications et retour à l'accueil pour reconstruire les écrans avec les nouveaux réglages.

## Diagnostic de l'adhan (mobile)

- Prochain horaire attendu parmi les prières activées et les calendriers compatibles disponibles, sur huit jours.
- État des notifications, localisation et disponibilité du calendrier ; alarmes exactes et batterie sur Android ; autorisation sonore et présence de la notification correspondante sur iPhone.
- Actualisation manuelle ou au retour des réglages du téléphone.
- Test du son choisi, volume affiché et bouton d'arrêt. L'écran distingue explicitement ce test immédiat de la livraison d'une alarme en arrière-plan.

## Téléchargements (mobile)

- Conservation des fichiers partiels, reprise HTTP Range, vérification d'intégrité et progrès basés sur les fichiers réellement terminés.
- Suivi persistant des échecs, annulations et interruptions, avec nombre de tentatives et catégorie d'erreur.
- Reprise individuelle ou globale, annulation du transfert actif et progression détaillée des lots.
- Un lot interrompu reste identifiable après fermeture ; les fichiers déjà vérifiés sont réutilisés. Les lots de sourates et d'ayahs possèdent des identifiants distincts.

## Révision espacée (mobile et Web)

- Ajout d'un passage depuis la liste des révisions ou directement depuis la mémorisation par répétition. Bornes validées, y compris entre deux sourates.
- Liste triée par échéance, indication « À réviser », ouverture du passage dans le lecteur de répétition et suppression avec confirmation.
- Auto-évaluation : à revoir, difficile, bien, facile. Première échéance à 1, 1, 3 ou 7 jours ; ensuite remise à 1 jour, multiplication par 1,2, 2 ou 3, avec plafond à 365 jours.
- Dates calculées en jours calendaires ; ajout en double sans effacer la progression ; écritures sérialisées.
- La liste indique les révisions dues dans l'application. Aucun rappel système de révision espacée ni compte de synchronisation cloud n'est ajouté dans ce lot.

## Validation et recette appareil

Les tests couvrent le rejet des sauvegardes invalides avant écriture, le retour arrière, la récupération après interruption, la conservation des données propres à l'appareil, les dates et doublons de révision, le suivi des téléchargements, le prochain adhan et les écrans dans les trois langues.

Les compilations Android debug et Web standard ont réussi pendant la validation. Le build iOS et les essais physiques de sélection/partage de fichier, de restauration des compteurs et de lecture sonore restent à faire sur appareils. Le diagnostic ne garantit pas la livraison d'une alarme si le système la restreint.

Dépendance ajoutée : `file_selector` 1.1.0 et ses implémentations de plateforme. Le verrou de dépendances requiert Flutter 3.47 ou supérieur ; le SDK utilisé pour les builds est déjà compatible.

Résultats : suite complète de 267 tests réussie, puis 17 tests ciblés réussis sur les derniers ajustements et 6 tests du suivi des téléchargements réussis, dont la séparation des deux types de lots. Analyse des derniers fichiers modifiés sans problème ; l’analyse globale conserve uniquement trois suggestions `const` préexistantes après correction du style ajouté. Builds Android debug et Web standard réussis.
