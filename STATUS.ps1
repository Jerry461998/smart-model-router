$ErrorActionPreference = 'Stop'
$status = Join-Path $env:USERPROFILE 'plugins\smart-model-router\scripts\status.ps1'
if (-not (Test-Path -LiteralPath $status)) {
    throw "Smart Model Router is not installed at: $status"
}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $status
