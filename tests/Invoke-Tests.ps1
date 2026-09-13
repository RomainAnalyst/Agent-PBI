<#
    Lance les tests sur toutes les fixtures presentes.
    Pester n'est pas requis : la PowerShell Gallery est souvent bloquee en
    entreprise. Si Pester 5 est disponible, il pourra etre branche ici.
#>
$fixtures = Get-ChildItem (Join-Path $PSScriptRoot "fixtures") -Directory -ErrorAction SilentlyContinue

if (-not $fixtures) {
    Write-Host "Aucune fixture. Utilise outils\Capture-Fixture.ps1 pour en creer une." -ForegroundColor DarkYellow
    return
}

$echec = $false
$scriptExport = Join-Path (Split-Path $PSScriptRoot -Parent) "src\Export-PowerBIMetadata-Full.ps1"

foreach ($f in $fixtures) {
    Write-Host "`n=== $($f.Name) ===" -ForegroundColor Cyan
    $manif = Join-Path $f.FullName "manifeste.json"
    if (Test-Path $manif) {
        $m = Get-Content $manif -Raw | ConvertFrom-Json
        Write-Host "    produit : $($m.produit)   version : $($m.versionPBIDesktop)" -ForegroundColor DarkGray
    }

    $bimPath = Join-Path $f.FullName "Model.bim"
    if (-not (Test-Path $bimPath)) {
        # TODO : ajouter ici la comparaison a attendu.json (nb tables, colonnes,
        #        mesures, relations, pages, visuels) pour les fixtures qui n'ont
        #        pas de Model.bim exploitable (capture .pbix seule, etc.).
        Write-Host "    (pas de Model.bim -- aucune assertion definie)" -ForegroundColor DarkYellow
        continue
    }

    $sortie = Join-Path ([System.IO.Path]::GetTempPath()) "PBI_Test_$($f.Name)_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $repDir = Get-ChildItem $f.FullName -Directory -Filter "*.Report" -ErrorAction SilentlyContinue | Select-Object -First 1

    $params = @{
        BimPath       = $bimPath
        OutputFolder  = $sortie
        ReportName    = $f.Name
        SkipDmv       = $true
        SansOuverture = $true
    }
    if ($repDir) { $params['PbipFolder'] = $f.FullName }

    & $scriptExport @params | Out-Null

    $csvPath = Join-Path (Join-Path $sortie $f.Name) "24_Champs_NonUtilises.csv"
    if (-not (Test-Path $csvPath)) {
        Write-Host "    (pas de couche rapport dans cette fixture -- 24_Champs_NonUtilises.csv non genere)" -ForegroundColor DarkYellow
        Remove-Item $sortie -Recurse -Force -ErrorAction SilentlyContinue
        continue
    }

    # Invariant : une colonne portant une relation (source ou cible) ne doit
    # jamais ressortir "Supprimable" -- la supprimer casserait le modele.
    # Bug corrige : les relations n'etaient pas des racines du graphe de
    # dependances de 24_Champs_NonUtilises.csv.
    $bimJson = Get-Content $bimPath -Raw | ConvertFrom-Json
    $colonnesRelation = New-Object System.Collections.Generic.HashSet[string]
    foreach ($r in @($bimJson.model.relationships)) {
        [void]$colonnesRelation.Add("$($r.fromTable)[$($r.fromColumn)]")
        [void]$colonnesRelation.Add("$($r.toTable)[$($r.toColumn)]")
    }

    $lignes = Import-Csv $csvPath -Delimiter ';'
    $casse = foreach ($l in $lignes) {
        $cle = "$($l.Table)[$($l.Objet)]"
        if ($colonnesRelation.Contains($cle) -and $l.Verdict -eq 'Supprimable') { $cle }
    }

    if ($casse) {
        Write-Host "    ECHEC : colonnes de relation classees Supprimable : $($casse -join ', ')" -ForegroundColor Red
        $echec = $true
    } else {
        Write-Host "    OK : aucune des $($colonnesRelation.Count) colonnes de relation n'est Supprimable" -ForegroundColor Green
    }

    Remove-Item $sortie -Recurse -Force -ErrorAction SilentlyContinue
}

if ($echec) {
    Write-Host "`nECHEC des tests." -ForegroundColor Red
    exit 1
}
Write-Host "`nTous les tests sont passes." -ForegroundColor Green
