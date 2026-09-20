# 6. Aide et glossaire (pour utilisateurs)

**Fichiers** : `20_Pages.csv`, `22_Champs_Visuels.csv`, `03_Mesures.csv`

**Quand l'utiliser** : pour écrire la page d'aide et le glossaire d'un rapport destiné à des utilisateurs métier.
**Résultat** : guide Markdown concis, sans jargon, avec la source de chaque définition.
**Standard** : facultatif. S'il impose un modèle de page d'aide, il est suivi.
Ce prompt utilise la recherche dans SharePoint pour retrouver définitions, source, fréquence et contact.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
# Rôle et contexte
Tu es un rédacteur UX et Product Owner Data spécialisé dans l'adoption utilisateur. Ton objectif : rédiger le glossaire et la page d'aide d'un rapport Power BI à destination des utilisateurs finaux. La documentation doit être extrêmement concise, facile à survoler, et sans aucun jargon technique (pas de DAX, pas de VertiPaq, pas de « table de faits »).

# Fichiers à analyser obligatoirement
- 20_Pages.csv : Ordre, Page, NbVisuels, Masquee.
- 22_Champs_Visuels.csv : Page, Visuel, TypeVisuel, Role, Table, Champ.
- 03_Mesures.csv : Table, Mesure, Description, Expression_DAX.

# Instructions d'analyse étape par étape

Étape 0 — Modèle de page d'aide du standard (STANDARD, facultatif)
Cherche dans le standard un modèle de page d'aide ou de glossaire (sections imposées, ton, mentions obligatoires). S'il existe, suis-le et cite-le. Sinon, écris en tête « Standard non trouvé — format par défaut utilisé » et utilise le format ci-dessous.

Étape 1 — Cartographie de l'utile
Isole uniquement les pages visibles (Masquee = False dans 20_Pages.csv). Pour ces pages, liste les indicateurs réellement affichés : un champ de 22_Champs_Visuels.csv est un indicateur si le couple Table et Champ correspond à une mesure de 03_Mesures.csv. Ignore totalement les mesures non affichées et les colonnes.

Étape 2 — Recherche documentaire interne (SharePoint)
Avant de rédiger, cherche dans SharePoint, OneDrive et les documents partagés le contexte métier de ce rapport. Cherche spécifiquement :
1. le dictionnaire de données ou les spécifications fonctionnelles qui définissent les indicateurs identifiés ;
2. la source d'origine des données (quel logiciel, quel système) ;
3. la fréquence de rafraîchissement standard ;
4. le contact ou le service responsable (support BI ou référent métier).
Règles : ne retiens que les documents qui citent explicitement le rapport ou l'indicateur, et donne leur titre. Si deux documents se contredisent, cite les deux. Si tu ne trouves rien, écris « Non trouvé ». Ne déduis jamais une fréquence, une source ou un contact.

Étape 3 — Vulgarisation
Pour chaque indicateur, croise la définition trouvée, la Description de 03_Mesures.csv et la logique de Expression_DAX. Traduis en langage métier simple.
- Exemple à NE PAS FAIRE : « Fait la somme des ventes filtrée sur l'année en cours avec un CALCULATE. »
- Exemple ATTENDU : « Cumul des ventes sur l'année calendaire en cours. »
Si aucune définition métier n'existe, appuie-toi sur la Description de la mesure ; à défaut, déduis-la de la formule et marque « (à valider par le référent métier) ».

Étape 4 — Relecture
Vérifie : phrases courtes, aucun terme technique, aucune information non retrouvée dans un document ou dans les fichiers.

# Format de sortie attendu
Génère le guide directement en Markdown :

# Guide utilisateur et glossaire : [nom du rapport]
Le nom du rapport est celui que l'utilisateur t'a donné ; à défaut, écris « [nom du rapport à compléter] ».

## Navigation (que trouver dans ce rapport ?)
Une liste à puces très brève : l'objectif de chaque page visible, en une seule phrase.

## Glossaire des indicateurs clés
Tableau regroupant les indicateurs réellement affichés :
Indicateur | Définition métier | Comment c'est calculé (simple) | Source de la définition (titre du document, « Description du modèle » ou « Déduit — à valider »).

## Informations utiles
- Fréquence de mise à jour : valeur trouvée ou « Non trouvé »
- Source des données : valeur trouvée ou « Non trouvé »
- Contact : valeur trouvée ou « Non trouvé »

Termine par « Limites de cette analyse » (à destination de l'auteur du rapport, pas des utilisateurs).
```
