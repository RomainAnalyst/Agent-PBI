# Projet — Export des métadonnées Power BI

Ce fichier est lu à chaque session. Il fait autorité sur les conventions et l'état
du projet. Toute décision structurante prise en session doit y être reportée, ou
dans `DECISIONS.md`.

## Objectif

Extraire l'intégralité des métadonnées d'un rapport Power BI — modèle sémantique
**et** couche rapport — vers des CSV exploitables et un JSON destiné à des agents IA.
Le livrable doit être déployable par un collègue sans droits administrateur.

## Contraintes d'environnement (non négociables)

- Poste Windows d'entreprise **sans droits administrateur**.
- Windows PowerShell **5.1** uniquement. Pas de PowerShell 7, pas de `??`,
  pas de `-Parallel`, pas de classes PowerShell.
- Tabular Editor 2 en **version portable** extraite d'un zip, jamais installée.
- Accès réseau restreint : proxy d'entreprise, PowerShell Gallery souvent bloqué.
  Aucune dépendance à installer depuis Internet à l'exécution.
- GPO pouvant bloquer les stratégies d'exécution : le script doit rester lançable
  via `-ExecutionPolicy Bypass` ou par copier-coller dans la console.
- Deux produits en parallèle : **Power BI Desktop** et **Power BI Desktop for
  Report Server**. Voir `docs/COMPATIBILITE.md`.

## Règle de travail la plus importante

**Ne jamais présenter du code non exécuté comme s'il était vérifié.**

Chaque modification appartient à l'une de ces trois catégories, et doit être
annoncée comme telle :

| Statut | Signification |
|---|---|
| `VÉRIFIÉ` | Exécuté sur ce poste, sortie constatée |
| `TESTÉ SUR FIXTURE` | Passe les tests sur un artefact capturé, mais pas exécuté de bout en bout |
| `NON TESTÉ` | Écrit d'après la documentation ou par raisonnement |

Le code `NON TESTÉ` est acceptable, mais doit être signalé explicitement, et testé
avant d'être considéré comme acquis.

## Cycle de travail attendu

1. Modifier le code.
2. `.\tests\Invoke-Tests.ps1` — doit passer sur toutes les fixtures.
3. Exécution réelle avec Power BI ouvert quand le changement touche la découverte
   d'instance, les DMV ou la lecture du `.pbix`.
4. Reporter la décision dans `DECISIONS.md` si elle est structurante.

Ne pas enchaîner plusieurs modifications sans exécuter les tests entre les deux.

## Conventions de code

- Français sans accents dans les identifiants, commentaires et messages console
  (la console Windows d'entreprise est en page de code 850).
- Accents autorisés dans les fichiers Markdown et dans les données produites.
- Fichiers `.ps1` en **UTF-8 avec BOM** — sans BOM, PowerShell 5.1 casse les accents.
- Une fonction par responsabilité, dans `src/`. Pas de fonction de plus de 80 lignes.
- Toute lecture de propriété d'objet JSON passe par le helper `P` (restitution des
  valeurs par défaut TMSL) — jamais d'accès direct `$obj.prop`.
- Aucune sortie parasite : le code de mise à plat renvoie des objets, l'affichage
  console est isolé.

## Pièges déjà rencontrés (ne pas les réintroduire)

- `ConvertFrom-Json` en PS 5.1 plafonne à ~2 Mo. Au-delà, repli
  `JavaScriptSerializer` **suivi d'une reconversion en PSCustomObject**, sinon
  toutes les lectures de propriétés renvoient vide.
- Le TMSL **omet les propriétés à leur valeur par défaut**. Une relation sans
  `fromCardinality` est en `many`, pas « inconnue ».
- Les expressions DAX/M sont tantôt des chaînes, tantôt des tableaux de lignes.
- `Report/Layout` dans le `.pbix` est encodé en **UTF-16 LE**, et ses champs
  `config`, `filters`, `query` sont des **chaînes contenant du JSON** à reparser.
- Le `.pbix` est verrouillé par Power BI Desktop : ouvrir en `FileShare.ReadWrite`.
- `ZipArchive` et `ZipArchiveMode` sont dans l'assembly `System.IO.Compression`,
  pas dans `System.IO.Compression.FileSystem`.
- Le provider OLE DB MSOLAP n'est pas enregistré sur tous les postes. Utiliser
  ADOMD.NET livré avec Power BI Desktop en premier.
- Ne jamais deviner le `.pbix` : un fichier dont le nom ne correspond pas au modèle
  chargé produit une couche rapport silencieusement fausse.
- Les options de Tabular Editor 2 en CLI sont **positionnelles** pour le serveur et
  la base ; `-B` attend un chemin de fichier.

## Hors périmètre

Thème, signets, mise en forme conditionnelle, images embarquées, et toute
modification du rapport. L'outil est en lecture seule.
