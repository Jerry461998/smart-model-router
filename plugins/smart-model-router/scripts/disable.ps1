param(
    [string]$CodexRoot = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$SkipPluginCommand
)

. (Join-Path $PSScriptRoot 'common.ps1')

$globalAgentsPath = Join-Path $CodexRoot 'AGENTS.md'
if (Test-Path -LiteralPath $globalAgentsPath) {
    $text = Read-Utf8Text -Path $globalAgentsPath
    Write-Utf8NoBom -Path $globalAgentsPath -Text (Remove-GlobalBlockText -Text $text)
}
if (-not $SkipPluginCommand) {
    $codex = Get-CodexCommand
    & $codex plugin remove 'smart-model-router@personal'
    if ($LASTEXITCODE -ne 0) { throw "Codex plugin disable failed with exit code $LASTEXITCODE" }
}
[ordered]@{ status = 'disabled'; restartRequired = $true } | ConvertTo-Json
