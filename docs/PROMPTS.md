# Bibliothèque de prompts — exploitation des exports

Prompts à utiliser avec les fichiers produits par `Export-PowerBIMetadata-Full.ps1`,
dans **Microsoft 365 Copilot** (relié au SharePoint de l'entreprise).

À la fin de l'export, le menu copie dans le presse-papier : les règles communes
ci-dessous, la liste des fichiers requis, puis le prompt choisi. Les prompts sont
numérotés du plus important au moins important.

## Règles communes à tous les prompts

Premier bloc de code de ce fichier : c'est celui que lit le menu. Ne pas insérer
d'autre bloc de code avant lui.

```
Les fichiers joints font autorité. Contraintes de réponse :

1. N'invente aucun nom de table, colonne, mesure, page ou visuel. Tout objet cité doit exister dans les fichiers et s'écrire Table[Objet].
2. Utilise les colonnes de verdict déjà calculées (Verdict, Motif, Masque, SourceAnalyse) au lieu de refaire le calcul.
3. Distingue ce que tu LIS dans les fichiers de ce que tu DÉDUIS : marque chaque déduction par « (déduit) ».
4. Si une information manque, dis-le et indique quel fichier la contiendrait, plutôt que de la combler. Si un fichier est absent, vide ou semble tronqué, signale-le avant de conclure.
5. Les fichiers ne contiennent que des métadonnées. Ne demande aucune donnée métier. Ne recopie jamais de chaîne de connexion complète, d'identifiant, de mot de passe ni d'adresse e-mail de personne.
6. Standard de l'entreprise (uniquement quand une étape marquée STANDARD te le demande) :
   - ouvre uniquement le fichier « Standard_developpement_Power_BI » (Word) du dossier « 01 - Standards » du référentiel SharePoint « Power BI - Référentiel de développement ». Pour les dérogations, tu peux aussi lire « Guide_de_derogation » du même dossier. N'ouvre aucun autre document de ce référentiel, notamment rien dans « 04 - BPA » ;
   - cite son titre, sa version et sa date. S'il existe plusieurs versions, retiens la plus récente et dis laquelle ;
   - ne juge la conformité que sur les règles écrites dans ce document, jamais sur d'autres documents ni sur tes préférences ;
   - si tu ne le trouves pas : écris « Standard non trouvé » en tête de ta réponse, n'émets aucun verdict de conformité, et ne fais que les analyses marquées « hors standard ».
7. Limites connues : le mappage des visuels ne couvre ni la mise en forme conditionnelle ni les info-bulles de type page, et ne voit que ce rapport (un modèle partagé peut être utilisé ailleurs). Les verdicts de 24_Champs_NonUtilises.csv sont fiables quand SourceAnalyse = DMV, indicatifs quand SourceAnalyse = Analyse textuelle.
8. Termine toujours par une section « Limites de cette analyse » qui liste ce que tu n'as pas pu vérifier.
9. N'écris et ne propose aucun script ni code (C#, .csx, PowerShell, DAX de correction) et ne demande pas d'ouvrir Tabular Editor, sauf si le prompt ci-dessous demande explicitement un script. Décris chaque correction en français, sous la forme Table[Objet] : valeur actuelle → valeur attendue.
```

## Le standard

Le bloc ci-dessus désigne le fichier « Standard_developpement_Power_BI » du dossier
« 01 - Standards » du référentiel SharePoint. S'il est renommé ou déplacé, modifier
la règle 6 ici. Le dossier « 04 - BPA » est volontairement exclu : Copilot y trouvait
un script Tabular Editor et le proposait à l'utilisateur. Ce document doit être lisible par tous les
utilisateurs des prompts : Copilot ne voit que ce que l'utilisateur a le droit
d'ouvrir.

## Utilisation avec Copilot

1. Lancer l'export, puis choisir le prompt dans le menu (il est copié).
2. Ouvrir Copilot et joindre uniquement les fichiers listés pour ce prompt
   (dossier de sortie du rapport).
3. Coller le prompt et envoyer.

Points d'attention :

- Un gros CSV (DMV, `03_Mesures.csv`) peut n'être lu que partiellement. Les règles
  communes demandent à Copilot de le signaler.
- Le prompt 12 compare deux exports : préfixer les fichiers par `A_` (ancienne
  version) et `B_` (nouvelle version) avant de les joindre.
- Le prompt 3 est scindé en deux : 3a (synthèse du modèle) et 3b (fiche détaillée
  par lot de 5 à 8 tables), pour que Copilot n'ait plus à choisir lui-même entre
  les deux intentions. 3a s'appuie sur trois fichiers produits par l'export :
  `Sources_Par_Table.csv` (nature des sources), `Schema_Relations.svg` (schéma à
  insérer dans le Word) et `Volumetrie_Propre.csv` (nombre de lignes par table,
  déjà filtré et trié). La référence au standard de développement (Annexe A de
  3a) est aussi insérée automatiquement par le script depuis
  `config/standard-reference.json`, sans recherche par l'IA.
- Le prompt 8 contient une zone à compléter avant envoi.

## Limites à connaître

Elles conditionnent la fiabilité de plusieurs prompts (voir aussi `DECISIONS.md`) :

- `22_Champs_Visuels.csv` provient des `projections` du visuel : seuls les champs
  posés dans un puits de champs y apparaissent. Les titres dynamiques et les
  filtres (rapport, page, visuel) portant sur une mesure ou une colonne n'y
  figurent pas, mais alimentent le calcul d'usage de `24_Champs_NonUtilises.csv`
  (`DECISIONS.md` #011). **Reste hors périmètre** : mise en forme conditionnelle,
  info-bulles de type « page rapport ».
- Les verdicts de `24_Champs_NonUtilises.csv` sont fiables quand
  `SourceAnalyse = DMV`. En `Analyse textuelle`, ils sont indicatifs.
- `24_Champs_NonUtilises.csv` traite comme racines (jamais `Supprimable`) les
  colonnes de relation, celles référencées par `sortByColumn`, celles d'une
  hiérarchie, les colonnes de `DataCategory` temporelle et celles d'une table
  marquée « table de dates », en plus des champs posés dans un visuel et de la RLS
  (`DECISIONS.md` #012). La colonne `Motif` indique la raison retenue.
- Aucun fichier ne contient de données métier, uniquement des métadonnées. Les
  exports peuvent toutefois contenir des noms de serveurs et des chaînes de
  connexion (`12_SourcesDonnees.csv`, `04_Partitions_PowerQuery.csv`).
- Le support de Power BI Desktop for Report Server est **NON TESTÉ** de bout en
  bout (`docs/COMPATIBILITE.md`).

## Index des prompts

Standard : « Oui » = sans le document du standard, aucun verdict de conformité
n'est rendu (le reste de l'analyse continue, marqué « hors standard »).

| # | Prompt | Fichiers requis | Standard |
|---|---|---|---|
| 1 | [Trouver les champs inutiles](prompts/01-trouver-champs-inutiles.md) | `24_Champs_NonUtilises.csv`, `02_Colonnes.csv`, `05_Relations.csv`, `DMV_Colonnes_Memoire.csv`, `DMV_Colonnes_Cardinalite.csv` | Non |
| 2 | [Contrôler les noms et conventions](prompts/02-controler-noms-conventions.md) | `00_Modele.csv`, `01_Tables.csv`, `02_Colonnes.csv`, `03_Mesures.csv`, `06_Hierarchies.csv`, `20_Pages.csv` | Oui |
| 3a | [Documentation technique — Synthèse du modèle](prompts/03a-documentation-synthese.md) | `<Rapport>.model.json`, `Sources_Par_Table.csv`, `Volumetrie_Propre.csv` (facultatif), `01_Tables.csv` (facultatif), `20_Pages.csv` (facultatif), `Schema_Relations.svg` | Non (référence insérée automatiquement, aucun verdict de conformité) |
| 3b | [Documentation technique — Fiches tables](prompts/03b-documentation-tables.md) | `<Rapport>.model.json`, `01_Tables.csv` (facultatif), `Sources_Par_Table.csv`, `DMV_Dependances.csv` (facultatif) | Non |
| 4 | [Relire mes mesures DAX](prompts/04-relire-mesures-dax.md) | `03_Mesures.csv`, `02_Colonnes.csv`, `DMV_Dependances.csv` | Oui |
| 5 | [Contrôler la RLS](prompts/05-controler-rls.md) | `09_Roles_RLS.csv`, `05_Relations.csv`, `01_Tables.csv` | Oui |
| 6 | [Aide et glossaire (pour utilisateurs)](prompts/06-aide-glossaire-utilisateurs.md) | `20_Pages.csv`, `22_Champs_Visuels.csv`, `03_Mesures.csv` | Facultatif (modèle de page) |
| 7 | [Alléger le modèle (mémoire, relations, DAX)](prompts/07-alleger-le-modele.md) | `24_Champs_NonUtilises.csv`, `01_Tables.csv`, `02_Colonnes.csv`, `03_Mesures.csv`, `05_Relations.csv`, `DMV_Colonnes_Memoire.csv`, `DMV_Colonnes_Cardinalite.csv`, `DMV_Tables_NbLignes.csv` | Non |
| 8 | [Que casse ce changement ?](prompts/08-que-casse-ce-changement.md) | `DMV_Dependances.csv`, `03_Mesures.csv`, `02_Colonnes.csv`, `05_Relations.csv`, `22_Champs_Visuels.csv`, `23_Filtres.csv`, `09_Roles_RLS.csv`, `06_Hierarchies.csv`, `07_GroupesDeCalcul.csv` | Non |
| 9 | [Relire mes requêtes Power Query](prompts/09-relire-requetes-power-query.md) | `04_Partitions_PowerQuery.csv`, `08_ExpressionsPartagees.csv`, `14_QueryGroups.csv`, `12_SourcesDonnees.csv` | Oui |
| 10 | [Générer un script de nettoyage réversible](prompts/10-script-nettoyage-reversible.md) | `24_Champs_NonUtilises.csv`, `02_Colonnes.csv`, `05_Relations.csv`, `06_Hierarchies.csv` | Non |
| 11 | [Prendre en main un rapport hérité](prompts/11-prendre-en-main-rapport-herite.md) | `<Rapport>.model.json`, `<Rapport>.report.json`, `24_Champs_NonUtilises.csv`, `DMV_Dependances.csv` | Facultatif (écart global) |
| 12 | [Comparer deux versions](prompts/12-comparer-deux-versions.md) | huit fichiers de chaque export, préfixés `A_` et `B_` | Non |
| 13 | [Préparer la migration Report Server vers le service Power BI](prompts/13-migration-report-server-vers-service.md) | `00_Modele.csv`, `<Rapport>.model.json`, `04_Partitions_PowerQuery.csv`, `08_ExpressionsPartagees.csv`, `12_SourcesDonnees.csv` | Non |
