<#
.SYNOPSIS
    Export exhaustif des metadonnees d'un modele Power BI Desktop.

.DESCRIPTION
    Etape 1 : Tabular Editor 2 genere Model.bim (dump TMSL complet) -- seule etape
              qui depend de TE2, via l'option -B qui n'utilise aucune API C#.
    Etape 2 : le .bim est parse en PowerShell -> CSV thematiques.
    Etape 3 : DMV (dependances + statistiques VertiPaq), optionnel.

.PARAMETER BimPath
    Si fourni, l'etape 1 est sautee : les CSV sont regeneres depuis un .bim
    existant. Power BI Desktop n'a alors pas besoin d'etre ouvert.

.PARAMETER SansOuverture
    N'ouvre pas l'explorateur Windows sur le dossier de sortie a la fin.

.EXEMPLES
    powershell -ExecutionPolicy Bypass -File .\Export-PowerBIMetadata-Full.ps1
    powershell -ExecutionPolicy Bypass -File .\Export-PowerBIMetadata-Full.ps1 -BimPath "C:\...\Model.bim"
#>

param(
    [string]$OutputFolder      = (Join-Path $env:USERPROFILE "Documents\PowerBI_Metadata"),
    [string]$TabularEditorPath = "",
    [string]$BimPath           = "",
    [string]$ReportName        = "",
    [string]$PbixPath          = "",
    [string]$PbipFolder        = "",
    [switch]$SkipReport,
    [switch]$SkipDmv,
    [switch]$SansOuverture
)

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$port = $null; $database = $null; $conn = $null; $calcDep = $null
$asCtx = $null       # contexte de requete Analysis Services (ADOMD ou ADODB)
$ProduitPBI = ""     # "Power BI Desktop" ou "Power BI Desktop for Report Server"
$script:AsResolveDir        = $null    # dossier de recherche courant du gestionnaire AssemblyResolve
$script:AsResolverRegistered = $false  # n'enregistrer le gestionnaire qu'une fois, meme si Open-AsContext est appelee plusieurs fois

# ------------------------------------------------------------------
# Acces aux DMV. Deux backends, essayes dans cet ordre :
#   1. ADOMD.NET, dont la DLL est livree avec Power BI Desktop -- ne
#      necessite aucun provider OLE DB enregistre sur le poste ;
#   2. ADODB + provider MSOLAP, si ADOMD est introuvable.
# ------------------------------------------------------------------
# Deroule la chaine InnerException et, quand elle existe, la propriete
# LoaderExceptions (cas de ReflectionTypeLoadException, leve par Add-Type
# quand l'assembly chargee reference un type dont une dependance manque ou ne
# correspond pas -- le message .NET de premier niveau se contente de renvoyer
# vers cette propriete sans la detailler, d'ou ce deroulage explicite).
function Get-ErrDetail { param($Ex)
    $msgs = New-Object System.Collections.Generic.List[string]
    $cur = $Ex
    while ($cur) {
        $msgs.Add($cur.Message)
        $le = $cur.PSObject.Properties['LoaderExceptions']
        if ($le -and $le.Value) {
            foreach ($sub in $le.Value) { $msgs.Add("LoaderException : $($sub.Message)") }
        }
        $cur = $cur.InnerException
    }
    return ($msgs -join ' <- ')
}

# ADOMD.NET reference des assemblies satellites (ex. Microsoft.Identity.Client,
# alias MSAL) que le probing .NET standard ne trouve pas quand elles sont a
# cote de la DLL ADOMD plutot que dans le GAC ou le dossier de l'executable
# hote. VERIFIE : cas constate sur poste Enedis (Add-Type sur l'ADOMD echoue
# avec une ReflectionTypeLoadException faute de resoudre MSAL 4.65.0.0, alors
# que Microsoft.Identity.Client.dll est bien present dans le meme dossier).
# Ce gestionnaire la fournit en la cherchant dans $script:AsResolveDir (mis a
# jour avant chaque tentative de chargement d'une DLL ADOMD).
#
# N'utilise que des appels .NET statiques (pas de cmdlet) : le gestionnaire
# est invoque par le CLR de facon synchrone pendant Add-Type/AdomdConnection,
# et rien ne garantit qu'une cmdlet (Get-ChildItem, Test-Path, New-Object) s'y
# comporte normalement dans ce contexte -- non teste, aucun poste avec ADOMD
# disponible sur ce depot pour le confirmer, d'ou ce choix prudent.
function Register-AsResolveHandler {
    if ($script:AsResolverRegistered) { return }
    $handler = [System.ResolveEventHandler] {
        param($resolveSender, $resolveArgs)
        try {
            $nom = ([System.Reflection.AssemblyName]::new($resolveArgs.Name)).Name
        } catch { return $null }
        $dir = $script:AsResolveDir
        if (-not $dir -or -not [System.IO.Directory]::Exists($dir)) { return $null }
        $candidats = [System.IO.Directory]::GetFiles($dir, "$nom.dll", [System.IO.SearchOption]::AllDirectories)
        if ($candidats.Count -eq 0) { return $null }
        try {
            # LoadFrom tolere un numero de version different de celui demande --
            # ADOMD s'en contente generalement (cas MSAL constate sur poste Enedis).
            $asm = [System.Reflection.Assembly]::LoadFrom($candidats[0])
            # PIEGE PS : "if ($script:AsDiag)" sur une List[string] VIDE vaut
            # $false (verite d'une collection = son Count, pas sa nullite) --
            # VERIFIE (le tout premier message journalise depuis le gestionnaire
            # disparaissait silencieusement). D'ou le test explicite sur $null.
            if ($null -ne $script:AsDiag) { [void]$script:AsDiag.Add("AssemblyResolve : $nom -> $($candidats[0]) (version $($asm.GetName().Version))") }
            return $asm
        } catch {
            if ($null -ne $script:AsDiag) { [void]$script:AsDiag.Add("AssemblyResolve : $nom trouve ($($candidats[0])) mais LoadFrom en echec -- $($_.Exception.Message)") }
            return $null
        }
    }
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($handler)
    $script:AsResolverRegistered = $true
}

function Open-AsContext { param([string]$Port)

    # $script:AsDiag journalise chaque chemin/provider essaye et pourquoi il a
    # echoue, pour diagnostiquer un poste (ex. Enedis) ou aucun backend ne
    # repond alors que le correctif ADOMD fonctionne sur un autre poste (Store).
    # NON TESTE sur poste Report Server : dossier d'installation issu de la
    # documentation Microsoft, aucun poste disponible pour le confirmer.
    $script:AsDiag = New-Object System.Collections.Generic.List[string]
    $dirs    = New-Object System.Collections.Generic.List[string]
    $dirsVus = New-Object System.Collections.Generic.HashSet[string]   # eviter les doublons (ex. process en cours + chemin fixe identiques)
    function Add-Dir { param([string]$D)
        if (-not $D) { return }
        if ($dirsVus.Add($D.ToLowerInvariant())) { $dirs.Add($D) }
    }

    # Source la plus fiable, valable pour les 3 variantes (classique, Report
    # Server, Microsoft Store) : le dossier d'ou tourne reellement le process.
    # Utile en particulier pour la variante Store, dont le dossier
    # WindowsApps\Microsoft.MicrosoftPowerBIDesktop_<version> n'est PAS
    # enumerable par un utilisateur standard (Acces refuse constate),
    # donc injoignable par un motif avec caractere generique. VERIFIE.
    $running = Get-Process msmdsrv, PBIDesktop -ErrorAction SilentlyContinue |
               Where-Object { $_.Path } | Select-Object -First 1
    if ($running) {
        Add-Dir (Split-Path $running.Path -Parent)
        $script:AsDiag.Add("Process en cours detecte : $($running.Path)")
    } else {
        $script:AsDiag.Add("Aucun process msmdsrv/PBIDesktop avec chemin accessible (tourne peut-etre sous un autre compte, ou n'est pas lance).")
    }

    foreach ($d in @(
        "$env:ProgramFiles\Microsoft Power BI Desktop\bin",
        "${env:ProgramFiles(x86)}\Microsoft Power BI Desktop\bin",
        "$env:ProgramFiles\Microsoft Power BI Desktop RS\bin",
        "${env:ProgramFiles(x86)}\Microsoft Power BI Desktop RS\bin",
        "$env:ProgramFiles\Microsoft.NET\ADOMD.NET",
        "${env:ProgramFiles(x86)}\Microsoft.NET\ADOMD.NET"
    )) {
        if (-not $d) { continue }
        if (Test-Path $d) { Add-Dir $d } else { $script:AsDiag.Add("Dossier candidat absent : $d") }
    }

    # Secours best-effort : fonctionne seulement si la GPO du poste autorise
    # l'enumeration de WindowsApps (pas le cas constate ici). NON TESTE comme
    # source effective -- $running ci-dessus suffit deja quand Power BI tourne.
    try {
        $trouves = @(Get-ChildItem "$env:ProgramFiles\WindowsApps" -Directory -Filter "Microsoft.MicrosoftPowerBIDesktop_*" -ErrorAction Stop)
        if ($trouves.Count -eq 0) { $script:AsDiag.Add("WindowsApps enumerable mais aucun dossier Microsoft.MicrosoftPowerBIDesktop_* trouve.") }
        foreach ($it in $trouves) {
            $b = Join-Path $it.FullName "bin"
            if (Test-Path $b) { Add-Dir $b } else { $script:AsDiag.Add("WindowsApps : $b absent") }
        }
    } catch {
        $script:AsDiag.Add("WindowsApps non enumerable (GPO ou acces refuse) : $(Get-ErrDetail $_.Exception)")
    }

    Register-AsResolveHandler

    foreach ($d in $dirs) {
        # Le nom du fichier a change selon les versions : "Microsoft.PowerBI.AdomdClient.dll"
        # dans les builds recentes (dont la variante Microsoft Store), au lieu de
        # "Microsoft.AnalysisServices.AdomdClient.dll". Le namespace des types .NET a
        # l'interieur, lui, reste "Microsoft.AnalysisServices.AdomdClient.*" dans les
        # deux cas -- VERIFIE par inspection de l'assembly. On cherche donc les deux noms.
        $dll = Get-ChildItem $d -Include "Microsoft.AnalysisServices.AdomdClient.dll", "Microsoft.PowerBI.AdomdClient.dll" -Recurse -ErrorAction SilentlyContinue |
               Sort-Object { $_.VersionInfo.FileVersion } -Descending | Select-Object -First 1
        if (-not $dll) {
            $script:AsDiag.Add("$d : ni Microsoft.AnalysisServices.AdomdClient.dll ni Microsoft.PowerBI.AdomdClient.dll")
            continue
        }
        $dllDir = Split-Path $dll.FullName -Parent

        # MSAL (Microsoft.Identity.Client) : dependance d'ADOMD non resolue par
        # le probing standard sur certains postes (Enedis) alors qu'elle est
        # bien presente a cote de l'ADOMD. Journalise sa version pour comparer
        # a celle demandee au chargement (visible dans le message d'echec).
        $msal = Get-ChildItem $dllDir -Filter "Microsoft.Identity.Client.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($msal) {
            $verAssembly = try { [System.Reflection.AssemblyName]::GetAssemblyName($msal.FullName).Version } catch { "?" }
            $script:AsDiag.Add("Microsoft.Identity.Client.dll trouve : $($msal.FullName) (assembly $verAssembly, fichier $($msal.VersionInfo.FileVersion))")
        } else {
            $script:AsDiag.Add("Microsoft.Identity.Client.dll absent de $dllDir")
        }

        # Dossier fourni au gestionnaire AssemblyResolve pour cette tentative :
        # celui de la DLL ADOMD en cours de chargement, et ses sous-dossiers.
        $script:AsResolveDir = $dllDir
        try {
            Add-Type -Path $dll.FullName -ErrorAction Stop
            $cn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$Port;")
            $cn.Open()
            $script:AsDiag.Add("OK : $($dll.FullName) (version $($dll.VersionInfo.FileVersion))")
            return @{ Mode = 'adomd'; Conn = $cn; Info = "ADOMD.NET ($($dll.FullName))" }
        } catch {
            $script:AsDiag.Add("$($dll.FullName) (version $($dll.VersionInfo.FileVersion)) : chargement ou connexion en echec -- $(Get-ErrDetail $_.Exception)")
        }
    }

    foreach ($prov in @("MSOLAP", "MSOLAP.8", "MSOLAP.7")) {
        try {
            $c = New-Object -ComObject ADODB.Connection
            $c.Open("Provider=$prov;Data Source=localhost:$Port;")
            $script:AsDiag.Add("OK : ADODB/$prov")
            return @{ Mode = 'adodb'; Conn = $c; Info = "ADODB/$prov" }
        } catch {
            $script:AsDiag.Add("Provider $prov : echec -- $(Get-ErrDetail $_.Exception)")
        }
    }
    return $null
}

function Invoke-AsQuery { param($Ctx, [string]$Query)
    $rows = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Ctx) { return $rows }
    if ($Ctx.Mode -eq 'adomd') {
        $cmd = $Ctx.Conn.CreateCommand()
        $cmd.CommandText = $Query
        $rdr = $cmd.ExecuteReader()
        try {
            while ($rdr.Read()) {
                $h = [ordered]@{}
                for ($i = 0; $i -lt $rdr.FieldCount; $i++) {
                    $v = $rdr.GetValue($i)
                    $h[$rdr.GetName($i)] = $(if ($v -is [System.DBNull]) { $null } else { $v })
                }
                $rows.Add([pscustomobject]$h)
            }
        } finally { $rdr.Close() }
    } else {
        $rs = $Ctx.Conn.Execute($Query)
        $n = $rs.Fields.Count
        $names = @(); for ($i = 0; $i -lt $n; $i++) { $names += $rs.Fields.Item($i).Name }
        while (-not $rs.EOF) {
            $h = [ordered]@{}
            for ($i = 0; $i -lt $n; $i++) { $h[$names[$i]] = $rs.Fields.Item($i).Value }
            $rows.Add([pscustomobject]$h); $rs.MoveNext()
        }
        $rs.Close()
    }
    return $rows
}

function Close-AsContext { param($Ctx)
    if ($null -eq $Ctx) { return }
    try { $Ctx.Conn.Close() } catch { }
}

# ==================================================================
# Nom du rapport : titre de la fenetre Power BI Desktop
# ==================================================================
function Get-SafeName {
    param([string]$n)
    if (-not $n) { return "Modele" }
    foreach ($ch in [System.IO.Path]::GetInvalidFileNameChars()) { $n = $n.Replace($ch, '_') }
    $n = ($n -replace '\s+', ' ').Trim(' ', '.', '_')
    if (-not $n) { return "Modele" }
    return $n
}

if (-not $ReportName) {
    if ($BimPath) {
        $ReportName = [System.IO.Path]::GetFileNameWithoutExtension($BimPath)
    } else {
        $wins = @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle })
        if ($wins.Count -gt 1) {
            Write-Host "ATTENTION : plusieurs fenetres Power BI Desktop ouvertes, la premiere est utilisee." -ForegroundColor DarkYellow
        }
        if ($wins.Count -ge 1) {
            # "*MonRapport - Power BI Desktop"  ->  "MonRapport"
            $ReportName = $wins[0].MainWindowTitle -replace '^\s*\*', '' -replace '\s*[-\u2013]\s*Power BI Desktop\s*$', ''
        }
    }
}
$ReportName   = Get-SafeName $ReportName
$OutputFolder = Join-Path $OutputFolder $ReportName
if (-not (Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null }
Write-Host "-> Rapport : $ReportName" -ForegroundColor Green

# ==================================================================
# ETAPE 1 : generation du Model.bim via Tabular Editor 2
# ==================================================================
if (-not $BimPath) {

    # --- 1a. Localisation de TabularEditor.exe ---
    if (-not $TabularEditorPath) {
        if ($env:TABULAR_EDITOR_PATH -and (Test-Path $env:TABULAR_EDITOR_PATH)) {
            $TabularEditorPath = $env:TABULAR_EDITOR_PATH
        }
        if (-not $TabularEditorPath) {
            $RepoRoot = Split-Path $PSScriptRoot -Parent
            $candidates = @(
                (Join-Path $RepoRoot "TabularEditor\TabularEditor.exe"),
                (Join-Path $PSScriptRoot "TabularEditor\TabularEditor.exe"),
                (Join-Path $PSScriptRoot "TabularEditor.exe"),
                "C:\Program Files (x86)\Tabular Editor\TabularEditor.exe",
                "C:\Program Files\Tabular Editor\TabularEditor.exe",
                (Join-Path $env:LOCALAPPDATA "Programs\Tabular Editor\TabularEditor.exe"),
                (Join-Path $env:USERPROFILE "TabularEditor\TabularEditor.exe"),
                (Join-Path $env:USERPROFILE "Downloads\TabularEditor\TabularEditor.exe")
            )
            $TabularEditorPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        }
        if (-not $TabularEditorPath) {
            $cmd = Get-Command "TabularEditor.exe" -ErrorAction SilentlyContinue
            if ($cmd) { $TabularEditorPath = $cmd.Source }
        }
    }
    if (-not $TabularEditorPath -or -not (Test-Path $TabularEditorPath)) {
        Write-Host "ERREUR : TabularEditor.exe introuvable. Utilise -TabularEditorPath." -ForegroundColor Red
        return
    }
    Write-Host "-> Tabular Editor : $TabularEditorPath" -ForegroundColor Green

    # Version portable extraite d'un zip : lever le Mark-of-the-Web
    try {
        Get-ChildItem (Split-Path $TabularEditorPath -Parent) -Recurse -File -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
    } catch { }

    # --- 1b. Port de l'instance Analysis Services locale ---
    # Le dossier de travail differe selon le produit. Les deux sont balayes ;
    # celui dont le fichier de port est le plus recent determine le produit
    # detecte. NON TESTE : le chemin Report Server vient de la documentation
    # Microsoft (dossier local "Power BI Desktop SSRS"), aucun poste Report
    # Server n'etait disponible pour le confirmer sur ce depot.
    $wsRoots = [ordered]@{
        'Power BI Desktop'                    = Join-Path $env:LOCALAPPDATA "Microsoft\Power BI Desktop\AnalysisServicesWorkspaces"
        'Power BI Desktop for Report Server'  = Join-Path $env:LOCALAPPDATA "Microsoft\Power BI Desktop SSRS\AnalysisServicesWorkspaces"
    }
    $portFile = $null
    foreach ($kv in $wsRoots.GetEnumerator()) {
        if (-not (Test-Path $kv.Value)) { continue }
        $pf = Get-ChildItem -Path $kv.Value -Filter "msmdsrv.port.txt" -Recurse -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($pf -and (-not $portFile -or $pf.LastWriteTime -gt $portFile.LastWriteTime)) {
            $portFile   = $pf
            $ProduitPBI = $kv.Key
        }
    }
    if ($portFile) { $port = ((Get-Content $portFile.FullName -Raw) -replace '\D','') }
    if (-not $port) {
        $pbi = Get-Process msmdsrv -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pbi) {
            $line = netstat -ano | Where-Object { $_ -match "LISTENING\s+$($pbi.Id)\s*$" } | Select-Object -First 1
            if ($line -and $line -match '127\.0\.0\.1:(\d+)') { $port = $Matches[1] }
        }
        if ($port) {
            # Variante Microsoft Store : le dossier de travail est versionne
            # (WindowsApps\Microsoft.MicrosoftPowerBIDesktop_<version>\bin) et
            # n'apparait donc pas dans $wsRoots ci-dessus. VERIFIE sur poste Store.
            $ProduitPBI = if ($pbi.Path -match '\\WindowsApps\\Microsoft\.MicrosoftPowerBIDesktop_') {
                'Power BI Desktop (Microsoft Store)'
            } else {
                "Indetermine (detecte via processus msmdsrv)"
            }
        }
    }
    if (-not $port) {
        Write-Host "ERREUR : Power BI Desktop n'est pas ouvert (ou port introuvable)." -ForegroundColor Red
        return
    }
    Write-Host "-> Port detecte : $port" -ForegroundColor Green
    Write-Host "-> Produit detecte : $ProduitPBI" -ForegroundColor Green

    # --- 1c. Nom de la base ---
    $asCtx = Open-AsContext $port
    if ($asCtx) {
        Write-Host "-> Acces aux DMV : $($asCtx.Info)" -ForegroundColor DarkGray
        try {
            $r = Invoke-AsQuery $asCtx 'SELECT [CATALOG_NAME] FROM $SYSTEM.DBSCHEMA_CATALOGS'
            if (@($r).Count -gt 0) { $database = $r[0].CATALOG_NAME }
        } catch { }
    }
    if (-not $database -and $portFile) {
        $dbDir = Get-ChildItem (Split-Path $portFile.FullName -Parent) -Directory -Filter "*.db" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($dbDir) { $database = $dbDir.Name -replace '\.\d+\.db$','' }
    }
    if (-not $database) {
        Write-Host "ERREUR : impossible de determiner le nom de la base." -ForegroundColor Red
        return
    }
    Write-Host "-> Base detectee : $database" -ForegroundColor Green

    # --- 1d. Dump TMSL ---
    $BimPath = Join-Path $OutputFolder "$ReportName.bim"
    Write-Host "-> Generation de $ReportName.bim..." -ForegroundColor Cyan
    & $TabularEditorPath "localhost:$port" "$database" -B "$BimPath" 2>&1 | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkGray }
    if (-not (Test-Path $BimPath)) {
        Write-Host "ERREUR : fichier .bim non genere." -ForegroundColor Red
        return
    }
}

if (-not (Test-Path $BimPath)) {
    Write-Host "ERREUR : fichier .bim introuvable ($BimPath)" -ForegroundColor Red
    return
}

# ==================================================================
# ETAPE 2 : parsing du .bim -> CSV
# ==================================================================
Write-Host "-> Analyse du fichier .bim..." -ForegroundColor Cyan

$json = [System.IO.File]::ReadAllText($BimPath, [System.Text.Encoding]::UTF8) -replace '^\uFEFF',''

# JavaScriptSerializer rend des Dictionary<string,object> : on les reconvertit en
# PSCustomObject pour homogeneiser avec la sortie de ConvertFrom-Json.
function ConvertTo-PsTree { param($o)
    if ($o -is [System.Collections.IDictionary]) {
        $h = [ordered]@{}
        foreach ($k in $o.Keys) { $h[[string]$k] = ConvertTo-PsTree $o[$k] }
        return [pscustomobject]$h
    }
    if ($o -isnot [string] -and $o -is [System.Collections.IEnumerable]) {
        return @(foreach ($i in $o) { ConvertTo-PsTree $i })
    }
    return $o
}

$bim = $null
try {
    # ConvertFrom-Json (PS 5.1) plafonne a ~2 Mo : echoue sur les gros modeles.
    $bim = $json | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Host "   (modele volumineux : bascule sur le parseur etendu)" -ForegroundColor DarkGray
    Add-Type -AssemblyName System.Web.Extensions
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.MaxJsonLength   = [int]::MaxValue
    $ser.RecursionLimit  = 1000
    $bim = ConvertTo-PsTree $ser.DeserializeObject($json)
}
if ($null -eq $bim) {
    Write-Host "ERREUR : le fichier .bim n'a pas pu etre analyse." -ForegroundColor Red
    return
}
$mdl = $bim.model

# --- Helpers -----------------------------------------------------
# TMSL omet les proprietes a leur valeur par defaut : P() les restaure.
# Gere indifferemment PSCustomObject, Hashtable et Dictionary.
function P { param($o, [string]$n, $def = "")
    if ($null -eq $o) { return $def }
    $v = $null
    if ($o -is [System.Collections.IDictionary]) {
        if (-not $o.Contains($n)) { return $def }
        $v = $o[$n]
    } elseif ($o.PSObject.Properties.Name -contains $n) {
        $v = $o.$n
    } else {
        return $def
    }
    if ($null -eq $v) { return $def }
    return $v
}
# Une expression DAX/M est soit une string, soit un tableau de lignes.
function E { param($v)
    if ($null -eq $v) { return "" }
    if ($v -is [System.Array]) { return ($v -join "`r`n") }
    return [string]$v
}
function Save { param([string]$Name, $Rows)
    # PIEGE PS 5.1 : "@($Rows)" sur une List[object] VIDE declenche une
    # ArgumentException dans le binder dynamique (PSToObjectArrayBinder).
    # VERIFIE (reproduit avec un rapport sans filtre -> $rowFiltr vide).
    # Contournement : compter via .Count directement (sans @()) et laisser
    # Export-Csv consommer $Rows par le pipeline plutot que par cast @().
    $n = if ($null -eq $Rows) { 0 } elseif ($Rows -is [System.Collections.ICollection]) { $Rows.Count } else { 1 }
    if ($n -eq 0) { return $false }
    $p = Join-Path $OutputFolder $Name
    $Rows | Export-Csv -Path $p -NoTypeInformation -Delimiter ';' -Encoding UTF8
    Write-Host ("   OK  {0,-36} {1,5} lignes" -f $Name, $n) -ForegroundColor DarkGray
    return $true
}

$tables = @(P $mdl 'tables' @())
$vides  = New-Object System.Collections.Generic.List[string]

if ($tables.Count -eq 0) {
    Write-Host "ERREUR : aucune table lue dans le .bim - analyse interrompue." -ForegroundColor Red
    Write-Host "         Le fichier est peut-etre tronque ou dans un format inattendu." -ForegroundColor Red
    return
}
Write-Host "   $($tables.Count) tables lues" -ForegroundColor DarkGray

# --- 00 Modele ---------------------------------------------------
$props = [ordered]@{
    'Produit'                         = if ($ProduitPBI) { $ProduitPBI } else { 'Indetermine (.bim fourni directement)' }
    'Database'                        = P $bim 'name'
    'CompatibilityLevel'              = P $bim 'compatibilityLevel'
    'Culture'                         = P $mdl 'culture'
    'SourceQueryCulture'              = P $mdl 'sourceQueryCulture'
    'DefaultPowerBIDataSourceVersion' = P $mdl 'defaultPowerBIDataSourceVersion'
    'DefaultMode'                     = P $mdl 'defaultMode' 'import'
    'DiscourageImplicitMeasures'      = P $mdl 'discourageImplicitMeasures' $false
    'NbTables'                        = $tables.Count
    'NbColonnes'                      = (@($tables | ForEach-Object { @(P $_ 'columns'  @()) }) | Measure-Object).Count
    'NbMesures'                       = (@($tables | ForEach-Object { @(P $_ 'measures' @()) }) | Measure-Object).Count
    'NbRelations'                     = @(P $mdl 'relationships' @()).Count
    'NbRoles'                         = @(P $mdl 'roles' @()).Count
    'SourceBim'                       = $BimPath
    'DateExtraction'                  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
}
Save "00_Modele.csv" ($props.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Propriete = $_.Key; Valeur = $_.Value } }) | Out-Null

# --- 01 Tables ---------------------------------------------------
$rows = foreach ($t in $tables) {
    $parts = @(P $t 'partitions' @())
    $typeT = 'Table'
    if ($null -ne (P $t 'calculationGroup' $null)) { $typeT = 'Groupe de calcul' }
    elseif ($parts | Where-Object { (P $_.source 'type') -eq 'calculated' }) { $typeT = 'Table calculee' }
    [pscustomobject]@{
        Table          = $t.name
        TypeTable      = $typeT
        Description    = E (P $t 'description')
        IsHidden       = P $t 'isHidden' $false
        DataCategory   = P $t 'dataCategory'
        NbColonnes     = @(P $t 'columns' @()).Count
        NbMesures      = @(P $t 'measures' @()).Count
        NbHierarchies  = @(P $t 'hierarchies' @()).Count
        NbPartitions   = $parts.Count
        Mode           = ($parts | ForEach-Object { P $_ 'mode' } | Select-Object -Unique) -join ','
        ExcludeRefresh = P $t 'excludeFromModelRefresh' $false
        LineageTag     = P $t 'lineageTag'
    }
}
Save "01_Tables.csv" $rows | Out-Null

# --- 02 Colonnes -------------------------------------------------
$rows = foreach ($t in $tables) {
    foreach ($c in @(P $t 'columns' @())) {
        [pscustomobject]@{
            Table         = $t.name
            Colonne       = $c.name
            TypeColonne   = P $c 'type' 'data'
            Description   = E (P $c 'description')
            DataType      = P $c 'dataType'
            FormatString  = P $c 'formatString'
            DisplayFolder = P $c 'displayFolder'
            SortByColumn  = P $c 'sortByColumn'
            DataCategory  = P $c 'dataCategory'
            SummarizeBy   = P $c 'summarizeBy' 'default'
            IsKey         = P $c 'isKey' $false
            IsHidden      = P $c 'isHidden' $false
            IsNullable    = P $c 'isNullable' $true
            SourceColumn  = P $c 'sourceColumn'
            Expression    = E (P $c 'expression')
            LineageTag    = P $c 'lineageTag'
        }
    }
}
Save "02_Colonnes.csv" $rows | Out-Null

# --- 03 Mesures --------------------------------------------------
$rows = foreach ($t in $tables) {
    foreach ($m in @(P $t 'measures' @())) {
        $fsd = P $m 'formatStringDefinition' $null
        [pscustomobject]@{
            Table                  = $t.name
            Mesure                 = $m.name
            Description            = E (P $m 'description')
            IsHidden               = P $m 'isHidden' $false
            FormatString           = P $m 'formatString'
            DisplayFolder          = P $m 'displayFolder'
            DataCategory           = P $m 'dataCategory'
            Expression_DAX         = E (P $m 'expression')
            FormatStringExpression = if ($fsd) { E (P $fsd 'expression') } else { "" }
            LineageTag             = P $m 'lineageTag'
        }
    }
}
Save "03_Mesures.csv" $rows | Out-Null

# --- 04 Partitions / Power Query ---------------------------------
$rows = foreach ($t in $tables) {
    foreach ($p in @(P $t 'partitions' @())) {
        $src = P $p 'source' $null
        [pscustomobject]@{
            Table      = $t.name
            Partition  = $p.name
            Mode       = P $p 'mode' 'import'
            TypeSource = if ($src) { P $src 'type' } else { "" }
            QueryGroup = P $p 'queryGroup'
            Requete    = if ($src) { E (P $src 'expression') } else { "" }
        }
    }
}
Save "04_Partitions_PowerQuery.csv" $rows | Out-Null

# --- 05 Relations ------------------------------------------------
$rows = foreach ($r in @(P $mdl 'relationships' @())) {
    [pscustomobject]@{
        Nom               = P $r 'name'
        TableSource       = P $r 'fromTable'
        ColonneSource     = P $r 'fromColumn'
        CardinaliteSource = P $r 'fromCardinality' 'many'
        TableCible        = P $r 'toTable'
        ColonneCible      = P $r 'toColumn'
        CardinaliteCible  = P $r 'toCardinality' 'one'
        SensFiltre        = P $r 'crossFilteringBehavior' 'oneDirection'
        IsActive          = P $r 'isActive' $true
        SecurityFiltering = P $r 'securityFilteringBehavior' 'oneDirection'
        JoinOnDate        = P $r 'joinOnDateBehavior' 'dateAndTime'
        RelyOnRI          = P $r 'relyOnReferentialIntegrity' $false
    }
}
Save "05_Relations.csv" $rows | Out-Null

# --- 06 Hierarchies ----------------------------------------------
$rows = foreach ($t in $tables) {
    foreach ($h in @(P $t 'hierarchies' @())) {
        foreach ($l in @(P $h 'levels' @())) {
            [pscustomobject]@{
                Table         = $t.name
                Hierarchie    = $h.name
                IsHidden      = P $h 'isHidden' $false
                Description   = E (P $h 'description')
                Ordinal       = P $l 'ordinal'
                Niveau        = $l.name
                ColonneSource = P $l 'column'
            }
        }
    }
}
if (-not (Save "06_Hierarchies.csv" $rows)) { $vides.Add("hierarchies") }

# --- 07 Groupes de calcul ----------------------------------------
$rows = foreach ($t in $tables) {
    $cg = P $t 'calculationGroup' $null
    if ($null -eq $cg) { continue }
    foreach ($ci in @(P $cg 'calculationItems' @())) {
        $fsd = P $ci 'formatStringDefinition' $null
        [pscustomobject]@{
            Table                  = $t.name
            Precedence             = P $cg 'precedence'
            Ordinal                = P $ci 'ordinal'
            CalculationItem        = $ci.name
            Expression_DAX         = E (P $ci 'expression')
            FormatStringExpression = if ($fsd) { E (P $fsd 'expression') } else { "" }
            Description            = E (P $ci 'description')
        }
    }
}
if (-not (Save "07_GroupesDeCalcul.csv" $rows)) { $vides.Add("groupes de calcul") }

# --- 08 Expressions partagees (parametres / requetes M) ----------
$rows = foreach ($e in @(P $mdl 'expressions' @())) {
    [pscustomobject]@{
        Nom         = $e.name
        Kind        = P $e 'kind'
        QueryGroup  = P $e 'queryGroup'
        Description = E (P $e 'description')
        Expression  = E (P $e 'expression')
    }
}
if (-not (Save "08_ExpressionsPartagees.csv" $rows)) { $vides.Add("expressions partagees") }

# --- 09 Roles / RLS ----------------------------------------------
$rows = foreach ($r in @(P $mdl 'roles' @())) {
    $membres = (@(P $r 'members' @()) | ForEach-Object { P $_ 'memberName' }) -join ' | '
    $tps = @(P $r 'tablePermissions' @())
    if ($tps.Count -eq 0) {
        [pscustomobject]@{ Role=$r.name; Permission=(P $r 'modelPermission'); Description=(E (P $r 'description')); Table=""; FiltreDAX=""; Membres=$membres }
    } else {
        foreach ($tp in $tps) {
            [pscustomobject]@{
                Role        = $r.name
                Permission  = P $r 'modelPermission'
                Description = E (P $r 'description')
                Table       = P $tp 'name'
                FiltreDAX   = E (P $tp 'filterExpression')
                Membres     = $membres
            }
        }
    }
}
if (-not (Save "09_Roles_RLS.csv" $rows)) { $vides.Add("roles") }

# --- 10 Perspectives ---------------------------------------------
$rows = foreach ($p in @(P $mdl 'perspectives' @())) {
    foreach ($pt in @(P $p 'tables' @())) {
        [pscustomobject]@{ Perspective=$p.name; Table=$pt.name; TypeObjet='Table'; Objet=$pt.name }
        foreach ($x in @(P $pt 'columns'    @())) { [pscustomobject]@{ Perspective=$p.name; Table=$pt.name; TypeObjet='Colonne';    Objet=$x.name } }
        foreach ($x in @(P $pt 'measures'   @())) { [pscustomobject]@{ Perspective=$p.name; Table=$pt.name; TypeObjet='Mesure';     Objet=$x.name } }
        foreach ($x in @(P $pt 'hierarchies'@())) { [pscustomobject]@{ Perspective=$p.name; Table=$pt.name; TypeObjet='Hierarchie'; Objet=$x.name } }
    }
}
if (-not (Save "10_Perspectives.csv" $rows)) { $vides.Add("perspectives") }

# --- 11 Traductions ----------------------------------------------
$rows = foreach ($cu in @(P $mdl 'cultures' @())) {
    $tr = P $cu 'translations' $null
    if ($null -eq $tr) { continue }
    foreach ($tt in @(P $tr.model 'tables' @())) {
        [pscustomobject]@{ Culture=$cu.name; TypeObjet='Table'; Objet=$tt.name; Caption=(P $tt 'translatedCaption'); Description=(P $tt 'translatedDescription') }
        foreach ($tc in @(P $tt 'columns'  @())) { [pscustomobject]@{ Culture=$cu.name; TypeObjet='Colonne'; Objet="$($tt.name)[$($tc.name)]"; Caption=(P $tc 'translatedCaption'); Description=(P $tc 'translatedDescription') } }
        foreach ($tm in @(P $tt 'measures' @())) { [pscustomobject]@{ Culture=$cu.name; TypeObjet='Mesure';  Objet="$($tt.name)[$($tm.name)]"; Caption=(P $tm 'translatedCaption'); Description=(P $tm 'translatedDescription') } }
    }
}
if (-not (Save "11_Traductions.csv" $rows)) { $vides.Add("traductions") }

# --- 12 Sources de donnees ---------------------------------------
$rows = foreach ($ds in @(P $mdl 'dataSources' @())) {
    [pscustomobject]@{
        Nom              = $ds.name
        Type             = P $ds 'type'
        Description      = E (P $ds 'description')
        ConnectionString = P $ds 'connectionString'
    }
}
if (-not (Save "12_SourcesDonnees.csv" $rows)) { $vides.Add("sources de donnees") }

# --- 13 Annotations ----------------------------------------------
$rows = @()
$rows += @(P $mdl 'annotations' @()) | ForEach-Object { [pscustomobject]@{ TypeObjet='Model'; Objet=(P $bim 'name'); Annotation=$_.name; Valeur=(E $_.value) } }
foreach ($t in $tables) {
    $rows += @(P $t 'annotations' @()) | ForEach-Object { [pscustomobject]@{ TypeObjet='Table'; Objet=$t.name; Annotation=$_.name; Valeur=(E $_.value) } }
    foreach ($c in @(P $t 'columns'  @())) { $rows += @(P $c 'annotations' @()) | ForEach-Object { [pscustomobject]@{ TypeObjet='Colonne'; Objet="$($t.name)[$($c.name)]"; Annotation=$_.name; Valeur=(E $_.value) } } }
    foreach ($m in @(P $t 'measures' @())) { $rows += @(P $m 'annotations' @()) | ForEach-Object { [pscustomobject]@{ TypeObjet='Mesure';  Objet="$($t.name)[$($m.name)]"; Annotation=$_.name; Valeur=(E $_.value) } } }
}
Save "13_Annotations.csv" $rows | Out-Null

# --- 14 Query groups (dossiers Power Query) ----------------------
$rows = foreach ($qg in @(P $mdl 'queryGroups' @())) {
    [pscustomobject]@{ Dossier = P $qg 'folder'; Description = E (P $qg 'description') }
}
if (-not (Save "14_QueryGroups.csv" $rows)) { $vides.Add("query groups") }

# --- 15 JSON normalise pour agents IA ----------------------------
# Le .bim brut est mal exploite par les LLM : GUID de lignage sur chaque objet,
# annotations internes, metadonnees linguistiques volumineuses, expressions DAX
# stockees en tableau de lignes, et proprietes omises quand elles valent leur
# defaut. Ce JSON corrige les quatre points.

function Clean { param($h)
    $o = [ordered]@{}
    foreach ($k in $h.Keys) {
        $v = $h[$k]
        if ($null -eq $v) { continue }
        if ($v -is [string] -and $v -eq "") { continue }
        if ($v -is [System.Collections.ICollection] -and @($v).Count -eq 0) { continue }
        $o[$k] = $v
    }
    return $o
}

$jsonTables = foreach ($t in $tables) {
    $parts = @(P $t 'partitions' @())
    $typeT = 'table'
    if ($null -ne (P $t 'calculationGroup' $null)) { $typeT = 'calculationGroup' }
    elseif ($parts | Where-Object { (P $_.source 'type') -eq 'calculated' }) { $typeT = 'calculatedTable' }

    $jCols = foreach ($c in @(P $t 'columns' @())) {
        Clean ([ordered]@{
            name          = $c.name
            dataType      = P $c 'dataType'
            kind          = P $c 'type' 'data'
            description   = E (P $c 'description')
            sourceColumn  = P $c 'sourceColumn'
            expression    = E (P $c 'expression')
            formatString  = P $c 'formatString'
            displayFolder = P $c 'displayFolder'
            sortByColumn  = P $c 'sortByColumn'
            summarizeBy   = P $c 'summarizeBy' 'default'
            isKey         = if (P $c 'isKey' $false) { $true } else { $null }
            isHidden      = if (P $c 'isHidden' $false) { $true } else { $null }
        })
    }

    $jMeas = foreach ($m in @(P $t 'measures' @())) {
        $fsd = P $m 'formatStringDefinition' $null
        Clean ([ordered]@{
            name                   = $m.name
            description            = E (P $m 'description')
            expression             = E (P $m 'expression')
            formatString           = P $m 'formatString'
            formatStringExpression = if ($fsd) { E (P $fsd 'expression') } else { "" }
            displayFolder          = P $m 'displayFolder'
            isHidden               = if (P $m 'isHidden' $false) { $true } else { $null }
        })
    }

    $jParts = foreach ($p in $parts) {
        $src = P $p 'source' $null
        Clean ([ordered]@{
            name        = $p.name
            mode        = P $p 'mode' 'import'
            sourceType  = if ($src) { P $src 'type' } else { "" }
            queryGroup  = P $p 'queryGroup'
            expression  = if ($src) { E (P $src 'expression') } else { "" }
        })
    }

    $jHier = foreach ($h in @(P $t 'hierarchies' @())) {
        Clean ([ordered]@{
            name   = $h.name
            levels = @(@(P $h 'levels' @()) | Sort-Object { P $_ 'ordinal' 0 } | ForEach-Object {
                        [ordered]@{ ordinal = (P $_ 'ordinal' 0); name = $_.name; column = (P $_ 'column') } })
        })
    }

    $jCalc = $null
    $cg = P $t 'calculationGroup' $null
    if ($cg) {
        $jCalc = [ordered]@{
            precedence = P $cg 'precedence' 0
            items      = @(@(P $cg 'calculationItems' @()) | ForEach-Object {
                            $f = P $_ 'formatStringDefinition' $null
                            Clean ([ordered]@{
                                name                   = $_.name
                                ordinal                = P $_ 'ordinal'
                                expression             = E (P $_ 'expression')
                                formatStringExpression = if ($f) { E (P $f 'expression') } else { "" }
                            }) })
        }
    }

    Clean ([ordered]@{
        name             = $t.name
        kind             = $typeT
        description      = E (P $t 'description')
        isHidden         = if (P $t 'isHidden' $false) { $true } else { $null }
        dataCategory     = P $t 'dataCategory'
        columns          = @($jCols)
        measures         = @($jMeas)
        hierarchies      = @($jHier)
        partitions       = @($jParts)
        calculationGroup = $jCalc
    })
}

$jsonRels = foreach ($r in @(P $mdl 'relationships' @())) {
    $fc = P $r 'fromCardinality' 'many'
    $tc = P $r 'toCardinality' 'one'
    [ordered]@{
        name                      = P $r 'name'
        fromTable                 = P $r 'fromTable'
        fromColumn                = P $r 'fromColumn'
        fromCardinality           = $fc
        toTable                   = P $r 'toTable'
        toColumn                  = P $r 'toColumn'
        toCardinality             = $tc
        cardinality               = "$fc-to-$tc"
        crossFilteringBehavior    = P $r 'crossFilteringBehavior' 'oneDirection'
        isActive                  = P $r 'isActive' $true
        securityFilteringBehavior = P $r 'securityFilteringBehavior' 'oneDirection'
        summary                   = "$(P $r 'fromTable')[$(P $r 'fromColumn')] -> $(P $r 'toTable')[$(P $r 'toColumn')]"
    }
}

$jsonRoles = foreach ($r in @(P $mdl 'roles' @())) {
    Clean ([ordered]@{
        name             = $r.name
        modelPermission  = P $r 'modelPermission'
        members          = @(@(P $r 'members' @()) | ForEach-Object { P $_ 'memberName' })
        tablePermissions = @(@(P $r 'tablePermissions' @()) | ForEach-Object {
                              Clean ([ordered]@{ table = (P $_ 'name'); filterExpression = (E (P $_ 'filterExpression')) }) })
    })
}

$jsonExpr = foreach ($e in @(P $mdl 'expressions' @())) {
    Clean ([ordered]@{
        name       = $e.name
        kind       = P $e 'kind'
        queryGroup = P $e 'queryGroup'
        expression = E (P $e 'expression')
    })
}

$doc = [ordered]@{
    '$schema'  = 'powerbi-semantic-model/1.0'
    reportName = $ReportName
    generatedAt = (Get-Date -Format 'o')
    model = [ordered]@{
        database           = P $bim 'name'
        compatibilityLevel = P $bim 'compatibilityLevel'
        culture            = P $mdl 'culture'
        defaultMode        = P $mdl 'defaultMode' 'import'
    }
    summary = [ordered]@{
        tables        = $tables.Count
        columns       = (@($tables | ForEach-Object { @(P $_ 'columns'  @()) }) | Measure-Object).Count
        measures      = (@($tables | ForEach-Object { @(P $_ 'measures' @()) }) | Measure-Object).Count
        relationships = @(P $mdl 'relationships' @()).Count
        roles         = @(P $mdl 'roles' @()).Count
    }
    tables            = @($jsonTables)
    relationships     = @($jsonRels)
    roles             = @($jsonRoles)
    sharedExpressions = @($jsonExpr)
    queryGroups       = @(@(P $mdl 'queryGroups' @()) | ForEach-Object { P $_ 'folder' })
}

$jsonOut = Join-Path $OutputFolder "$ReportName.model.json"
$txt = $doc | ConvertTo-Json -Depth 12
# ConvertTo-Json (PS 5.1) echappe les non-ASCII en \uXXXX : on les restitue.
# Le lookbehind evite de toucher un "\\u" litteral present dans du code DAX/M.
$txt = [regex]::Replace($txt, '(?<!\\)\\u(?<c>[0-9a-fA-F]{4})', { param($m) [char][int]::Parse($m.Groups['c'].Value, 'HexNumber') })
[System.IO.File]::WriteAllText($jsonOut, $txt, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("   OK  {0,-36} {1,5:N0} Ko" -f "$ReportName.model.json", ((Get-Item $jsonOut).Length / 1KB)) -ForegroundColor DarkGray

# ==================================================================
# ETAPE 3 : DMV (dependances + statistiques VertiPaq)
# ==================================================================
if (-not $SkipDmv -and $port) {
    if (-not $asCtx) { $asCtx = Open-AsContext $port }
    if ($asCtx) {
        Write-Host "-> Extraction DMV ($($asCtx.Info))..." -ForegroundColor Cyan
        $dmvs = [ordered]@{
            'DMV_Dependances.csv'           = 'SELECT * FROM $SYSTEM.DISCOVER_CALC_DEPENDENCY'
            'DMV_Tables_NbLignes.csv'       = 'SELECT * FROM $SYSTEM.DISCOVER_STORAGE_TABLES'
            'DMV_Colonnes_Cardinalite.csv'  = 'SELECT * FROM $SYSTEM.DISCOVER_STORAGE_TABLE_COLUMNS'
            'DMV_Colonnes_Memoire.csv'      = 'SELECT * FROM $SYSTEM.DISCOVER_STORAGE_TABLE_COLUMN_SEGMENTS'
        }
        foreach ($k in $dmvs.Keys) {
            try {
                $out = Invoke-AsQuery $asCtx $dmvs[$k]
                if ($k -eq 'DMV_Dependances.csv') { $calcDep = $out }
                Save $k $out | Out-Null
            } catch {
                Write-Host ("   KO  {0,-36} {1}" -f $k, $_.Exception.Message) -ForegroundColor DarkYellow
            }
        }
        Close-AsContext $asCtx
    } else {
        Write-Host "-> DMV ignorees : ni ADOMD.NET ni le provider MSOLAP n'ont repondu." -ForegroundColor DarkYellow
        Write-Host "   Le graphe de dependances sera deduit du texte des expressions." -ForegroundColor DarkYellow
        # Diagnostic pour identifier la variante en cause sur un poste ou ce
        # correctif ne suffit pas (ex. Enedis) alors qu'il fonctionne ailleurs
        # (ex. variante Store) : chemins/DLL/providers essayes et raison de
        # chaque echec.
        if ($script:AsDiag -and $script:AsDiag.Count -gt 0) {
            Write-Host "   Diagnostic ADOMD/MSOLAP :" -ForegroundColor DarkYellow
            $script:AsDiag | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
        }
    }
}

# ==================================================================
# ETAPE 4 : couche rapport (pages, visuels, mappage des champs)
# ==================================================================
# Le modele semantique ne contient pas la couche rapport. Elle est lue soit dans
# le .pbix (entree ZIP "Report/Layout", encodee en UTF-16 LE), soit dans un
# dossier .pbip (report.json classique, ou arborescence PBIR recente).

function Read-JsonSafe { param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $Text = $Text -replace '^\uFEFF',''
    try { return ($Text | ConvertFrom-Json -ErrorAction Stop) }
    catch {
        Add-Type -AssemblyName System.Web.Extensions
        $s = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $s.MaxJsonLength = [int]::MaxValue
        $s.RecursionLimit = 1000
        try { return (ConvertTo-PsTree $s.DeserializeObject($Text)) } catch { return $null }
    }
}

# Champ reference par une expression Column/Measure/HierarchyLevel (forme
# commune aux filtres et aux liaisons dynamiques de titre) : renvoie
# "Table.Champ", ou "" si illisible.
function Get-ExprField { param($e)
    foreach ($kind in @('Column','Measure','HierarchyLevel')) {
        $o = P $e $kind $null
        if ($null -eq $o) { continue }
        $ent = P (P (P $o 'Expression' $null) 'SourceRef' $null) 'Entity'
        $prp = P $o 'Property'
        if ($ent -or $prp) { return "$ent.$prp".Trim('.') }
    }
    return ""
}
# Champ porte par un filtre : renvoie "Table.Colonne" ou "" si illisible.
function Get-FilterField { param($f) return (Get-ExprField (P $f 'expression' $null)) }

# Litteral Power BI : "'Mon titre'" -> "Mon titre"
function Get-Literal { param($o)
    $v = P (P (P $o 'expr' $null) 'Literal' $null) 'Value'
    if ($v -is [string]) { return $v.Trim("'") }
    return ""
}

# "Sum(Table.Colonne)" / "Table.Mesure" -> "Table.Mesure"
function Normalize-QueryRef { param([string]$q)
    if (-not $q) { return "" }
    if ($q -match '^[A-Za-z]+\((?<i>.+)\)$') { return $Matches['i'] }
    return $q
}

# Pre-declarees pour que le Resume final puisse s'y referer meme si la couche
# rapport est absente, ignoree (-SkipReport) ou introuvable.
$rowPages  = @()
$rowVis    = @()
$rowBind   = @()
$rowFiltr  = @()
$rowUnused = @()
$usedRefs  = New-Object System.Collections.Generic.HashSet[string]
$srcDep    = ""

if (-not $SkipReport) {

    $layout = $null
    $srcRapport = ""

    # --- 4a. Source : dossier .pbip explicite ---
    if ($PbipFolder -and (Test-Path $PbipFolder)) {
        $repDir = Get-ChildItem $PbipFolder -Directory -Filter "*.Report" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $repDir -and (Split-Path $PbipFolder -Leaf) -like "*.Report") { $repDir = Get-Item $PbipFolder }
        if ($repDir) {
            $legacy = Join-Path $repDir.FullName "report.json"
            $pbirIdx = Join-Path $repDir.FullName "definition\pages\pages.json"
            if (Test-Path $legacy) {
                $layout = Read-JsonSafe ([System.IO.File]::ReadAllText($legacy, [System.Text.Encoding]::UTF8))
                $srcRapport = $legacy
            } elseif (Test-Path $pbirIdx) {
                # Format PBIR : une page par dossier, un visuel par dossier
                $pagesDir = Split-Path $pbirIdx -Parent
                $secs = foreach ($pd in (Get-ChildItem $pagesDir -Directory)) {
                    $pj = Join-Path $pd.FullName "page.json"
                    if (-not (Test-Path $pj)) { continue }
                    $pg = Read-JsonSafe ([System.IO.File]::ReadAllText($pj, [System.Text.Encoding]::UTF8))
                    $vcs = foreach ($vd in (Get-ChildItem (Join-Path $pd.FullName "visuals") -Directory -ErrorAction SilentlyContinue)) {
                        $vj = Join-Path $vd.FullName "visual.json"
                        if (-not (Test-Path $vj)) { continue }
                        Read-JsonSafe ([System.IO.File]::ReadAllText($vj, [System.Text.Encoding]::UTF8))
                    }
                    [pscustomobject]@{ name = (P $pg 'name'); displayName = (P $pg 'displayName'); ordinal = (P $pg 'ordinal')
                                       width = (P $pg 'width'); height = (P $pg 'height'); _pbir = $true; visualContainers = @($vcs) }
                }
                $layout = [pscustomobject]@{ sections = @($secs); _pbir = $true }
                $srcRapport = $pagesDir
            }
        }
        if (-not $layout) { Write-Host "-> Dossier .pbip : structure rapport non reconnue." -ForegroundColor DarkYellow }
    }

    # --- 4b. Source : fichier .pbix ---
    if (-not $layout) {
        if (-not $PbixPath) {
            # Le chemin figure dans la ligne de commande quand le rapport a ete
            # ouvert par double-clic ou depuis l'explorateur.
            try {
                $cl = (Get-CimInstance Win32_Process -Filter "Name='PBIDesktop.exe'" -ErrorAction SilentlyContinue |
                       Where-Object { $_.CommandLine -match '\.pbix' } | Select-Object -First 1).CommandLine
                if ($cl -match '"(?<p>[^"]+\.pbix)"') { $PbixPath = $Matches['p'] }
                elseif ($cl -match '(?<p>[A-Za-z]:\\[^"]+\.pbix)') { $PbixPath = $Matches['p'] }
            } catch { }
        }
        if (-not $PbixPath) {
            # Repli : raccourci .pbix portant le nom du rapport, dans les fichiers
            # recents. Le nom est exige : le raccourci le plus recent peut tres
            # bien designer un tout autre rapport.
            $rec = Join-Path $env:APPDATA "Microsoft\Windows\Recent"
            $lnk = Get-ChildItem $rec -Filter "*.pbix.lnk" -ErrorAction SilentlyContinue |
                   Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.BaseName) -eq $ReportName } |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($lnk) {
                try {
                    $t = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk.FullName).TargetPath
                    if ($t -and (Test-Path $t)) { $PbixPath = $t }
                } catch { }
            }
        }

        # Garde-fou : un .pbix devine dont le nom ne correspond pas au modele
        # charge produirait une couche rapport sans rapport avec le modele.
        if ($PbixPath -and -not $PSBoundParameters.ContainsKey('PbixPath')) {
            $nomPbix = [System.IO.Path]::GetFileNameWithoutExtension($PbixPath)
            if ((Get-SafeName $nomPbix) -ne $ReportName) {
                Write-Host "-> Couche rapport ignoree : le .pbix detecte ne correspond pas au modele." -ForegroundColor DarkYellow
                Write-Host "   Modele : $ReportName" -ForegroundColor DarkYellow
                Write-Host "   Fichier detecte : $nomPbix" -ForegroundColor DarkYellow
                Write-Host "   Relance avec -PbixPath pour designer le bon fichier." -ForegroundColor DarkYellow
                $PbixPath = ""
            }
        }

        if ($PbixPath -and (Test-Path $PbixPath)) {
            Write-Host "-> Lecture de la couche rapport : $(Split-Path $PbixPath -Leaf)" -ForegroundColor Cyan
            try {
                # Les deux assemblies sont necessaires : FileSystem pour ZipFile,
                # Compression pour ZipArchive et ZipArchiveMode.
                Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                # FileShare ReadWrite : le .pbix est verrouille par Power BI Desktop.
                $fs  = [System.IO.File]::Open($PbixPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                # 'Read' en chaine : evite d'avoir a resoudre le type enum.
                $zip = New-Object System.IO.Compression.ZipArchive($fs, 'Read')
                $entry = $zip.Entries | Where-Object { $_.FullName -eq 'Report/Layout' } | Select-Object -First 1
                if ($entry) {
                    $sr = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::Unicode, $true)
                    $layout = Read-JsonSafe $sr.ReadToEnd()
                    $sr.Close()
                    $srcRapport = $PbixPath
                } else {
                    Write-Host "   Entree Report/Layout absente du .pbix." -ForegroundColor DarkYellow
                }
                $zip.Dispose(); $fs.Close()
            } catch {
                Write-Host "   Lecture impossible : $($_.Exception.Message)" -ForegroundColor DarkYellow
            }
        } else {
            Write-Host "-> Couche rapport ignoree : .pbix introuvable (utilise -PbixPath ou -PbipFolder)." -ForegroundColor DarkYellow
        }
    }

    # --- 4c. Mise a plat ---
    if ($layout) {
        $isPbir   = [bool](P $layout '_pbir' $false)
        $rowPages = New-Object System.Collections.Generic.List[object]
        $rowVis   = New-Object System.Collections.Generic.List[object]
        $rowBind  = New-Object System.Collections.Generic.List[object]
        $rowFiltr = New-Object System.Collections.Generic.List[object]
        $usedRefs = New-Object System.Collections.Generic.HashSet[string]

        # Filtres au niveau rapport
        foreach ($f in @(Read-JsonSafe (P $layout 'filters'))) {
            $champFiltre = Get-FilterField $f
            # Un champ filtrant (notamment une mesure) est un usage reel, meme
            # sans etre pose dans un visuel : sinon 24_Champs_NonUtilises.csv le
            # classe a tort comme supprimable (angle mort documente dans
            # docs/PROMPTS.md).
            if ($champFiltre) { [void]$usedRefs.Add($champFiltre) }
            $rowFiltr.Add([pscustomobject]@{ Niveau='Rapport'; Page=''; Visuel=''
                Champ = $champFiltre
                Type  = P $f 'type'; Etat = P $f 'howCreated' })
        }

        $iPage = 0
        foreach ($s in @(P $layout 'sections' @())) {
            $iPage++
            $pageNom = P $s 'displayName'
            if (-not $pageNom) { $pageNom = P $s 'name' }
            $vcs = @(P $s 'visualContainers' @())

            $rowPages.Add([pscustomobject]@{
                Ordre       = (P $s 'ordinal' $iPage)
                Page        = $pageNom
                NomInterne  = P $s 'name'
                Largeur     = P $s 'width'
                Hauteur     = P $s 'height'
                NbVisuels   = $vcs.Count
                Masquee     = ((P (Read-JsonSafe (P $s 'config')) 'visibility' 0) -ne 0)
            })

            foreach ($f in @(Read-JsonSafe (P $s 'filters'))) {
                $champFiltre = Get-FilterField $f
                if ($champFiltre) { [void]$usedRefs.Add($champFiltre) }
                $rowFiltr.Add([pscustomobject]@{ Niveau='Page'; Page=$pageNom; Visuel=''
                    Champ = $champFiltre
                    Type  = P $f 'type'; Etat = P $f 'howCreated' })
            }

            foreach ($vc in $vcs) {
                if ($isPbir) {
                    $pos   = P $vc 'position' $null
                    $vis   = P $vc 'visual' $null
                    $vid   = P $vc 'name'
                    $vtype = P $vis 'visualType'
                    $x = P $pos 'x'; $y = P $pos 'y'; $z = P $pos 'z'; $w = P $pos 'width'; $h = P $pos 'height'
                    $titre = ""
                    $tObj  = @(P (P $vis 'objects' $null) 'title' @())
                    if ($tObj.Count -gt 0) {
                        $tTxt = (P $tObj[0] 'properties' $null).text
                        $titre = Get-Literal $tTxt
                        if (-not $titre) {
                            # Titre dynamique (lie a une mesure/colonne plutot qu'a un
                            # texte fixe) : le champ ne remonte dans aucune projection,
                            # donc sans ceci il serait vu a tort comme non utilise.
                            $champTitre = Get-ExprField (P $tTxt 'expr' $null)
                            if ($champTitre) { [void]$usedRefs.Add($champTitre); $titre = "(titre dynamique : $champTitre)" }
                        }
                    }
                    $qs = P (P $vis 'query' $null) 'queryState' $null
                } else {
                    $cfg   = Read-JsonSafe (P $vc 'config')
                    $sv    = P $cfg 'singleVisual' $null
                    $grp   = P $cfg 'singleVisualGroup' $null
                    $vid   = P $cfg 'name'
                    $vtype = if ($sv) { P $sv 'visualType' } elseif ($grp) { 'group' } else { '' }
                    $x = P $vc 'x'; $y = P $vc 'y'; $z = P $vc 'z'; $w = P $vc 'width'; $h = P $vc 'height'
                    $titre = ""
                    # BUG PREEXISTANT CORRIGE : un appel P(...) surnumeraire ici
                    # enveloppait le tableau de titre dans un appel P supplementaire,
                    # qui retombait systematiquement sur "" -- le titre (fixe ou
                    # dynamique) n'etait donc jamais lu sur ce chemin (.pbix /
                    # report.json classique). VERIFIE sur fixture synthetique.
                    $tObj = @(P (P $sv 'vcObjects' $null) 'title' @())
                    if ($tObj.Count -gt 0) {
                        $tTxt = (P $tObj[0] 'properties' $null).text
                        $titre = Get-Literal $tTxt
                        if (-not $titre) {
                            # Titre dynamique : voir commentaire equivalent dans la
                            # branche PBIR ci-dessus.
                            $champTitre = Get-ExprField (P $tTxt 'expr' $null)
                            if ($champTitre) { [void]$usedRefs.Add($champTitre); $titre = "(titre dynamique : $champTitre)" }
                        }
                    }
                    if (-not $titre -and $grp) { $titre = P $grp 'displayName' }
                    $qs = P $sv 'projections' $null
                }

                $nbChamps = 0
                if ($qs) {
                    foreach ($role in $qs.PSObject.Properties) {
                        # Legacy : role -> [projections]. PBIR : role -> { projections: [...] }
                        $projs = $role.Value
                        $sub = P $projs 'projections' $null
                        if ($sub) { $projs = $sub }
                        foreach ($proj in @($projs)) {
                            $qref = P $proj 'queryRef'
                            if (-not $qref) { $qref = P (P $proj 'field' $null) 'NativeQueryRef' }
                            if (-not $qref) { continue }
                            $norm = Normalize-QueryRef $qref
                            [void]$usedRefs.Add($norm)
                            $nbChamps++
                            $tbl = ""; $chp = $norm
                            if ($norm -match '^(?<t>[^.]+)\.(?<c>.+)$') { $tbl = $Matches['t']; $chp = $Matches['c'] }
                            $rowBind.Add([pscustomobject]@{
                                Page = $pageNom; Visuel = $(if ($titre) { $titre } else { $vid }); TypeVisuel = $vtype
                                Role = $role.Name; Table = $tbl; Champ = $chp; QueryRef = $qref
                            })
                        }
                    }
                }

                $rowVis.Add([pscustomobject]@{
                    Page = $pageNom; Visuel = $(if ($titre) { $titre } else { $vid }); TypeVisuel = $vtype
                    NomInterne = $vid; X = $x; Y = $y; Z = $z; Largeur = $w; Hauteur = $h; NbChamps = $nbChamps
                })

                foreach ($f in @(Read-JsonSafe (P $vc 'filters'))) {
                    $champFiltre = Get-FilterField $f
                    if ($champFiltre) { [void]$usedRefs.Add($champFiltre) }
                    $rowFiltr.Add([pscustomobject]@{ Niveau='Visuel'; Page=$pageNom; Visuel=$(if ($titre) { $titre } else { $vid })
                        Champ = $champFiltre
                        Type  = P $f 'type'; Etat = P $f 'howCreated' })
                }
            }
        }

        Save "20_Pages.csv"          $rowPages | Out-Null
        Save "21_Visuels.csv"        $rowVis   | Out-Null
        Save "22_Champs_Visuels.csv" $rowBind  | Out-Null
        if (-not (Save "23_Filtres.csv" $rowFiltr)) { $vides.Add("filtres de rapport") }

        # --- 4d. Objets du modele reellement inutilises ---
        #
        # La question utile n'est pas "cet objet est-il cite quelque part ?" mais
        # "est-il atteignable depuis un visuel ?". On construit donc un graphe de
        # dependances, puis on propage l'usage depuis les racines.
        #
        # Source primaire : DISCOVER_CALC_DEPENDENCY (calculee par le moteur,
        # qualifiee par table, insensible aux commentaires et aux litteraux,
        # couvre RLS, calculation items et tables calculees).
        # Repli hors connexion : analyse textuelle des expressions, apres
        # suppression des commentaires et des chaines.

        $K = { param([string]$t, [string]$o) return ("$t|$o").ToLowerInvariant() }

        $graph  = @{}   # cle -> HashSet des cles dont elle depend
        $roots  = New-Object System.Collections.Generic.HashSet[string]
        $srcDep = ""

        function Add-Edge { param($g, [string]$from, [string]$to)
            if (-not $from -or -not $to -or $from -eq $to) { return }
            if (-not $g.ContainsKey($from)) { $g[$from] = New-Object System.Collections.Generic.HashSet[string] }
            [void]$g[$from].Add($to)
        }

        # Racines "structurelles" : un objet peut etre indispensable au modele
        # sans jamais apparaitre dans un visuel ni dans une expression DAX (ex.
        # colonne technique servant uniquement de cle de relation). $rootMotifs
        # garde la raison de chaque racine directe pour la colonne Motif du CSV.
        $rootMotifs = @{}   # cle -> HashSet des motifs ('relation','tri','hierarchie','RLS','visuel','table de dates','categorie temporelle')
        function Add-Root { param([string]$key, [string]$motif)
            if (-not $key) { return }
            [void]$roots.Add($key)
            if (-not $rootMotifs.ContainsKey($key)) { $rootMotifs[$key] = New-Object System.Collections.Generic.HashSet[string] }
            [void]$rootMotifs[$key].Add($motif)
        }

        if ($calcDep -and @($calcDep).Count -gt 0) {
            $srcDep = "DMV"
            foreach ($d in $calcDep) {
                $ot = [string](P $d 'OBJECT_TYPE')
                $from = & $K ([string](P $d 'TABLE')) ([string](P $d 'OBJECT'))
                $to   = & $K ([string](P $d 'REFERENCED_TABLE')) ([string](P $d 'REFERENCED_OBJECT'))
                Add-Edge $graph $from $to
                # La securite au niveau des lignes est un usage legitime : ses
                # dependances sont des racines au meme titre que les visuels.
                if ($ot -eq 'ROWS_ALLOWED') { Add-Root $to 'RLS' }
            }
        } else {
            $srcDep = "Analyse textuelle"
            # Retrait des commentaires puis des litteraux, dans cet ordre.
            function Clear-Dax { param([string]$x)
                if (-not $x) { return "" }
                $x = [regex]::Replace($x, '/\*.*?\*/', ' ', 'Singleline')
                $x = [regex]::Replace($x, '(//|--).*?$', ' ', 'Multiline')
                $x = [regex]::Replace($x, '"(?:[^"]|"")*"', ' ')
                return $x
            }
            # Index des noms d'objets pour resoudre les references non qualifiees.
            $idxMeas = @{}; $idxCol = @{}
            foreach ($t in $tables) {
                foreach ($m in @(P $t 'measures' @())) { $idxMeas[$m.name.ToLowerInvariant()] = (& $K $t.name $m.name) }
                foreach ($c in @(P $t 'columns'  @())) {
                    $kk = $c.name.ToLowerInvariant()
                    if (-not $idxCol.ContainsKey($kk)) { $idxCol[$kk] = New-Object System.Collections.Generic.List[string] }
                    $idxCol[$kk].Add((& $K $t.name $c.name))
                }
            }
            $scan = {
                param($ownerKey, $expr, $ownerTable)
                $txt = Clear-Dax $expr
                if (-not $txt) { return }
                # 'Table'[Objet] ou Table[Objet] : reference qualifiee.
                foreach ($mm in [regex]::Matches($txt, "'(?<t>[^']+)'\[(?<o>[^\]]+)\]|(?<t2>[A-Za-z_][\w]*)\[(?<o2>[^\]]+)\]")) {
                    $tt = if ($mm.Groups['t'].Success) { $mm.Groups['t'].Value } else { $mm.Groups['t2'].Value }
                    $oo = if ($mm.Groups['o'].Success) { $mm.Groups['o'].Value } else { $mm.Groups['o2'].Value }
                    Add-Edge $graph $ownerKey (& $K $tt $oo)
                }
                # [Objet] seul : mesure si le nom existe, sinon colonne de la table porteuse.
                foreach ($mm in [regex]::Matches($txt, "(?<![\w'\]])\[(?<o>[^\]]+)\]")) {
                    $oo = $mm.Groups['o'].Value.ToLowerInvariant()
                    if ($idxMeas.ContainsKey($oo)) { Add-Edge $graph $ownerKey $idxMeas[$oo]; continue }
                    $own = (& $K $ownerTable $mm.Groups['o'].Value)
                    if ($idxCol.ContainsKey($oo)) {
                        if ($idxCol[$oo] -contains $own) { Add-Edge $graph $ownerKey $own }
                        elseif ($idxCol[$oo].Count -eq 1) { Add-Edge $graph $ownerKey $idxCol[$oo][0] }
                    }
                }
            }
            foreach ($t in $tables) {
                foreach ($m in @(P $t 'measures' @())) { & $scan (& $K $t.name $m.name) (E (P $m 'expression')) $t.name }
                foreach ($c in @(P $t 'columns'  @())) { & $scan (& $K $t.name $c.name) (E (P $c 'expression')) $t.name }
                $cg = P $t 'calculationGroup' $null
                if ($cg) { foreach ($ci in @(P $cg 'calculationItems' @())) { & $scan (& $K $t.name $ci.name) (E (P $ci 'expression')) $t.name } }
            }
            # RLS : racines.
            foreach ($r in @(P $mdl 'roles' @())) {
                foreach ($tp in @(P $r 'tablePermissions' @())) {
                    $rk = & $K "RLS" "$($r.name)/$(P $tp 'name')"
                    & $scan $rk (E (P $tp 'filterExpression')) (P $tp 'name')
                    Add-Root $rk 'RLS'
                }
            }
        }

        # Racines structurelles : relations, tri, hierarchies, tables/colonnes
        # de dates. Aucune de ces trois-la n'apparait forcement dans un visuel
        # ou une expression DAX, mais les retirer casse le modele (bug corrige :
        # des colonnes de relation comme Absenteisme[NNI] ressortaient a tort
        # "Supprimable" faute d'etre une racine du graphe).
        foreach ($r in @(P $mdl 'relationships' @())) {
            Add-Root (& $K (P $r 'fromTable') (P $r 'fromColumn')) 'relation'
            Add-Root (& $K (P $r 'toTable')   (P $r 'toColumn'))   'relation'
        }
        foreach ($t in $tables) {
            foreach ($c in @(P $t 'columns' @())) {
                $sbc = P $c 'sortByColumn' $null
                if ($sbc) { Add-Root (& $K $t.name $sbc) 'tri' }
            }
            foreach ($h in @(P $t 'hierarchies' @())) {
                foreach ($l in @(P $h 'levels' @())) {
                    $lc = P $l 'column' $null
                    if ($lc) { Add-Root (& $K $t.name $lc) 'hierarchie' }
                }
            }
            # Table marquee "table de dates" (Table.DataCategory = "Time") :
            # ses colonnes, y compris techniques (numeros de mois, etc.), sont
            # utilisees par la hierarchie de dates integree meme sans lien
            # explicite dans le modele ni pose dans un visuel.
            if (([string](P $t 'dataCategory' '')).Trim() -ieq 'Time') {
                foreach ($c in @(P $t 'columns' @())) { Add-Root (& $K $t.name $c.name) 'table de dates' }
            }
            # Colonnes dont le DataCategory releve de la taxonomie date/heure
            # Power BI (Year, Quarter, Month, Day, ...), meme hors table de
            # dates marquee comme telle.
            foreach ($c in @(P $t 'columns' @())) {
                $dc = [string](P $c 'dataCategory' '')
                if ($dc -match '(?i)^(year|years|quarter|quarters|month|months|day|days|date|dates|time|paddeddatetabledates)$') {
                    Add-Root (& $K $t.name $c.name) 'categorie temporelle'
                }
            }
        }

        # Racines : tout champ pose dans un visuel.
        foreach ($ref in $usedRefs) {
            if ($ref -match '^(?<t>[^.]+)\.(?<o>.+)$') { Add-Root (& $K $Matches['t'] $Matches['o']) 'visuel' }
        }

        # Propagation : si A est utilise, tout ce dont A depend l'est aussi.
        $reach = New-Object System.Collections.Generic.HashSet[string]
        $queue = New-Object System.Collections.Generic.Queue[string]
        foreach ($r in $roots) { if ($reach.Add($r)) { $queue.Enqueue($r) } }
        while ($queue.Count -gt 0) {
            $cur = $queue.Dequeue()
            if (-not $graph.ContainsKey($cur)) { continue }
            foreach ($nxt in $graph[$cur]) { if ($reach.Add($nxt)) { $queue.Enqueue($nxt) } }
        }

        # Verdict par objet non pose directement dans un visuel.
        $rowUnused = New-Object System.Collections.Generic.List[object]
        foreach ($t in $tables) {
            $objs = @()
            foreach ($m in @(P $t 'measures' @())) { $objs += ,@('Mesure',  $m.name, (P $m 'isHidden' $false)) }
            foreach ($c in @(P $t 'columns'  @())) {
                if ((P $c 'type' 'data') -eq 'rowNumber') { continue }
                $objs += ,@('Colonne', $c.name, (P $c 'isHidden' $false))
            }
            foreach ($o in $objs) {
                $key = & $K $t.name $o[1]
                $direct = $usedRefs.Contains("$($t.name).$($o[1])")
                if ($direct) { continue }
                $atteignable = $reach.Contains($key)
                $appelants = @($graph.Keys | Where-Object { $graph[$_].Contains($key) }).Count
                $verdict = if ($atteignable) { 'Intermediaire - conserver' }
                           elseif ($appelants -gt 0) { 'Chaine morte - a verifier' }
                           else { 'Supprimable' }
                # Motif : pourquoi l'objet est retenu. Racine directe (relation,
                # tri, hierarchie, RLS, visuel, table de dates, categorie
                # temporelle) sinon simple dependance transitive d'une racine.
                $motif = ""
                if ($atteignable) {
                    if ($rootMotifs.ContainsKey($key)) { $motif = (@($rootMotifs[$key]) | Sort-Object) -join ', ' }
                    else { $motif = 'dependance DAX' }
                }
                $rowUnused.Add([pscustomobject]@{
                    Type                = $o[0]
                    Table               = $t.name
                    Objet               = $o[1]
                    PoseDansVisuel      = $false
                    AtteignableDepuisVisuel = $atteignable
                    NbAppelantsDirects  = $appelants
                    Verdict             = $verdict
                    Motif               = $motif
                    Masque              = $o[2]
                    SourceAnalyse       = $srcDep
                })
            }
        }
        $rowUnused = $rowUnused | Sort-Object @{e={ @('Supprimable','Chaine morte - a verifier','Intermediaire - conserver').IndexOf($_.Verdict) }}, Table, Objet
        Save "24_Champs_NonUtilises.csv" $rowUnused | Out-Null
        if ($srcDep -eq "Analyse textuelle") {
            Write-Host "   (dependances deduites du texte : DMV indisponible, verdicts a confirmer)" -ForegroundColor DarkYellow
        }

        # --- 4e. JSON rapport pour agents IA ---
        $docRep = [ordered]@{
            '$schema'   = 'powerbi-report-layer/1.0'
            reportName  = $ReportName
            source      = $srcRapport
            generatedAt = (Get-Date -Format 'o')
            summary     = [ordered]@{ pages = $rowPages.Count; visuals = $rowVis.Count; boundFields = $usedRefs.Count }
            pages = @(foreach ($pg in $rowPages) {
                [ordered]@{
                    name    = $pg.Page
                    ordinal = $pg.Ordre
                    hidden  = $pg.Masquee
                    visuals = @(foreach ($v in ($rowVis | Where-Object { $_.Page -eq $pg.Page })) {
                        [ordered]@{
                            title    = $v.Visuel
                            type     = $v.TypeVisuel
                            position = [ordered]@{ x = $v.X; y = $v.Y; width = $v.Largeur; height = $v.Hauteur }
                            fields   = @(foreach ($b in ($rowBind | Where-Object { $_.Page -eq $pg.Page -and $_.Visuel -eq $v.Visuel })) {
                                [ordered]@{ role = $b.Role; table = $b.Table; field = $b.Champ }
                            })
                        }
                    })
                }
            })
        }
        $repOut = Join-Path $OutputFolder "$ReportName.report.json"
        $txtRep = $docRep | ConvertTo-Json -Depth 12
        $txtRep = [regex]::Replace($txtRep, '(?<!\\)\\u(?<c>[0-9a-fA-F]{4})', { param($m) [char][int]::Parse($m.Groups['c'].Value, 'HexNumber') })
        [System.IO.File]::WriteAllText($repOut, $txtRep, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ("   OK  {0,-36} {1,5:N0} Ko" -f "$ReportName.report.json", ((Get-Item $repOut).Length / 1KB)) -ForegroundColor DarkGray
    }
}

# ==================================================================
# Bilan
# ==================================================================
$sw.Stop()
$files = Get-ChildItem $OutputFolder -File | Sort-Object Name
Write-Host "`nTermine en $([math]::Round($sw.Elapsed.TotalSeconds,1))s - $($files.Count) fichiers dans :" -ForegroundColor Green
Write-Host $OutputFolder -ForegroundColor Yellow
$files | ForEach-Object { "   {0,-40} {1,8:N0} Ko" -f $_.Name, ($_.Length / 1KB) }
if ($vides.Count -gt 0) {
    Write-Host "`nSections absentes du modele (aucun fichier) : $($vides -join ', ')" -ForegroundColor DarkGray
}

# --- Resume.md : lecture rapide sans ouvrir les CSV un a un -----
$verdicts = [ordered]@{ 'Supprimable' = 0; 'Chaine morte - a verifier' = 0; 'Intermediaire - conserver' = 0 }
foreach ($u in $rowUnused) { if ($verdicts.Contains($u.Verdict)) { $verdicts[$u.Verdict]++ } }

$resume = New-Object System.Text.StringBuilder
[void]$resume.AppendLine("# Resume de l'export - $ReportName")
[void]$resume.AppendLine("")
[void]$resume.AppendLine("Genere le $(Get-Date -Format 'yyyy-MM-dd HH:mm') en $([math]::Round($sw.Elapsed.TotalSeconds,1))s.")
[void]$resume.AppendLine("")
[void]$resume.AppendLine("## Modele")
[void]$resume.AppendLine("- Produit : $($props['Produit'])")
[void]$resume.AppendLine("- Tables : $($props['NbTables'])")
[void]$resume.AppendLine("- Colonnes : $($props['NbColonnes'])")
[void]$resume.AppendLine("- Mesures : $($props['NbMesures'])")
[void]$resume.AppendLine("- Relations : $($props['NbRelations'])")
[void]$resume.AppendLine("- Roles RLS : $($props['NbRoles'])")
if ($rowPages.Count -gt 0 -or $rowVis.Count -gt 0) {
    [void]$resume.AppendLine("")
    [void]$resume.AppendLine("## Rapport")
    [void]$resume.AppendLine("- Pages : $($rowPages.Count)")
    [void]$resume.AppendLine("- Visuels : $($rowVis.Count)")
    [void]$resume.AppendLine("- Champs utilises dans les visuels, titres et filtres : $($usedRefs.Count)")
}
if ($rowUnused.Count -gt 0) {
    [void]$resume.AppendLine("")
    [void]$resume.AppendLine("## Pistes de nettoyage (voir 24_Champs_NonUtilises.csv)")
    [void]$resume.AppendLine("- Supprimable : $($verdicts['Supprimable'])")
    [void]$resume.AppendLine("- Chaine morte - a verifier : $($verdicts['Chaine morte - a verifier'])")
    [void]$resume.AppendLine("- Intermediaire - a conserver : $($verdicts['Intermediaire - conserver'])")
    [void]$resume.AppendLine("- Fiabilite des verdicts : $srcDep$(if ($srcDep -eq 'Analyse textuelle') { ' (indicatif, DMV indisponible lors de cet export)' })")
}
if ($vides.Count -gt 0) {
    [void]$resume.AppendLine("")
    [void]$resume.AppendLine("## Sections absentes du modele")
    [void]$resume.AppendLine("- $($vides -join ', ')")
}
[void]$resume.AppendLine("")
[void]$resume.AppendLine("## Fichiers produits ($($files.Count))")
foreach ($f in $files) { [void]$resume.AppendLine("- $($f.Name) ($([math]::Round($f.Length / 1KB, 1)) Ko)") }

$resumePath = Join-Path $OutputFolder "Resume.md"
[System.IO.File]::WriteAllText($resumePath, $resume.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "`nResume : Resume.md" -ForegroundColor Yellow

# --- Ouverture automatique du dossier ----------------------------
if (-not $SansOuverture) {
    try { Start-Process -FilePath "explorer.exe" -ArgumentList "`"$OutputFolder`"" | Out-Null } catch { }
}
