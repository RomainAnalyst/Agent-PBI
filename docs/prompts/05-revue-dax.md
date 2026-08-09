# 5. Revue de code DAX

**Fichiers** : `03_Mesures.csv`, `DMV_Dependances.csv`

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Fais une revue des mesures DAX.

Repère : logique dupliquée entre mesures, colonnes calculées qui gagneraient à
être des mesures, imbrications de CALCULATE difficiles à suivre, FILTER sur table
entière remplaçable par une condition sur colonne, chaînes de dépendances
profondes, mesures dépassant 30 lignes.

Pour chaque cas : la mesure concernée, le problème, l'impact attendu
(lisibilité ou performance), et une réécriture proposée.

Classe par gain décroissant. N'invente aucune mesure inexistante.
```
