$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$packageRoot = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path $env:TEMP ('smart-model-router-test-' + [guid]::NewGuid().ToString('N'))
$codexRoot = Join-Path $tempRoot '.codex'
$pluginHome = Join-Path $tempRoot 'plugins'
$marketplacePath = Join-Path $tempRoot '.agents\plugins\marketplace.json'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureConfigText = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures\config.toml'), $utf8)
$fixtureAgentsText = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures\AGENTS.md'), $utf8)
$expectedProjectLine = @($fixtureConfigText -split "`r?`n" | Where-Object { $_ -match '^\[projects\.' })[0]
$expectedAgentLine = @($fixtureAgentsText -split "`r?`n" | Where-Object { $_ -and $_ -notmatch '^(#|Preserve)' })[0]

try {
    New-Item -ItemType Directory -Path $codexRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $marketplacePath) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures\config.toml') -Destination (Join-Path $codexRoot 'config.toml')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures\AGENTS.md') -Destination (Join-Path $codexRoot 'AGENTS.md')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures\marketplace.json') -Destination $marketplacePath

    & (Join-Path $packageRoot 'scripts\install.ps1') -CodexRoot $codexRoot -PluginHome $pluginHome -MarketplacePath $marketplacePath -SkipPluginCommand | Out-Null
    $config = [System.IO.File]::ReadAllText((Join-Path $codexRoot 'config.toml'), $utf8)
    Assert-True ($config.Contains('# SMART-MODEL-ROUTER:ROOT-BEGIN')) 'managed root block missing'
    Assert-True ($config.Contains('model = "gpt-5.6-terra"')) 'Terra root missing'
    Assert-True ($config.Contains('max_concurrent_threads_per_session = 3')) 'managed concurrency missing'
    Assert-True ($config.Contains('[unrelated]')) 'unrelated config section lost'
    Assert-True ($config.Contains($expectedProjectLine)) 'UTF-8 project path was corrupted'
    $marketplace = [System.IO.File]::ReadAllText($marketplacePath, $utf8) | ConvertFrom-Json
    Assert-True (@($marketplace.plugins | Where-Object name -eq 'existing-plugin').Count -eq 1) 'existing marketplace entry lost'
    Assert-True (@($marketplace.plugins | Where-Object name -eq 'smart-model-router').Count -eq 1) 'router marketplace entry missing'

    & (Join-Path $packageRoot 'scripts\install.ps1') -CodexRoot $codexRoot -PluginHome $pluginHome -MarketplacePath $marketplacePath -SkipPluginCommand | Out-Null
    $marketplace = [System.IO.File]::ReadAllText($marketplacePath, $utf8) | ConvertFrom-Json
    Assert-True (@($marketplace.plugins | Where-Object name -eq 'smart-model-router').Count -eq 1) 'idempotent install duplicated marketplace entry'

    & (Join-Path $packageRoot 'scripts\disable.ps1') -CodexRoot $codexRoot -SkipPluginCommand | Out-Null
    $agents = [System.IO.File]::ReadAllText((Join-Path $codexRoot 'AGENTS.md'), $utf8)
    Assert-True (-not $agents.Contains('SMART-MODEL-ROUTER:BEGIN')) 'disable left global block active'
    & (Join-Path $packageRoot 'scripts\enable.ps1') -CodexRoot $codexRoot -PluginHome $pluginHome -SkipPluginCommand | Out-Null
    $agents = [System.IO.File]::ReadAllText((Join-Path $codexRoot 'AGENTS.md'), $utf8)
    Assert-True ($agents.Contains('SMART-MODEL-ROUTER:BEGIN')) 'enable did not restore global block'

    & (Join-Path $packageRoot 'scripts\uninstall.ps1') -CodexRoot $codexRoot -PluginHome $pluginHome -MarketplacePath $marketplacePath -SkipPluginCommand | Out-Null
    $restoredConfig = [System.IO.File]::ReadAllText((Join-Path $codexRoot 'config.toml'), $utf8)
    Assert-True ($restoredConfig.Contains('model = "gpt-5.6-sol"')) 'original root model not restored'
    Assert-True ($restoredConfig.Contains('model_reasoning_effort = "high"')) 'original root effort not restored'
    Assert-True ($restoredConfig.Contains('max_concurrent_threads_per_session = 7')) 'original agent setting not restored'
    Assert-True ($restoredConfig.Contains('[unrelated]')) 'unrelated config section lost on uninstall'
    Assert-True ($restoredConfig.Contains($expectedProjectLine)) 'UTF-8 project path was corrupted on uninstall'
    $restoredAgents = [System.IO.File]::ReadAllText((Join-Path $codexRoot 'AGENTS.md'), $utf8)
    Assert-True ($restoredAgents.Contains('Preserve this text.')) 'existing global instructions lost'
    Assert-True ($restoredAgents.Contains($expectedAgentLine)) 'UTF-8 global instruction text was corrupted'
    Assert-True (-not $restoredAgents.Contains('SMART-MODEL-ROUTER:BEGIN')) 'managed global block left after uninstall'
    $restoredMarketplace = [System.IO.File]::ReadAllText($marketplacePath, $utf8) | ConvertFrom-Json
    Assert-True (@($restoredMarketplace.plugins | Where-Object name -eq 'existing-plugin').Count -eq 1) 'existing marketplace entry lost on uninstall'
    Assert-True (@($restoredMarketplace.plugins | Where-Object name -eq 'smart-model-router').Count -eq 0) 'router marketplace entry left on uninstall'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $pluginHome 'smart-model-router'))) 'plugin source left after uninstall'

    Write-Output 'INSTALLATION_TESTS_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolved = (Resolve-Path -LiteralPath $tempRoot).Path
        $tempPrefix = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Unexpected test cleanup target: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
