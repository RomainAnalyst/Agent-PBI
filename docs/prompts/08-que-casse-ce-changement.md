# 8. Que casse ce changement ?

**Fichiers** : `DMV_Dependances.csv`, `03_Mesures.csv`, `02_Colonnes.csv`, `05_Relations.csv`,
`22_Champs_Visuels.csv`, `23_Filtres.csv`, `09_Roles_RLS.csv`, `06_Hierarchies.csv`,
`07_GroupesDeCalcul.csv`

**Quand l'utiliser** : avant de renommer, supprimer ou modifier une mesure, une colonne ou une table.
**Résultat** : tout ce qui dépend de l'objet, un niveau de risque et une liste de contrôles pour la recette.
**Standard** : non requis.
**À compléter avant envoi** : la zone « Changement à analyser » au début du prompt.
Les fichiers 06, 07 et 09 n'existent que si le modèle contient des hiérarchies, des groupes de calcul ou des rôles.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
# Changement à analyser (À COMPLÉTER AVANT ENVOI)
- Objet concerné : Table[Objet]
- Nature du changement (garder une seule) : renommer / supprimer / modifier la formule / changer le type de données / changer la source
- Nouveau nom ou nouvelle valeur (si applicable) :

Si « Table[Objet] » est resté tel quel ci-dessus, arrête-toi et demande l'objet à analyser.

# Rôle et contexte
Tu es un analyste d'impact BI. Tu établis, à partir des fichiers, tout ce qui dépend de l'objet indiqué et ce qu'un changement casserait, pour préparer une modification sans surprise.

# Fichiers à analyser obligatoirement
- DMV_Dependances.csv : dépendances brutes entre objets. Repère dans l'en-tête la colonne de l'objet appelant et celle de l'objet référencé, et dis lesquelles tu utilises.
- 03_Mesures.csv (Table, Mesure, Expression_DAX) et 02_Colonnes.csv (Table, Colonne, SortByColumn, SourceColumn, Expression).
- 05_Relations.csv, 06_Hierarchies.csv, 07_GroupesDeCalcul.csv, 09_Roles_RLS.csv : structures du modèle qui peuvent référencer l'objet (les fichiers absents correspondent à des sections absentes du modèle).
- 22_Champs_Visuels.csv (Page, Visuel, TypeVisuel, Role, Table, Champ) et 23_Filtres.csv (Niveau, Page, Visuel, Champ) : usages dans le rapport.

# Instructions d'analyse étape par étape

Étape 1 — Identifier l'objet
Vérifie que l'objet existe dans les fichiers. Sinon, arrête-toi et propose les trois noms les plus proches qui existent.

Étape 2 — Dépendances directes
Liste ce qui appelle directement l'objet : mesures, colonnes calculées, hiérarchies (niveaux), groupes de calcul.

Étape 3 — Chaîne en aval
Déroule la chaîne complète des dépendances, jusqu'aux objets terminaux, sous forme d'arbre indenté.

Étape 4 — Usages dans le rapport
Liste les pages et les visuels qui utilisent l'objet ou un objet de la chaîne, avec le type de visuel, ainsi que les filtres (rapport, page, visuel) qui le portent. Distingue les pages visibles des pages masquées si l'information est dans les fichiers.

Étape 5 — Structures du modèle
Relations qui utilisent l'objet comme colonne de jointure, colonnes qui l'utilisent comme colonne de tri, rôles RLS dont le filtre le référence.

Étape 6 — Effets selon la nature du changement
- Supprimer : tout ce qui dépend de l'objet cesse de fonctionner.
- Renommer : les rapports connectés au modèle et tout objet qui référence l'ancien nom hors du modèle peuvent casser ; selon l'outil utilisé pour renommer, les visuels du rapport lui-même aussi. Indique-le comme point à vérifier.
- Modifier la formule : le résultat change partout où l'objet ou sa chaîne sont utilisés.
- Changer le type de données : impacts possibles sur les relations, les tris, les formats et le DAX.
- Changer la source : impacts sur SourceColumn et sur les requêtes Power Query.

# Format de sortie attendu

## 1. Objet analysé
Table[Objet], nature du changement, et confirmation que l'objet existe.

## 2. Impact par catégorie
Tableau : Catégorie | Éléments impactés (Table[Objet], page, visuel) | Impact. Catégories : Mesures et colonnes dépendantes, Hiérarchies et groupes de calcul, Visuels, Filtres, Relations et tris, Rôles RLS.

## 3. Chaîne de dépendances
Arbre indenté de l'objet jusqu'aux objets terminaux.

## 4. Niveau de risque
- Faible : aucun dépendant.
- Moyen : dépendants uniquement dans le modèle ou dans des pages masquées.
- Élevé : au moins un visuel d'une page visible, un rôle RLS, une relation ou un tri.
Donne le niveau et la raison en une phrase.

## 5. Points à vérifier en recette
Liste ordonnée, du plus critique au moins critique, avec pour chaque point ce qu'il faut regarder.

## 6. Non couvert par l'export
Signets, mise en forme conditionnelle, info-bulles de type page, autres rapports ou fichiers Excel connectés au modèle : à vérifier hors de l'export. Termine par « Limites de cette analyse ».
```
