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
    Assert-True ($config.Contains('model = "gpt-6.1-sol"')) 'GPT-6.1 Sol root missing'
    Assert-True ($config.Contains('default_subagent_model = "gpt-6-luna"')) 'GPT-6 Luna subagent default missing'
    Assert-True ($config.Contains('max_concurrent_threads_per_session = 3')) 'managed concurrency missing'
    Assert-True ($config.Contains('[unrelated]')) 'unrelated config section lost'
    Assert-True ($config.Contains($expectedProjectLine)) 'UTF-8 project path was corrupted'
    $marketplace = [System.IO.File]::ReadAllText($marketplacePath, $utf8) | ConvertFrom-Json
    Assert-True (@($marketplace.plugins | Where-Object name -eq 'existing-plugin').Count -eq 1) 'existing marketplace entry lost'
    Assert-True (@($marketplace.plugins | Where-Object name -eq 'smart-model-router').Count -eq 1) 'router marketplace entry missing'

    $status = & (Join-Path $packageRoot 'scripts\status.ps1') -CodexRoot $codexRoot -PluginHome $pluginHome -MarketplacePath $marketplacePath -SkipPluginCommand | ConvertFrom-Json
    Assert-True $status.defaultRootSolMedium 'installed root status incorrect'
    $highRootConfig = $config.Replace('model_reasoning_effort = "medium"', 'model_reasoning_effort = "high"')
    [System.IO.File]::WriteAllText((Join-Path $codexRoot 'config.toml'), $highRootConfig, $utf8)
    $status = & (Join-Path $packageRoot 'scripts\status.ps1') -CodexRoot $codexRoot -PluginHome $pluginHome -MarketplacePath $marketplacePath -SkipPluginCommand | ConvertFrom-Json
    Assert-True (-not $status.defaultRootSolMedium) 'subagent medium effort incorrectly satisfied root status'

    # Simulate an owned prior release: upgrade old Sol profile contents using its recorded hashes.
    $statePath = Join-Path $codexRoot 'smart-model-router\install-state.json'
    $priorState = [System.IO.File]::ReadAllText($statePath, $utf8) | ConvertFrom-Json
    $priorState.version = '0.1.0+codex.20260923020300'
    foreach ($profile in @('builder', 'diagnostician', 'expert')) {
        $profileName = "smart_router_sol_$profile.toml"
        $profilePath = Join-Path $codexRoot "agents\$profileName"
        $oldText = [System.IO.File]::ReadAllText($profilePath, $utf8).Replace('gpt-6.1-sol', 'gpt-6-sol')
        [System.IO.File]::WriteAllText($profilePath, $oldText, $utf8)
        $priorState.agentHashes.PSObject.Properties[$profileName].Value = (Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash
    }
    [System.IO.File]::WriteAllText($statePath, ($priorState | ConvertTo-Json -Depth 20), $utf8)
    & (Join-Path $packageRoot 'scripts\install.ps1') -CodexRoot $codexRoot -PluginHome $pluginHome -MarketplacePath $marketplacePath -SkipPluginCommand | Out-Null
    $marketplace = [System.IO.File]::ReadAllText($marketplacePath, $utf8) | ConvertFrom-Json
    Assert-True (@($marketplace.plugins | Where-Object name -eq 'smart-model-router').Count -eq 1) 'idempotent install duplicated marketplace entry'
    $upgradedState = [System.IO.File]::ReadAllText($statePath, $utf8) | ConvertFrom-Json
    Assert-True ($upgradedState.version -eq '0.2.0') 'upgrade version not recorded'
    Assert-True ($upgradedState.originalConfig.modelLine -eq $priorState.originalConfig.modelLine) 'upgrade lost original root snapshot'
    foreach ($profile in @('builder', 'diagnostician', 'expert')) {
        $profileText = [System.IO.File]::ReadAllText((Join-Path $codexRoot "agents\smart_router_sol_$profile.toml"), $utf8)
        Assert-True ($profileText.Contains('model = "gpt-6.1-sol"')) 'owned old Sol profile did not upgrade'
    }
    $status = & (Join-Path $packageRoot 'scripts\status.ps1') -CodexRoot $codexRoot -PluginHome $pluginHome -MarketplacePath $marketplacePath -SkipPluginCommand | ConvertFrom-Json
    Assert-True $status.defaultRootSolMedium 'upgraded root status incorrect'
    Write-Output 'UPGRADE_OWNED_PROFILES_OK'


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


    # Empty and absent configuration both exercise backup writes of empty strings.
    foreach ($scenario in @('empty', 'new')) {
        $scenarioRoot = Join-Path $tempRoot $scenario
        $scenarioCodex = Join-Path $scenarioRoot '.codex'
        $scenarioPlugin = Join-Path $scenarioRoot 'plugins'
        $scenarioMarketplace = Join-Path $scenarioRoot 'marketplace.json'
        if ($scenario -eq 'empty') {
            New-Item -ItemType Directory -Path $scenarioCodex -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $scenarioCodex 'config.toml'), '', $utf8)
            [System.IO.File]::WriteAllText((Join-Path $scenarioCodex 'AGENTS.md'), '', $utf8)
            [System.IO.File]::WriteAllText($scenarioMarketplace, '', $utf8)
        }
        foreach ($attempt in 1..2) {
            & (Join-Path $packageRoot 'scripts\install.ps1') -CodexRoot $scenarioCodex -PluginHome $scenarioPlugin -MarketplacePath $scenarioMarketplace -SkipPluginCommand | Out-Null
        }
        $scenarioConfig = [System.IO.File]::ReadAllText((Join-Path $scenarioCodex 'config.toml'), $utf8)
        Assert-True ($scenarioConfig.Contains('model = "gpt-6.1-sol"')) "$scenario root missing"
        $scenarioState = [System.IO.File]::ReadAllText((Join-Path $scenarioCodex 'smart-model-router\install-state.json'), $utf8) | ConvertFrom-Json
        Assert-True ($scenarioState.version -eq '0.2.0') "$scenario installed version incorrect"
        foreach ($profile in @('builder', 'diagnostician', 'expert')) {
            $profileText = [System.IO.File]::ReadAllText((Join-Path $scenarioCodex "agents\smart_router_sol_$profile.toml"), $utf8)
            Assert-True ($profileText.Contains('model = "gpt-6.1-sol"')) "$scenario Sol profile wrong"
        }
        # User changes to owned profiles must block overwrite and survive uninstall.
        $modifiedProfile = Join-Path $scenarioCodex 'agents\smart_router_sol_builder.toml'
        [System.IO.File]::AppendAllText($modifiedProfile, "`n# user customization`n", $utf8)
        $reinstallRejected = $false
        try {
            & (Join-Path $packageRoot 'scripts\install.ps1') -CodexRoot $scenarioCodex -PluginHome $scenarioPlugin -MarketplacePath $scenarioMarketplace -SkipPluginCommand | Out-Null
        } catch {
            Assert-True ($_.Exception.Message.Contains('Agent profile already exists')) 'unexpected reinstall failure'
            $reinstallRejected = $true
        }
        Assert-True $reinstallRejected 'modified owned profile was overwritten'
        & (Join-Path $packageRoot 'scripts\uninstall.ps1') -CodexRoot $scenarioCodex -PluginHome $scenarioPlugin -MarketplacePath $scenarioMarketplace -SkipPluginCommand | Out-Null
        Assert-True ([System.IO.File]::ReadAllText($modifiedProfile, $utf8).Contains('# user customization')) 'modified profile lost on uninstall'
        $restoredScenarioConfig = [System.IO.File]::ReadAllText((Join-Path $scenarioCodex 'config.toml'), $utf8)
        Assert-True (-not $restoredScenarioConfig.Trim()) "$scenario original blank config not restored"
        $scenarioAgentsPath = Join-Path $scenarioCodex 'AGENTS.md'
        if ($scenario -eq 'empty') {
            Assert-True (Test-Path -LiteralPath $scenarioAgentsPath) 'existing empty AGENTS.md removed'
            Assert-True (-not [System.IO.File]::ReadAllText($scenarioAgentsPath, $utf8).Trim()) 'existing empty AGENTS.md not restored'
        } else {
            Assert-True (-not (Test-Path -LiteralPath $scenarioAgentsPath)) 'new AGENTS.md left after uninstall'
        }
        Write-Output ("INSTALL_SCENARIO_OK: " + $scenario)
    }

    # Run copied entry wrappers against stub child scripts, never the user's installation.
    $repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
    $wrapperRoot = Join-Path $tempRoot 'wrappers'
    $stubScripts = Join-Path $wrapperRoot 'plugins\smart-model-router\scripts'
    New-Item -ItemType Directory -Path $stubScripts -Force | Out-Null
    $originalUserProfile = $env:USERPROFILE
    try {
        $env:USERPROFILE = $wrapperRoot
        foreach ($entry in @('INSTALL', 'STATUS', 'UNINSTALL')) {
            $wrapperPath = Join-Path $wrapperRoot "$entry.ps1"
            Copy-Item -LiteralPath (Join-Path $repoRoot "$entry.ps1") -Destination $wrapperPath
            $childName = @{ INSTALL = 'install'; STATUS = 'status'; UNINSTALL = 'uninstall' }[$entry]
            foreach ($expectedExit in @(0, 37)) {
                [System.IO.File]::WriteAllText((Join-Path $stubScripts "$childName.ps1"), "exit $expectedExit", $utf8)
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrapperPath | Out-Null
                $actualExit = $LASTEXITCODE
                Assert-True ($actualExit -eq $expectedExit) "$entry masked child exit $expectedExit with $actualExit"
            }
            Write-Output ("WRAPPER_EXIT_OK: " + $entry)
        }
    } finally {
        $env:USERPROFILE = $originalUserProfile
    }
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
