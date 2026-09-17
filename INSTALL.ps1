$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$installer = Join-Path $root 'plugins\smart-model-router\scripts\install.ps1'
if (-not (Test-Path -LiteralPath $installer)) {
    throw "Installer not found: $installer"
}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
