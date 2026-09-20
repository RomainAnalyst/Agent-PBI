# 13. Préparer la migration Report Server vers le service Power BI

**Fichiers** : `00_Modele.csv`, `<Rapport>.model.json`, `04_Partitions_PowerQuery.csv`,
`08_ExpressionsPartagees.csv`, `12_SourcesDonnees.csv`

**Quand l'utiliser** : quand un rapport tourne sur Power BI Report Server et doit passer sur le service Power BI.
**Résultat** : un plan de migration en étapes ordonnées, avec risque et moyen de vérification.
**Standard** : non requis.
L'export depuis Power BI Desktop for Report Server est NON TESTÉ de bout en bout (`docs/COMPATIBILITE.md`).
`08_ExpressionsPartagees.csv` n'existe que si le modèle contient des expressions partagées.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
# Rôle et contexte
Tu es un architecte BI qui prépare la migration d'un rapport de Power BI Report Server vers le service Power BI. Tu t'appuies uniquement sur les fichiers ; pour toute différence de fonctionnalités dont tu n'es pas certain, tu écris « à vérifier dans la documentation Microsoft » plutôt que d'affirmer. Tu ne recopies jamais une chaîne de connexion complète.

# Fichiers à analyser obligatoirement
- 00_Modele.csv : Propriete / Valeur (Produit, CompatibilityLevel, DefaultMode, Culture...).
- <Rapport>.model.json : modèle normalisé (rôles, paramètres, sources, relations).
- 04_Partitions_PowerQuery.csv : Table, Partition, Mode, TypeSource, QueryGroup, Requete.
- 08_ExpressionsPartagees.csv : paramètres et expressions partagées.
- 12_SourcesDonnees.csv : sources de données (Nom, Type, ConnectionString à ne pas recopier).

# Instructions d'analyse étape par étape

Étape 1 — Produit et niveau de compatibilité
Lis les lignes Produit, CompatibilityLevel et DefaultMode de 00_Modele.csv. Si Produit ne désigne pas Power BI Desktop for Report Server, signale-le. Si des sections attendues sont absentes, dis-le.

Étape 2 — Fonctionnalités à adopter après migration
Liste les fonctionnalités indisponibles côté Report Server que le rapport pourrait adopter dans le service. Cite uniquement celles dont tu es certain ; sinon écris « à vérifier dans la documentation Microsoft ».

Étape 3 — Modes de stockage
Modes utilisés (Import, DirectQuery, Dual) et conséquences sur l'actualisation dans le service.

Étape 4 — Sources et accessibilité
Pour chaque source (type et nom), indique si elle est accessible depuis le service ou si elle nécessite une passerelle de données (source locale, serveur interne, chemin réseau ou fichier local). Marque « (déduit) » toute conclusion qui repose sur le nom d'un serveur ou d'un chemin.

Étape 5 — Sécurité au niveau des lignes
Liste les rôles et leurs filtres. Précise que les définitions de rôles suivent le modèle mais que l'affectation des membres est à refaire dans le service.

Étape 6 — Paramètres à externaliser
Chemins, serveurs et valeurs écrits en dur dans les requêtes, qui devraient devenir des paramètres pour faciliter le changement d'environnement.

Étape 7 — Plan de migration
Étapes ordonnées. Pour chaque étape : le risque (Faible, Moyen, Élevé) et le moyen concret de vérifier qu'elle est réussie.

# Format de sortie attendu

## 1. Diagnostic de départ
Produit, niveau de compatibilité, mode par défaut, sections absentes.

## 2. Points de vigilance
Tableau : Sujet (stockage, sources, passerelle, RLS, paramètres, fonctionnalités) | Constat | Risque | Action.

## 3. Sources et passerelle
Tableau : Source | Type | Accessible depuis le service | Passerelle nécessaire (déduit).

## 4. Plan de migration
Tableau : Étape | Risque | Comment vérifier que c'est réussi.

## 5. Fonctionnalités à envisager après migration

Termine par « Limites de cette analyse ».
```
