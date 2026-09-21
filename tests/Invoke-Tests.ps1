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

# Verifie Sources_Par_Table.csv (compare a attendu-sources.csv si present dans la
# fixture) et Schema_Relations.svg (XML valide, une ligne par relation, aucune
# virgule decimale). Renvoie la liste des erreurs, vide si tout est conforme.
function Test-SourcesEtSchema { param([string]$FixtureDir, [string]$Dossier)
    $err = @()
    $bim = Get-Content (Join-Path $FixtureDir "Model.bim") -Raw | ConvertFrom-Json
    $rels = @($bim.model.relationships)
    $csv = Join-Path $Dossier "Sources_Par_Table.csv"
    if (-not (Test-Path $csv)) { $err += "Sources_Par_Table.csv absent"; return $err }
    $att = Join-Path $FixtureDir "attendu-sources.csv"
    if (Test-Path $att) {
        $obt = @(Import-Csv $csv -Delimiter ';' -Encoding UTF8)
        $exp = @(Import-Csv $att -Delimiter ';' -Encoding UTF8)
        if ($obt.Count -ne $exp.Count) { $err += "Sources_Par_Table.csv : $($obt.Count) lignes, $($exp.Count) attendues" }
        foreach ($x in $exp) {
            $o = $obt | Where-Object { $_.Table -eq $x.Table } | Select-Object -First 1
            if (-not $o) { $err += "table absente : $($x.Table)"; continue }
            foreach ($c in 'Groupe', 'Nature', 'Objet', 'Mode', 'Chargement') {
                if ($o.$c -ne $x.$c) { $err += "$($x.Table).$c : '$($o.$c)' au lieu de '$($x.$c)'" }
            }
        }
    }
    $svg = Join-Path $Dossier "Schema_Relations.svg"
    if ($rels.Count -eq 0) {
        if (Test-Path $svg) { $err += "Schema_Relations.svg produit sans relation" }
        return $err
    }
    if (-not (Test-Path $svg)) { $err += "Schema_Relations.svg absent"; return $err }
    $texte = [System.IO.File]::ReadAllText($svg, [System.Text.Encoding]::UTF8)
    try { $null = [xml]$texte } catch { $err += "Schema_Relations.svg n'est pas du XML valide : $($_.Exception.Message)" }
    $nbLignes = ([regex]::Matches($texte, '<line ')).Count
    $attenduL = @($rels | Where-Object { $_.fromTable -ne $_.toTable }).Count
    if ($nbLignes -ne $attenduL) { $err += "Schema_Relations.svg : $nbLignes lignes, $attenduL relations" }
    if ($texte -match '(x|y)[12]="\d+,\d') { $err += "Schema_Relations.svg : virgule decimale dans une coordonnee" }
    return $err
}

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
        SansMenu      = $true
    }
    if ($repDir) { $params['PbipFolder'] = $f.FullName }

    & $scriptExport @params | Out-Null

    $dossierRapport = Join-Path $sortie $f.Name
    $erreursSS = @(Test-SourcesEtSchema $f.FullName $dossierRapport)
    if ($erreursSS.Count -gt 0) {
        foreach ($e in $erreursSS) { Write-Host "    ECHEC : $e" -ForegroundColor Red }
        $echec = $true
    } else {
        Write-Host "    OK : Sources_Par_Table.csv et Schema_Relations.svg conformes" -ForegroundColor Green
    }

    $csvPath = Join-Path $dossierRapport "24_Champs_NonUtilises.csv"
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
