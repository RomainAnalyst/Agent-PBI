# Matrice de compatibilité

Statuts : ✅ vérifié sur un poste · 🧪 testé sur fixture · ❓ supposé, non testé ·
❌ non supporté.

Toute case ❓ est une hypothèse. Elle ne doit pas être présentée autrement tant
qu'une exécution ou une fixture ne l'a pas confirmée.

## Produits

| Capacité | Desktop (courant) | Desktop for Report Server |
|---|---|---|
| Détection du port de l'instance | ✅ | ❓ chemin de workspace différent |
| Nom de la base via DMV | ✅ ADOMD | ❓ |
| Export `.bim` par Tabular Editor 2 | ✅ | ❓ |
| Lecture de `Report/Layout` dans le `.pbix` | ❓ | ❓ |
| DMV `DISCOVER_CALC_DEPENDENCY` | ❓ | ❓ |
| Groupes de calcul | ✅ | ❌ selon niveau de compatibilité |
| Chaînes de format dynamiques | ❓ | ❌ |
| Format `.pbip` / PBIR | ❓ | ❌ non disponible |

### Différences Report Server à traiter

1. **Dossier de travail.** Desktop utilise
   `%LOCALAPPDATA%\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces`.
   Report Server utilise
   `%LOCALAPPDATA%\Microsoft\Power BI Desktop SSRS\AnalysisServicesWorkspaces`.
   **Le code actuel ne balaie que le premier chemin.** À corriger en priorité.
2. **Niveau de compatibilité** plus bas : certaines sections du `.bim` sont
   absentes. Le parsing doit les omettre sans erreur, jamais échouer.
3. **Cadence de publication** distincte : une version Report Server peut être
   antérieure de plusieurs mois à la version Desktop courante.
4. **Chemin d'installation** de Power BI Desktop différent, donc emplacement
   de la DLL ADOMD différent également.

## Formats de fichier

| Format | Statut | Notes |
|---|---|---|
| `.bim` TMSL depuis TE2 | ✅ | Testé sur deux modèles réels |
| `.pbix` → `Report/Layout` | ❓ | Jamais exécuté avec succès à ce jour |
| `.pbip` → `report.json` classique | ❓ | Code écrit, aucune fixture |
| `.pbip` → arborescence PBIR | ❓ | Code écrit, aucune fixture |

## Environnement d'exécution

| Élément | Statut | Notes |
|---|---|---|
| Windows PowerShell 5.1 64 bits | ✅ | Cible unique |
| ADOMD.NET livré avec Power BI Desktop | ❓ | Remplace MSOLAP, non encore constaté |
| Provider OLE DB MSOLAP | ❌ | Absent du poste de référence |
| Tabular Editor 2.28 portable | ✅ | |

## Fixtures manquantes

Chaque ligne est un test qu'on ne peut pas écrire aujourd'hui :

- [ ] `.bim` produit depuis Power BI Desktop for Report Server
- [ ] `Report/Layout` extrait d'un `.pbix` Desktop
- [ ] `Report/Layout` extrait d'un `.pbix` Report Server
- [ ] Dossier `.pbip` au format `report.json` classique
- [ ] Dossier `.pbip` au format PBIR
- [ ] `.bim` contenant un groupe de calcul et des rôles RLS
