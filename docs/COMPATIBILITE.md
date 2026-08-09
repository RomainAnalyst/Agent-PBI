# Matrice de compatibilité

Statuts : ✅ vérifié sur un poste · 🧪 testé sur fixture · ❓ supposé, non testé ·
❌ non supporté.

Toute case ❓ est une hypothèse. Elle ne doit pas être présentée autrement tant
qu'une exécution ou une fixture ne l'a pas confirmée.

## Produits

Il existe en réalité **trois** installations possibles de Power BI Desktop, pas
deux : l'installeur classique, la variante Microsoft Store, et Report Server.
Les deux premières partagent le même moteur et le même format de fichier ; seul
le chemin d'installation (et donc la découverte du port/de la DLL ADOMD) diffère.

| Capacité | Desktop (installeur classique) | Desktop (Microsoft Store) | Desktop for Report Server |
|---|---|---|---|
| Détection du port de l'instance | ✅ | ✅ via le workspace, ou repli process+netstat | ❓ code écrit pour balayer le workspace SSRS, non confirmé sur un poste Report Server |
| Nom de la base via DMV | ✅ ADOMD | ✅ ADOMD (`Microsoft.PowerBI.AdomdClient.dll`) | ❓ |
| Export `.bim` par Tabular Editor 2 | ✅ | ✅ | ❓ |
| Lecture de `Report/Layout` dans le `.pbix` | ❓ non exécuté sous cette variante précise | ✅ | ❓ |
| DMV `DISCOVER_CALC_DEPENDENCY` | ❓ | ✅ | ❓ |
| Groupes de calcul | ✅ | ❓ non rencontré dans le rapport testé | ❌ selon niveau de compatibilité |
| Chaînes de format dynamiques | ❓ | ❓ | ❌ |
| Format `.pbip` / PBIR | ❓ | ❓ | ❌ non disponible |

### Variante Microsoft Store

Détectée quand `msmdsrv.exe`/`PBIDesktop.exe` tourne depuis
`C:\Program Files\WindowsApps\Microsoft.MicrosoftPowerBIDesktop_<version>\bin`
(le numéro de version change à chaque mise à jour de l'app Store).

1. **`WindowsApps` n'est pas énumérable par un utilisateur standard.**
   `Get-ChildItem 'C:\Program Files\WindowsApps' -Filter 'Microsoft.MicrosoftPowerBIDesktop_*'`
   lève une `UnauthorizedAccessException` — constaté sur ce poste, sans droits
   admin. Un motif générique sur le dossier parent est donc inutilisable en
   pratique, même sans version en dur.
   **Corrigé (VÉRIFIÉ) :** `Open-AsContext` dérive le dossier `bin` du chemin
   réel du processus `msmdsrv`/`PBIDesktop` en cours d'exécution
   (`Get-Process ... | Select-Object Path`), accessible sans droits particuliers.
   Le balayage par motif sur `WindowsApps` est conservé en secours (silencieux
   s'il échoue), au cas où une GPO autoriserait l'énumération sur un autre poste.
2. **Le fichier ADOMD s'appelle différemment.** `Microsoft.PowerBI.AdomdClient.dll`
   au lieu de `Microsoft.AnalysisServices.AdomdClient.dll`. Le namespace des
   types .NET à l'intérieur (`Microsoft.AnalysisServices.AdomdClient.AdomdConnection`)
   est inchangé — vérifié par inspection de l'assembly avec `Add-Type` +
   réflexion. **Corrigé (VÉRIFIÉ) :** `Open-AsContext` recherche les deux noms
   de fichier.
3. **`AnalysisServicesWorkspaces` introuvable par recherche.** Recherche
   exhaustive sous `%LOCALAPPDATA%`, `%LOCALAPPDATA%\Packages\...`, `%TEMP%` et
   `%ProgramData%` sur le poste de test : aucun `msmdsrv.port.txt` ni dossier
   `AnalysisServicesWorkspaces` trouvé pour cette variante. Le repli par dossier
   `.db` (étape 1c du script) reste donc **inopérant** pour la variante Store —
   sans conséquence pratique puisque la voie DMV (ADOMD) fonctionne désormais et
   sert de source principale.
4. **Libellé produit.** `Produit detecte` affiche
   `Power BI Desktop (Microsoft Store)` quand le chemin du processus contient
   `WindowsApps\Microsoft.MicrosoftPowerBIDesktop_`.

**Statut global de cette variante : VÉRIFIÉ** — export complet exécuté de bout
en bout (modèle, DMV, couche rapport, JSON normalisé) sur ce poste, rapport
« Retail Analysis Sample PBIX ». Voir `DECISIONS.md` #007.

### Différences Report Server à traiter

1. **Dossier de travail.** Desktop utilise
   `%LOCALAPPDATA%\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces`.
   Report Server utilise
   `%LOCALAPPDATA%\Microsoft\Power BI Desktop SSRS\AnalysisServicesWorkspaces`.
   **Corrigé (NON TESTÉ) :** le script balaie désormais les deux chemins ; celui
   dont le `msmdsrv.port.txt` est le plus récent détermine le produit détecté,
   affiché en console (`-> Produit detecte : ...`) et repris dans la colonne
   `Produit` de `00_Modele.csv`. Aucun poste Report Server n'était disponible
   pour exécuter ce chemin de bout en bout — à confirmer dès qu'un tel poste
   est accessible.
2. **Niveau de compatibilité** plus bas : certaines sections du `.bim` sont
   absentes. Le parsing doit les omettre sans erreur, jamais échouer.
3. **Cadence de publication** distincte : une version Report Server peut être
   antérieure de plusieurs mois à la version Desktop courante.
4. **Chemin d'installation** de Power BI Desktop différent, donc emplacement
   de la DLL ADOMD différent également.
   **Corrigé (NON TESTÉ) :** `Open-AsContext` recherche aussi la DLL ADOMD
   dans `Program Files\Microsoft Power BI Desktop RS\bin` (et son équivalent
   x86). Ce chemin d'installation vient de la documentation Microsoft, pas
   d'une constatation sur poste — à confirmer.

## Formats de fichier

| Format | Statut | Notes |
|---|---|---|
| `.bim` TMSL depuis TE2 | ✅ | Testé sur deux modèles réels |
| `.pbix` → `Report/Layout` | ✅ | Vérifié sur « Retail Analysis Sample PBIX » (Desktop Store) : 4 pages, 24 visuels, 43 filtres extraits. Non encore confirmé sous l'installeur classique ni sous Report Server. |
| `.pbip` → `report.json` classique | ❓ | Code écrit, aucune fixture |
| `.pbip` → arborescence PBIR | ❓ | Code écrit, aucune fixture |

## Environnement d'exécution

| Élément | Statut | Notes |
|---|---|---|
| Windows PowerShell 5.1 64 bits | ✅ | Cible unique |
| ADOMD.NET livré avec Power BI Desktop | ✅ | Vérifié (variante Store, DLL `Microsoft.PowerBI.AdomdClient.dll`) — voir section « Variante Microsoft Store » ci-dessus |
| Provider OLE DB MSOLAP | ❌ | Absent du poste de référence |
| Tabular Editor 2.28 portable | ✅ | |

## Fixtures manquantes

Chaque ligne est un test qu'on ne peut pas écrire aujourd'hui :

- [ ] `.bim` produit depuis Power BI Desktop for Report Server (valide aussi
      la détection du workspace SSRS et de la DLL ADOMD `...Desktop RS\bin`)
- [x] `Report/Layout` extrait d'un `.pbix` Desktop — vérifié en exécution réelle
      (variante Store) le 2026-08-09, mais **aucune fixture capturée** : à faire
      avec `outils\Capture-Fixture.ps1` pour figer un cas de régression.
- [ ] `Report/Layout` extrait d'un `.pbix` Report Server
- [ ] `.bim` avec un rapport contenant au moins un filtre de page/visuel vide
      (`$rowFiltr` vide) — couvre le bug PS 5.1 `@()` sur `List[object]` vide
      corrigé dans `Save` (voir `DECISIONS.md` #008)
- [ ] Dossier `.pbip` au format `report.json` classique
- [ ] Dossier `.pbip` au format PBIR
- [ ] `.bim` contenant un groupe de calcul et des rôles RLS
