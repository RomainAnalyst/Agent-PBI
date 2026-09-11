# Journal des décisions

Une entrée par choix structurant. Format : décision, motif, alternative écartée.
À compléter à chaque session — c'est ce qui évite de refaire les mêmes débats.

---

## 001 — Générer le `.bim` plutôt que d'exécuter un script C# dans Tabular Editor

**Décision.** Tabular Editor 2 n'est appelé que pour l'option `-B`, qui sérialise le
modèle en TMSL. Toute l'extraction se fait ensuite en PowerShell sur ce fichier.

**Motif.** L'API scriptable de TE2 change entre versions, et `MetadataObject` est
`internal` en 2.28 — un script C# passant par TOM ne compile pas. `-B` ne dépend
d'aucune API scriptable et le `.bim` est exhaustif par construction.

**Alternative écartée.** Script C# via le wrapper TOMWrapper : fonctionne, mais
casse chez un collègue dont la version de TE2 diffère.

**Effet de bord bénéfique.** Les deux étapes sont découplées : un poste peut produire
le `.bim`, un autre les CSV (paramètre `-BimPath`).

---

## 002 — ADOMD.NET plutôt que le provider OLE DB MSOLAP

**Décision.** Les DMV sont interrogées via `Microsoft.AnalysisServices.AdomdClient.dll`,
livrée avec Power BI Desktop. ADODB/MSOLAP ne sert plus que de repli.

**Motif.** Le provider MSOLAP n'est pas enregistré sur le poste de référence, et son
installation demande des droits administrateur.

**Statut.** NON TESTÉ — à confirmer sur le poste.

---

## 003 — Graphe de dépendances plutôt que recherche textuelle

**Décision.** `24_Champs_NonUtilises.csv` s'appuie sur `DISCOVER_CALC_DEPENDENCY`,
avec propagation transitive de l'usage depuis deux types de racines : les champs
posés dans les visuels et les expressions RLS.

**Motif.** La question utile est « atteignable depuis un visuel », pas « cité quelque
part ». Une recherche `Contains("[Nom]")` ignore la qualification par table, compte
les commentaires et les littéraux, et classe comme utilisée une mesure appelée
uniquement par une chaîne elle-même morte.

**Repli.** Hors connexion, analyse textuelle après retrait des commentaires et des
chaînes, alimentant le même graphe. Verdicts marqués comme à confirmer.

---

## 004 — Refuser un `.pbix` deviné dont le nom ne correspond pas au modèle

**Décision.** Le repli par fichiers récents exige que le nom du `.pbix` corresponde au
nom du modèle chargé. Un `-PbixPath` explicite reste prioritaire.

**Motif.** Un run réel a lu la couche rapport d'un tout autre rapport que le modèle
extrait, sans aucun signal d'erreur. Une sortie silencieusement fausse est pire
qu'une sortie absente.

---

## 005 — JSON normalisé distinct du `.bim`

**Décision.** Produire `<Rapport>.model.json` en plus du `.bim`, avec suppression du
bruit interne, expressions reconstituées en chaînes et valeurs par défaut explicitées.

**Motif.** Le `.bim` brut est mal exploité par les LLM : environ 75 % de son volume
est sans valeur sémantique, et l'omission des valeurs par défaut conduit les agents
à halluciner le schéma des relations.

---

## 006 — Détection du produit par le workspace qui répond, pas par un choix explicite

**Décision.** `Open-AsContext` et la recherche du port balaient désormais les deux
dossiers de workspace (`Power BI Desktop` et `Power BI Desktop SSRS`), ainsi que
les deux dossiers d'installation (`...Desktop\bin` et `...Desktop RS\bin`) pour la
DLL ADOMD. Celui dont le `msmdsrv.port.txt` est le plus récent détermine le produit
détecté, écrit en console et dans la colonne `Produit` de `00_Modele.csv`.

**Motif.** Un collègue peut avoir les deux produits installés en parallèle (voir
`docs/COMPATIBILITE.md`). Choisir un chemin en dur aurait forcé un paramètre
supplémentaire ; balayer les deux et garder le plus récent évite toute question à
l'utilisateur dans le cas courant où un seul produit est ouvert.

**Statut.** NON TESTÉ — aucun poste Power BI Desktop for Report Server n'était
disponible pour exécuter ce chemin. Le chemin de workspace et le dossier
d'installation `...Desktop RS\bin` viennent de la documentation Microsoft, pas
d'une constatation sur poste. À confirmer dès qu'un tel poste est accessible.

---

## 007 — Troisième variante : Power BI Desktop installé depuis le Microsoft Store

**Décision.** `Open-AsContext` localise désormais la DLL ADOMD en priorité via le
dossier réel du processus `msmdsrv`/`PBIDesktop` en cours d'exécution
(`Get-Process ... | Path`), plutôt qu'en devinant un chemin d'installation. La
recherche accepte aussi le nom de fichier `Microsoft.PowerBI.AdomdClient.dll` en
plus de `Microsoft.AnalysisServices.AdomdClient.dll`. Le libellé produit détecte
la variante Store via le chemin du processus.

**Motif.** Un run réel a échoué avec « impossible de determiner le nom de la
base » : Power BI Desktop était installé depuis le Microsoft Store
(`C:\Program Files\WindowsApps\Microsoft.MicrosoftPowerBIDesktop_<version>\bin`),
un chemin absent des candidats codés en dur. Deux causes combinées :
1. Le dossier `WindowsApps` **n'est pas énumérable par un utilisateur standard**
   (`UnauthorizedAccessException` constatée) — un motif générique
   `Microsoft.MicrosoftPowerBIDesktop_*` dans un `Get-ChildItem` sur le dossier
   parent échoue silencieusement, y compris avec le numéro de version en clair.
2. Dans cette variante, l'assembly ADOMD s'appelle `Microsoft.PowerBI.AdomdClient.dll`
   et non `Microsoft.AnalysisServices.AdomdClient.dll` — seul le nom de fichier a
   changé, le namespace des types .NET à l'intérieur reste identique (constaté par
   inspection de l'assembly).

**Alternative écartée.** Ajouter le chemin `WindowsApps\Microsoft.MicrosoftPowerBIDesktop_*`
comme candidat statique : ne fonctionne pas pour un utilisateur standard (ACL),
donc inutile en pratique. Le chemin dérivé du processus en cours fonctionne pour
les trois variantes sans jamais avoir besoin de deviner ni le numéro de version
ni le dossier d'installation.

**Effet de bord.** L'énumération de `AnalysisServicesWorkspaces` n'a pas été
retrouvée sur le poste testé pour la variante Store (recherche exhaustive sous
`%LOCALAPPDATA%`, `%LOCALAPPDATA%\Packages\...`, `%TEMP%`, `%ProgramData%` —
sans résultat). Le repli par dossier `.db` (étape 1c) reste donc inopérant pour
cette variante ; seule la voie DMV fonctionne, ce qui est suffisant puisqu'elle
fonctionne désormais.

**Statut.** VÉRIFIÉ — export complet exécuté de bout en bout (modèle + DMV +
couche rapport) sur ce poste avec Power BI Desktop version Store, rapport
« Retail Analysis Sample PBIX » ouvert.

---

## 008 — Contournement d'un bug PowerShell 5.1 : `@()` sur une `List[object]` vide

**Décision.** La fonction `Save` (écriture des CSV) ne passe plus par
`@($Rows).Count` ni `@($Rows) | Export-Csv`. Le nombre de lignes est lu via
`.Count` directement (avec test de type `ICollection`), et `$Rows` est envoyé
tel quel au pipeline vers `Export-Csv`.

**Motif.** Un run réel a levé une `ArgumentException` (« Les types des arguments
ne correspondent pas ») dans `Save`, sur un rapport dont `$rowFiltr` (filtres de
page/visuel) était vide. Reproduit isolément : `@($vide)` sur une
`System.Collections.Generic.List[object]` vide plante le binder dynamique de PS
5.1 (`PSToObjectArrayBinder`) ; `$vide.Count` fonctionne. Les erreurs étant non
bloquantes, le script continuait et affichait un faux succès — risque de
`23_Filtres.csv` silencieusement absent sans que `$vides` ne le signale.

**Statut.** VÉRIFIÉ — reproduit isolément et corrigé ; export réel relancé sans
aucune erreur résiduelle (hors l'`UnauthorizedAccessException` de la décision
007, elle-même interceptée et sans effet).

---

## 009 — Versionner Tabular Editor 2 portable dans le dépôt

**Décision.** Le contenu du zip portable (`TabularEditor.exe` et ses DLL, dossier
`runtimes\`) est copié dans `TabularEditor\` à la racine du dépôt et n'est plus
exclu par `.gitignore`. `Export-PowerBIMetadata-Full.ps1` cherche désormais ce
chemin en premier, avant les installations Program Files et le profil utilisateur.

**Motif.** Un collègue sans droits administrateur ne doit rien télécharger pour
lancer l'outil. Tabular Editor 2 est distribué sous licence MIT (fichier
`license-TabularEditor.txt` inclus), qui autorise la redistribution. Fixer un
chemin garanti dans le dépôt évite aussi qu'un poste utilise par erreur une
version installée différente de celle validée ici.

**Alternative écartée.** Garder le binaire hors du dépôt avec une instruction
« extraire le zip ici » (approche précédente, documentée dans `LISEZ-MOI.md`) :
fonctionne, mais réintroduit une étape manuelle et une dépendance réseau que
les contraintes du projet cherchent justement à éliminer.

**Effet de bord.** Le dépôt grossit d'environ 18 Mo. Les fichiers copiés
excluent le contenu parasite trouvé dans le dossier source d'origine
(certificats WindowsLAPS, notes de placeholder) qui n'a aucun rapport avec
Tabular Editor.

**Statut.** NON TESTÉ — le nouvel ordre de résolution de chemin n'a pas encore
été exécuté de bout en bout ; à confirmer via `tests\Invoke-Tests.ps1` puis un
run réel avec Power BI ouvert.

---

## 010 — Résumé lisible + ouverture automatique du dossier de sortie

**Décision.** En fin d'export, le script génère `Resume.md` (produit, compteurs
modèle/rapport, répartition des verdicts de `24_Champs_NonUtilises.csv`,
sections absentes, liste des fichiers) puis ouvre l'explorateur Windows sur le
dossier de sortie. Nouveau paramètre `-SansOuverture` pour désactiver
l'ouverture (utile en exécution scriptée/automatisée).

**Motif.** Objectif d'adoption : un collègue qui lance l'outil doit atterrir
directement sur le résultat, pas chercher `Documents\PowerBI_Metadata\...` à la
main, ni ouvrir 19 CSV pour savoir ce qu'il y a dedans.

**Statut.** VÉRIFIÉ sur fixture synthétique (voir décision 011) : `Resume.md`
généré avec les bons compteurs, ouverture testée en mode désactivé
(`-SansOuverture`) pour ne pas perturber l'environnement de développement.
L'ouverture elle-même (`explorer.exe`) n'a pas été déclenchée en conditions
réelles — comportement standard de Windows, risque jugé négligeable, mais
non observé sur ce poste.

---

## 011 — Angle mort d'usage corrigé : titres dynamiques et filtres sur mesure

**Décision.** Trois changements dans la couche rapport :

1. Un champ (colonne ou mesure) référencé par un filtre — rapport, page ou
   visuel — alimente désormais le même ensemble d'« usages » que les champs
   posés dans un visuel. Auparavant seul `23_Filtres.csv` le mentionnait ;
   `24_Champs_NonUtilises.csv` classait à tort une mesure utilisée uniquement
   en filtre comme supprimable.
2. Un titre de visuel lié dynamiquement à une mesure/colonne (plutôt qu'un
   texte fixe) est désormais détecté (`Get-ExprField`, factorisée à partir de
   `Get-FilterField`) : le champ référencé alimente le même ensemble d'usages,
   et `21_Visuels.csv` affiche `(titre dynamique : Table.Champ)` au lieu de
   l'identifiant technique du visuel.
3. **Bug préexistant corrigé**, découvert en écrivant le test du point 2 :
   dans le chemin `.pbix` / `report.json` classique (hors PBIR), l'extraction
   du titre passait par un appel `P(...)` enveloppé une fois de trop
   (`P (P (P $sv 'vcObjects' $null) 'title' @()) )` au lieu de
   `P (P $sv 'vcObjects' $null) 'title' @()`). Résultat : **aucun titre,
   même fixe**, n'était jamais lu sur ce chemin — `21_Visuels.csv` affichait
   systématiquement l'identifiant technique du visuel à la place. Le chemin
   PBIR (`.pbip` récent) n'avait pas ce bug.

**Motif.** `docs/PROMPTS.md` documentait déjà ces angles morts comme limite
connue du prompt « Plan de nettoyage du modèle » (prompt #1) : une mesure
utilisée uniquement en filtre ou en titre dynamique y apparaissait à tort
comme supprimable. Les info-bulles posées via le puits de champs standard
(« Tooltips ») n'ont pas cet angle mort : elles remontent déjà par la boucle
générique sur les rôles de `projections`/`queryState`, qui n'est pas limitée
à une liste de rôles connus — seules les info-bulles de type « page rapport »
(page masquée utilisée comme info-bulle) restent hors périmètre de cette
correction, la question posée y étant « la page est-elle atteignable », pas
« le champ est-il atteignable ».

**Statut.** VÉRIFIÉ sur deux fixtures synthétiques construites à la main
(non capturées depuis un vrai `.pbix` — voir limite ci-dessous), une par
format :
- chemin `.pbix`/`report.json` classique : titre fixe, titre dynamique lié à
  une mesure, filtre de visuel sur une mesure, une mesure jamais utilisée ;
- chemin PBIR (`.pbip` récent) : titre dynamique et titre fixe.

Dans les deux cas, `21_Visuels.csv` affiche le bon titre et
`24_Champs_NonUtilises.csv` ne classe plus la mesure utilisée en titre ou en
filtre comme supprimable, tout en continuant de classer correctement la
mesure réellement inutilisée. Script exécuté de bout en bout sur ce poste via
`-BimPath`/`-PbipFolder`/`-SkipDmv`/`-SansOuverture`, sortie constatée.

**Limite non couverte par ce test.** Les fixtures sont écrites à la main
d'après la structure documentée du JSON Power BI, pas capturées depuis un
vrai rapport (`outils\Capture-Fixture.ps1` n'a pas été utilisé). Un run réel
sur un rapport contenant un titre dynamique ou un filtre sur mesure reste à
faire pour passer ce point de NON TESTÉ (implicite dans la fixture) à VÉRIFIÉ
en conditions réelles.
