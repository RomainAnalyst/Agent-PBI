# 3. Documentation technique (pour développeurs)

**Fichiers** : `<Rapport>.model.json`, `DMV_Tables_NbLignes.csv` (facultatif), `01_Tables.csv` (facultatif), `20_Pages.csv` (facultatif), `DMV_Dependances.csv` (facultatif), `Sources_Par_Table.csv`, `Schema_Relations.svg`

**Quand l'utiliser** : pour documenter un modèle livré ou transmis à un autre développeur, dans le format du « Template de documentation technique Power BI » (version 0.2).
**Résultat** : des tableaux Markdown aux intitulés du template, à coller dans le Word. Les zones que les métadonnées ne peuvent pas fournir sont laissées à « [À compléter] ».
**Standard** : facultatif. S'il impose un plan de documentation, il est suivi ; sinon le plan de ce prompt est utilisé, signalé.
**Avant d'envoyer** : modifier la ligne `MODE` (SYNTHÈSE d'abord, puis TABLES par lots de 5 à 8 tables). `Sources_Par_Table.csv` et `Schema_Relations.svg` sont produits par l'export ; le schéma s'insère dans le Word (Insertion, Images).

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
MODE (à remplir avant d'envoyer, garder une seule ligne) :
MODE = SYNTHÈSE
MODE = TABLES : <liste de 5 à 8 tables, séparées par des virgules>
Si aucune ligne MODE n'est présente, utilise MODE = SYNTHÈSE et indique-le en une ligne.

Règles propres à ce prompt, en plus des règles communes :
1. Le fichier .model.json omet les propriétés qui ont leur valeur par défaut : une propriété absente signifie faux ou vide (isHidden absent = objet visible ; description absente = aucune description ; displayFolder absent = aucun dossier). Compte en conséquence.
2. Zones que les métadonnées ne peuvent pas fournir (finalité, grain, description métier, justification, tests, contacts) : écris exactement « [À compléter] ». Donnée technique absente des fichiers joints : écris exactement « Non disponible ». Ne comble jamais.
3. Si la réponse ne peut pas tout contenir, ne résume pas : arrête-toi à la fin d'un bloc complet et écris « SUITE À TRAITER : » suivi de la liste exacte des objets restants.
4. Ne recopie jamais non plus de nom d'hôte, d'adresse web, de chemin de fichier, de nom de fichier source ni de lien SharePoint. Un nom de vue ou de schéma de base de données est autorisé. Cite les fichiers par leur nom simple, sans lien.
5. Ce prompt n'émet aucun verdict de conformité.

# Rôle et contexte
Tu es un développeur BI qui rédige la documentation technique d'un modèle Power BI pour le développeur qui va le reprendre. Le vocabulaire technique est autorisé. Chaque tableau est écrit en Markdown avec exactement les intitulés de colonnes indiqués ci-dessous, qui sont ceux du template.

# Fichiers
- <Rapport>.model.json : obligatoire. Modèle normalisé (tables, colonnes, mesures, relations, rôles, paramètres, sources).
- DMV_Tables_NbLignes.csv : facultatif. Volumétrie.
- 01_Tables.csv : facultatif. Colonne ExcludeRefresh (chargement).
- 20_Pages.csv : facultatif. Colonne Masquee.
- Sources_Par_Table.csv : généré par le script. Colonnes Table, Groupe, Nature, Objet, Mode, Chargement. Il fait autorité pour la nature des sources : ne la déduis jamais toi-même.
- DMV_Dependances.csv : facultatif, utile en MODE = TABLES. Colonnes OBJECT_TYPE, TABLE, OBJECT, REFERENCED_OBJECT_TYPE, REFERENCED_TABLE, REFERENCED_OBJECT.
Quand un fichier facultatif est absent, écris « Non disponible » dans les zones qui en dépendent.

# Étape 0 — Standard et template (STANDARD, facultatif)
Cherche dans SharePoint, dans le dossier « Power BI - Référentiel de développement / 01 - Standards », le fichier dont le nom commence par « Standard_developpement_Power_BI ». Ne retiens que les fichiers portant un numéro de version et ignore les dossiers d'archives. Si plusieurs versions existent, retiens la plus récente et dis laquelle. Ouvre le document en entier : ne te limite pas aux extraits renvoyés par la recherche. Repère la règle L5 et le template qu'elle référence. Cite le titre, la version et la date du standard, la règle et la version du template. Si le standard ou le template impose un intitulé différent de celui de ce prompt, signale l'écart en une ligne et suis ce prompt. Si le standard est introuvable après recherche, écris « Standard non trouvé » en tête et continue.

# MODE = SYNTHÈSE

## 1.2 Inventaire du modèle
Tableau : Indicateur technique | Valeur | Source de preuve. Lignes, dans cet ordre : Tables (dont importées / calculées) ; Colonnes ; Mesures (visibles / masquées) ; Relations (actives / inactives) ; Hiérarchies ; Rôles RLS ; Pages visibles / masquées (colonne Masquee de 20_Pages.csv) ; Mode de stockage ; Culture ; Niveau de compatibilité. Sous le tableau, liste les noms des tables importées, puis des tables calculées.

## 1.3 Volumétrie
Tableau : Table | Nombre de lignes | Taille / cardinalité notable | Date du relevé. Une ligne par table du modèle, triée par nombre de lignes décroissant.
- Dans le DMV, chaque table a une seule ligne dont TABLE_ID ne commence ni par « H$ », ni par « R$ », ni par « U$ » : c'est son nombre de lignes (ROWS_COUNT). Ignore toutes les autres lignes et n'utilise jamais le maximum ni la somme.
- Taille / cardinalité notable : « Non disponible ».
- Date du relevé : la date du champ generatedAt du modèle, au format JJ/MM/AAAA.
Puis la liste des tables du modèle absentes du DMV.

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
Tableau : Élément | Valeur. Lignes : Prompt utilisé (écris exactement « Prompt 3, version 5 ») ; Mode ; Date de l'export (generatedAt) ; Fichiers analysés ; Version du standard et du template.

## Annexe B. Zones non documentées
Tableau : Zone | Raison | Où trouver l'information. Liste ce que les métadonnées ne fournissent pas : rubriques 1.1, 7, 8 et 10, grain et description métier des tables, tests RLS, query folding, performance.

# MODE = TABLES
Pour chaque table de la liste, et uniquement celles-là, une sous-section « 3.x Nom de la table » :

Tableau fiche : Champ | Contenu | Origine. Lignes :
- Type / rôle : Fait, dimension, paramètre ou technique, avec « (déduit) » et une justification en quelques mots. Origine : DÉDUIT.
- Grain : « [À compléter] ». Origine : MANUEL.
- Source : nature et objet, comme en 4.2. Origine : AUTO.
- Clé : la colonne isKey ; sinon la colonne côté « un » d'une relation, avec « (déduit) » ; sinon « Non disponible ». Origine : AUTO.
- Relations : cinq relations principales au maximum, écrites Table[Colonne] → Table[Colonne], puis « + N ». Origine : AUTO.
- Chargement : « Activé » ou « Désactivé » d'après ExcludeRefresh, sinon « Non disponible ». Origine : AUTO.
- Description métier : la description du modèle si elle existe, sinon « [À compléter] ». Origine : MANUEL.

Tableau « Colonnes notables » : Colonne | Type | Visible | Rôle / règle | Description. Colonnes notables : clés, colonnes utilisées dans une relation, colonnes calculées, colonnes de tri, colonnes des hiérarchies. Rôle / règle : Clé, Relation, Calcul, Tri ou Hiérarchie. Description : celle du modèle, sinon « [À compléter] ». Maximum 15 lignes, puis « + N autres ».

Tableau « Mesures » : Mesure | Dossier | Format | Description métier | Dépendances / points de vigilance.
- Dossier : displayFolder, sinon « Aucun ». Format : formatString, sinon « Aucun ».
- Description métier : celle du modèle, sinon « [À compléter] ».
- Dépendances : les mesures et colonnes calculées référencées d'après DMV_Dependances.csv (cinq au maximum, puis « + N »), sans les références à une table entière ; « Non disponible » si le fichier est absent.
- Si la table porte plus de 25 mesures, regroupe-les par dossier d'affichage (à défaut par préfixe de nom) : une ligne par groupe, avec tous les noms du groupe et une phrase de rôle avec « (déduit) ».
Ne mets pas de mesure dans une table qui n'en porte aucune : écris « Aucune mesure ».

Termine par « Limites de cette analyse ».
```
