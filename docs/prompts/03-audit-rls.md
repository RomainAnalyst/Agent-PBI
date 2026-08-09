# 3. Audit de la sécurité au niveau des lignes

**Fichiers** : `09_Roles_RLS.csv`, `05_Relations.csv`, `01_Tables.csv`

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Audite la configuration RLS.

Pour chaque rôle : ce qu'il autorise en langage courant, les tables filtrées,
et les tables atteintes indirectement par propagation via les relations.

Signale spécifiquement :
- les tables non couvertes par un filtre alors qu'elles sont reliées à une table
  filtrée par une relation qui ne propage pas le filtre dans le bon sens ;
- les relations bidirectionnelles, qui peuvent contourner un filtre de sécurité ;
- les rôles sans membre déclaré ;
- les filtres identiques dupliqués entre rôles.
```
