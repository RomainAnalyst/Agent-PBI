# Validation de l'Agent PBI Master — phase A

Date : 2026-09-21. Aucune modification de code ni de prompt : seul ce fichier a été créé.
Rapport de référence lu : `Documents\PowerBI_Metadata\Indicateur RI ARMA - V2` (export réel du 2026-09-20).

## Résultat des tests (A1)

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Invoke-Tests.ps1` → « Tous les tests sont passés », code de sortie 0. **VÉRIFIÉ.**
Limite : une seule fixture (`relations-supprimables`, synthétique, 5 tables) et une seule assertion (colonnes de relation jamais `Supprimable`). Le `TODO` `attendu.json` n'est pas implémenté. Aucun test de culture fr-FR, de DMV, de menu ni de sources.

## Constats A2

| # | Point | Constat | Preuve | Décision proposée |
|---|---|---|---|---|
| 1 | BOM | **Confirmé, et plus large que prévu** : aucun des trois `.ps1` (`src/`, `tests/`, `outils/`) n'a de BOM (premiers octets `3C 23 0D`). `src/` est 100 % ASCII (0 octet > 127). | Lecture des octets | Ajouter le BOM aux trois (sans effet sur le contenu, respecte `CLAUDE.md` et protège contre un futur accent). Alternative : nuancer la règle en « BOM obligatoire dès qu'un octet non ASCII apparaît ». **Recommandé : ajouter le BOM.** |
| 2 | `Open-AsContext` | **Confirmé : 110 lignes** (l. 116-225, mesure par AST). C'est la seule des 25 fonctions au-dessus de 80. | Analyse AST du script | Découper en B1 ou avant, en premier (résolution de chemin ADOMD / chargement / repli MSAL / diagnostic). Touche les DMV : **run réel obligatoire**. |
| 3 | `docs/COMPATIBILITE.md` | **Confirmé absent**, cité 5 fois (`CLAUDE.md`, `LISEZ-MOI.md`, `PROMPTS.md`, prompt 13, `DECISIONS.md` #006). | Grep | Le créer. Contenu factuel disponible : #006 (Report Server NON TESTÉ), #007 (variante Store VÉRIFIÉE), #013-#015 (Enedis VÉRIFIÉ). |
| 4 | « Claude Code » ou « Copilot » | **Confirmé.** Le menu (l. 391) et #016 disent « à coller dans Claude Code » ; `PROMPTS.md` et les prompts 3, 12 disent Copilot. Les règles communes (SharePoint, dossier « 04 - BPA ») ne valent que pour Microsoft 365 Copilot. | Lecture | Le menu doit dire « Copilot » (message console et commentaire l. 1723). Corriger #016 par une note, sans réécrire l'historique. |
| 5 | Fichiers absents | **Nuancé.** Sur l'export réel, le menu signale « ATTENTION, absents » pour 3 prompts : **8** (`07_GroupesDeCalcul.csv`), **9** et **13** (`12_SourcesDonnees.csv`). Le prompt 5 est correct (le brief se trompait). Ces fichiers sont absents parce que le modèle n'a ni groupe de calcul ni source héritée : ce n'est pas une anomalie, mais « ATTENTION » le laisse croire. Le prompt 9 a `Oui` en Standard et liste `12_` comme requis. | Simulation de `Get-PromptsDisponibles` + `Get-CsvManquants` sur l'export réel | Distinguer dans le message « absent car section vide du modèle » (le script sait déjà quelles sections sont vides : variable `$vides`) de « absent par erreur ». Dire aux prompts 8, 9, 13 que ce fichier est facultatif. |
| 6 | Volumétrie DMV | **Confirmé, chiffres exacts.** `DMV_Tables_NbLignes.csv` : 595 lignes = 34 tables + 518 `H$` + 42 `R$` + 1 `U$`. Colonne du nombre de lignes : `ROWS_COUNT`, clé : `TABLE_ID`. Le vrai nombre est celui de la ligne sans préfixe `H$`/`R$`/`U$`. `Annuaire` : ligne table 474, max toutes lignes 477, somme 1 605. Autres : `Table_Indicateurs` 26 (max 29), `Base_Denodo` 1 (max 4), `_Mesures` 1 (max 3), `paco_histo` 406 743. **Aggravant** : un tri naïf de tout le fichier (prompt 7, « les 5 tables qui ont le plus de lignes ») donne en 2e place une ligne `H$…$aff id` (256 173), qui n'est pas une table. Le prompt 3 dit « volumétrie brute par table » : faux. | Lecture du CSV réel (script de contrôle) | B1 : fichier filtré (une ligne par table) et prompts 3 et 7 alignés. Nécessite un run réel. |
| 7 | En-têtes vs prompts | **Constat plus favorable que craint** : tous les prompts qui décrivent un CSV le décrivent par un **sous-ensemble** d'en-têtes, jamais par des noms inconnus (vérifié pour les 34 descriptions, dans le sens « en-tête réel non cité »). Ce n'est donc pas faux, mais incomplet là où cela pèse : prompt 2 (`02_Colonnes.csv` sans `DataType`, `SummarizeBy`, `TypeColonne`, `IsKey` ; `20_Pages.csv` sans `NbVisuels`), prompt 6 (`22_Champs_Visuels.csv` sans `QueryRef`), prompt 11 (aucun en-tête cité), prompt 12 (fichiers listés sans colonnes). **Non vérifié** : le sens inverse (un nom cité qui n'existe pas) n'a pas été contrôlé par machine, seulement par lecture. Le fichier `13_Annotations.csv` (produit) n'est cité par aucun prompt. | Script de comparaison sur les 13 prompts et les en-têtes réels | Traiter en B3 pour le prompt 2 ; les autres n'ont pas d'incidence. |
| 8 | Statuts `NON TESTÉ` | 4 décisions : **#002** ADOMD (« à confirmer sur le poste » : en fait confirmé par #007, #013-#015, statut à mettre à jour), **#006** Report Server (NON TESTÉ, aucun poste disponible), **#009** ordre de résolution de chemin de Tabular Editor portable (NON TESTÉ), et **#016** dont le statut « pas encore testé avec un export complet » est **périmé en pratique** : le menu a été simulé ci-dessus sur un export réel complet (sorties de `Get-PromptsDisponibles`, `Get-CsvManquants`). Cela reste un test de fonctions, pas un run interactif : `Read-Host` et `Set-Clipboard` n'ont pas été rejoués. | `DECISIONS.md` l. 33, 88, 180, 448-451 | Mettre à jour #002 en VÉRIFIÉ (renvoi vers #013-#015). #016 : `TESTÉ SUR FIXTURE` pour la construction du texte, run interactif à faire. |

## Écarts trouvés en plus du brief

| # | Constat | Preuve | Décision proposée |
|---|---|---|---|
| E1 | **Le brief annonce 144 mesures (142 visibles). Le rapport en contient 143 (141 visibles, 2 masquées)** : identique dans `03_Mesures.csv` (143 lignes, aucun doublon Table+Mesure), `00_Modele.csv` (`NbMesures` 143), `model.json` (`summary.measures` = 143). Les autres chiffres vérifiés concordent : 34 tables (27 importées, 7 calculées), 518 colonnes, 42 relations (41 actives, 1 inactive ; `many`→`one`, filtre unidirectionnel ; `Calendrier` 21, `Annuaire` 20, `Controle` 1), 26 pages, exclues de l'actualisation `NNImanquant` et `im_annuaire_perimetre`. | Comptages sur l'export réel | **À trancher avant B2** : la valeur attendue de la section C doit être 143 ou l'export n'est pas celui du brief. Ne pas figer 144 dans `attendu.json`. |
| E2 | **Fuite de chemin personnel** : `00_Modele.csv` contient `SourceBim` = `C:\Users\<nom d'utilisateur>\Documents\PowerBI_Metadata\…`. Ce fichier est joint aux prompts 2 et 13. Cela viole le critère D (« aucun chemin personnel ») et la règle 5. | `00_Modele.csv` ; script l. 671 (`'SourceBim' = $BimPath`) | Retirer `SourceBim` de `00_Modele.csv` ou ne garder que le nom de fichier. Petit correctif, hors périmètre B1 mais à faire avant la fixture anonymisée. |
| E3 | **Changements non commités** dans `docs/PROMPTS.md` et les prompts 2, 4, 5, 9 : la règle 6 nomme déjà `Standard_developpement_Power_BI`, dossier « 01 - Standards », « 04 - BPA » exclu, et une règle 9 (« aucun script ») est ajoutée. Une partie de B3 (règle 6) est donc **déjà faite** dans le dossier de travail. Règles 2 et 7 : pas encore conditionnelles. | `git diff` | Les commiter d'abord (ou dire de ne pas y toucher), pour que la phase B parte d'un état propre. Ne pas les écraser. |
| E4 | Le prompt 3 du dépôt est **l'ancien** : le nouveau `03-documentation-technique.md`, `PROTOTYPE_Prepare-CopilotInputs.ps1`, le template `.docx`, `Schema_Relations_….svg` et l'archive `Agent-PBI-master.zip` **ne sont pas** sur ce poste (recherche dans Documents, Téléchargements, Bureau). Seul `Standard_developpement_Power_BI_v0.1.docx` est présent (v0.1, non v0.2). | Recherche de fichiers | Me fournir ces fichiers avant B1, B3 (prompt 3) et B4. Sans le prototype, je réécris la logique des sources depuis la description du brief, ce qui sera `NON TESTÉ` face à lui. |
| E5 | Le seul `.csv` du menu est repéré par la regex `[\w\-]+\.csv` : les fichiers `<Rapport>.model.json` et `.report.json` (prompts 3, 11, 13) ne sont **jamais** contrôlés comme absents. | `Get-CsvManquants`, l. 312-319 | Étendre le contrôle aux fichiers `.json` (petit changement, `TESTÉ SUR FIXTURE` possible). |
| E6 | Autres écarts d'export : `12_SourcesDonnees.csv` et `07_GroupesDeCalcul.csv` sont absents alors que `13_Annotations.csv` est produit sans être utilisé par aucun prompt. `DiscourageImplicitMeasures = False` sur ce rapport (l'avertissement de B3 reste pertinent pour d'autres rapports). | Liste des fichiers de l'export | Aucune action immédiate. |

## A3. Relecture des prompts

Je n'ai **pas** les résultats des essais Copilot (B3 : « 104 fois À compléter manuellement », R21 et R22 à 100 %, taux par niveau…). Sans eux, la relecture se limite à la conformité au format du dépôt : ligne `**Fichiers**`, premier bloc de code = corps du prompt, règles communes non dupliquées. Les 13 prompts respectent ce format (simulation du menu : règles 2 398 caractères + corps de 2 497 à 4 461 selon le prompt). **Pour aller plus loin, il me faut les sorties Copilot.**

## Ce qui n'a pas été fait

- Aucun run avec Power BI Desktop ouvert : la phase A n'exigeait ni DMV ni découverte d'instance.
- Le menu interactif n'a pas été rejoué (voir #8).
- Les décisions de B1 sur `SharePoint.Files`, `Sql.Database`, `Folder.Files`, `OData.Feed` : hors phase A. Sur l'export réel, `TypeSource` ne vaut que `m` (27) ou `calculated` (7) ; le classement fin dépendra de l'analyse des expressions M en B1.

## Questions à trancher avant la phase B

1. **E1** : 143 ou 144 mesures ? (recommandation : 143, valeur constatée.)
2. **E2** : retirer `SourceBim` de `00_Modele.csv` ? (recommandation : oui.)
3. **#1** : BOM ajouté aux trois `.ps1` ? (recommandation : oui.)
4. **E3** : commiter d'abord vos modifications de prompts en cours ?
5. **E4** : où sont les fichiers manquants (prototype, nouveau prompt 3, template, SVG, standard v0.2, zip) ?
6. **A3** : pouvez-vous fournir les sorties Copilot ?
7. **#2** : découper `Open-AsContext` en début de phase B (run réel requis) ou plus tard ?
