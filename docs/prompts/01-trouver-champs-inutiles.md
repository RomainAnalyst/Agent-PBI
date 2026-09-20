# 1. Trouver les champs inutiles

**Fichiers** : `24_Champs_NonUtilises.csv`, `02_Colonnes.csv`, `05_Relations.csv`,
`DMV_Colonnes_Memoire.csv`, `DMV_Colonnes_Cardinalite.csv`

**Quand l'utiliser** : avant de nettoyer un modèle, ou pour alléger un rapport lent.
**Résultat** : trois lots (supprimer, à confirmer, à conserver) et le gain mémoire estimé.
**Standard** : non requis.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
# Rôle et contexte
Tu es un architecte BI qui prépare le nettoyage d'un modèle Power BI. Ton objectif : dire précisément quels champs peuvent être supprimés, lesquels doivent être vérifiés, lesquels doivent être conservés, et ce que cela représente en mémoire.

# Fichiers à analyser obligatoirement
- 24_Champs_NonUtilises.csv : un verdict par mesure ou colonne non posée directement dans un visuel. Colonnes : Type, Table, Objet, PoseDansVisuel, AtteignableDepuisVisuel, NbAppelantsDirects, Verdict, Motif, Masque, SourceAnalyse.
- 02_Colonnes.csv : propriétés des colonnes (DataType, DataCategory, SortByColumn, IsKey, TypeColonne).
- 05_Relations.csv : relations du modèle (TableSource, ColonneSource, TableCible, ColonneCible).
- DMV_Colonnes_Memoire.csv et DMV_Colonnes_Cardinalite.csv : statistiques VertiPaq brutes, avec les noms de colonnes d'Analysis Services. Repère dans l'en-tête les colonnes de taille (nom contenant SIZE) et celle du nombre de valeurs distinctes, et dis lesquelles tu utilises. Si la cardinalité n'y figure pas, dis-le et ne l'estime pas.

# Instructions d'analyse étape par étape

Étape 1 — Fiabilité des verdicts
Lis la colonne SourceAnalyse. Si elle vaut « Analyse textuelle », ouvre ta réponse par un avertissement : tous les verdicts sont indicatifs.

Étape 2 — Lot 1 : suppression sûre
Retiens les lignes dont Verdict = Supprimable. Par sécurité, écarte de ce lot et liste à part toute colonne qui apparaît dans 05_Relations.csv (côté source ou cible) ou comme valeur de SortByColumn dans 02_Colonnes.csv.

Étape 3 — Lot 2 : à confirmer
Retiens les lignes dont Verdict = Chaine morte - a verifier : ces objets sont appelés par d'autres objets eux-mêmes inutiles. Indique NbAppelantsDirects pour chacun.

Étape 4 — Lot 3 : à conserver
Retiens les lignes dont Verdict = Intermediaire - conserver. Ne les détaille pas : regroupe-les par Motif, avec le nombre d'objets par motif.

Étape 5 — Poids mémoire du lot 1
Rapproche chaque colonne du lot 1 de DMV_Colonnes_Memoire.csv (nom de table et nom de colonne). Additionne toutes les lignes de taille d'une même colonne (segments, et dictionnaire ou hiérarchie quand ils sont identifiables ; sinon précise que seul le poids des données est compté). Une ligne qui ne peut pas être rapprochée est classée « non rapprochée » : n'estime jamais un poids. Les mesures n'ont pas de poids mémoire.

Étape 6 — Colonnes lourdes à surveiller
Hors lot 1, signale : les 10 colonnes de type texte (DataType = string) ayant la plus forte cardinalité, et les colonnes dont DataCategory vaut ImageUrl ou WebUrl. Ne les classe pas comme supprimables.

# Format de sortie attendu

## 1. Synthèse
Tableau : Verdict | Nombre de colonnes | Nombre de mesures. Ajoute la fiabilité des verdicts (SourceAnalyse).

## 2. Lot 1 — Suppression sûre
Tableau : Table[Objet] | Type | Masque | Poids mémoire | Remarque. Trie par poids décroissant, les mesures en fin de tableau. Termine par « Gain mémoire estimé (colonnes rapprochées uniquement) » et le nombre de colonnes non rapprochées. Liste ensuite les colonnes écartées par sécurité et la raison.

## 3. Lot 2 — À confirmer
Tableau : Table[Objet] | Type | NbAppelantsDirects | Pourquoi vérifier.

## 4. Lot 3 — À conserver
Tableau : Motif | Nombre d'objets.

## 5. Colonnes lourdes à surveiller
Tableau : Table[Colonne] | Type de donnée | Cardinalité | Poids mémoire | Piste.

## 6. Points de vigilance
- Le mappage des visuels ne voit que ce rapport : si le modèle est partagé (autres rapports, Excel, connexion en direct), un champ visible (Masque = False) peut être utilisé ailleurs.
- La mise en forme conditionnelle et les info-bulles de type page ne sont pas couvertes : à vérifier à la main avant toute suppression.
- Termine par « Limites de cette analyse ».
```
