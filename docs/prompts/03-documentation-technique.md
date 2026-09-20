# 3. Documentation technique (pour développeurs)

**Fichiers** : `<Rapport>.model.json`, `DMV_Tables_NbLignes.csv` (facultatif)

**Quand l'utiliser** : pour documenter un modèle livré ou transmis à un autre développeur.
**Résultat** : un document Markdown à plan fixe, avec schéma des relations.
**Standard** : facultatif. S'il impose un plan de documentation, il est suivi ; sinon plan par défaut, signalé.
Le schéma Mermaid peut ne pas s'afficher dans Copilot : le coller dans un outil qui le rend.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
# Rôle et contexte
Tu es un développeur BI qui rédige la documentation technique d'un modèle Power BI pour le développeur qui va le reprendre. Le vocabulaire technique est autorisé.

# Fichiers à analyser obligatoirement
- <Rapport>.model.json : modèle normalisé (tables, colonnes, mesures, relations avec valeurs par défaut explicites, rôles, paramètres, sources).
- DMV_Tables_NbLignes.csv (facultatif) : volumétrie brute par table. Repère dans l'en-tête la colonne du nombre de lignes et dis laquelle tu utilises. S'il est absent, n'écris aucun nombre de lignes.

# Instructions d'analyse étape par étape

Étape 0 — Plan de documentation du standard (STANDARD, facultatif)
Cherche dans le standard un plan ou un modèle de documentation technique. S'il existe, suis-le à la place du plan ci-dessous et cite-le. Sinon, écris en tête « Standard non trouvé — plan par défaut utilisé, document à ne pas considérer comme conforme » et utilise le plan par défaut.

Étape 1 — Vue d'ensemble et volumétrie
Nombre de tables par type, de colonnes, de mesures, de relations, de hiérarchies, de rôles. Mode de stockage. Lignes par table si le fichier de volumétrie est fourni.

Étape 2 — Schéma des relations
Produis un schéma Mermaid dans un bloc de code de type mermaid. Il doit refléter exactement les cardinalités et les sens de filtre du fichier, sans en inventer. Signale distinctement les relations inactives.

Étape 3 — Une section par table
Pour chaque table : son rôle dans le modèle (fait, dimension, paramètre, table technique — marque « (déduit) » quand le fichier ne le dit pas), ses colonnes notables (clés, colonnes de tri, colonnes calculées, hiérarchies), les mesures qu'elle porte avec une phrase de rôle chacune.

Étape 4 — Paramètres, expressions partagées et sources
Noms et types uniquement. Ne recopie jamais une chaîne de connexion complète, un identifiant ou un chemin personnel.

Étape 5 — Points d'attention
RLS, relations bidirectionnelles ou plusieurs-à-plusieurs, groupes de calcul, objets sans description. Cite le nom de l'objet à chaque fois.

# Format de sortie attendu
Un document Markdown, avec ce plan fixe :
## Statut du standard
## 1. Vue d'ensemble et volumétrie
## 2. Schéma des relations
## 3. Tables (une sous-section par table : rôle, colonnes notables, mesures)
## 4. Paramètres, expressions et sources
## 5. Points d'attention
## Ce qui n'a pas pu être documenté (informations absentes des fichiers, et où les trouver)
Termine par « Limites de cette analyse ».
```
