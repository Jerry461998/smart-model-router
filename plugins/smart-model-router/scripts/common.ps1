$ErrorActionPreference = 'Stop'

$script:SmrRootBegin = '# SMART-MODEL-ROUTER:ROOT-BEGIN'
$script:SmrRootEnd = '# SMART-MODEL-ROUTER:ROOT-END'
$script:SmrAgentsBegin = '# SMART-MODEL-ROUTER:AGENTS-BEGIN'
$script:SmrAgentsEnd = '# SMART-MODEL-ROUTER:AGENTS-END'
$script:SmrGlobalBegin = '<!-- SMART-MODEL-ROUTER:BEGIN -->'
$script:SmrGlobalEnd = '<!-- SMART-MODEL-ROUTER:END -->'

function Write-Utf8NoBom {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Text)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Read-Utf8Text {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function New-LineList {
    param([string]$Text)
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split "`r?`n")) { [void]$list.Add($line) }
    Write-Output -NoEnumerate $list
}

function Find-SectionRange {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)][string]$Name
    )
    $start = -1
    $end = $Lines.Count
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\[([^\]]+)\]\s*$') {
            if ($start -ge 0) { $end = $i; break }
            if ($Matches[1] -eq $Name) { $start = $i }
        }
    }
    return [pscustomobject]@{ Start = $start; End = $end }
}

function Remove-MarkerBlock {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)][string]$Begin,
        [Parameter(Mandatory)][string]$End
    )
    while ($true) {
        $start = -1
        $finish = -1
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i].Trim() -eq $Begin) { $start = $i; break }
        }
        if ($start -lt 0) { break }
        for ($i = $start; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i].Trim() -eq $End) { $finish = $i; break }
        }
        if ($finish -lt 0) { throw "Managed block begins with '$Begin' but has no end marker." }
        $Lines.RemoveRange($start, $finish - $start + 1)
    }
}

function Get-SmrConfigSnapshot {
    param([string]$Text)
    $lines = New-LineList -Text $Text
    Remove-MarkerBlock -Lines $lines -Begin $script:SmrRootBegin -End $script:SmrRootEnd
    Remove-MarkerBlock -Lines $lines -Begin $script:SmrAgentsBegin -End $script:SmrAgentsEnd
    $firstSection = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[') { $firstSection = $i; break }
    }
    $modelLine = $null
    $effortLine = $null
    for ($i = 0; $i -lt $firstSection; $i++) {
        if ($lines[$i] -match '^\s*model\s*=') { $modelLine = $lines[$i] }
        if ($lines[$i] -match '^\s*model_reasoning_effort\s*=') { $effortLine = $lines[$i] }
    }
    $agentLines = [ordered]@{}
    $agentRange = Find-SectionRange -Lines $lines -Name 'agents'
    if ($agentRange.Start -ge 0) {
        foreach ($key in @('enabled','max_concurrent_threads_per_session','default_subagent_model','default_subagent_reasoning_effort','interrupt_message')) {
            for ($i = $agentRange.Start + 1; $i -lt $agentRange.End; $i++) {
                if ($lines[$i] -match ('^\s*' + [regex]::Escape($key) + '\s*=')) {
                    $agentLines[$key] = $lines[$i]
                    break
                }
            }
        }
    }
    return [ordered]@{
        modelLine = $modelLine
        effortLine = $effortLine
        agentsSectionExisted = ($agentRange.Start -ge 0)
        agentLines = $agentLines
    }
}

function Set-SmrConfig {
    param([string]$Text)
    $lines = New-LineList -Text $Text
    Remove-MarkerBlock -Lines $lines -Begin $script:SmrRootBegin -End $script:SmrRootEnd
    Remove-MarkerBlock -Lines $lines -Begin $script:SmrAgentsBegin -End $script:SmrAgentsEnd

    $firstSection = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[') { $firstSection = $i; break }
    }
    for ($i = $firstSection - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '^\s*(model|model_reasoning_effort)\s*=') { $lines.RemoveAt($i) }
    }
    $rootBlock = @(
        $script:SmrRootBegin,
        'model = "gpt-6-sol"',
        'model_reasoning_effort = "medium"',
        $script:SmrRootEnd,
        ''
    )
    for ($i = $rootBlock.Count - 1; $i -ge 0; $i--) { $lines.Insert(0, $rootBlock[$i]) }

    $agentRange = Find-SectionRange -Lines $lines -Name 'agents'
    $managedKeys = @('enabled','max_concurrent_threads_per_session','default_subagent_model','default_subagent_reasoning_effort','interrupt_message')
    if ($agentRange.Start -ge 0) {
        for ($i = $agentRange.End - 1; $i -gt $agentRange.Start; $i--) {
            foreach ($key in $managedKeys) {
                if ($lines[$i] -match ('^\s*' + [regex]::Escape($key) + '\s*=')) { $lines.RemoveAt($i); break }
            }
        }
        $block = @(
            $script:SmrAgentsBegin,
            'enabled = true',
            'max_concurrent_threads_per_session = 3',
            'default_subagent_model = "gpt-6-luna"',
            'default_subagent_reasoning_effort = "medium"',
            'interrupt_message = true',
            $script:SmrAgentsEnd
        )
        for ($i = $block.Count - 1; $i -ge 0; $i--) { $lines.Insert($agentRange.Start + 1, $block[$i]) }
    } else {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') { [void]$lines.Add('') }
        foreach ($line in @(
            $script:SmrAgentsBegin,
            '[agents]',
            'enabled = true',
            'max_concurrent_threads_per_session = 3',
            'default_subagent_model = "gpt-6-luna"',
            'default_subagent_reasoning_effort = "medium"',
            'interrupt_message = true',
            $script:SmrAgentsEnd,
            ''
        )) { [void]$lines.Add($line) }
    }
    return (($lines -join "`r`n").TrimEnd() + "`r`n")
}

function Restore-SmrConfig {
    param([string]$Text, [Parameter(Mandatory)]$Snapshot)
    $lines = New-LineList -Text $Text
    Remove-MarkerBlock -Lines $lines -Begin $script:SmrRootBegin -End $script:SmrRootEnd
    Remove-MarkerBlock -Lines $lines -Begin $script:SmrAgentsBegin -End $script:SmrAgentsEnd

    $firstSection = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[') { $firstSection = $i; break }
    }
    for ($i = $firstSection - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '^\s*(model|model_reasoning_effort)\s*=') { $lines.RemoveAt($i) }
    }
    $restoreTop = @()
    if ($Snapshot.modelLine) { $restoreTop += [string]$Snapshot.modelLine }
    if ($Snapshot.effortLine) { $restoreTop += [string]$Snapshot.effortLine }
    if ($restoreTop.Count -gt 0) { $restoreTop += '' }
    for ($i = $restoreTop.Count - 1; $i -ge 0; $i--) { $lines.Insert(0, $restoreTop[$i]) }

    $agentRange = Find-SectionRange -Lines $lines -Name 'agents'
    $restoreAgentLines = @()
    if ($Snapshot.agentLines) {
        foreach ($property in $Snapshot.agentLines.PSObject.Properties) { $restoreAgentLines += [string]$property.Value }
    }
    if ($restoreAgentLines.Count -gt 0) {
        if ($agentRange.Start -lt 0) {
            if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') { [void]$lines.Add('') }
            [void]$lines.Add('[agents]')
            $agentRange = Find-SectionRange -Lines $lines -Name 'agents'
        }
        for ($i = $restoreAgentLines.Count - 1; $i -ge 0; $i--) { $lines.Insert($agentRange.Start + 1, $restoreAgentLines[$i]) }
    } elseif (-not $Snapshot.agentsSectionExisted -and $agentRange.Start -ge 0) {
        $nonBlank = @($lines[($agentRange.Start + 1)..([Math]::Max($agentRange.Start + 1, $agentRange.End - 1))] | Where-Object { $_.Trim() })
        if ($nonBlank.Count -eq 0) { $lines.RemoveRange($agentRange.Start, $agentRange.End - $agentRange.Start) }
    }
    return (($lines -join "`r`n").TrimEnd() + "`r`n")
}

function Remove-GlobalBlockText {
    param([string]$Text)
    $lines = New-LineList -Text $Text
    Remove-MarkerBlock -Lines $lines -Begin $script:SmrGlobalBegin -End $script:SmrGlobalEnd
    return (($lines -join "`r`n").TrimEnd() + "`r`n")
}

function Add-GlobalBlockText {
    param([string]$Text, [string]$Block)
    $clean = (Remove-GlobalBlockText -Text $Text).TrimEnd()
    if ($clean) { return ($clean + "`r`n`r`n" + $Block.Trim() + "`r`n") }
    return ($Block.Trim() + "`r`n")
}

function Get-CodexCommand {
    $command = Get-Command codex -ErrorAction SilentlyContinue
    if (-not $command) { throw 'The Codex launcher is not available on PATH.' }
    return $command.Source
}
