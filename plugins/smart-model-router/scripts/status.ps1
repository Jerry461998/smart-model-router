param(
    [string]$CodexRoot = (Join-Path $env:USERPROFILE '.codex'),
    [string]$PluginHome = (Join-Path $env:USERPROFILE 'plugins'),
    [string]$MarketplacePath = (Join-Path $env:USERPROFILE '.agents\plugins\marketplace.json'),
    [switch]$SkipPluginCommand
)

. (Join-Path $PSScriptRoot 'common.ps1')

$pluginTarget = Join-Path $PluginHome 'smart-model-router'
$configPath = Join-Path $CodexRoot 'config.toml'
$agentsPath = Join-Path $CodexRoot 'AGENTS.md'
$config = if (Test-Path -LiteralPath $configPath) { Read-Utf8Text -Path $configPath } else { '' }
$agents = if (Test-Path -LiteralPath $agentsPath) { Read-Utf8Text -Path $agentsPath } else { '' }
$marketplacePresent = $false
if (Test-Path -LiteralPath $MarketplacePath) {
    $marketplace = Read-Utf8Text -Path $MarketplacePath | ConvertFrom-Json
    $marketplacePresent = @($marketplace.plugins | Where-Object { $_.name -eq 'smart-model-router' }).Count -eq 1
}
$profiles = @('smart_router_luna_explorer.toml','smart_router_luna_verifier.toml','smart_router_terra_builder.toml','smart_router_terra_diagnostician.toml','smart_router_sol_expert.toml','smart_router_astra_escalation.toml')
$profileStatus = [ordered]@{}
foreach ($profile in $profiles) { $profileStatus[$profile] = Test-Path -LiteralPath (Join-Path $CodexRoot "agents\$profile") }
$pluginLine = ''
if (-not $SkipPluginCommand) {
    $codex = Get-CodexCommand
    $pluginLine = ((& $codex plugin list 2>&1 | Select-String -SimpleMatch 'smart-model-router@personal') | Out-String).Trim()
}
[ordered]@{
    pluginSourcePresent = Test-Path -LiteralPath $pluginTarget
    marketplaceEntryPresent = $marketplacePresent
    configManaged = $config.Contains($script:SmrRootBegin) -and $config.Contains($script:SmrAgentsBegin)
    defaultRootTerraMedium = $config.Contains('model = "gpt-5.6-terra"') -and $config.Contains('model_reasoning_effort = "medium"')
    globalInstructionEnabled = $agents.Contains($script:SmrGlobalBegin)
    profiles = $profileStatus
    pluginListEvidence = $pluginLine
    newTaskRequiredAfterChange = $true
} | ConvertTo-Json -Depth 8
