param(
    [string]$CodexRoot = (Join-Path $env:USERPROFILE '.codex'),
    [string]$PluginHome = (Join-Path $env:USERPROFILE 'plugins'),
    [switch]$SkipPluginCommand
)

. (Join-Path $PSScriptRoot 'common.ps1')

$pluginRoot = Join-Path $PluginHome 'smart-model-router'
$globalAgentsPath = Join-Path $CodexRoot 'AGENTS.md'
$blockPath = Join-Path $pluginRoot 'global-agents-block.md'
if (-not (Test-Path -LiteralPath $blockPath)) { throw "Installed Smart Model Router source is missing: $blockPath" }
$existing = if (Test-Path -LiteralPath $globalAgentsPath) { Read-Utf8Text -Path $globalAgentsPath } else { '' }
$block = Read-Utf8Text -Path $blockPath
Write-Utf8NoBom -Path $globalAgentsPath -Text (Add-GlobalBlockText -Text $existing -Block $block)
if (-not $SkipPluginCommand) {
    $codex = Get-CodexCommand
    & $codex plugin add 'smart-model-router@personal'
    if ($LASTEXITCODE -ne 0) { throw "Codex plugin enable failed with exit code $LASTEXITCODE" }
}
[ordered]@{ status = 'enabled'; restartRequired = $true } | ConvertTo-Json
