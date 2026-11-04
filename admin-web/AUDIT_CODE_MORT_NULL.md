# Audit admin — code mort, objets nuls et bugs prioritaires

Date : 4 novembre 2026. Périmètre : `admin-web/src` (21 fichiers TypeScript/TSX), scripts administratifs, configuration et migrations Supabase associées.

Le scan initial ne modifiait pas le code applicatif. Après autorisation de nettoyage, une seconde vérification a confirmé puis supprimé `hiddenByMissingCategory`, l'alias `AdminRow` et les cinq SVG du modèle de démarrage Next.js. Aucun appel, import indirect, usage dans les styles, la configuration ou la documentation produit n'a été trouvé pour ces éléments. La logique de visibilité réellement utilisée reste dans `newsVisibility` et ses consommateurs. Aucun usage futur documenté n'a été identifié ; Git conserve l'historique si un besoin apparaît ultérieurement.

Les éléments ambigus (`AuthState.session`, `StatsFilterOptions.features`) et les mécanismes de compatibilité restent conservés. Aucune opération n'a été exécutée sur la base distante. Les constats ci-dessous décrivent l'état initial avant correction.

## Corrections réalisées après l'audit

- Création et modification séparées pour les récitants et les actualités ; conflit de clé et ligne disparue signalés, sans écrasement ni recréation implicite.
- Chargements et mutations vérifient les erreurs API et les lignes affectées. Les confirmations restent ouvertes après échec ; les messages ajoutés sont traduits en arabe, anglais et français.
- Réponses obsolètes invalidées pour l'authentification, les statistiques et les listes, y compris au démontage. `AppShell` vérifie la concordance entre session et profil. Les renouvellements de session du même utilisateur ne démontent pas les formulaires.
- Valeurs nulles contrôlées dans les statistiques et options RPC. Un ciblage invalide n'est jamais transformé silencieusement en audience universelle. Les lignes de ciblage malformées produisent un échec de chargement explicite.
- Préférences utilisables en mémoire si le stockage navigateur est inaccessible ; gardes de session et gestion des exceptions dans les formulaires de connexion et de compte.
- Scripts administratifs : échec explicite si la vérification des droits échoue ou si la création Auth ne renvoie aucun utilisateur.
- Migration `20261104000001_admin_concurrency_and_news_arrays.sql` : compteur privé transactionnel pour les membres administrateurs, protection du premier et du dernier administrateur, interdiction de TRUNCATE, contrainte sur les éléments nuls du ciblage. Les contraintes nouvelles préservent les anciennes données invalides pour une réparation explicite.

Validation : 18 tests applicatifs hors ligne réussis ; six groupes de vérifications SQL réussis sur PostgreSQL 17 local (concurrence avec RLS, upsert, suppressions concurrentes, cascade/TRUNCATE, rollback/privilèges, ciblage). TypeScript et build de production réussis ; quatre avertissements ESLint préexistants. La migration et le site n'ont pas été déployés sur Supabase/Firebase.

## Résultats prioritaires

### 1. P1 — Ajouter un récitant peut écraser un récitant existant

Fichier : `src/app/reciters/page.tsx:231`.

La création et la modification utilisent toutes deux `upsert(..., { onConflict: "code" })`. Lors d'un ajout, saisir le code d'un récitant déjà présent remplace sa configuration, y compris ses chemins audio. `isNew` ne change pas l'opération SQL. Le formulaire n'avertit pas qu'il va remplacer une ligne existante.

Correction proposée : `insert` pour un ajout, `update` ciblé pour une modification ; afficher une erreur de code déjà existant. Le même principe évite qu'une modification recrée une ligne supprimée entre-temps. Le schéma possède déjà la clé primaire nécessaire.

### 2. P1 — Une réponse retardée rétablit un ancien profil après déconnexion

Fichier : `src/lib/auth-context.tsx:31–59`.

`loadAdmin` applique sa réponse sans vérifier que la session demandée est encore courante. Scénario reproduit avec la fonction extraite du code et une requête simulée : démarrer le chargement du profil A, appeler `loadAdmin(null)`, puis terminer la requête A. Résultat : le profil A redevient non nul. `AppShell` décide de l'affichage protégé à partir d'`admin`, sans vérifier la concordance avec la session.

Impact : ancien profil affiché, mauvais état de navigation, incohérences lors d'un changement de compte. Ce constat ne démontre pas un contournement de la sécurité RLS de Supabase.

Correction proposée : invalider les requêtes précédentes lors de chaque changement de session, ne publier que la réponse encore courante et invalider également au démontage. Gérer explicitement les erreurs et l'état de chargement.

### 3. P1 conditionnel — Protection du dernier administrateur non atomique

Fichier : `../supabase/migrations/20260831000003_attribution_and_last_admin.sql:103`.

Le trigger vérifie `count(*) <= 1` avant suppression, sans sérialiser les suppressions concurrentes. Avec deux administrateurs, deux transactions supprimant chacune une ligne différente peuvent chacune voir deux lignes avant que l'autre transaction soit validée. La protection des scripts comporte également un comptage préalable.

Impact possible : table `admins` vide, perte des accès existants et réouverture du parcours de création du premier administrateur, autorisé par `admins_insert_first` tant que la table est vide. Le premier provisionnement lui-même repose sur un test d'absence, sans mécanisme d'exclusion concurrente.

Correction proposée : concevoir une opération transactionnelle sérialisée pour les changements d'administrateurs et un provisionnement initial contrôlé. Tester avec deux connexions PostgreSQL. Ce scénario est identifié par lecture du SQL, non reproduit sur une base ; il ne prouve pas un incident en production.

### 4. P2 — Élément null dans target_languages : plantage de la page actualités

Fichier : `src/lib/news-visibility.ts:76–77`.

`row.target_languages ?? []` protège le tableau lui-même, mais pas ses éléments. Avec `[null]`, `l.trim()` lève `Cannot read properties of null (reading 'trim')`. Reproduction locale réussie sur la fonction réelle extraite du fichier.

Le schéma local déclare `target_languages text[] NOT NULL` mais n'interdit pas les éléments NULL du tableau. Le formulaire actuel ne produit pas ce cas ; un import ou une écriture externe peut le produire. La fonction est appelée pendant le rendu de chaque actualité et peut bloquer la liste entière.

Correction proposée : vérifier les éléments à la frontière des données, signaler les données invalides et ajouter une contrainte SQL adaptée. Ne pas convertir silencieusement une liste de ciblage invalide en liste vide : une liste vide signifie tous les publics.

### 5. P2 — Erreurs de suppression/désactivation ignorées

Fichiers : `src/app/news/page.tsx:176`, `src/app/reciters/page.tsx:58` et `:76`.

Les réponses des suppressions et de la désactivation ne sont pas examinées. Supabase peut retourner `{ error }` sans lever d'exception. La confirmation se ferme quand même et la désactivation affiche même le message de réussite. Les chargements des listes ignorent également `error` et transforment `data: null` en liste vide, présentant une panne comme une absence de contenu.

Correction proposée : vérifier les erreurs avant de fermer ou d'afficher une réussite ; distinguer échec de chargement et liste vide. Gérer aussi les exceptions avec un message traduit et permettre de réessayer.

### 6. P2 — Résultats de statistiques périmés après changement rapide des filtres

Fichier : `src/app/dashboard/page.tsx:116–149`.

Chaque changement de filtre lance une requête. Rien n'empêche une ancienne requête de terminer après une plus récente et de remplacer ses statistiques. Les contrôles peuvent alors afficher le filtre B et les chiffres du filtre A.

Correction proposée : n'accepter que la réponse du dernier chargement, ou annuler les requêtes précédentes. Ce scénario est déduit du flux asynchrone, sans test navigateur effectué.

## Autres risques d'objet nul ou d'exception

- `src/app/dashboard/page.tsx:60–87, 256–259` : `normalizeStats` protège les tableaux et les nombres de premier niveau, pas les éléments internes. Reproductions avec `features: [null]` et `avgMin: null` : exceptions sur `avgMin` et `toFixed`. La fusion des options à la ligne 160 peut aussi remplacer un tableau par `null`, puis casser `options.map`. Les migrations RPC actuelles produisent des tableaux et agrégats protégés ; il s'agit ici d'une robustesse insuffisante face à une réponse malformée ou un décalage de schéma, pas d'un bug établi avec leur sortie normale.
- `src/app/login/page.tsx:60–64` : `uid as string` ne vérifie rien à l'exécution. Si la session disparaît, une requête part avec un identifiant indéfini. Ajouter un retour explicite en l'absence d'identifiant ; ce n'est pas une déréférence nulle directe.
- `src/lib/ui-context.tsx:35–36,57,61` : accès à `localStorage` sans protection contre le refus du stockage ou un échec d'écriture. Peut empêcher l'initialisation ou provoquer une exception lors du changement de préférence. Prévoir un fonctionnement en mémoire quand le stockage est indisponible.
- Les opérations asynchrones des formulaires ont généralement `try/finally` mais pas `catch`. Le drapeau `busy` est réinitialisé, mais une exception inattendue n'est pas présentée à l'utilisateur.

## Code mort confirmé ou candidats au nettoyage

Le tableau ci-dessous conserve les constats du scan initial. Les trois premières lignes ont depuis été nettoyées après revérification ; les deux dernières sont conservées.

Recherche des références dans le dépôt, en excluant dépendances, builds et exports générés :

| Élément | Conclusion |
| --- | --- |
| `src/lib/news-visibility.ts:105`, `hiddenByMissingCategory` | Aucun appel. La page calcule déjà ce sous-ensemble à partir de `newsVisibility`. Fonction supprimable. |
| `src/lib/types.ts:34`, `AdminRow` | Alias de type sans consommateur. Supprimable sans effet à l'exécution. |
| `public/file.svg`, `globe.svg`, `next.svg`, `vercel.svg`, `window.svg` | Images de démarrage sans référence dans le dépôt. Candidates à suppression ; les accès externes directs à ces URL ne sont pas vérifiables par recherche locale. |
| `AuthState.session` | Valeur exposée par le contexte sans consommateur actuel. À traiter pendant la correction de l'authentification : son utilisation pour valider le profil peut être préférable à sa suppression. |
| `StatsFilterOptions.features` | Donnée RPC chargée mais aucun filtre de fonctionnalité ne la consomme. Ne pas confondre avec `stats.features`, qui alimente réellement le tableau. Examiner le besoin produit avant de retirer ce contrat RPC. |

Il n'y a pas de grand écran ou module applicatif entièrement abandonné identifié. Les pages et layouts Next.js sont des points d'entrée par convention, même sans import explicite. Les scripts `admin:*`, leurs variantes SQL et `fix-export-rsc.mjs` sont des outils réellement accessibles par les commandes/documentations ; ils ne sont pas du code mort.

La recherche des identifiants et chaînes des clés de traduction hors `i18n.ts` n'a pas identifié de clé sans référence. Aucun paquet directement déclaré n'a été confirmé inutile.

## Faux positifs écartés

- `admin!.id` dans `account/page.tsx:42` : assertion fragile mais le composant est actuellement rendu uniquement sous `AppShell`, qui exige un admin. Aucun plantage nul démontré sur ce chemin. Une garde locale reste utile si le composant est réutilisé.
- `g.rows[0]` dans `news/page.tsx:397` : le mode TypeScript renforcé signale un élément potentiellement indéfini, mais `groupNews` construit chaque groupe avec au moins une ligne. Amélioration du type vers une liste non vide possible ; pas de crash réel démontré dans le parcours actuel.
- `byKey.get(key)!` dans `news-grouping.ts` : chaque clé est ajoutée simultanément à la map et à la liste d'ordre, sans suppression intermédiaire.
- Catégories nulles et `surahs_path` nul : les usages examinés possèdent déjà des gardes.
- Attribution `updated_by` envoyée par le client : redondante avec le trigger récent, mais volontairement compatible avec une base pas encore migrée. Ne pas supprimer avant vérification du déploiement SQL.

## Vérifications effectuées

- Après nettoyage : TypeScript avec `noUnusedLocals` et `noUnusedParameters` réussi ; ESLint sans erreur et avec les quatre avertissements préexistants ; build de production et export statique réussis, y compris les six fichiers RSC de compatibilité. Aucune publication effectuée.
- TypeScript standard : réussite, aucune erreur.
- TypeScript avec `noUnusedLocals`, `noUnusedParameters`, `noUncheckedIndexedAccess` : un signalement sur `g.rows[0]`, analysé ci-dessus ; aucun local/paramètre inutilisé signalé.
- ESLint : aucune erreur, quatre avertissements `react-hooks/set-state-in-effect`.
- Reproductions locales en mémoire à partir de fonctions extraites du code : langue nulle, élément de statistiques nul, moyenne nulle, réponse de profil après déconnexion.
- Aucun test utilisant les identifiants distants, aucune modification de données, aucun déploiement. Pas de test navigateur authentifié ni de test de concurrence PostgreSQL.

Ordre conseillé : empêcher l'écrasement involontaire d'un récitant ; fiabiliser l'état d'authentification ; tester et renforcer la protection transactionnelle des administrateurs ; traiter les données nulles et les erreurs API ; nettoyer ensuite les éléments effectivement inutilisés.
