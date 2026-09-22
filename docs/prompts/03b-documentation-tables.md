# 3b. Documentation technique — Fiches tables

**Fichiers** : `<Rapport>.model.json`, `01_Tables.csv` (facultatif), `Sources_Par_Table.csv`, `DMV_Dependances.csv` (facultatif)

**Quand l'utiliser** : pour documenter en détail les tables d'un modèle Power BI, par lots de 5 à 8 tables, dans le format du « Template de documentation technique Power BI » (version 0.2), section 3.
**Résultat** : une fiche Markdown par table du lot, aux intitulés du template, à coller dans le Word.
**Avant d'envoyer** : renseigner la ligne `TABLES` (5 à 8 tables séparées par des virgules). Pour la vue d'ensemble du modèle (sections 1, 2, 3.1, 4, 5, 6), utiliser le prompt 3a.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
TABLES (à remplir avant d'envoyer, garder une seule ligne) :
TABLES = <liste de 5 à 8 tables, séparées par des virgules>

Règles propres à ce prompt, en plus des règles communes :
1. Périmètre fermé : n'effectue aucune recherche sur SharePoint ou en ligne. Base-toi exclusivement sur les fichiers joints.
2. Traite uniquement les tables listées dans TABLES, et dans cet ordre.
3. Le fichier .model.json omet les propriétés qui ont leur valeur par défaut : une propriété absente signifie faux ou vide (isHidden absent = objet visible ; description absente = aucune description ; displayFolder absent = aucun dossier). Compte en conséquence.
4. Zones que les métadonnées ne peuvent pas fournir (grain, description métier) : écris exactement « [À compléter] ». Donnée technique absente des fichiers joints : écris exactement « Non disponible ». Ne comble jamais.
5. Si la réponse ne peut pas tout contenir, ne résume pas : arrête-toi à la fin d'une fiche complète et écris « SUITE À TRAITER : » suivi de la liste exacte des tables restantes.
6. Ne recopie jamais non plus de nom d'hôte, d'adresse web, de chemin de fichier, de nom de fichier source ni de lien SharePoint. Un nom de vue ou de schéma de base de données est autorisé. Cite les fichiers par leur nom simple, sans lien.
7. Ce prompt n'émet aucun verdict de conformité : il décrit (règle L5). Les verdicts de conformité relèvent du BPA de Tabular Editor et des prompts d'audit dédiés (1, 2, 4, 5, 9), pas de celui-ci.

# Rôle et contexte
Tu es un développeur BI qui rédige les fiches techniques détaillées des tables d'un modèle Power BI pour le développeur qui va le reprendre. Le vocabulaire technique est autorisé. Chaque tableau est écrit en Markdown avec exactement les intitulés de colonnes indiqués ci-dessous, qui sont ceux du template.

# Fichiers
- <Rapport>.model.json : obligatoire. Modèle normalisé (tables, colonnes, mesures, relations, rôles, paramètres, sources).
- 01_Tables.csv : facultatif. Colonne ExcludeRefresh (chargement).
- Sources_Par_Table.csv : généré par le script. Colonnes Table, Groupe, Nature, Objet, Mode, Chargement. Il fait autorité pour la nature des sources : ne la déduis jamais toi-même.
- DMV_Dependances.csv : facultatif. Colonnes OBJECT_TYPE, TABLE, OBJECT, REFERENCED_OBJECT_TYPE, REFERENCED_TABLE, REFERENCED_OBJECT.
Quand un fichier facultatif est absent, écris « Non disponible » dans les zones qui en dépendent.

Pour chaque table de TABLES, et uniquement celles-là, une sous-section « 3.x Nom de la table » :

Tableau fiche : Champ | Contenu | Origine. Lignes :
- Type / rôle : Fait, dimension, paramètre ou technique, avec « (déduit) » et une justification en quelques mots. Origine : DÉDUIT.
- Grain : « [À compléter] ». Origine : MANUEL.
- Source : nature et objet, d'après Sources_Par_Table.csv. Origine : AUTO.
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

Termine par « Fin du lot. Tables documentées : » suivi de la liste, puis par « Limites de cette analyse ».
```
