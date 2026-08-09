# 1. Plan de nettoyage du modèle

**Fichiers** : `24_Champs_NonUtilises.csv`, `02_Colonnes.csv`,
`DMV_Colonnes_Memoire.csv`, `DMV_Colonnes_Cardinalite.csv`

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Construis un plan de nettoyage priorisé du modèle.

Classe les objets en trois lots :
- Lot 1, suppression sûre : Verdict = Supprimable, non masqué, non impliqué dans
  une relation (croise avec 05_Relations.csv).
- Lot 2, à confirmer : Verdict = Chaine morte - a verifier.
- Lot 3, à ne pas toucher : Verdict = Intermediaire - conserver.

Pour le lot 1, trie par empreinte mémoire décroissante en croisant
DMV_Colonnes_Memoire.csv, et donne le gain estimé cumulé.

Signale séparément les colonnes à forte cardinalité et les colonnes de type
image ou URL, qui pèsent le plus lourd.

Termine par les cas où le verdict est peu fiable, en rappelant les limites du
mappage des visuels.
```
