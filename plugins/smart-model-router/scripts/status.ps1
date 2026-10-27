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
$rootConfig = ($config -split '(?m)^[ \t]*\[', 2)[0]
$agents = if (Test-Path -LiteralPath $agentsPath) { Read-Utf8Text -Path $agentsPath } else { '' }
$marketplacePresent = $false
if (Test-Path -LiteralPath $MarketplacePath) {
    $marketplace = Read-Utf8Text -Path $MarketplacePath | ConvertFrom-Json
    $marketplacePresent = @($marketplace.plugins | Where-Object { $_.name -eq 'smart-model-router' }).Count -eq 1
}
$profiles = @('smart_router_luna_explorer.toml','smart_router_luna_verifier.toml','smart_router_sol_builder.toml','smart_router_sol_diagnostician.toml','smart_router_sol_expert.toml','smart_router_astra_escalation.toml','smart_router_terra_builder.toml','smart_router_terra_visual_reviewer.toml')
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
    defaultRootSolMedium = ($rootConfig -match '(?m)^[ \t]*model[ \t]*=[ \t]*"gpt-6\.1-sol"[ \t]*(?:#[^\r\n]*)?\r?$') -and ($rootConfig -match '(?m)^[ \t]*model_reasoning_effort[ \t]*=[ \t]*"medium"[ \t]*(?:#[^\r\n]*)?\r?$')
    rootModel = if ($rootConfig -match '(?m)^\s*model\s*=\s*"([^"\r\n]+)"') { $Matches[1] } else { $null }
    rootEffort = if ($rootConfig -match '(?m)^\s*model_reasoning_effort\s*=\s*"([^"\r\n]+)"') { $Matches[1] } else { $null }
    defaultRootSol = $rootConfig -match '(?m)^\s*model\s*=\s*"gpt-6\.1-sol"'
    defaultSubagentLuna = $config.Contains('default_subagent_model = "gpt-6-luna"')
    legacyTerraProfilesPresent = @(Get-ChildItem -LiteralPath (Join-Path $CodexRoot 'agents') -Filter 'smart_router_terra_diagnostician.toml' -File -ErrorAction SilentlyContinue).Count -gt 0
    globalInstructionEnabled = $agents.Contains($script:SmrGlobalBegin)
    profiles = $profileStatus
    pluginListEvidence = $pluginLine
    newTaskRequiredAfterChange = $true
} | ConvertTo-Json -Depth 8
