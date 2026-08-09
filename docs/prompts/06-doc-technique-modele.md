# 6. Documentation technique du modèle

**Fichiers** : `<Rapport>.model.json`

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Produis la documentation technique du modèle en Markdown.

Plan imposé : vue d'ensemble et volumétrie, schéma des relations en Mermaid,
puis une section par table (rôle dans le modèle, colonnes notables, mesures
portées), et enfin la liste des paramètres et sources.

Le schéma Mermaid doit refléter exactement les cardinalités et sens de filtre
du fichier, sans en inventer.

Destinataire : un développeur BI qui reprend le rapport. Vocabulaire technique
autorisé.
```
