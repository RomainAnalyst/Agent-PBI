# 10. Générer un script de nettoyage réversible

**Fichiers** : `24_Champs_NonUtilises.csv`, `02_Colonnes.csv`, `05_Relations.csv`,
`06_Hierarchies.csv`

**Quand l'utiliser** : après le prompt 1, pour appliquer le nettoyage sans suppression définitive.
**Résultat** : un script Tabular Editor 2 de marquage (avec exécution à blanc) et un script de retour arrière.
**Standard** : non requis.
Le code généré n'est jamais exécuté par Copilot : il est NON TESTÉ tant qu'il n'a pas tourné sur une copie du modèle.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

```
# Rôle et contexte
Tu es un développeur BI qui écrit des scripts C# pour Tabular Editor 2. Ton objectif : produire un script qui marque les objets supprimables sans jamais les supprimer, et un script qui annule ce marquage. Un mauvais script peut casser un modèle : la prudence prime sur la concision.

# Fichiers à analyser obligatoirement
- 24_Champs_NonUtilises.csv : Type, Table, Objet, Verdict, Motif, Masque, SourceAnalyse.
- 02_Colonnes.csv : Table, Colonne, TypeColonne, SortByColumn, IsKey.
- 05_Relations.csv : colonnes de jointure (TableSource, ColonneSource, TableCible, ColonneCible).
- 06_Hierarchies.csv : colonnes utilisées dans des hiérarchies (absent si le modèle n'en a pas).

# Instructions d'analyse étape par étape

Étape 1 — Périmètre
Retiens uniquement les lignes dont Verdict = Supprimable. N'inclus jamais les lignes « Chaine morte - a verifier » ni « Intermediaire - conserver ». Par sécurité, exclus et liste à part toute colonne présente dans 05_Relations.csv, dans 06_Hierarchies.csv, comme valeur de SortByColumn ou avec IsKey = True. Si SourceAnalyse vaut « Analyse textuelle », préviens que les verdicts sont indicatifs.

Étape 2 — Script 1 : marquage
Pour chaque objet retenu, le script le masque et préfixe son nom par ZZZ_. Contraintes :
- une variable de début de script DryRun, à true par défaut : en exécution à blanc, le script liste ce qu'il ferait sans rien modifier ;
- vérifier l'existence de chaque objet avant d'agir, et ignorer sans erreur un objet absent ;
- script réentrant : relancé, il ne préfixe pas une deuxième fois un objet déjà préfixé ;
- utiliser les types concrets de Tabular Editor 2 avec un cast explicite quand il est nécessaire (par exemple pour une colonne calculée), jamais les classes abstraites de TOMWrapper ;
- ne pas utiliser l'interpolation de chaînes $"..." (non supportée par le compilateur des scripts Tabular Editor 2) : concaténer avec l'opérateur + ;
- journaliser chaque action (type, table, objet, action, mode exécution à blanc ou réel) et afficher le journal complet en fin de script ;
- n'utiliser que des API de Tabular Editor 2 dont tu es certain de l'existence ; sinon, écrire un commentaire « API à vérifier ».

Étape 3 — Script 2 : retour arrière
Un second script retire le préfixe ZZZ_ et restaure la visibilité d'origine. La visibilité d'origine de chaque objet est la valeur de la colonne Masque du fichier : un objet qui était déjà masqué doit le rester. Mêmes contraintes que le script 1.

Étape 4 — Mode d'emploi
Cinq lignes maximum : ordre d'exécution, contrôle du journal en exécution à blanc, travail sur une copie du modèle, période d'observation avant toute suppression définitive.

# Format de sortie attendu

## 1. Avertissements
Rappelle en préambule que le mappage des visuels ne couvre ni la mise en forme conditionnelle ni les info-bulles de type page, et ne voit que ce rapport : ces cas doivent être vérifiés à la main avant d'exécuter quoi que ce soit. Indique le nombre d'objets retenus, le nombre d'objets exclus par sécurité et la fiabilité des verdicts.

## 2. Objets exclus par sécurité
Tableau : Table[Objet] | Raison de l'exclusion.

## 3. Script 1 — Marquage (exécution à blanc par défaut)
Dans un bloc de code C#. Le commentaire d'en-tête contient « Statut : NON TESTÉ ».

## 4. Script 2 — Retour arrière
Dans un bloc de code C#. Le commentaire d'en-tête contient « Statut : NON TESTÉ ».

## 5. Mode d'emploi

Termine par « Limites de cette analyse ».
```
