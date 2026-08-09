# 2. Analyse d'impact avant modification

**Fichiers** : `DMV_Dependances.csv`, `03_Mesures.csv`, `22_Champs_Visuels.csv`

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Je veux modifier ou supprimer [Table[Objet]].

Établis :
1. Ce qui dépend directement de cet objet.
2. La chaîne complète de dépendances en aval, jusqu'aux objets terminaux.
3. Les pages et visuels impactés, avec leur type.
4. Les rôles RLS concernés, s'il y en a.

Conclus par un niveau de risque et la liste ordonnée des points à vérifier
en recette.
```
