# 3a. Documentation technique — Synthèse du modèle

**Fichiers** : `<Rapport>.model.json`, `Sources_Par_Table.csv`, `Volumetrie_Propre.csv` (facultatif), `01_Tables.csv` (facultatif), `20_Pages.csv` (facultatif), `Schema_Relations.svg`

**Quand l'utiliser** : pour produire la vue d'ensemble technique d'un modèle Power BI livré ou transmis à un autre développeur, dans le format du « Template de documentation technique Power BI » (version 0.2), sections 1, 2, 3.1, 4, 5 et 6.
**Résultat** : des tableaux Markdown aux intitulés du template, à coller dans le Word. Les zones que les métadonnées ne peuvent pas fournir sont laissées à « [À compléter] ».
**Standard** : la référence (nom, version, date) est insérée automatiquement par le script à la place des balises `<STANDARD_VERSION>` et `<TEMPLATE_INFO>` en Annexe A, à partir de `config\standard-reference.json`. L'IA ne cherche pas le standard elle-même.
**Avant d'envoyer** : `Sources_Par_Table.csv`, `Volumetrie_Propre.csv` et `Schema_Relations.svg` sont produits par l'export ; le schéma s'insère dans le Word (Insertion, Images). Pour la fiche détaillée de chaque table (section 3.x), utiliser le prompt 3b, par lots de 5 à 8 tables.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
Règles propres à ce prompt, en plus des règles communes :
1. Périmètre fermé : n'effectue aucune recherche sur SharePoint ou en ligne. Base-toi exclusivement sur les fichiers joints.
2. Le fichier .model.json omet les propriétés qui ont leur valeur par défaut : une propriété absente signifie faux ou vide (isHidden absent = objet visible ; description absente = aucune description ; displayFolder absent = aucun dossier). Compte en conséquence.
3. Zones que les métadonnées ne peuvent pas fournir (finalité, description métier, justification, tests, contacts) : écris exactement « [À compléter] ». Donnée technique absente des fichiers joints : écris exactement « Non disponible ». Ne comble jamais.
4. Ne recopie jamais non plus de nom d'hôte, d'adresse web, de chemin de fichier, de nom de fichier source ni de lien SharePoint. Un nom de vue ou de schéma de base de données est autorisé. Cite les fichiers par leur nom simple, sans lien.
5. Ce prompt n'émet aucun verdict de conformité.

# Rôle et contexte
Tu es un développeur BI qui rédige la synthèse technique d'un modèle Power BI pour le développeur qui va le reprendre. Le vocabulaire technique est autorisé. Chaque tableau est écrit en Markdown avec exactement les intitulés de colonnes indiqués ci-dessous, qui sont ceux du template.

# Fichiers
- <Rapport>.model.json : obligatoire. Modèle normalisé (tables, colonnes, mesures, relations, rôles, paramètres, sources).
- Sources_Par_Table.csv : généré par le script. Colonnes Table, Groupe, Nature, Objet, Mode, Chargement. Il fait autorité pour la nature des sources : ne la déduis jamais toi-même.
- Volumetrie_Propre.csv : facultatif, généré par le script à partir du DMV, déjà filtré (lignes internes VertiPaq exclues) et trié. Colonnes Table, NombreLignes. Il fait autorité pour la volumétrie : ne recalcule rien à partir des DMV bruts.
- 01_Tables.csv : facultatif. Colonne ExcludeRefresh (chargement).
- 20_Pages.csv : facultatif. Colonne Masquee.
Quand un fichier facultatif est absent, écris « Non disponible » dans les zones qui en dépendent.

## 1.2 Inventaire du modèle
Tableau : Indicateur technique | Valeur | Source de preuve. Lignes, dans cet ordre : Tables (dont importées / calculées) ; Colonnes ; Mesures (visibles / masquées) ; Relations (actives / inactives) ; Hiérarchies ; Rôles RLS ; Pages visibles / masquées (colonne Masquee de 20_Pages.csv) ; Mode de stockage ; Culture ; Niveau de compatibilité. Sous le tableau, liste les noms des tables importées, puis des tables calculées.

## 1.3 Volumétrie
Tableau : Table | Nombre de lignes | Taille / cardinalité notable | Date du relevé.
- Recopie les lignes de Volumetrie_Propre.csv dans l'ordre fourni (déjà filtré et trié). Ne recalcule rien et ne retrie rien.
- Taille / cardinalité notable : « Non disponible ».
- Date du relevé : la date du champ generatedAt du modèle, au format JJ/MM/AAAA.
- Si Volumetrie_Propre.csv est absent, écris « Non disponible » dans tout le tableau et n'essaie pas de déduire la volumétrie d'un autre fichier.
Puis la liste des tables du modèle absentes de Volumetrie_Propre.csv (s'il est présent).

## 2. Schéma des relations
a) Tableau exhaustif, une ligne par relation : Table 1 / colonne (côté un) | Table 2 / colonne (côté plusieurs) | Cardinalité | Filtrage | Active | Justification / usage.
- Table 1 est la table dont la cardinalité est « one », Table 2 l'autre.
- Cardinalité : 1:* pour plusieurs-à-un, 1:1, *:*.
- Filtrage : « Simple » si oneDirection, « Bidirectionnel » sinon.
- Active : Oui ou Non. Justification / usage : « [À compléter] ».
b) Le schéma est fourni par le script dans Schema_Relations.svg, à insérer dans le Word. Ne produis pas de Mermaid. Écris seulement : « Schéma : voir Schema_Relations.svg ».

## 3.1 Inventaire des tables
Tableau : Table | Type | Visible | Nb colonnes | Nb mesures | Lignes. Une ligne par table. Type : Importée ou Calculée.

## 4.1 Paramètres et environnements
Tableau : Paramètre | Type | Valeurs autorisées | Valeur par défaut | Usage. Une ligne par expression partagée dont la définition est un paramètre. Valeurs autorisées : le nombre de valeurs, sans les recopier si l'une ressemble à un nom d'hôte ou à une adresse (écris par exemple « 2 valeurs, dont un nom d'hôte non reproduit »). Valeur par défaut : « Non disponible » si elle n'est pas lisible. Usage : « [À compléter] ». S'il n'y en a aucun, dis dans quelle partie du fichier tu as cherché.

## 4.2 Sources et requêtes Power Query
Recopie Sources_Par_Table.csv en tableau, une ligne par table : Requête | Groupe | Source | Objet | Mode | Chargement | Query folding / remarque.
- Requête = colonne Table ; Source = colonne Nature ; Groupe, Objet, Mode et Chargement = colonnes du même nom. Ne reclasse rien et ne corrige rien.
- Query folding / remarque : « Non disponible ».
- Si Sources_Par_Table.csv est absent, écris « Non disponible » et n'essaie pas de déduire les sources.
Puis un tableau « Synthèse par nature de source » calculé à partir de ce fichier : Nature de la source | Nombre | Tables. Le total doit être égal au nombre de tables du modèle.

## 4.3 Transformations structurantes
Ne génère pas cette rubrique. Écris le tableau Étape / composant | Emplacement | Description | Justification | Impact avec une seule ligne dont chaque cellule vaut « [À compléter] ».

## 5. Points d'attention
Tableau : Catégorie | Objet concerné | Constat / risque | Décision / justification | Action. Les catégories, dans cet ordre, toutes présentes même sans constat (écris alors « Aucun ») :
- Relation inactive ou atypique : relations inactives, bidirectionnelles, plusieurs-à-plusieurs ; groupes de calcul.
- Table sans aucune relation : liste des tables, avec leur nombre de lignes si disponible.
- Table exclue de l'actualisation : tables où ExcludeRefresh = True.
- Performance : « Non disponible ».
- Objet sans description : nombre par type (tables visibles, colonnes visibles, mesures visibles) et 10 exemples au maximum, écrits Table[Objet].
- Donnée sensible : une ligne par table concernée, avec la liste complète (sans limite de nombre) des colonnes dont le nom laisse penser qu'elles portent des noms, prénoms, adresses e-mail, numéros de téléphone, adresses postales, identifiants clients ou de points de livraison (PRM), ou des NNI, avec « (déduit) ». Ne dis rien du contenu.
- Mesure de test ou de debug visible : mesures visibles dont le nom contient DEBUG, TEST, TMP ou TEMP.
Décision / justification et Action : « [À compléter] ».

## 6. Sécurité et RLS
Tableau : Rôle | Périmètre | Expression / principe | Affectation | Test effectué | Résultat. Périmètre : les Table[Colonne] filtrées, ou « aucun filtre ». Expression / principe : une phrase en clair, sans recopier de code, d'identifiant ni d'adresse, avec « (déduit) ». Affectation, Test effectué, Résultat : « [À compléter] ».

## Annexe A. Traçabilité de la génération
Tableau : Élément | Valeur. Lignes :
- Prompt utilisé : Prompt 3a, version 1
- Date de l'export : generatedAt
- Fichiers analysés : liste des fichiers analysés
- Standard de référence : <STANDARD_VERSION>
- Template associé : <TEMPLATE_INFO>

## Annexe B. Zones non documentées
Tableau : Zone | Raison | Où trouver l'information. Liste ce que les métadonnées ne fournissent pas : rubriques 1.1, 7, 8 et 10, grain et description métier des tables (voir prompt 3b), tests RLS, query folding, performance.

Termine par « Limites de cette analyse ».
```
