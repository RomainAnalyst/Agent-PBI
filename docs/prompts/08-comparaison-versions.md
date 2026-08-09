# 8. Comparaison de deux versions d'un rapport

**Fichiers** : deux exports complets, dans deux dossiers distincts

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Compare les deux exports fournis et produis une note de version.

Sections attendues :
- Modèle : tables, colonnes et mesures ajoutées, supprimées, renommées.
- DAX : mesures dont l'expression a changé, avec le différentiel.
- Relations : créations, suppressions, changements de cardinalité ou de sens.
- Rapport : pages et visuels ajoutés ou supprimés, changements de champs.
- Sécurité : évolutions des rôles et des filtres.

Distingue les changements avec impact utilisateur de ceux purement internes.
Signale les ruptures de compatibilité pour un rapport connecté au modèle.
```
