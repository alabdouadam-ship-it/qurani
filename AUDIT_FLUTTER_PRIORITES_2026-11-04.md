# Audit Flutter — Android, iPhone et Web

Date : 4 novembre 2026. Base examinée : `55ae459`.

## Portée et niveau de preuve

Revue transversale du démarrage, des services natifs/Web, lecture coranique, audio, répétition, exercices de mémorisation, recherche, prières/adhan, notifications, téléchargements, préférences, actualités et traductions. Les fichiers natifs et les dépendances installées ont également été consultés pour les notifications.

Ce document distingue les défauts établis par lecture du chemin d'exécution, les comportements reproduits avec données simulées et les risques nécessitant un appareil. Il ne constitue pas une certification de tous les comportements possibles. Aucun correctif fonctionnel n'a été appliqué pendant cet audit.

Vérifications exécutées :

- Suite existante : **181 tests réussis** (`build/mobile_full_scan_tests.txt`).
- Analyse `lib`, `test`, `tool` : **4 avertissements** `unawaited_return_in_try_block`, **3 informations** `prefer_const_constructors`, aucune erreur statique (`build/mobile_full_scan_analysis.txt`).
- Trois sondes complémentaires réussies : elles reproduisent les défauts actuels, elles ne signifient pas que ces défauts sont corrigés (`build/audit_regression_probe_test.dart`, `build/audit_regression_probe.txt`).
- AR/EN/FR : **450 clés par langue**, aucune clé manquante entre les trois catalogues. Cela ne garantit ni la qualité sémantique de chaque traduction ni l'absence de chaînes hors catalogues.
- Base coranique : **114 sourates, 6 236 ayahs** ; les 13 colonnes de textes examinées ne contiennent pas de texte nul ou vide. Contrôle structurel uniquement, pas validation éditoriale/religieuse des textes.
- Les cinq extraits audio iOS ont été inspectés par `ffprobe` : format MP3, durées de 21 à 29,1 secondes.

Pas d'exécution sur iPhone ni de validation physique des alarmes Android pendant cet audit. Les builds Android/Web précédemment réussis ne remplacent pas ces tests. Les sondes et journaux restent dans `build/`, ignoré par Git.

## Priorité 1 — fiabilité des fonctions essentielles

### F01 — Horaires conservés après un changement de ville

**Preuve : chemin de code établi. Plateformes : mobile.**

`lib/prayer_times_screen.dart:188` et `lib/services/prayer_times_service_io.dart:467`.

L'écran vérifie la présence des mois précédent/courant/suivant avant de décider de télécharger. Si les trois existent, il peut réutiliser les horaires sans vérifier leur correspondance avec la position actuelle. Le nom de ville est, lui, susceptible d'être mis à jour. Le rafraîchissement de lancement quitte aussi immédiatement si le dernier succès date de moins de dix jours.

**Scénario :** charger les trois mois dans la ville A, voyager dans la ville B et rouvrir les prières avant dix jours. Les données de A peuvent rester utilisées avec une indication de B.

**Correction :** associer explicitement chaque calendrier à sa position de référence, sa méthode et son fuseau ; contrôler cette identité avant utilisation. Un changement significatif doit invalider/recalculer les horaires et la programmation correspondante. Conserver un repli hors ligne, mais indiquer clairement sa ville et son ancienneté.

### F02 — Un calendrier vieillissant peut être marqué « récent » sans téléchargement

**Preuve : chemin de code établi. Plateformes : service natif et équivalent Web.**

`lib/services/prayer_times_service_io.dart:473`.

Après dix jours, le chemin « déplacement inférieur à 2 km » met à jour `prayer_last_success` sans vérifier la couverture des mois ni télécharger. À chaque passage, il repousse ainsi l'âge du cache ; le seuil de soixante jours peut ne jamais être atteint. Un utilisateur stationnaire qui ouvre régulièrement l'accueil peut finir sans calendrier pour les dates à venir. L'ouverture de l'écran des prières peut réparer les mois manquants, mais le service de lancement ne le garantit pas.

**Correction :** séparer date de vérification et date de téléchargement ; vérifier la présence de toutes les dates nécessaires à la prochaine programmation avant de prendre le raccourci GPS.

### F03 — Adhan au premier plan trop tôt, puis calendrier périmé après minuit

**Preuve : conditions explicites dans le code. Plateformes : mobile.**

`lib/services/global_adhan_service.dart:97` et `:136`.

- La différence avec l'heure de prière utilise `.abs()` puis `<= 30`. Elle autorise donc le déclenchement avant l'heure, dans une fenêtre d'environ trente secondes.
- Le changement de jour est traité dans `_loadTodayTimes`, mais la boucle périodique ne rappelle cette méthode que si les horaires sont nuls. Si l'application reste au premier plan pendant minuit, elle peut conserver la journée précédente.

**Correction :** interdire tout déclenchement anticipé ; injecter une horloge pour tester les limites temporelles ; recharger au changement de date et après modification du calendrier. Tester aussi la coordination avec les autres moteurs d'adhan.

### F04 — Alarmes audio Android non persistantes au redémarrage

**Preuve : appel applicatif et valeur par défaut de la dépendance installée.**

`lib/services/adhan_scheduler_io.dart:457` appelle `AndroidAlarmManager.oneShotAt` sans `rescheduleOnReboot`. Dans `android_alarm_manager_plus 5.0.0`, cette option vaut `false` par défaut.

**Impact :** les alarmes de lecture audio peuvent disparaître après redémarrage jusqu'à une nouvelle programmation. Une notification éventuellement restaurée par l'autre plugin ne garantit pas la restauration de l'audio complet.

**Correction :** définir une stratégie de restauration au redémarrage et vérifier ses prérequis natifs ; tester téléphone redémarré, application non rouverte, écran verrouillé et économie d'énergie. Ne pas considérer la seule présence d'un receiver dans le manifeste comme preuve suffisante.

### F05 — iPhone : renouvellement incomplet et formats des sons à corriger

**Preuve : code et inspection des fichiers ; résultat final à valider sur iPhone.**

- `lib/main.dart:177` : la passe de programmation sur sept jours au démarrage est limitée à Android. Un utilisateur iPhone qui ouvre l'accueil sans retourner aux prières ne bénéficie pas de ce renouvellement quotidien. Le rafraîchissement occasionnel du calendrier n'offre pas une garantie équivalente.
- `lib/services/adhan_scheduler_io.dart:479` : chaque programmation journalière annule tous les timers du premier plan. La boucle sur les jours suivants de `lib/prayer_times_screen.dart:557` peut donc effacer ceux du jour. Le moniteur global reste un autre chemin de déclenchement : ce défaut ne prouve pas un silence systématique.
- `lib/services/notification_service_io.dart:340` : les sons fournis au système sont des `*-ios.mp3`. Leur durée est correcte, mais le conteneur MP3 ne fait pas partie des formats de sons de notification documentés par Apple. Utiliser un format/codec compatible, puis tester une notification réelle. [Documentation Apple](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SupportingNotificationsinYourApp.html).
- `lib/services/notification_service_io.dart:304` : si le fichier personnalisé manque, `presentSound` devient faux ; le repli est silencieux, alors que le commentaire annonce un son système.

**Correction :** renouveler la fenêtre iOS lors des occasions pertinentes, programmer les timers en une passe, convertir les extraits et expliciter le comportement de repli. Une notification sonore iOS et une lecture audio complète au premier plan sont deux capacités distinctes à présenter correctement.

### F06 — Une page manquante peut créer une question de mémorisation incorrecte

**Preuve : chemin d'erreur établi, scénario réseau non reproduit dans l'interface.**

`lib/services/memorization_test_service.dart:24` et `:67`.

Le chargement d'un juz ignore une page qui échoue et poursuit avec les suivantes. La génération « quelle ayah vient après ? » prend ensuite l'élément suivant de cette liste, sans vérifier la continuité des numéros. Une lacune de chargement peut être transformée en réponse pédagogique fausse. Le Web est particulièrement concerné par des chargements réseau partiels.

**Correction :** refuser une série incomplète ou vérifier explicitement la continuité avant chaque question ; proposer une nouvelle tentative localisée. Ajouter un test avec une page intermédiaire absente.

### F07 — Réponse de calendrier incomplète : assertion nulle ; réponse invalide : minuit artificiel

**Preuve : reproduit sur le service Web avec données simulées ; même construction fragile repérée dans le service natif.**

`lib/services/prayer_times_service_web.dart:105` ; `lib/services/prayer_times_service_io.dart:146`.

Une valeur Fajr absente atteint `parse('Fajr')!` et lève une erreur. Une valeur `xx:yy` devient 00:00 à cause de `int.tryParse(...) ?? 0`. Les sondes confirment ces deux comportements. Le résultat utilisateur dépend du `catch` appelant : ce n'est pas la preuve d'un écran rouge dans tous les cas. L'écran des prières étant masqué sur Web, la sonde Web sert à vérifier le parseur, pas à prétendre reproduire un parcours Web public.

**Correction :** valider structure, type, heures et minutes avant mise en cache ; retourner une erreur métier exploitable ; ne jamais fabriquer une heure de prière par défaut à zéro.

### F08 — Lecture audio susceptible de réappliquer une ancienne sélection

**Preuve : risque de concurrence identifié ; test réseau lent sur interface restant à faire.**

`lib/audio_player_screen.dart:324` et `:356`.

`_playSurah` incrémente une génération, mais la chaîne de chargement de cette méthode et de `_loadAndPlaySurah` ne vérifie pas systématiquement cette génération après les attentes. Une opération A lente, puis une sélection B, peuvent laisser A remplacer les sources ou lancer une nouvelle tentative après B.

**Correction :** propager un identifiant de requête jusqu'au changement des sources, au lancement et aux retries ; vérifier aussi la destruction du lecteur. Tester changements rapides de sourate/récitateur sous réseau ralenti. Les protections déjà présentes dans d'autres chemins audio sont à conserver et à étendre.

## Priorité 2 — cohérence, robustesse et expérience utilisateur

| Référence | Constat et preuve | Action recommandée |
|---|---|---|
| F09 — Catalogue récitateurs | `lib/services/reciter_config_service.dart:160` fusionne toujours les récitateurs embarqués avec le catalogue distant/cache. Sonde : un cache valide contenant uniquement un récitant de test produit tout de même 32 récitateurs embarqués supplémentaires. Un retrait/désactivation distant d'un récitant embarqué ne suffit donc pas à le retirer du choix mobile. | Séparer catalogue visible et résolution des anciens choix ; distinguer réponse distante vide volontaire et échec réseau. |
| F10 — Téléchargements | `lib/services/offline_audio_service_io.dart:88` compte une ayah avant la fin du téléchargement ; plusieurs erreurs sont absorbées ; `:137` marque le téléchargement complet même après des échecs. L'annulation vérifie la boucle sans transmettre son jeton à la requête active. | Compter les succès réellement écrits, montrer succès/échecs, permettre reprise et annulation effective. |
| F11 — Recherche | `lib/search_quran_screen.dart:78` ne possède pas de génération de recherche. Les changements de filtre et soumissions peuvent lancer des requêtes dont les résultats arrivent dans un ordre différent. | Ignorer les résultats périmés ; tester deux requêtes à délais inversés et l'effacement de la recherche. |
| F12 — Exceptions asynchrones | Les quatre avertissements de l'analyseur concernent `audio_service_io.dart:137`, `prayer_times_service_io.dart:113`, `prayer_times_service_web.dart:67`, `quran_repository_io.dart:215`. Retourner une Future sans l'attendre dans ces blocs laisse ses erreurs asynchrones échapper au `catch` local. | Examiner chaque intention de repli/retry puis utiliser `return await` lorsque le `catch` doit traiter l'erreur. Ne pas assimiler ces avertissements à quatre plantages déjà observés. |
| F13 — Navigation de notification iOS | `lib/main.dart:115` limite à Android l'installation du gestionnaire de clic ouvrant le Wird, lancement à froid compris. | Installer le routage mobile sur les deux plateformes et tester les deux états de l'application. |
| F14 — Permission d'alarme Android | `lib/services/notification_permissions.dart:50` ignore tout appareil avant API 33 pour les deux permissions. L'accès spécial aux alarmes exactes existe dès Android 12/API 31. Le contrôle explicite de l'écran des prières apporte une récupération partielle. | Séparer les conditions API des notifications et des alarmes exactes ; tester notamment une autorisation révoquée sur Android 12/12L. [Documentation Android](https://developer.android.com/about/versions/12/behavior-changes-12). |
| F15 — Erreurs silencieuses des prières | Le chargement absorbe certaines erreurs et retire le chargement sans explication utile ; les lectures concurrentes utilisent aussi une date d'écran mutable. | Capturer la date de la requête, refuser les résultats périmés, afficher un message AR/EN/FR et un bouton Réessayer. |
| F16 — Promesse Web | `lib/options_screen.dart` masque volontairement prières, qibla et plusieurs modules natifs. Les métadonnées de `web/index.html` annoncent pourtant notamment prières/adhan/qibla et hors ligne. | Définir la matrice de disponibilité et aligner les textes Web. Ne pas présenter les branches natives volontairement exclues comme du code mort. |

## Localisation AR / EN / FR

La structure des catalogues est cohérente ; les textes écrits hors de ceux-ci restent à terminer :

- `lib/news_notifications_screen.dart:129` : infobulle « Text Size ».
- `lib/hadith_books_screen.dart:203` : « Error: … » et exposition directe d'une erreur technique.
- `lib/local_webview_screen_web.dart:91` : « Failed to load content ».
- Titres audio utilisant littéralement « Ayah » dans le lecteur et la recherche.
- Quelques boutons « OK » codés directement dans les dialogues.
- `ios/Runner/Info.plist` : justification de localisation en anglais, sans fichiers `InfoPlist.strings` localisés trouvés.
- `lib/memorization_stats_screen.dart:454` : direction RTL forcée sur un libellé de juz traduit, à revoir en français et anglais.

Recommandation : migrer les chaînes UI vers les ARB, puis vérifier les écrans dans les trois langues avec grande taille de texte. Conserver naturellement l'arabe du texte coranique et des invocations ; distinguer ce contenu de la langue des commandes. Donner des libellés compréhensibles aux codes de méthode de calcul tout en conservant les identifiants techniques pour les appels API.

## GPS : nécessaire, à conserver

Les coordonnées servent légitimement à la requête Aladhan et à l'association locale des horaires. Leur présence dans le code ou la base locale n'est pas un bug. Le problème F01 est précisément de ne pas toujours rattacher assez strictement les horaires aux bonnes coordonnées.

Le service de statistiques examiné envoie notamment pays/ville grossière et fuseau, pas les champs latitude/longitude dans la charge étudiée. Cela ne signifie pas qu'aucun service ne reçoit des coordonnées : Aladhan les reçoit pour fournir les horaires.

Améliorations utiles : afficher ville, méthode et fraîcheur des horaires ; offrir un choix manuel de ville lorsque le GPS est refusé ou indisponible ; éviter les coordonnées brutes dans l'interface ordinaire sauf besoin explicite de diagnostic. Ce sont des améliorations de compréhension et de disponibilité, pas une demande de supprimer la géolocalisation.

## Propositions fonctionnelles, après stabilisation

1. **Sauvegarde/export et restauration** des favoris, préférences, passages de répétition et progression. Un format versionné local apporte déjà de la valeur sans imposer un compte ; envisager ensuite la synchronisation entre appareils.
2. **Écran de diagnostic adhan** : permissions, prochain déclenchement réellement programmé, ville/méthode, test sonore et action de réparation, en AR/EN/FR.
3. **Gestionnaire de téléchargements fiable** : taille, fichiers validés, échecs, reprise et suppression par récitant/sourate.
4. **Parcours de révision** : historique des passages travaillés, objectifs et rappels facultatifs, puis répétition espacée. Réutiliser la mémorisation existante plutôt que multiplier les écrans.
5. **Accessibilité** : VoiceOver/TalkBack, labels des icônes, focus clavier Web, textes agrandis et vérification RTL/LTR.
6. **Hors ligne Web explicite** : annoncer la disponibilité réelle des textes/audio ; étudier un téléchargement volontaire et versionné, avec limites d'espace affichées.

## Points forts à préserver

- Séparation des implémentations natives et Web et large socle fonctionnel partagé.
- Base coranique embarquée structurée ; diversité des éditions et traductions.
- Répétition avec bornes entre sourates, préférence de mémorisation et tests dédiés.
- Protections existantes contre les annulations de sélecteurs et certaines courses audio ; elles ne doivent pas être supprimées sous prétexte de simplification.
- Tests de logique de programmation, changement de date, budget de notifications, modèles et lecture PDF.
- Infrastructure de traduction homogène sur les trois langues.

## Ordre de réalisation conseillé

1. F01/F02/F07 : identité du calendrier, fraîcheur, validation des données ; tests de voyage, changement de mois, absence de GPS et réponse partielle.
2. F03/F04/F05/F13/F14 : programmation adhan commune, cycle de vie et intégration native ; validation sur Android et iPhone physiques avant livraison.
3. F06 : empêcher toute question fondée sur une succession de versets non vérifiée.
4. F08/F10/F11/F12 : concurrence audio/recherche, téléchargements et exceptions.
5. F09/F15/F16 et localisation : cohérence administration/mobile, messages et promesse produit.
6. Fonctionnalités nouvelles, en commençant par sauvegarde et diagnostic.

Pour chaque lot, ajouter des tests ciblés sur le défaut puis effectuer une recette de la fonctionnalité concernée. Avant publication : build Android release, build iOS sur Mac, recette Web sur plusieurs navigateurs et vérification des trois langues. Aucun P0 (panne générale ou perte massive établie) n'est démontré dans cet audit ; les P1 restent importants parce qu'ils touchent les horaires, l'adhan et l'exactitude des exercices.

## Suivi des corrections demandées après l'audit

Les constats ci-dessus décrivent l'état initial. Les modifications suivantes ont depuis été implémentées :

- F01/F02 : validation du cache par position, méthode et date de téléchargement propre à chaque mois, sur mobile et Web. Les vérifications stationnaires ne modifient plus la fraîcheur. Les écrans quotidien/mensuel et les lectures utilisées par les alarmes refusent un calendrier d'une autre position connue ; les anciennes alarmes sont annulées lors d'un changement de contexte. Le cache correspondant reste utilisable hors ligne. La position actuelle est recherchée si l'autorisation le permet, avec repli sur la dernière position connue.
- F06 : rejet des juz incomplets et contrôle de continuité, avec message AR/EN/FR.
- F07 : parseur partagé strict et validation des calendriers avant mise en cache.
- F08 : invalidation des chargements audio obsolètes et ordonnancement des changements de sources.
- F03 : rechargement au changement de date, abandon des données de la veille et suppression du déclenchement anticipé du moniteur.
- F04 : alarmes Android persistantes après redémarrage, migration du marqueur de programmation et rejet des alarmes restaurées en retard de plus de deux minutes.
- F05, partie renouvellement/timers : programmation iOS au lancement, au retour au premier plan et au changement de jour ; timers indépendants par date/prière ; rejet des timers retardés par la suspension ; une fenêtre incomplète n'est plus marquée complète. Les problèmes de format des sons et de son de repli listés dans F05 restent distincts et ne sont pas corrigés par ce lot.

Validation cumulée : 212 tests Flutter réussis et build Android debug réussi. Le premier lot a également passé le build Web. Les essais physiques de redémarrage Android et de livraison des notifications iOS restent à faire. Le renouvellement iOS se produit lorsque l'application peut exécuter du code ; il ne constitue pas une promesse de renouvellement indéfini si elle reste fermée au-delà de la fenêtre programmée.

Après le lot cache/localisation : 223 tests Flutter réussis, builds Android debug et Web réussis. Ces tests incluent les voyages, changements de méthode, mois manquants, passage à janvier, non-modification des dates lors des vérifications et rejet d'un chargement devenu obsolète pendant un changement de position. L'analyse ciblée ne signale que trois suggestions `const` préexistantes ; le build Web conserve l'avertissement WebAssembly de la dépendance `flutter_timezone` (la compilation Web standard réussit).


### Catalogue, téléchargements, recherche, exceptions, notifications et Web

- F09 corrigé : le dernier catalogue serveur/cache définit les choix visibles, même vide. Les éléments embarqués servent au premier lancement hors ligne et à la résolution des anciens choix audio, sans réapparaître dans les listes. Actualisation distante à chaque lancement à froid ; le bouton de rafraîchissement préserve le cache en cas d'échec et respecte le filtre ayah/sourate.
- F10 corrigé : progression basée sur les fichiers vérifiés, résultat explicite (succès/échecs/annulation), indicateur de fin conditionné à 114 réussites. Annulation transmise à Dio, arrêt des retries, conservation des fichiers partiels et reprise HTTP Range. Validation des fichiers existants et des tailles annoncées ; messages AR/EN/FR et bouton Annuler dans le téléchargement du récitant.
- F11 corrigé : seules les réponses de la recherche courante peuvent modifier résultats, erreurs et état de chargement. L'édition du texte, le changement de langue et la fermeture invalident les réponses en attente ; un changement de sourate relance la requête avec son filtre.
- F12 corrigé : les quatre retours asynchrones signalés attendent désormais la Future dans leur bloc de traitement des erreurs. Les deux services de prières avaient été corrigés dans le lot précédent ; les services audio et dépôt coranique complètent ce lot.
- Routage Wird iOS corrigé : installation sur Android et iOS avant l'initialisation des notifications ; payload de démarrage conservé jusqu'au premier rendu, appuis ultérieurs routés directement. Les notifications étrangères au Wird sont ignorées par ce routeur.
- F16 corrigé : métadonnées Web, manifeste, description « À propos » et aide AR/EN/FR distinguent les fonctions Web de celles réservées à l'application mobile. Les services Web de téléchargement audio refusent explicitement une demande au lieu de simuler un succès.

Validation : 241 tests Flutter réussis (18 nouveaux tests). Les tests HTTP locaux couvrent le remplacement d'un fichier corrompu, l'échec serveur, l'annulation pendant le transfert, la reprise exacte des octets et le refus de déclarer 114/114 lorsque la dernière sourate échoue. Les tests du catalogue couvrent l'absence de réintroduction, un catalogue vide persistant et le premier lancement hors ligne ; ceux de recherche couvrent succès et erreurs obsolètes ; ceux du Wird couvrent Android/iOS, démarrage à froid et appuis ultérieurs. La réception effective d'une notification et la navigation sur iPhone physique restent à vérifier sur appareil.

Compilations de ce lot : Android debug et Web réussis. Analyse finale sans erreur ni avertissement, hors trois suggestions `const` préexistantes dans l'écran mensuel des prières ; la suggestion ajoutée dans le nouveau routeur a été corrigée et son analyse ciblée est propre. Les outils conservent les avis de migration Gradle/AGP/Kotlin et l'incompatibilité WebAssembly connue de `flutter_timezone` ; la compilation Web JavaScript réussit. Manifeste JSON, chemins des icônes et présence des textes AR/EN/FR vérifiés.
