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

## 012 — Colonnes de relation classées à tort « Supprimable » : nouvelles racines structurelles + colonne Motif

**Bug signalé (poste Enedis).** 25 colonnes portant une relation (ex.
`Absenteisme[NNI]`, `ICOL[NniCA]`, `Plan_de_Prevention[nni_cp]`) ressortaient
`Supprimable` dans `24_Champs_NonUtilises.csv`. Les supprimer aurait cassé le
modèle : ce sont des clés de relation, jamais posées telles quelles dans un
visuel, et le graphe de dépendances ne les traitait comme racines dans aucun
cas — ni DMV (`DISCOVER_CALC_DEPENDENCY` ne relie pas deux colonnes par une
relation, seulement par une expression DAX/M), ni analyse textuelle.

**Décision.** `24_Champs_NonUtilises.csv` traite désormais comme racines du
graphe, en plus des champs posés dans un visuel et des colonnes de sécurité
au niveau ligne (RLS) déjà couvertes :
- la colonne source et la colonne cible de chaque relation (`05_Relations.csv`) ;
- la colonne référencée par `sortByColumn` d'une autre colonne ;
- les colonnes utilisées comme niveau d'une hiérarchie ;
- les colonnes dont le `DataCategory` relève de la taxonomie date/heure Power
  BI (`Year`, `Quarter`, `Month`, `Day`, ...) ;
- toutes les colonnes d'une table dont `DataCategory = "Time"` (table marquée
  « table de dates » dans Power BI Desktop), y compris les colonnes
  techniques (numéro de mois, etc.) qu'une hiérarchie de dates intégrée
  utilise sans lien explicite dans le modèle.

Une colonne `Motif` est ajoutée à `24_Champs_NonUtilises.csv` : elle indique
pourquoi un objet non posé directement dans un visuel est retenu —
`relation`, `tri`, `hierarchie`, `RLS`, `visuel`, `table de dates`,
`categorie temporelle`, ou `dependance DAX` quand l'objet n'est lui-même
aucune de ces racines mais qu'une racine en dépend (propagation dans le
graphe). Vide quand l'objet reste `Supprimable` ou `Chaine morte - a
verifier`.

**Motif du choix.** Le TMSL n'expose pas de propriété « pourquoi cette
colonne existe » : une relation, un tri personnalisé ou une hiérarchie sont
des usages du modèle au même titre qu'un visuel, mais ne produisent aucune
ligne dans le calcul d'usage existant, qui ne regardait que les visuels, les
filtres/titres (décision #011) et la RLS. La colonne `DataCategory = "Time"`
pour une table est la représentation TMSL documentée du marquage « Table de
dates » de Power BI Desktop ; la liste de valeurs `DataCategory` temporelles
au niveau colonne est une reconstruction raisonnée d'après la taxonomie
Power BI connue (`Year`, `Quarter`, `Month`, `Day` et variantes), **non
vérifiée sur un vrai modèle marqué comme tel** — voir statut ci-dessous.

**Statut.** VÉRIFIÉ sur fixture synthétique
(`tests/fixtures/relations-supprimables/`, écrite à la main : pas de capture
`outils\Capture-Fixture.ps1`) : un modèle avec 3 relations vers une table
`Personnel`, une colonne triée par une colonne technique masquée
(`sortByColumn`), une hiérarchie référençant deux colonnes masquées, et une
table `Calendrier` marquée `DataCategory = "Time"`. Script exécuté de bout en
bout sur ce poste via `-BimPath`/`-PbipFolder`/`-SkipDmv`/`-SansOuverture` :
- avant le correctif (script d'avant ce commit, ré-exécuté pour comparaison) :
  les 4 colonnes de relation, les 2 colonnes de date technique et la colonne
  triée ressortaient toutes `Supprimable` ;
- après : elles ressortent `Intermediaire - conserver` avec le `Motif`
  attendu (`relation`, `tri`, `hierarchie`, `table de dates`, `categorie
  temporelle`, combinés quand plusieurs s'appliquent), et les deux colonnes
  réellement inutilisées de la fixture (`ICOL[Commentaire]`,
  `Plan_de_Prevention[Intitule]`) restent correctement `Supprimable`.

**Limite non couverte par ce test.** La liste de valeurs `DataCategory`
temporelles au niveau colonne (`Year`, `Quarter`, `Month`, `Day`,
`PaddedDateTableDates`, ...) est écrite d'après la documentation et le
raisonnement, pas confirmée sur un modèle réel marqué « Table de dates » par
l'assistant Power BI Desktop — à vérifier sur un poste avec Power BI Desktop
ouvert et un vrai marquage de table de dates avant de considérer ce point
acquis.

## 013 — Diagnostic explicite quand ADOMD/MSOLAP échouent (poste Enedis)

**Constat.** Sur le poste Enedis, aucun `DMV_*.csv` n'est produit — les DMV
échouent silencieusement — alors que le correctif ADOMD (recherche des deux
noms de DLL, `Microsoft.AnalysisServices.AdomdClient.dll` et
`Microsoft.PowerBI.AdomdClient.dll`) fonctionne sur poste Store. `Open-AsContext`
avalait toutes les exceptions (`catch { }`) sans laisser de trace exploitable
pour distinguer « dossier absent », « DLL introuvable » et « DLL trouvée mais
connexion refusée ».

**Décision.** `Open-AsContext` construit maintenant un journal
(`$script:AsDiag`, une ligne par étape) : dossiers candidats testés et
absents, résultat de l'énumération `WindowsApps`, DLL introuvable par
dossier, ou message d'exception exact quand `Add-Type`/`AdomdConnection.Open`
échoue malgré une DLL trouvée, puis la même chose pour chaque provider ADODB
(`MSOLAP`, `MSOLAP.8`, `MSOLAP.7`). Quand l'étape 3 (DMV) échoue au final, ce
journal est affiché en console sous le message « DMV ignorées » existant, pour
identifier sur le poste concerné laquelle des causes possibles s'applique
(dossier d'installation non standard, DLL absente, GPO bloquant
`WindowsApps`, provider MSOLAP non enregistré, etc.).

**Statut.** VÉRIFIÉ sur le poste Enedis (« Indicateur RI ARMA - V2 », sortie
collée par l'utilisateur) : le journal s'affiche bien et a immédiatement
identifié la cause précise — voir #014.

Historique : lors de l'écriture de ce commit, sans accès au poste concerné,
seule la syntaxe avait pu être vérifiée
(`[System.Management.Automation.Language.Parser]::ParseFile`, aucune erreur)
et le comportement de repli (aucun DMV disponible → analyse textuelle) via le
test de la décision #012 (`-SkipDmv`).

## 014 — Cause identifiée sur le poste Enedis : `Add-Type` échoue sans détailler `LoaderExceptions`

**Constat (poste Enedis, run réel).** Le journal de la décision #013 a
immédiatement pointé la cause : les deux DLL `Microsoft.PowerBI.AdomdClient.dll`
trouvées (`...\Microsoft Power BI Desktop\bin`, version 17.0.31.22, et
`...\Microsoft Power BI Desktop RS\bin`, version 16.0.109.17 — **ce poste a
les deux variantes installées en parallèle**) échouent toutes les deux au
chargement avec le même message .NET : *« Impossible de charger un ou
plusieurs des types requis. Extrayez la propriété LoaderExceptions pour plus
d'informations. »* — une `ReflectionTypeLoadException` dont le journal ne
capturait que `$_.Exception.Message`, sans jamais lire la propriété
`LoaderExceptions` que le message pointe explicitement. Les trois providers
MSOLAP échouent aussi (non enregistrés sur ce poste). Effet de bord observé :
le même dossier apparaissait deux fois dans le journal (process `msmdsrv.exe`
en cours et chemin fixe `Program Files\...\bin` pointent vers le même
dossier, ajouté sans déduplication).

**Décision.** Ajout de `Get-ErrDetail`, qui déroule la chaîne
`InnerException` d'une exception et, à chaque niveau, lit `LoaderExceptions`
quand elle est présente (test par nom de propriété via `PSObject.Properties`,
sans dépendre du type exact de l'exception). Utilisée dans les trois `catch`
de `Open-AsContext` à la place de `$_.Exception.Message`. `$dirs` est
maintenant dédupliqué (`Add-Dir`, comparaison insensible à la casse) pour ne
plus scanner/journaliser deux fois le même dossier.

**Statut.** TESTÉ SUR FIXTURE : `Get-ErrDetail` vérifiée isolément sur ce
poste avec une exception simple (aucune `LoaderExceptions` → une seule
ligne) et une `ReflectionTypeLoadException` synthétique portant une
`LoaderExceptions` peuplée (→ message principal suivi du détail de la
`LoaderException`, sortie constatée). `.\tests\Invoke-Tests.ps1` repasse
après ce changement. **Reste à faire** : relancer l'export sur le poste
Enedis pour lire le détail réel de la `LoaderExceptions` sous-jacente (la
sortie déjà collée date d'avant ce correctif) et en déduire l'action
corrective (assembly dépendante manquante, version de .NET Framework,
conflit entre les deux variantes installées, etc.).

## 015 — Cause confirmée sur le poste Enedis : MSAL présent mais non résolu par ADOMD

**Constat (poste Enedis, `LoaderExceptions` lue grâce à #014).** La
dépendance manquante est `Microsoft.Identity.Client` (MSAL) version 4.65.0.0.
Or `Microsoft.Identity.Client.dll` existe bien dans le même dossier que
l'ADOMD (`C:\Program Files\Microsoft Power BI Desktop\bin\`) : ce n'est donc
pas une absence, mais un problème de résolution — le probing .NET standard
(dossier de l'exécutable hôte `powershell.exe`, GAC) ne regarde pas le
dossier où se trouve l'ADOMD lui-même. La variante Microsoft Store fonctionne
parce que son dossier `bin` est celui du processus hôte (`PBIDesktop.exe`
tournant depuis ce même dossier), ce qui n'est pas le cas ici : le script
tourne dans `powershell.exe`, dont le dossier ne contient pas MSAL.

**Décision.** `Open-AsContext` enregistre un gestionnaire
`AppDomain.CurrentDomain.AssemblyResolve` (`Register-AsResolveHandler`)
avant toute tentative de chargement de l'ADOMD. Il :
- extrait le nom court de l'assembly demandée (`AssemblyName`) ;
- la cherche dans le dossier de la DLL ADOMD en cours de chargement et ses
  sous-dossiers (`$script:AsResolveDir`, mis à jour avant chaque tentative) ;
- la charge avec `Assembly.LoadFrom` même si son numéro de version diffère de
  celui demandé (ADOMD s'en contente généralement) ;
- renvoie `$null` sans lever d'exception si rien n'est trouvé, pour laisser
  l'erreur d'origine remonter normalement ;
- ne s'enregistre qu'une fois (`$script:AsResolverRegistered`), même si
  `Open-AsContext` est appelée deux fois (étape 1c puis étape 3).

Le diagnostic (#013) journalise en plus, pour chaque DLL ADOMD candidate, si
`Microsoft.Identity.Client.dll` est présente à côté et sa version d'assembly
réelle — pour comparer directement à la 4.65.0.0 attendue sans avoir à lire
une `LoaderExceptions`.

---

## 016 — Menu console interactif pour choisir un prompt, plutôt qu'une fenêtre graphique

**Décision.** En fin d'export, si `-SansMenu` n'est pas passé, le script affiche
le `Resume.md` dans la console puis un menu numéroté listant les prompts de
`docs/prompts/*.md`. Le prompt choisi (règles communes de `docs/PROMPTS.md` +
liste des fichiers requis, chemin résolu dans `$OutputFolder` + corps du
prompt) est copié dans le presse-papier via `Set-Clipboard`, prêt à coller
dans Claude Code. `Get-PromptsDisponibles` parse les fichiers Markdown
existants (aucune duplication de leur contenu dans le script) ; `Remove-Diacritiques`
retire les accents des titres/listes de fichiers uniquement pour l'affichage
console (cp850), jamais du texte copié dans le presse-papier.

**Motif.** Poste sans droits admin, PowerShell 5.1 uniquement : un menu
console ne demande aucune dépendance ni fenêtre. `-SansMenu` évite que
`tests\Invoke-Tests.ps1` (exécution non interactive) ne bloque sur un
`Read-Host` — ajouté au même appel que `SkipDmv`/`SansOuverture`.

**Alternative écartée.** Fenêtre WinForms : plus lisible mais plus de code à
maintenir pour un gain limité sur ce cas d'usage ; page HTML générée : pose la
question de l'ouverture/sandbox du navigateur sur un poste d'entreprise.

**Statut.** VÉRIFIÉ sur fixture synthétique (`relations-supprimables`) : menu
affiché, choix d'un prompt, contenu confirmé correct en UTF-8 dans le
presse-papier (vérifié octet par octet, pas seulement à l'écran). Pas encore
testé sur un poste réel avec un export complet (DMV + couche rapport).

**Motif.** Conforme à la décision #002 (ADOMD.NET plutôt que le provider
OLE DB) : le problème n'est pas ADOMD lui-même mais la résolution de ses
dépendances quand le processus hôte n'est pas celui dont le dossier `bin`
contient déjà tout. Un gestionnaire `AssemblyResolve` est la solution .NET
standard à ce problème, plus robuste qu'une copie manuelle de DLL (qui devrait
être répétée à chaque mise à jour de Power BI Desktop) et sans dépendance
externe à installer (contrainte d'environnement non négociable).

**Statut.** Le mécanisme du gestionnaire est VÉRIFIÉ, mais pas avec MSAL
réel — aucun poste avec ADOMD/MSAL n'est disponible sur ce dépôt. Reproduit à
l'identique avec deux assemblies .NET compilées à la volée (`Add-Type
-OutputAssembly`) : `Consumer.dll` référence `Dependency.dll` en version
1.0.0.0 à la compilation, sans l'avoir à côté de lui à l'exécution ; une
version 2.0.0.0 de `Dependency.dll` est placée dans un dossier tiers pointé
par `$script:AsResolveDir`. Constaté dans un processus PowerShell isolé
(`-NoProfile`, pour exclure toute assembly déjà chargée en mémoire) :
- sans gestionnaire enregistré : `FileNotFoundException` (comportement
  actuel sur poste Enedis) ;
- gestionnaire enregistré, `$script:AsResolveDir` pointé vers le dossier
  tiers : l'appel réussit et renvoie la valeur de la version 2.0.0.0, malgré
  le numéro de version demandé (1.0.0.0) différent de celui trouvé — preuve
  que la tolérance de version fonctionne ;
- gestionnaire enregistré 3 fois de suite avant une résolution : une seule
  entrée de journal produite pour cette résolution (pas de double
  déclenchement) ;
- dépendance absente du dossier pointé (dossier vide) : l'exception d'origine
  (`FileNotFoundException`) remonte inchangée, rien n'est masqué.

**Bug trouvé et corrigé pendant ce test** : `if ($script:AsDiag) { ... }`
dans le gestionnaire ne journalisait jamais sa toute première entrée — en
PowerShell, la véracité d'une collection (ici `List[string]`) se juge sur son
`Count`, pas sur sa nullité ; une liste vide vaut `$false`. Remplacé par
`if ($null -ne $script:AsDiag)`. Sans ce test, ce bug serait passé inaperçu
jusqu'à sa découverte sur un vrai poste, en silence.

**Confirmation finale — VÉRIFIÉ sur poste Enedis (run réel, sortie collée par
l'utilisateur).** L'export complet sur le rapport « Indicateur RI ARMA - V2 »
affiche désormais `-> Acces aux DMV : ADOMD.NET
(C:\Program Files\Microsoft Power BI Desktop\bin\Microsoft.PowerBI.AdomdClient.dll)`
dès l'étape 1c (donc le gestionnaire a résolu MSAL au tout premier essai, pas
seulement en repli), puis à l'étape 3 : `-> Extraction DMV (ADOMD.NET...)`
avec les quatre fichiers produits (`DMV_Dependances.csv` 855 lignes,
`DMV_Tables_NbLignes.csv` 595, `DMV_Colonnes_Cardinalite.csv` 1595,
`DMV_Colonnes_Memoire.csv` 2847), et `24_Champs_NonUtilises.csv` généré
**sans** le message de repli « dependances deduites du texte » — confirmant
que `SourceAnalyse = DMV`, plus fiable que l'analyse textuelle (voir
`docs/PROMPTS.md`). Le problème signalé au départ (aucun `DMV_*.csv` produit
sur ce poste) est résolu.


## 017 — Sources_Par_Table.csv et Schema_Relations.svg produits par le script, pas par l'IA

**Décision.** L'export produit deux fichiers de plus, juste après `05_Relations.csv`,
à partir des objets TMSL (`$tables`, `$mdl.relationships`) et non des CSV :
- `Sources_Par_Table.csv` (`Table;Groupe;Nature;Objet;Mode;Chargement`) : nature
  de la source de chaque table, règles évaluées dans l'ordre (table calculée,
  Excel, CSV, table saisie, ODBC, requête référencée par `Source = …` à
  profondeur 5 maximum, sinon « Autre »). Seule la **première partition** de
  chaque table est lue. `Objet` n'est renseigné que pour ODBC (`schéma.vue`),
  jamais d'adresse, de chemin ni de nom d'hôte.
- `Schema_Relations.svg` : schéma des relations (tables « un » à gauche/droite
  en alternance, tables « plusieurs » au centre), UTF-8 sans BOM, culture
  invariante forcée pendant la génération puis restaurée (sous fr-FR, `-f`
  écrit `12,5` et casse le SVG). Rien n'est produit sans relation. Les accents
  du texte fixe sont des entités numériques, le script reste en ASCII.
- Les deux blocs sont sous `try/catch` : un échec affiche un avertissement mais
  n'interrompt pas l'export.

**Motif.** Copilot classe les sources différemment d'une exécution à l'autre et
ne rend pas le Mermaid dans Word. Un script produit toujours le même résultat.

**Sort de SharePoint.Files, Sql.Database, Folder.Files, OData.Feed** (auparavant
« Autre »). Ils reçoivent leur propre nature — « Dossier SharePoint »,
« Base SQL Server », « Dossier de fichiers », « Flux OData » — placée après ODBC
et avant le suivi de requête référencée. Raison : « Autre » est précisément ce
qui pousse l'IA à deviner. `Objet` reste « Non disponible » pour eux. Les règles
Excel/CSV (`Web.Contents`) gardent la priorité ; un `SharePoint.Files` lu avec
`Excel.Workbook` (sans `Web.Contents`) est donc « Dossier SharePoint ».

**Écart au brief.** Pour ODBC, l'objet est lu aussi avec `Kind="Table"` (pas
seulement `Kind="View"`), car la navigation ODBC vers une table s'écrit ainsi.

**Limites connues.**
- Lisibilité du SVG : rendu constaté acceptable jusqu'à ~25 tables « plusieurs » ;
  à 30 tables et 6 dimensions très interconnectées, les faisceaux de lignes
  deviennent denses (hauteur ≈ 1100 px) mais restent lisibles ; au-delà, le
  schéma n'est plus un outil de lecture.
- Une relation entre deux tables « un » (flocon : une table à la fois cible et
  source) est tracée en ligne droite d'un bord à l'autre et peut traverser la
  colonne centrale. L'algorithme spécifié ne couvre pas ce cas.
- Les relations d'une table « un » sans aucune table « plusieurs » liée sont
  placées en haut de leur colonne.

**Statut.** `TESTÉ SUR FIXTURE` : `tests/fixtures/sources-et-schema` (11 tables,
toutes les règles, chaîne de requêtes, boucle, ODBC, exclusion d'actualisation,
relation inactive, double relation) avec `attendu-sources.csv`, et contrôles
génériques du SVG dans `Invoke-Tests.ps1` (XML valide, une ligne par relation,
pas de virgule décimale) sous culture fr-FR. Rendu visuel du SVG contrôlé dans
Edge (fixture et modèle synthétique de 30 tables). Run réel sur un modèle Power
BI ouvert : `NON TESTÉ`. Regex de détection d'après la forme habituelle du M,
non confrontées à des expressions réelles de l'entreprise.

---

## 018 — Référence au standard lue depuis un fichier local, plutôt que cherchée sur SharePoint par l'IA

**Décision.** Le prompt 3 (`docs/prompts/03-documentation-technique.md`) ne
demande plus à l'IA de chercher le standard de développement Power BI sur
SharePoint (ancienne « Étape 0 »). `config/standard-reference.json` porte
le nom, la version et la date du standard, ainsi que le nom, la version et
la règle du template associé. `Show-MenuPrompts` lit ce fichier et remplace
les balises `<STANDARD_VERSION>` et `<TEMPLATE_INFO>` du prompt copié dans
le presse-papier avant de l'y déposer. Une règle « Périmètre fermé » a été
ajoutée en tête des règles propres au prompt 3 pour interdire explicitement
toute recherche SharePoint ou en ligne. **Reste à trancher** : si
`config/standard-reference.json` doit être versionné (référence commune à
l'équipe) ou ignoré par Git (chaque poste adapte sa propre copie) — le fichier
n'est pour l'instant ni l'un ni l'autre, simplement non suivi.

**Motif.** Laisser Copilot/Claude chercher le standard sur SharePoint à
chaque génération donnait un résultat non déterministe (le fichier trouvé,
sa version retenue et parfois la simple présence du résultat variaient d'un
essai à l'autre) et une dépendance réseau/droits d'accès à SharePoint que
rien n'imposait ici : la référence (nom, version, date) est une donnée
stable qui change rarement et qu'un `Copy-Item`/une modification manuelle du
JSON suffit à tenir à jour.

**Alternative écartée.** Garder la recherche SharePoint par l'IA en
demandant seulement plus de rigueur dans le prompt (« ouvre le document en
entier », etc.) : n'élimine pas la variabilité intrinsèque d'une recherche
interprétée par un LLM, contrairement à une lecture de fichier déterministe.

**Statut.** `TESTÉ SUR FIXTURE` : `Get-PromptsDisponibles` et
`Show-MenuPrompts` extraites et exécutées isolément (Read-Host/Set-Clipboard
simulés) contre les vrais fichiers du dépôt (`docs/prompts/03-documentation-technique.md`,
`config/standard-reference.json`) — les balises sont remplacées par le
contenu attendu du JSON et aucune balise ne subsiste dans le texte copié.
`.\tests\Invoke-Tests.ps1` repasse après ce changement. Non exécuté via le
script principal de bout en bout (menu interactif) : à confirmer lors d'un
run réel.

---

## 019 — Volumetrie_Propre.csv produit par le script, plutôt que le filtrage des lignes VertiPaq confié au prompt

**Décision.** Après la boucle d'extraction des DMV (étape 3), le script filtre
la sortie déjà récupérée de `DISCOVER_STORAGE_TABLES` (variable `$storageTables`,
capturée dans la boucle comme `$calcDep` pour `DMV_Dependances.csv` — pas de
requête DMV supplémentaire) pour ne garder que les lignes utilisateur (`TABLE_ID`
ne commence pas par `H$`, `R$` ou `U$`), projette `Table`/`NombreLignes` et trie
par nombre de lignes décroissant, avant d'écrire `Volumetrie_Propre.csv`. Le
prompt 3 (section 1.3 Volumétrie) recopie désormais ce fichier tel quel, sans
consigne de filtrage ni de tri.

**Motif.** `DISCOVER_STORAGE_TABLES` mélange sous la même colonne `ROWS_COUNT`
les lignes de table réelles et des lignes internes VertiPaq (segments,
relations, mappages) dont le préfixe de `TABLE_ID` seul permet de les
distinguer. Confier ce filtrage au prompt (comme auparavant) demandait à l'IA
d'appliquer une règle regex sur des centaines de lignes techniques à chaque
génération : risque de mauvaise ligne retenue (max/somme au lieu de la bonne
ligne) plutôt qu'une erreur de calcul déterministe une fois pour toutes en
PowerShell.

**Statut.** `TESTÉ SUR FIXTURE` (au sens strict : donnée synthétique, pas un
fichier DMV capturé) : la logique de filtre/projection/tri a été extraite et
exécutée isolément sur un jeu de lignes construit à la main reproduisant le
mélange décrit (3 tables utilisateur, une table à 0 ligne, une ligne `H$...`,
une ligne `R$...`, une ligne `U$...`, un `TABLE_ID` nul) : le CSV produit ne
contient que les 4 lignes utilisateur, triées par nombre de lignes décroissant,
identique à l'exemple attendu. `.\tests\Invoke-Tests.ps1` repasse (fixtures en
`-SkipDmv`, ce chemin n'y est pas exercé). **Non testé** : run réel avec Power
BI ouvert et DMV disponibles — aucun poste avec une vraie connexion Analysis
Services n'était accessible pour cette session.

---

## 020 — Prompt 3 scindé en 3a (synthèse) et 3b (fiches tables), au lieu d'un MODE à choisir

**Décision.** `docs/prompts/03-documentation-technique.md` (une ligne `MODE =
SYNTHÈSE` ou `MODE = TABLES : <liste>` à éditer avant envoi) est supprimé et
remplacé par deux fichiers :
- `docs/prompts/03a-documentation-synthese.md` : vue d'ensemble du modèle
  (sections 1, 2, 3.1, 4, 5, 6 et Annexes A/B du template) ;
- `docs/prompts/03b-documentation-tables.md` : fiche détaillée par lot de 5 à
  8 tables (section 3.x), avec une ligne `TABLES = <liste>` à la place de
  l'ancienne ligne `MODE`.

`Get-PromptsDisponibles` extrayait jusqu'ici le numéro du prompt depuis le nom
de fichier avec `-replace '^0*(\d+).*', '$1'` puis un cast `[int]` : les deux
nouveaux fichiers (`03a-...`, `03b-...`) auraient tous les deux produit le
numéro entier 3, rendant les deux prompts indiscernables dans le menu (`$p`
serait devenu un tableau de deux éléments dans `Show-MenuPrompts`, faisant
échouer `$p.ReglesCommunes.Trim()`). Le cast `[int]` est retiré et la regex
autorise une lettre finale (`'^0*(\d+[a-zA-Z]?).*'`), donnant les identifiants
texte `3a`/`3b`, distincts et sélectionnables séparément (comparaison déjà en
chaîne dans `Show-MenuPrompts`, donc aucun autre changement requis). Le même
ajustement s'applique au titre affiché en console (`-replace '^\d+\.\s*',
''` devient `-replace '^\d+[a-zA-Z]?\.\s*', ''`), sans effet sur les prompts
numérotés simplement (1 à 13).

**Motif.** Avec un seul fichier, Copilot devait interpréter la ligne `MODE`
et pouvait s'en écarter (halluciner un mode, mélanger synthèse et détail par
table dans la même réponse). Deux fichiers séparés donnent une intention
unique par prompt, éliminant cette ambiguïté ; c'est aussi l'occasion
d'appliquer aux deux fichiers les correctifs des décisions #018
(`<STANDARD_VERSION>`/`<TEMPLATE_INFO>`, plus de recherche SharePoint) et #019
(`Volumetrie_Propre.csv`) déjà faits sur l'ancien fichier unique.

**Statut.** `TESTÉ SUR FIXTURE` : `Get-PromptsDisponibles`/`Show-MenuPrompts`
extraites et exécutées isolément (Read-Host simulé pour enchaîner le choix de
3a puis de 3b, Set-Clipboard capturé) contre les vrais fichiers du dépôt —
les deux prompts apparaissent comme deux entrées distinctes du menu (`3a`,
`3b`, ni collision ni tableau), chacun copié séparément dans le presse-papier
avec le contenu attendu (balises `<STANDARD_VERSION>`/`<TEMPLATE_INFO>`
substituées dans 3a, absentes par construction de 3b, aucune balise
résiduelle dans les deux cas). `.\tests\Invoke-Tests.ps1` repasse. Non testé
via le menu réel du script principal ni avec un document Word réel.

---

## 021 — Sauts de ligne DAX neutralisés dans les CSV ; console forcée en UTF-8 dans le `.bat`

**Décision (1).** Nouvelle fonction `E-Csv`, à côté de `E` : appelle `E` puis
remplace tout saut de ligne réel (`\r?\n\s*`) par un espace unique. Utilisée
à la place de `E` pour les trois colonnes de CSV qui recopient une expression
DAX pouvant être multiligne : `Expression` de `02_Colonnes.csv` (colonnes
calculées), `Expression_DAX` de `03_Mesures.csv` et `Expression_DAX` de
`07_GroupesDeCalcul.csv`. `$ReportName.model.json` continue d'utiliser `E`
sans changement, pour garder la mise en forme d'origine de l'expression dans
le JSON. Les autres usages de `E` (nature d'une source, dépendances déduites
du texte) restent inchangés : ce ne sont pas des colonnes de texte affichées
telles quelles, mais des chaînes analysées par le script lui-même.

**Motif.** Un saut de ligne réel à l'intérieur d'un champ délimité par `;`
reste valide au sens du format CSV (le champ est encadré de guillemets par
`Export-Csv`), mais un lecteur qui découpe naïvement par ligne physique
plutôt que par enregistrement CSV complet désynchronise les colonnes
suivantes. Une expression DAX/M à plusieurs lignes est un cas courant
(`CALCULATE` avec plusieurs arguments, `VAR`/`RETURN`).

**Statut (1).** `TESTÉ SUR FIXTURE` : `E`/`E-Csv` extraites et exécutées
isolément sur une expression donnée à la fois comme tableau de lignes (forme
que prend parfois le TMSL, décision déjà connue) et comme chaîne unique
contenant `` `r`n `` internes ; dans les deux cas, `E-Csv` produit une seule
ligne sans saut interne. Un CSV construit avec cette valeur et relu confirme
qu'il ne compte que le nombre de lignes physiques attendu (un en-tête + une
ligne par enregistrement). `.\tests\Invoke-Tests.ps1` repasse (les fixtures du
dépôt n'ont pas d'expression multiligne, ce chemin n'y est pas exercé).

**Décision (2).** `Lancer-Export.bat` exécute `chcp 65001 > nul` juste après
`@echo off`, avant tout le reste.

**Motif.** Un caractère accentué produit à l'exécution (dans un chemin de
fichier, un nom de rapport, un message d'erreur .NET) peut être mal restitué
par la console selon la page de code active au lancement du process
PowerShell. Passer la console en UTF-8 avant de lancer PowerShell élimine
cette dépendance à la page de code héritée du poste.

**Statut (2).** `VÉRIFIÉ` (mécanisme reproduit sur ce poste, pas sur un poste
d'entreprise réel) : un `.bat` minimal (CRLF, ASCII, comme `Lancer-Export.bat`)
lançant `powershell -Command` dont la sortie contient des caractères
accentués générés à l'exécution (pas codés en dur dans le `.bat`) a été
exécuté après avoir forcé la console en CP850 (`chcp 850`, la page de code
d'entreprise visée par ce dépôt) :
- sans `chcp 65001` en tête du `.bat` : sortie corrompue, ex.
  `Rapport : �valuation Cha�ne` (caractère de remplacement) ;
- avec `chcp 65001` en tête : sortie correcte, `Rapport : évaluation Chaîne`,
  code de retour PowerShell inchangé (0).

`chcp` ne demande aucun droit administrateur (changement de la page de code
de la seule session console courante). **Non testé** : le run réel via
`Lancer-Export.bat` sur un poste d'entreprise avec Power BI ouvert, où
d'autres particularités de la console (police, largeur) pourraient exister
mais n'ont pas été observées ici.

---

## 022 — Frontière explicite entre le BPA (Tabular Editor), les prompts d'audit et la documentation (3a/3b)

**Décision.** La règle commune 6 (`docs/PROMPTS.md`, section Standard) gagne
une clause : si le standard désigne une règle comme déjà vérifiée par le BPA
de Tabular Editor (`BPARules.json`), le prompt ne recalcule pas de verdict
pour cette règle — il écrit « Couverte par le BPA de Tabular Editor, hors
périmètre de ce prompt » et passe à la suivante. Une nouvelle section
« Répartition BPA / prompts d'audit / documentation » explicite le partage :
le BPA (déterministe, sur le modèle TOM directement) pour les règles
structurelles qu'il sait contrôler ; les prompts d'audit (1, 2, 4, 5, 9) pour
ce que le BPA ne couvre pas ou couvre partiellement (DAX, RLS, champs
inutilisés vus depuis le rapport, conventions de nommage, Power Query) ; les
prompts 3a/3b pour la documentation descriptive (règle L5) sans aucun
verdict, les verdicts relevant des fiches de conformité (règle L2). La règle
« Ce prompt n'émet aucun verdict de conformité » de 3a et 3b est complétée
pour pointer explicitement vers le BPA et les prompts d'audit.

**Motif.** Le LLM travaille sur des CSV aplatis produits par ce dépôt, pas
sur le modèle TOM lui-même : pour les règles que le BPA vérifie déjà de
façon déterministe, une nouvelle vérification par le LLM est strictement
moins fiable et risque de produire un verdict divergent de celui du BPA sans
que personne ne s'en aperçoive. Le mécanisme retenu ne fige aucun
numéro de règle dans le code ou les prompts : il renvoie au standard
lui-même pour dire quelles règles sont couvertes par le BPA, ce qui survit à
une renumérotation du standard sans toucher au dépôt.

**Statut.** `TESTÉ SUR FIXTURE` (changement de documentation, pas de logique
d'export) : `Get-PromptsDisponibles`/`Show-MenuPrompts` extraites et
exécutées isolément confirment que la nouvelle clause de la règle 6 est bien
présente dans le texte copié dans le presse-papier pour un prompt
standard-gated (prompt 2), et que les 15 prompts (1, 2, 3a, 3b, 4-13)
continuent d'apparaître correctement dans le menu après l'ajout.
`.\tests\Invoke-Tests.ps1` repasse. Non testé : un cas réel où Copilot
applique effectivement cette clause face à un standard qui désigne une règle
comme couverte par le BPA — le contenu réel du standard de l'entreprise n'a
pas été consulté pour cette session.
