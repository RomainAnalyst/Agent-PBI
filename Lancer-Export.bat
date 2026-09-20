@echo off
REM Lance l'export des metadonnees du rapport Power BI Desktop actuellement ouvert.
REM Force le PowerShell 64 bits (necessaire pour les DMV via le provider MSOLAP).

cd /d "%~dp0"

if exist "%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe" (
    set "PS=%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe"
) else (
    set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Export-PowerBIMetadata-Full.ps1" %*

echo.
pause
