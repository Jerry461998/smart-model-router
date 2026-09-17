param(
    [string]$CodexRoot = (Join-Path $env:USERPROFILE '.codex'),
    [string]$PluginHome = (Join-Path $env:USERPROFILE 'plugins'),
    [string]$MarketplacePath = (Join-Path $env:USERPROFILE '.agents\plugins\marketplace.json'),
    [switch]$SkipPluginCommand
)

. (Join-Path $PSScriptRoot 'common.ps1')

$sourceRoot = Split-Path -Parent $PSScriptRoot
$pluginTarget = Join-Path $PluginHome 'smart-model-router'
$stateRoot = Join-Path $CodexRoot 'smart-model-router'
$statePath = Join-Path $stateRoot 'install-state.json'
$backupRoot = Join-Path $stateRoot 'backups'
$configPath = Join-Path $CodexRoot 'config.toml'
$globalAgentsPath = Join-Path $CodexRoot 'AGENTS.md'
$agentTargetDir = Join-Path $CodexRoot 'agents'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'

foreach ($dir in @($CodexRoot, $PluginHome, (Split-Path -Parent $MarketplacePath), $stateRoot, $backupRoot, $agentTargetDir)) {
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$priorState = $null
if (Test-Path -LiteralPath $statePath) { $priorState = Read-Utf8Text -Path $statePath | ConvertFrom-Json }

$configText = if (Test-Path -LiteralPath $configPath) { Read-Utf8Text -Path $configPath } else { '' }
$agentsText = if (Test-Path -LiteralPath $globalAgentsPath) { Read-Utf8Text -Path $globalAgentsPath } else { '' }
$marketplaceText = if (Test-Path -LiteralPath $MarketplacePath) { Read-Utf8Text -Path $MarketplacePath } else { '' }

$configBackup = Join-Path $backupRoot "config-$timestamp.toml"
$agentsBackup = Join-Path $backupRoot "AGENTS-$timestamp.md"
$marketplaceBackup = Join-Path $backupRoot "marketplace-$timestamp.json"
Write-Utf8NoBom -Path $configBackup -Text $configText
Write-Utf8NoBom -Path $agentsBackup -Text $agentsText
Write-Utf8NoBom -Path $marketplaceBackup -Text $marketplaceText

$originalSnapshot = if ($priorState -and $priorState.originalConfig) { $priorState.originalConfig } else { Get-SmrConfigSnapshot -Text $configText }
$originalAgentsExisted = if ($priorState) { [bool]$priorState.originalAgentsExisted } else { Test-Path -LiteralPath $globalAgentsPath }

if (Test-Path -LiteralPath $pluginTarget) {
    $targetManifest = Join-Path $pluginTarget '.codex-plugin\plugin.json'
    if (-not (Test-Path -LiteralPath $targetManifest)) { throw "Existing target has no Smart Model Router manifest: $pluginTarget" }
    $manifest = Read-Utf8Text -Path $targetManifest | ConvertFrom-Json
    if ($manifest.name -ne 'smart-model-router') { throw "Existing target belongs to another plugin: $pluginTarget" }
} else {
    New-Item -ItemType Directory -Path $pluginTarget -Force | Out-Null
}

$sourceResolved = (Resolve-Path -LiteralPath $sourceRoot).Path
$targetResolved = (Resolve-Path -LiteralPath $pluginTarget).Path
if ($sourceResolved -ne $targetResolved) {
    foreach ($item in Get-ChildItem -LiteralPath $sourceRoot -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $pluginTarget -Recurse -Force
    }
}

$installedAgentHashes = [ordered]@{}
foreach ($agentSource in Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'codex-agents') -Filter '*.toml' -File) {
    $agentTarget = Join-Path $agentTargetDir $agentSource.Name
    if ((Test-Path -LiteralPath $agentTarget) -and -not $priorState) {
        $sourceHash = (Get-FileHash -LiteralPath $agentSource.FullName -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $agentTarget -Algorithm SHA256).Hash
        if ($sourceHash -ne $targetHash) {
            throw "Agent profile already exists and is not identical to this package: $agentTarget"
        }
    }
    Copy-Item -LiteralPath $agentSource.FullName -Destination $agentTarget -Force
    $installedAgentHashes[$agentSource.Name] = (Get-FileHash -LiteralPath $agentTarget -Algorithm SHA256).Hash
}

Write-Utf8NoBom -Path $configPath -Text (Set-SmrConfig -Text $configText)
$block = Read-Utf8Text -Path (Join-Path $sourceRoot 'global-agents-block.md')
Write-Utf8NoBom -Path $globalAgentsPath -Text (Add-GlobalBlockText -Text $agentsText -Block $block)

if ($marketplaceText.Trim()) {
    $marketplace = $marketplaceText | ConvertFrom-Json
} else {
    $marketplace = [pscustomobject]@{ name = 'personal'; interface = [pscustomobject]@{ displayName = 'Personal' }; plugins = @() }
}
$kept = @($marketplace.plugins | Where-Object { $_.name -ne 'smart-model-router' })
$entry = [pscustomobject]@{
    name = 'smart-model-router'
    source = [pscustomobject]@{ source = 'local'; path = './plugins/smart-model-router' }
    policy = [pscustomobject]@{ installation = 'AVAILABLE'; authentication = 'ON_INSTALL' }
    category = 'Productivity'
}
$marketplace.plugins = @($kept) + @($entry)
Write-Utf8NoBom -Path $MarketplacePath -Text (($marketplace | ConvertTo-Json -Depth 20) + "`r`n")

if (-not $SkipPluginCommand) {
    $codex = Get-CodexCommand
    & $codex plugin add 'smart-model-router@personal'
    if ($LASTEXITCODE -ne 0) { throw "Codex plugin installation failed with exit code $LASTEXITCODE" }
}

$state = [ordered]@{
    version = '0.1.0'
    installedAt = (Get-Date).ToUniversalTime().ToString('o')
    sourceRoot = $sourceRoot
    pluginTarget = $pluginTarget
    configPath = $configPath
    globalAgentsPath = $globalAgentsPath
    marketplacePath = $MarketplacePath
    latestBackups = [ordered]@{ config = $configBackup; agents = $agentsBackup; marketplace = $marketplaceBackup }
    originalConfig = $originalSnapshot
    originalAgentsExisted = $originalAgentsExisted
    agentHashes = $installedAgentHashes
    pluginCommandSkipped = [bool]$SkipPluginCommand
}
Write-Utf8NoBom -Path $statePath -Text (($state | ConvertTo-Json -Depth 20) + "`r`n")

[ordered]@{
    status = 'installed'
    plugin = $pluginTarget
    config = $configPath
    globalAgents = $globalAgentsPath
    state = $statePath
    backup = $configBackup
    restartRequired = $true
} | ConvertTo-Json -Depth 6
