$ErrorActionPreference = 'Stop'
$uninstaller = Join-Path $env:USERPROFILE 'plugins\smart-model-router\scripts\uninstall.ps1'
if (-not (Test-Path -LiteralPath $uninstaller)) {
    throw "Smart Model Router is not installed at: $uninstaller"
}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $uninstaller
