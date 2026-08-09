# 10. Reprise d'un rapport hérité

**Fichiers** : `<Rapport>.model.json`, `<Rapport>.report.json`,
`24_Champs_NonUtilises.csv`

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Je reprends ce rapport sans en connaître l'historique. Fais-moi une prise en main.

1. À quoi sert ce rapport, déduit des pages, des visuels et des noms d'objets.
2. Architecture du modèle : tables de faits, dimensions, granularité apparente.
3. Les dix mesures les plus centrales, d'après le graphe de dépendances.
4. Les zones à risque : complexité, dette technique, incohérences.
5. Les questions à poser au concepteur d'origine.

Distingue clairement ce que tu lis dans les fichiers de ce que tu déduis.
```
