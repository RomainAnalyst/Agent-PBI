# 12. Script de purge pour Tabular Editor

**Fichiers** : `24_Champs_NonUtilises.csv`

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts) et
les [limites à connaître](../PROMPTS.md#limites-à-connaître) avant utilisation.

```
Génère un script C# pour Tabular Editor 2 supprimant les objets dont le verdict
est Supprimable.

Contraintes :
- Aucune suppression directe : le script marque les objets en les renommant avec
  un préfixe ZZZ_ et en les masquant, pour permettre un retour arrière.
- Une exécution à blanc d'abord, qui liste sans modifier.
- Vérifier l'existence de chaque objet avant d'agir.
- Utiliser les types concrets, jamais les classes abstraites de TOMWrapper.
- Journaliser chaque action.

Rappelle en préambule que le mappage des visuels ne couvre ni les titres
dynamiques, ni la mise en forme conditionnelle, ni les info-bulles, et que ces
cas doivent être vérifiés manuellement avant exécution.
```
