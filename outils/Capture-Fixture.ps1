<#
.SYNOPSIS
    Capture un artefact reel comme jeu de test, depuis le poste courant.

.DESCRIPTION
    Depose dans tests\fixtures un .bim et/ou un Report_Layout.json accompagnes
    d'un manifeste decrivant l'environnement d'origine. Ces fichiers rendent le
    parsing testable sans Power BI ouvert, sur toutes les variantes a la fois.

.EXEMPLE
    .\outils\Capture-Fixture.ps1 -Nom "desktop-2026-06" -BimPath "...\Modele.bim"
    .\outils\Capture-Fixture.ps1 -Nom "reportserver-jan2026" -PbixPath "...\Rapport.pbix"
#>

param(
    [Parameter(Mandatory = $true)][string]$Nom,
    [string]$BimPath  = "",
    [string]$PbixPath = "",
    [string]$Produit  = "Desktop"   # Desktop | ReportServer
)

$racine = Split-Path $PSScriptRoot -Parent
$dest   = Join-Path $racine "tests\fixtures\$Nom"
New-Item -ItemType Directory -Path $dest -Force | Out-Null

if ($BimPath -and (Test-Path $BimPath)) {
    Copy-Item $BimPath (Join-Path $dest "Model.bim") -Force
    Write-Host "   Model.bim capture" -ForegroundColor Green
}

if ($PbixPath -and (Test-Path $PbixPath)) {
    Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $fs  = [System.IO.File]::Open($PbixPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $zip = New-Object System.IO.Compression.ZipArchive($fs, 'Read')
    Write-Host "   Entrees du .pbix :" -ForegroundColor DarkGray
    $zip.Entries | ForEach-Object { Write-Host "     $($_.FullName)" -ForegroundColor DarkGray }
    $e = $zip.Entries | Where-Object { $_.FullName -eq 'Report/Layout' } | Select-Object -First 1
    if ($e) {
        $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::Unicode, $true)
        [System.IO.File]::WriteAllText((Join-Path $dest "Report_Layout.json"), $sr.ReadToEnd(), (New-Object System.Text.UTF8Encoding($false)))
        $sr.Close()
        Write-Host "   Report/Layout capture" -ForegroundColor Green
    } else {
        Write-Host "   Report/Layout absent de ce .pbix" -ForegroundColor DarkYellow
    }
    $zip.Dispose(); $fs.Close()
}

# Manifeste : indispensable pour interpreter la fixture plus tard.
$pbi = Get-Process PBIDesktop -ErrorAction SilentlyContinue | Select-Object -First 1
@{
    nom              = $Nom
    produit          = $Produit
    versionPBIDesktop = $(if ($pbi) { $pbi.MainModule.FileVersionInfo.FileVersion } else { "" })
    capturePar       = $env:USERNAME
    dateCapture      = (Get-Date -Format 'o')
    sourceBim        = $BimPath
    sourcePbix       = $PbixPath
} | ConvertTo-Json | Set-Content (Join-Path $dest "manifeste.json") -Encoding UTF8

Write-Host "`nFixture ecrite dans : $dest" -ForegroundColor Green
Write-Host "Verifie qu'elle ne contient aucune donnee sensible avant de la versionner." -ForegroundColor DarkYellow
