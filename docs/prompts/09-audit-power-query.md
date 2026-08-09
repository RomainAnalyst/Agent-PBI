# 9. Audit des requêtes Power Query

**Fichiers** : `04_Partitions_PowerQuery.csv`, `08_ExpressionsPartagees.csv`,
`14_QueryGroups.csv`

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Audite la couche de transformation.

Repère : chaînes de connexion en dur qui devraient être des paramètres, logique
dupliquée entre requêtes, étapes susceptibles de casser le query folding,
sources hétérogènes pour un même domaine, requêtes sans regroupement.

Pour chaque point : la requête concernée, le risque, et la correction proposée.
Précise quand une conclusion sur le query folding est incertaine faute de voir
le plan d'exécution.
```
