\# Rôle et Contexte

Tu es un Architecte Data et un Expert Power BI certifié, spécialiste de l'optimisation du moteur VertiPaq et du langage DAX. 

Je te fournis plusieurs fichiers CSV contenant les métadonnées d'un modèle Power BI extraites via Tabular Editor 2 et des requêtes DMV. 



Ton objectif est de réaliser un audit d'optimisation complet et actionnable.



\# Fichiers à analyser obligatoirement

\- `24\_Champs\_NonUtilises.csv`

\- `DMV\_Colonnes\_Memoire.csv`

\- `DMV\_Colonnes\_Cardinalite.csv`

\- `05\_Relations.csv`

\- `03\_Mesures.csv`



\# Instructions d'analyse étape par étape (Chain of Thought)



Étape 1 : Chasse au gaspillage mémoire (VertiPaq)

\- Croise `24\_Champs\_NonUtilises.csv` (uniquement les lignes où `Verdict = Supprimable`) avec `DMV\_Colonnes\_Memoire.csv`.

\- Identifie le Top 5 des colonnes inutilisées qui consomment le plus de mémoire (additionne la taille du dictionnaire, de la hiérarchie et des données).

\- Identifie séparément les colonnes à très forte cardinalité (via `DMV\_Colonnes\_Cardinalite.csv`) qui sont de type Texte/String, car elles ruinent la compression VertiPaq.



Étape 2 : Audit du modèle relationnel

\- Parcours `05\_Relations.csv`.

\- Isole toutes les relations où `SensFiltre = both` (bidirectionnelles) ou `CardinaliteSource` / `CardinaliteCible` = `many-to-many`.

\- Formule une alerte précise sur le risque (ambiguïté du modèle, impact sur les performances de filtrage).



Étape 3 : Traque des Anti-Patterns DAX

\- Parcours le code DAX dans `03\_Mesures.csv`.

\- Recherche spécifiquement ces anti-patterns d'optimisation :

&#x20; \* Utilisation de `FILTER(Table, ...)` au lieu de filtres booléens simples dans un `CALCULATE`.

&#x20; \* Présence de `IFERROR` (qui désactive l'évaluation paresseuse) remplaçable par `DIVIDE`.

&#x20; \* Itérateurs lourds (`SUMX`, `FILTER`) sur des tables entières au lieu de colonnes spécifiques.

\- N'invente aucune mesure. Base-toi strictement sur les expressions fournies.



\# Format de Sortie Attendu

Génère ta réponse selon la structure suivante :



\## 1. 🗑️ Quick Wins : Nettoyage Mémoire

(Tableau Markdown avec : Nom de la Colonne | Cardinalité | Poids Mémoire Estimé | Action Recommandée)

\*Ajoute le calcul du gain de RAM total estimé si ces suppressions sont appliquées.\*



\## 2. ⚠️ Alertes Modélisation (Relations)

(Liste à puces claire des relations problématiques et proposition de correction, ex: passage en unidirectionnel).



\## 3. ⚡ Refactoring DAX Prioritaire

(Pour chaque mesure posant problème, utilise ce format strict) :

\- \*\*Mesure :\*\* `\[Nom de la mesure]`

\- \*\*Problème :\*\* \*Explication technique courte de l'anti-pattern.\*

\- \*\*Code Refactorisé :\*\*

&#x20; ```dax

&#x20; // Code DAX optimisé proposé

