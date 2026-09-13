# Bibliothèque de prompts — exploitation des exports

Prompts à utiliser avec les fichiers produits par `Export-PowerBIMetadata-Full.ps1`,
directement dans Claude Code (`sorties/<NomDuRapport>/`) ou en pièces jointes.

Chaque prompt est désormais dans son propre fichier sous `docs/prompts/`.

---

## Règles communes à tous les prompts

À reprendre en tête de chaque demande, ou à laisser ici comme référence partagée :

```
Les fichiers fournis font autorité. Contraintes de réponse :

- N'invente aucun nom de table, colonne, mesure, page ou visuel. Tout objet cité
  doit exister dans les fichiers, et être écrit sous la forme Table[Objet].
- Ne déduis pas un verdict quand une colonne le donne déjà : utilise la colonne.
- Si une information manque pour répondre, dis-le et indique quel fichier
  la contiendrait, plutôt que de combler.
- Signale les limites connues des données quand elles affectent ta conclusion.
```

## Limites à connaître

Elles conditionnent la fiabilité de plusieurs prompts ci-dessous :

- `22_Champs_Visuels.csv` provient des `projections` du visuel : seuls les
  champs posés dans un puits de champs y apparaissent. Les titres dynamiques
  et les filtres (rapport/page/visuel) portant sur une mesure ou une colonne
  n'y figurent pas non plus, mais alimentent désormais le calcul d'usage de
  `24_Champs_NonUtilises.csv` (voir `DECISIONS.md` #011) : une mesure utilisée
  uniquement en titre dynamique ou en filtre n'y apparaît plus comme
  supprimable. **Reste hors périmètre** : mise en forme conditionnelle,
  info-bulles de type « page rapport » (une page masquée utilisée comme
  info-bulle n'est pas reliée au champ qui la déclenche).
- Les verdicts de `24_Champs_NonUtilises.csv` sont fiables quand
  `SourceAnalyse = DMV`. En `Analyse textuelle`, ils sont indicatifs.
- `24_Champs_NonUtilises.csv` traite comme racines (jamais `Supprimable`) les
  colonnes de relation, les colonnes référencées par `sortByColumn`, les
  colonnes utilisées dans une hiérarchie, les colonnes de `DataCategory`
  temporelle et les colonnes d'une table marquée « table de dates », en plus
  des champs posés dans un visuel et de la RLS (voir `DECISIONS.md` #012).
  La colonne `Motif` indique laquelle de ces raisons justifie qu'un objet
  n'apparaisse pas comme supprimable.
- Aucun fichier ne contient de données métier, uniquement des métadonnées.

---

## Index des prompts

| # | Prompt | Fichiers requis |
|---|---|---|
| 1 | [Plan de nettoyage du modèle](prompts/01-plan-nettoyage-modele.md) | `24_Champs_NonUtilises.csv`, `02_Colonnes.csv`, `DMV_Colonnes_Memoire.csv`, `DMV_Colonnes_Cardinalite.csv` |
| 2 | [Analyse d'impact avant modification](prompts/02-analyse-impact.md) | `DMV_Dependances.csv`, `03_Mesures.csv`, `22_Champs_Visuels.csv` |
| 3 | [Audit de la sécurité au niveau des lignes](prompts/03-audit-rls.md) | `09_Roles_RLS.csv`, `05_Relations.csv`, `01_Tables.csv` |
| 4 | [Revue des conventions de nommage](prompts/04-revue-nommage.md) | `01_Tables.csv`, `02_Colonnes.csv`, `03_Mesures.csv` |
| 5 | [Revue de code DAX](prompts/05-revue-dax.md) | `03_Mesures.csv`, `DMV_Dependances.csv` |
| 6 | [Documentation technique du modèle](prompts/06-doc-technique-modele.md) | `<Rapport>.model.json` |
| 7 | [Page d'aide destinée aux utilisateurs](prompts/07-page-aide-utilisateurs.md) | `<Rapport>.model.json`, `<Rapport>.report.json` |
| 8 | [Comparaison de deux versions d'un rapport](prompts/08-comparaison-versions.md) | deux exports complets, dans deux dossiers distincts |
| 9 | [Audit des requêtes Power Query](prompts/09-audit-power-query.md) | `04_Partitions_PowerQuery.csv`, `08_ExpressionsPartagees.csv`, `14_QueryGroups.csv` |
| 10 | [Reprise d'un rapport hérité](prompts/10-reprise-rapport-herite.md) | `<Rapport>.model.json`, `<Rapport>.report.json`, `24_Champs_NonUtilises.csv` |
| 11 | [Préparation d'une migration Report Server vers Desktop](prompts/11-migration-report-server.md) | `00_Modele.csv`, `<Rapport>.model.json`, `04_Partitions_PowerQuery.csv` |
| 12 | [Script de purge pour Tabular Editor](prompts/12-script-purge-tabular-editor.md) | `24_Champs_NonUtilises.csv` |
