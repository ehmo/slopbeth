#!/usr/bin/env pwsh
# slopbeth.ps1 - PowerShell (Node-free) port of bin/slopbeth.js.
# Commands: install / installnpx / install-plugin / plugin install / doctor /
# benchmark / smoke / help / --version.

. "$PSScriptRoot/../scripts/SlopBeth.Common.ps1"

$Root = Split-Path $PSScriptRoot -Parent
$Version = (Read-TextFile (Join-Path $Root 'package.json') | ConvertFrom-Json).version

$InstallEntries = @('SKILL.md', 'BENCHMARKS.md', 'CONTRIBUTING.md', 'SECURITY.md', 'SUPPORT.md',
    'agents', 'assets', 'references', 'scripts', 'benchmarks', 'docs')

function Show-Usage {
    [Console]::Out.WriteLine(@"
slopbeth $Version

Usage:
  slopbeth install [-All]            install into agent skill dirs (see below)
  slopbeth install <target-dir>      install directly into <target-dir>
  slopbeth installnpx [target-dir]   install into all supported agents (or a dir)
  slopbeth install-plugin [all|claude|codex]
  slopbeth plugin install [all|claude|codex]
  slopbeth doctor
  slopbeth benchmark
  slopbeth smoke

Default install (no arguments):
  Installs only into agent skill directories that already exist under your home
  (e.g. ~/.claude/skills/slopbeth). Agents you do not use are skipped.
  Add -All to install into every supported agent (Codex, Claude Code, Hermes,
  OpenClaw, OpenCode, Pi) whether or not their directories exist yet.

Custom install:
  slopbeth install /path/to/dir
  If <dir> already contains agent config dirs (.claude, .codex, .agents,
  .hermes, .openclaw, .config/opencode, .pi), Slopbeth installs into each of
  their skills/slopbeth subdirs. Otherwise <dir> is treated as the skill
  directory and files are copied directly into it.

Plugin install:
  Installs Slopbeth as a Claude Code skills-directory plugin and/or a
  Codex personal plugin with marketplace metadata.
"@)
}

function Get-SlopbethHome {
    if ($env:HOME) { return $env:HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    return $HOME
}

function Get-XdgConfigHome {
    if ($env:XDG_CONFIG_HOME) { return $env:XDG_CONFIG_HOME }
    return (Join-Path (Get-SlopbethHome) '.config')
}

function Get-AgentTargets {
    # Build the agent skill targets rooted at $BaseDir (with OpenCode under $XdgDir).
    # Each target carries a 'marker' path: the agent's root dir under the base.
    # Callers decide whether to filter by marker existence.
    param([string]$BaseDir, [string]$XdgDir)
    $targets = [System.Collections.Generic.List[object]]::new()
    $targets.Add(@{ agent = 'codex'; marker = (Join-Path $BaseDir '.agents'); target = (Join-Path $BaseDir '.agents' 'skills' 'slopbeth') })
    $targets.Add(@{ agent = 'codex-legacy'; marker = (Join-Path $BaseDir '.codex'); target = (Join-Path $BaseDir '.codex' 'skills' 'slopbeth') })
    $targets.Add(@{ agent = 'claude-code'; marker = (Join-Path $BaseDir '.claude'); target = (Join-Path $BaseDir '.claude' 'skills' 'slopbeth') })
    $targets.Add(@{ agent = 'hermes'; marker = (Join-Path $BaseDir '.hermes'); target = (Join-Path $BaseDir '.hermes' 'skills' 'slopbeth') })
    $targets.Add(@{ agent = 'openclaw'; marker = (Join-Path $BaseDir '.openclaw'); target = (Join-Path $BaseDir '.openclaw' 'skills' 'slopbeth') })
    $targets.Add(@{ agent = 'opencode'; marker = (Join-Path $XdgDir 'opencode'); target = (Join-Path $XdgDir 'opencode' 'skills' 'slopbeth') })
    $targets.Add(@{ agent = 'pi'; marker = (Join-Path $BaseDir '.pi'); target = (Join-Path $BaseDir '.pi' 'agent' 'skills' 'slopbeth') })

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $deduped = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $targets) {
        $resolved = [System.IO.Path]::GetFullPath($item.target)
        if ($seen.Add($resolved)) { $deduped.Add($item) }
    }
    return $deduped
}

function Copy-Entry {
    param([string]$Name, [string]$Target)
    $source = Join-Path $Root $Name
    $dest = Join-Path $Target $Name
    if (-not (Test-Path -LiteralPath $source)) { return }
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Copy-Item -LiteralPath $source -Destination $dest -Recurse -Force
}

function Install-One {
    param([string]$Target)
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    foreach ($entry in $InstallEntries) { Copy-Entry $entry $Target }
}

function Write-InstallSummary {
    param([object[]]$Targets, [string]$Lead)
    $suffix = if ($Targets.Count -eq 1) { '' } else { 's' }
    [Console]::Out.WriteLine("$Lead $($Targets.Count) target${suffix}:")
    foreach ($item in $Targets) { [Console]::Out.WriteLine("- $($item.agent): $($item.target)") }
}

function Install-Slopbeth {
    param([string]$Target, [switch]$All)
    if ($Target) {
        # If the target already contains agent config dirs, install into their
        # skills/slopbeth subdirs; otherwise treat the target as the skill dir.
        $agentTargets = Get-AgentTargets -BaseDir $Target -XdgDir (Join-Path $Target '.config')
        $present = @($agentTargets | Where-Object { Test-Path -LiteralPath $_.marker })
        if ($present.Count -gt 0) {
            foreach ($item in $present) { Install-One $item.target }
            Write-InstallSummary $present "Installed Slopbeth $Version into $Target across"
            return
        }
        Install-One $Target
        [Console]::Out.WriteLine("Installed Slopbeth $Version to $Target")
        return
    }
    $homeDir = Get-SlopbethHome
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($item in (Get-AgentTargets -BaseDir $homeDir -XdgDir (Get-XdgConfigHome))) { $list.Add($item) }
    if ($env:SLOPBETH_SKILLS_DIR) { $list.Add(@{ agent = 'custom'; marker = $env:SLOPBETH_SKILLS_DIR; target = (Join-Path $env:SLOPBETH_SKILLS_DIR 'slopbeth') }) }
    $targets = $list
    if (-not $All) {
        $targets = @($targets | Where-Object { $_.agent -eq 'custom' -or (Test-Path -LiteralPath $_.marker) })
        if ($targets.Count -eq 0) {
            [Console]::Out.WriteLine("No known agent directories found under $homeDir.")
            [Console]::Out.WriteLine("Use 'install -All' to install for every supported agent, or 'install <dir>' for a specific path.")
            return
        }
    }
    foreach ($item in $targets) { Install-One $item.target }
    Write-InstallSummary $targets "Installed Slopbeth $Version to"
}

function Get-PluginManifest {
    param([string]$Agent)
    $base = [ordered]@{
        name        = 'slopbeth'
        version     = $Version
        description = 'Remove AI-writing tells while preserving meaning, voice, and density.'
        author      = [ordered]@{ name = 'ehmo'; url = 'https://github.com/ehmo' }
        homepage    = 'https://github.com/ehmo/slopbeth#readme'
        repository  = 'https://github.com/ehmo/slopbeth'
        license     = 'MIT'
        keywords    = @('writing', 'skill', 'anti-slop', 'editing', 'rewriting')
        skills      = './skills/'
    }
    if ($Agent -eq 'claude') {
        $base['displayName'] = 'Slopbeth'
        return $base
    }
    $base['interface'] = [ordered]@{
        displayName      = 'Slopbeth'
        shortDescription = 'Remove AI-writing tells while preserving meaning and voice.'
        longDescription  = 'Slopbeth rewrites and reviews prose by preserving sourced facts, cutting unsupported claims, protecting voice, and avoiding detector-chasing tricks.'
        developerName    = 'ehmo'
        category         = 'Productivity'
        capabilities     = @('Read', 'Write')
        websiteURL       = 'https://github.com/ehmo/slopbeth'
        defaultPrompt    = @(
            'Use Slopbeth to rewrite this while preserving facts, dates, numbers, uncertainty, and my voice.',
            'Use Slopbeth to review this for unsupported claims, bland-clean sentences, and AI-writing tells.'
        )
        brandColor       = '#111827'
    }
    return $base
}

function Write-JsonFile {
    param([string]$File, $Value)
    New-Item -ItemType Directory -Force -Path (Split-Path $File -Parent) | Out-Null
    $tmp = "$File.tmp"
    Write-TextFile $tmp ((ConvertTo-StableJson $Value) + "`n")
    Move-Item -LiteralPath $tmp -Destination $File -Force
}

function Read-JsonFile {
    param([string]$File, $Fallback)
    if (-not (Test-Path -LiteralPath $File)) { return $Fallback }
    try { return (Read-TextFile $File | ConvertFrom-Json -AsHashtable -Depth 100) }
    catch { throw "${File}: invalid JSON: $($_.Exception.Message)" }
}

function Install-PluginSkill {
    param([string]$Target)
    if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
    $skillDir = Join-Path $Target 'skills' 'slopbeth'
    New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
    foreach ($entry in $InstallEntries) { Copy-Entry $entry $skillDir }
}

function Install-ClaudePlugin {
    $target = Join-Path (Get-SlopbethHome) '.claude' 'skills' 'slopbeth'
    Install-PluginSkill $target
    Write-JsonFile (Join-Path $target '.claude-plugin' 'plugin.json') (Get-PluginManifest 'claude')
    return $target
}

function Get-CodexMarketplaceEntry {
    return [ordered]@{
        name      = 'slopbeth'
        source    = [ordered]@{ source = 'local'; path = './.codex/plugins/slopbeth' }
        policy    = [ordered]@{ installation = 'INSTALLED_BY_DEFAULT'; authentication = 'ON_INSTALL' }
        category  = 'Productivity'
        interface = [ordered]@{ displayName = 'Slopbeth'; shortDescription = 'Remove AI-writing tells while preserving meaning and voice.' }
    }
}

function Update-CodexMarketplace {
    $marketplaceFile = Join-Path (Get-SlopbethHome) '.agents' 'plugins' 'marketplace.json'
    $marketplace = Read-JsonFile $marketplaceFile ([ordered]@{
            name      = 'personal-plugins'
            interface = [ordered]@{ displayName = 'Personal Plugins' }
            plugins   = @()
        })
    $existing = Get-DictValue $marketplace 'plugins' @()
    if ($existing -isnot [System.Collections.IEnumerable] -or $existing -is [string]) { $existing = @() }
    $kept = @($existing | Where-Object { $_ -and (Get-DictValue $_ 'name') -ne 'slopbeth' })
    $kept += , (Get-CodexMarketplaceEntry)
    $marketplace['plugins'] = $kept
    Write-JsonFile $marketplaceFile $marketplace
    return $marketplaceFile
}

function Install-CodexPlugin {
    $target = Join-Path (Get-SlopbethHome) '.codex' 'plugins' 'slopbeth'
    Install-PluginSkill $target
    Write-JsonFile (Join-Path $target '.codex-plugin' 'plugin.json') (Get-PluginManifest 'codex')
    $marketplaceFile = Update-CodexMarketplace
    foreach ($stale in @((Join-Path (Get-SlopbethHome) '.agents' 'skills' 'slopbeth'), (Join-Path (Get-SlopbethHome) '.codex' 'skills' 'slopbeth'))) {
        if (Test-Path -LiteralPath $stale) { Remove-Item -LiteralPath $stale -Recurse -Force }
    }
    return @{ target = $target; marketplaceFile = $marketplaceFile }
}

function Install-Plugins {
    param([string]$Which = 'all')
    $normalized = ($Which ? $Which : 'all').ToLowerInvariant()
    if ($normalized -notin @('all', 'claude', 'codex')) {
        [Console]::Error.WriteLine("Unknown plugin target: $Which"); Show-Usage; exit 1
    }
    $installed = [System.Collections.Generic.List[object]]::new()
    if ($normalized -eq 'all' -or $normalized -eq 'claude') { $installed.Add(@{ agent = 'claude-code'; target = (Install-ClaudePlugin) }) }
    if ($normalized -eq 'all' -or $normalized -eq 'codex') {
        $result = Install-CodexPlugin
        $installed.Add(@{ agent = 'codex'; target = $result.target })
        $installed.Add(@{ agent = 'codex-marketplace'; target = $result.marketplaceFile })
    }
    [Console]::Out.WriteLine("Installed Slopbeth $Version plugin support:")
    foreach ($item in $installed) { [Console]::Out.WriteLine("- $($item.agent): $($item.target)") }
}

function Invoke-Doctor {
    $required = @(
        'BENCHMARKS.md', 'CODE_OF_CONDUCT.md', 'CONTRIBUTING.md', 'LICENSE', 'README.md', 'SECURITY.md', 'SKILL.md', 'SUPPORT.md',
        '.agents/plugins/marketplace.json', '.claude-plugin/marketplace.json', 'assets/slopbeth.png',
        'agents/claude-code.yaml', 'agents/codex.yaml', 'agents/hermes.yaml', 'agents/openclaw.yaml', 'agents/openai.yaml', 'agents/opencode.yaml', 'agents/pi.yaml',
        'references/evaluation.md', 'references/slop-taxonomy.md', 'references/density-and-unsummarizability.md', 'references/voice-and-preservation.md', 'references/writing-system.md',
        'benchmarks/benchmark-v2.jsonl', 'benchmarks/independent-judge-rows-v2.jsonl', 'benchmarks/span-annotations-v1.jsonl',
        'benchmarks/false-positive-tracker-v1.jsonl', 'benchmarks/competitor-output-runs-v1.jsonl', 'benchmarks/competitor-agent-runs-v1.jsonl',
        'benchmarks/orwell-writing-system-v1.jsonl',
        'benchmarks/score-snapshot.md', 'benchmarks/competitor-matrix-v2.md', 'benchmarks/public-detector-panel-v1.md',
        'docs/branch-protection.md', 'docs/false-positive-tracker.md', 'docs/literature-basis.md',
        'plugins/slopbeth/.claude-plugin/plugin.json', 'plugins/slopbeth/.codex-plugin/plugin.json', 'plugins/slopbeth/skills/slopbeth/SKILL.md',
        'scripts/Test-Attribution.ps1', 'scripts/Test-Secret.ps1', 'scripts/New-ScoreSnapshot.ps1', 'scripts/SlopBeth.Common.ps1',
        'scripts/Measure-Orwell.ps1', 'scripts/Measure-OrwellBenchmark.ps1'
    )
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Root $_)) })
    if ($missing.Count) {
        [Console]::Error.WriteLine("Missing files:`n$(($missing | ForEach-Object { "- $_" }) -join "`n")")
        exit 1
    }
    [Console]::Out.WriteLine("Slopbeth $Version package files are present.")
}

function Invoke-Check {
    param([string]$Script, [string[]]$CheckArgs)
    $full = Join-Path $Root 'scripts' $Script
    $output = & pwsh -NoProfile -File $full @CheckArgs 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        foreach ($line in $output) { [Console]::Error.WriteLine([string]$line) }
        exit $code
    }
}

function Invoke-Benchmark {
    $bm = Join-Path $Root 'benchmarks'
    $v2Pack = Join-Path $bm 'benchmark-v2.jsonl'
    $v2Judges = Join-Path $bm 'independent-judge-rows-v2.jsonl'

    $v2Rows = ConvertFrom-Jsonl $v2Pack
    $v2JudgeRows = ConvertFrom-Jsonl $v2Judges
    if ($v2Rows.Count -lt 80 -or $v2Rows.Count -gt 100) {
        [Console]::Error.WriteLine("Benchmark v2 must contain 80-100 cases; found $($v2Rows.Count)."); exit 1
    }
    $caseIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($row in $v2Rows) { [void]$caseIds.Add([string]$row['id']) }
    $judgesByCase = @{}
    $scoreShapes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($row in $v2JudgeRows) {
        $caseId = [string](Get-DictValue $row 'case_id')
        if (-not $caseIds.Contains($caseId)) { [Console]::Error.WriteLine("Judge row references unknown case: $caseId"); exit 1 }
        if ($judgesByCase.ContainsKey($caseId)) { $judgesByCase[$caseId]++ } else { $judgesByCase[$caseId] = 1 }
        [void]$scoreShapes.Add((@(
                    Get-DictValue $row 'meaning_preservation_score'
                    Get-DictValue $row 'voice_score'
                    Get-DictValue $row 'density_score'
                    Get-DictValue $row 'slop_removal_score'
                ) -join '/'))
    }
    $underJudged = @(@($caseIds) | Where-Object { (Get-DictValue $judgesByCase $_ 0) -lt 3 })
    if ($underJudged.Count) { [Console]::Error.WriteLine("Benchmark v2 cases with fewer than three judge rows: $($underJudged -join ', ')"); exit 1 }
    if ($scoreShapes.Count -lt 3) { [Console]::Error.WriteLine('Benchmark v2 judge rows are too uniform to be useful.'); exit 1 }

    $corpus = $v2Pack
    Invoke-Check 'Run-Benchmark.ps1' @('--corpus', $corpus, '--summary-only', '--fail-release-gate')
    Invoke-Check 'Measure-SemanticDrift.ps1' @('--corpus', $corpus, '--quiet', '--fail-gate')
    Invoke-Check 'Measure-Signature.ps1' @('--corpus', $corpus, '--fail-gate', '--format', 'json')
    Invoke-Check 'Measure-Cadence.ps1' @('--corpus', $corpus, '--fail-gate', '--format', 'json')
    Invoke-Check 'Measure-Unsummarizability.ps1' @('--corpus', $corpus, '--fail-gate', '--require-summary-loss', '--format', 'json')
    Invoke-Check 'Test-SpanAnnotation.ps1' @('--corpus', $corpus, '--annotations', (Join-Path $bm 'span-annotations-v1.jsonl'), '--fail-gate', '--format', 'json')
    Invoke-Check 'Test-FalsePositive.ps1' @('--tracker', (Join-Path $bm 'false-positive-tracker-v1.jsonl'), '--fail-gate', '--format', 'json')
    Invoke-Check 'Measure-CompetitorOutput.ps1' @('--corpus', $corpus, '--panel', (Join-Path $bm 'competitor-output-runs-v1.jsonl'), '--fail-gate', '--format', 'json')
    Invoke-Check 'Measure-CompetitorOutput.ps1' @('--corpus', $corpus, '--panel', (Join-Path $bm 'competitor-agent-runs-v1.jsonl'), '--min-competitors', '5', '--min-cases', '25', '--min-slopbeth-case-win-rate', '0.7', '--fail-gate', '--format', 'json')

    $orwellPack = Join-Path $bm 'orwell-writing-system-v1.jsonl'
    $orwellRows = ConvertFrom-Jsonl $orwellPack
    Invoke-Check 'Measure-OrwellBenchmark.ps1' @('--corpus', $orwellPack, '--fail-gate', '--format', 'json')

    [Console]::Out.WriteLine("Benchmark pack ready: $($v2Rows.Count) v2 output-bearing cases, $($v2JudgeRows.Count) v2 judge rows, plus span, false-positive, cadence, competitor-output, competitor-agent, and Orwell writing-system ($($orwellRows.Count) before/after rows) gates.")
}

function Invoke-Smoke {
    Invoke-Check 'Test-Install.ps1' @()
    [Console]::Out.WriteLine("Slopbeth $Version install smoke passed.")
}

$command = if ($args.Count -gt 0) { [string]$args[0] } else { $null }
$maybeTarget = if ($args.Count -gt 1) { [string]$args[1] } else { $null }
$extraTarget = if ($args.Count -gt 2) { [string]$args[2] } else { $null }

if (-not $command -or $command -in @('help', '--help', '-h')) { Show-Usage }
elseif ($command -in @('install', 'installnpx')) {
    $all = ($command -eq 'installnpx')
    $target = $null
    foreach ($a in @($maybeTarget, $extraTarget)) {
        if (-not $a) { continue }
        if ($a -in @('-All', '--all', '-all', '--All', '-a')) { $all = $true } else { $target = $a }
    }
    Install-Slopbeth -Target $target -All:$all
}
elseif ($command -in @('install-plugin', 'plugin-install', 'install-plugins')) { Install-Plugins $maybeTarget }
elseif ($command -eq 'plugin' -and $maybeTarget -eq 'install') { Install-Plugins $extraTarget }
elseif ($command -eq 'doctor') { Invoke-Doctor }
elseif ($command -eq 'benchmark') { Invoke-Benchmark }
elseif ($command -eq 'smoke') { Invoke-Smoke }
elseif ($command -in @('--version', '-v')) { [Console]::Out.WriteLine($Version) }
else { [Console]::Error.WriteLine("Unknown command: $command"); Show-Usage; exit 1 }
