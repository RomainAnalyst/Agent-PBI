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

foreach ($f in $fixtures) {
    Write-Host "`n=== $($f.Name) ===" -ForegroundColor Cyan
    $manif = Join-Path $f.FullName "manifeste.json"
    if (Test-Path $manif) {
        $m = Get-Content $manif -Raw | ConvertFrom-Json
        Write-Host "    produit : $($m.produit)   version : $($m.versionPBIDesktop)" -ForegroundColor DarkGray
    }
    # TODO : appeler ici les fonctions de src\ sur cette fixture, puis comparer
    #        aux valeurs de reference stockees dans attendu.json
    #        (nb tables, colonnes, mesures, relations, pages, visuels).
    Write-Host "    (aucune assertion definie)" -ForegroundColor DarkYellow
}
