# Export des métadonnées Power BI

Outil d'extraction des métadonnées d'un rapport Power BI — modèle sémantique et
couche rapport — vers CSV et JSON.

- `CLAUDE.md` — contexte projet, conventions, pièges connus. Lu à chaque session.
- `DECISIONS.md` — journal des choix structurants.
- `docs/COMPATIBILITE.md` — matrice Desktop / Report Server, et ce qui reste supposé.
- `src/` — le code.
- `tests/` — jeux de test et lanceur.
- `outils/Capture-Fixture.ps1` — capture d'un artefact réel comme jeu de test.

## Démarrage

```powershell
git init
git add .
git commit -m "Point de départ"
```

Le binaire Tabular Editor n'est pas versionné : extraire `TabularEditor.2.x.x.zip`
dans un dossier `TabularEditor\` à la racine.
