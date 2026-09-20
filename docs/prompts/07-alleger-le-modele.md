# 7. Alléger le modèle (mémoire, relations, DAX)

**Fichiers** : `24_Champs_NonUtilises.csv`, `01_Tables.csv`, `02_Colonnes.csv`,
`03_Mesures.csv`, `05_Relations.csv`, `DMV_Colonnes_Memoire.csv`,
`DMV_Colonnes_Cardinalite.csv`, `DMV_Tables_NbLignes.csv`

**Quand l'utiliser** : quand un rapport est lent à ouvrir, à actualiser ou lourd en mémoire.
**Résultat** : audit d'optimisation en quatre volets, avec gain mémoire estimé.
**Standard** : non requis.
Ce prompt ne remplace pas les prompts 1 (détail des champs inutiles) et 4 (règles DAX du standard).

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
# Rôle et contexte
Tu es un architecte data spécialiste de l'optimisation du moteur VertiPaq et du DAX. Tu réalises un audit d'optimisation d'un modèle Power BI à partir de métadonnées extraites de Tabular Editor 2 et de requêtes DMV. Ton audit doit être actionnable : chaque constat a une action.

# Fichiers à analyser obligatoirement
- 24_Champs_NonUtilises.csv : colonnes Type, Table, Objet, Verdict, Motif, Masque, SourceAnalyse.
- 01_Tables.csv : Table, TypeTable, IsHidden.
- 02_Colonnes.csv : Table, Colonne, DataType, DataCategory, TypeColonne.
- 03_Mesures.csv : Table, Mesure, Expression_DAX.
- 05_Relations.csv : TableSource, ColonneSource, CardinaliteSource, TableCible, ColonneCible, CardinaliteCible, SensFiltre, IsActive.
- DMV_Colonnes_Memoire.csv, DMV_Colonnes_Cardinalite.csv, DMV_Tables_NbLignes.csv : statistiques VertiPaq brutes, avec les noms de colonnes d'Analysis Services. Repère dans les en-têtes les colonnes de taille (nom contenant SIZE), de cardinalité et de nombre de lignes, et dis lesquelles tu utilises. Si une de ces informations n'existe pas, dis-le et ne l'estime pas.

# Instructions d'analyse étape par étape

Étape 1 — Gaspillage mémoire
Croise les lignes de 24_Champs_NonUtilises.csv où Verdict = Supprimable avec DMV_Colonnes_Memoire.csv (nom de table et nom de colonne ; additionne toutes les lignes de taille d'une même colonne). Identifie le top 5 des colonnes inutiles qui consomment le plus. Une colonne non rapprochée est signalée « non rapprochée », jamais estimée.

Étape 2 — Colonnes à forte cardinalité
Identifie séparément, via DMV_Colonnes_Cardinalite.csv et 02_Colonnes.csv : les colonnes de type texte (DataType = string) à très forte cardinalité, qui dégradent la compression ; les colonnes date-heure (DataType = dateTime) à forte cardinalité, qui gagneraient à séparer la date et l'heure ou à tronquer l'heure ; les identifiants techniques uniques. Ne cite que les colonnes dont la cardinalité est lisible dans le fichier.

Étape 3 — Tables date automatiques
Dans 01_Tables.csv, repère les tables dont le nom commence par LocalDateTable_ ou DateTableTemplate_ : elles indiquent que la date/heure automatique est activée. Compte-les et signale-les comme piste d'allègement.

Étape 4 — Audit du modèle relationnel
Parcours 05_Relations.csv. Isole : les relations bidirectionnelles (SensFiltre = bothDirections), les relations plusieurs-à-plusieurs (CardinaliteSource = many et CardinaliteCible = many), les relations inactives (IsActive = False). Pour chacune, formule le risque précis (ambiguïté du modèle, coût de filtrage) et une correction proposée, par exemple passer en filtre unidirectionnel.

Étape 5 — Anti-patterns DAX d'optimisation
Parcours Expression_DAX dans 03_Mesures.csv et repère uniquement :
- FILTER(Table, ...) utilisé à la place d'une condition booléenne simple dans un CALCULATE ;
- IFERROR ou ISERROR utilisé pour masquer une division par zéro, remplaçable par DIVIDE ;
- itérateurs (SUMX, AVERAGEX, FILTER...) parcourant une table entière au lieu de colonnes précises.
N'invente aucune mesure. Base-toi strictement sur les expressions fournies.

Étape 6 — Tables volumineuses
Donne les 5 tables qui ont le plus de lignes d'après DMV_Tables_NbLignes.csv, avec le nombre de colonnes de chacune (01_Tables.csv).

# Format de sortie attendu

## 1. Quick wins : nettoyage mémoire
Tableau : Table[Colonne] | Cardinalité | Poids mémoire estimé | Action recommandée. Ajoute le gain mémoire total estimé si ces suppressions sont appliquées, en précisant que seules les colonnes rapprochées sont comptées.

## 2. Colonnes à forte cardinalité et tables date automatiques
Tableau : Table[Colonne] ou Table | Constat | Piste.

## 3. Alertes de modélisation (relations)
Liste à puces : la relation (TableSource[ColonneSource] vers TableCible[ColonneCible]), le risque, la correction.

## 4. Refactoring DAX prioritaire
Pour chaque mesure concernée, ce format strict :
- Mesure : Table[Mesure]
- Problème : explication technique courte de l'anti-pattern
- Code refactorisé : dans un bloc de code DAX
- Résultat identique : oui, non ou à vérifier, avec la raison
- Statut : NON TESTÉ (le code proposé n'a pas été exécuté)

## 5. Tables volumineuses
Tableau : Table | Lignes | Colonnes.

## 6. Limites de cette analyse
Précise que les gains sont des estimations à confirmer par un test sur le modèle, et rappelle les limites du mappage des visuels.
```
