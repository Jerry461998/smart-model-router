param(
    [string]$CodexRoot = (Join-Path $env:USERPROFILE '.codex'),
    [string]$PluginHome = (Join-Path $env:USERPROFILE 'plugins'),
    [string]$MarketplacePath = (Join-Path $env:USERPROFILE '.agents\plugins\marketplace.json'),
    [switch]$SkipPluginCommand,
    [switch]$KeepSource
)

. (Join-Path $PSScriptRoot 'common.ps1')

$statePath = Join-Path $CodexRoot 'smart-model-router\install-state.json'
if (-not (Test-Path -LiteralPath $statePath)) { throw "Install state not found: $statePath" }
$state = Read-Utf8Text -Path $statePath | ConvertFrom-Json

if (-not $SkipPluginCommand) {
    $codex = Get-CodexCommand
    & $codex plugin remove 'smart-model-router@personal'
    if ($LASTEXITCODE -ne 0) { throw "Codex plugin removal failed with exit code $LASTEXITCODE" }
}

$configPath = Join-Path $CodexRoot 'config.toml'
if (Test-Path -LiteralPath $configPath) {
    $text = Read-Utf8Text -Path $configPath
    Write-Utf8NoBom -Path $configPath -Text (Restore-SmrConfig -Text $text -Snapshot $state.originalConfig)
}

$globalAgentsPath = Join-Path $CodexRoot 'AGENTS.md'
if (Test-Path -LiteralPath $globalAgentsPath) {
    $text = Read-Utf8Text -Path $globalAgentsPath
    $clean = Remove-GlobalBlockText -Text $text
    if (-not $state.originalAgentsExisted -and -not $clean.Trim()) {
        Remove-Item -LiteralPath $globalAgentsPath -Force
    } else {
        Write-Utf8NoBom -Path $globalAgentsPath -Text $clean
    }
}

$preservedAgents = @()
$agentDir = Join-Path $CodexRoot 'agents'
foreach ($property in $state.agentHashes.PSObject.Properties) {
    $path = Join-Path $agentDir $property.Name
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $currentHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($currentHash -eq [string]$property.Value) {
        Remove-Item -LiteralPath $path -Force
    } else {
        $preservedAgents += $path
    }
}

if (Test-Path -LiteralPath $MarketplacePath) {
    $marketplace = Read-Utf8Text -Path $MarketplacePath | ConvertFrom-Json
    $marketplace.plugins = @($marketplace.plugins | Where-Object { $_.name -ne 'smart-model-router' })
    Write-Utf8NoBom -Path $MarketplacePath -Text (($marketplace | ConvertTo-Json -Depth 20) + "`r`n")
}

$pluginTarget = Join-Path $PluginHome 'smart-model-router'
if (-not $KeepSource -and (Test-Path -LiteralPath $pluginTarget)) {
    $resolvedHome = (Resolve-Path -LiteralPath $PluginHome).Path.TrimEnd('\')
    $resolvedTarget = (Resolve-Path -LiteralPath $pluginTarget).Path
    $expectedPrefix = $resolvedHome + '\'
    $manifestPath = Join-Path $resolvedTarget '.codex-plugin\plugin.json'
    if (-not $resolvedTarget.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Refusing unexpected plugin path: $resolvedTarget" }
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Refusing target without manifest: $resolvedTarget" }
    $manifest = Read-Utf8Text -Path $manifestPath | ConvertFrom-Json
    if ($manifest.name -ne 'smart-model-router') { throw "Refusing target owned by another plugin: $resolvedTarget" }
    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
}

[ordered]@{
    status = 'uninstalled'
    preservedModifiedAgents = $preservedAgents
    backups = $state.latestBackups
    restartRequired = $true
} | ConvertTo-Json -Depth 8
