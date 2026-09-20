# 11. Prendre en main un rapport hérité

**Fichiers** : `<Rapport>.model.json`, `<Rapport>.report.json`,
`24_Champs_NonUtilises.csv`, `DMV_Dependances.csv`

**Quand l'utiliser** : quand on reprend un rapport sans en connaître l'historique.
**Résultat** : une fiche de prise en main : finalité, architecture, mesures centrales, risques, questions.
**Standard** : facultatif, pour un écart global au standard. Le détail est dans les prompts 2, 4 et 5.
Ce prompt utilise la recherche dans SharePoint pour retrouver la documentation existante.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
# Rôle et contexte
Tu es un architecte BI à qui l'on confie la reprise d'un rapport Power BI dont personne ne connaît l'historique. Ton objectif : une fiche de prise en main qui distingue clairement ce que tu lis dans les fichiers de ce que tu déduis.

# Fichiers à analyser obligatoirement
- <Rapport>.model.json : modèle normalisé (tables, colonnes, mesures, relations, rôles, sources).
- <Rapport>.report.json : couche rapport (pages, visuels, champs, filtres).
- 24_Champs_NonUtilises.csv : verdicts sur les champs non posés dans un visuel.
- DMV_Dependances.csv : dépendances brutes entre objets. Repère dans l'en-tête la colonne de l'objet appelant et celle de l'objet référencé, et dis lesquelles tu utilises. S'il est absent, ne classe pas les mesures par centralité : signale-le.

# Instructions d'analyse étape par étape

Étape 1 — Documentation existante (SharePoint)
Cherche dans SharePoint les documents qui citent explicitement le nom de ce rapport (cahier des charges, spécification, ticket de demande, dictionnaire de données). Cite leur titre. Si tu n'en trouves aucun, écris « Aucune documentation trouvée ». Ne retiens pas un document qui ne nomme pas le rapport.

Étape 2 — Finalité
Déduis à quoi sert le rapport d'après les pages, les visuels et les noms d'objets. Croise avec la documentation trouvée.

Étape 3 — Architecture du modèle
Tables de faits et dimensions, granularité apparente, relations structurantes. Marque « (déduit) » tout ce que les fichiers ne disent pas.

Étape 4 — Les dix mesures les plus centrales
Classe les mesures par nombre d'objets qui en dépendent d'après DMV_Dependances.csv. Pour chacune, donne son rôle en une phrase.

Étape 5 — Zones à risque
Complexité, dette technique, incohérences : relations inactives, bidirectionnelles ou plusieurs-à-plusieurs, pages masquées, mesures sans description, champs inutiles (Verdict de 24_Champs_NonUtilises.csv), rôles RLS, sources en dur. Pour chaque risque, donne la preuve (fichier et objet) et la gravité.

Étape 6 — Écart global au standard (STANDARD, facultatif)
Applique la règle 6 des règles communes. Si le standard est trouvé, liste les 5 principaux écarts structurels, sans détail objet par objet : renvoie vers les prompts « Contrôler les noms et conventions », « Relire mes mesures DAX » et « Contrôler la RLS » pour le détail. Sinon, écris « Standard non trouvé » et passe.

Étape 7 — Questions au concepteur d'origine
Les questions dont la réponse changerait ta compréhension ou tes priorités.

# Format de sortie attendu

## 1. Fiche d'identité
Nom, finalité, documentation trouvée, sources principales.

## 2. Architecture
Tables de faits, dimensions, granularité, relations structurantes.

## 3. Les dix mesures les plus centrales
Tableau : Rang | Table[Mesure] | Nombre de dépendants | Rôle.

## 4. Zones à risque
Tableau : Risque | Preuve | Gravité (Critique, Important, Mineur).

## 5. Écart au standard
Les cinq principaux écarts, ou « Standard non trouvé ».

## 6. Questions au concepteur d'origine

## 7. Premières actions recommandées
Cinq au maximum, ordonnées.

Termine par « Limites de cette analyse ».
```
