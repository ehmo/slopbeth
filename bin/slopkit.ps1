#!/usr/bin/env pwsh
# slopkit.ps1 - PowerShell (Node-free) port of bin/slopkit.js.
# Ships two skills (slopbeth, slopgent) that install by the same means.
# Commands: install / installnpx / install-plugin / plugin install / doctor /
# benchmark / smoke / help / --version.

. "$PSScriptRoot/../skills/slopbeth/scripts/SlopBeth.Common.ps1"

$Root = Split-Path $PSScriptRoot -Parent
$Version = (Read-TextFile (Join-Path $Root 'package.json') | ConvertFrom-Json).version

# --- Skill registry -------------------------------------------------------
# Each skill ships from skills/<name>/ and mirrors into plugins/<name>/. Both
# install as sibling subdirs of a skills parent. Copy-Entry no-ops on any
# installEntry a given skill does not carry, so the copy loop is shared.
$Skills = @(
    [ordered]@{
        name             = 'slopbeth'
        displayName      = 'Slopbeth'
        description      = 'Remove AI-writing tells while preserving meaning, voice, and density.'
        keywords         = @('writing', 'skill', 'anti-slop', 'editing', 'rewriting')
        installEntries   = @('SKILL.md', 'README.md', 'BENCHMARKS.md', 'CONTRIBUTING.md', 'SECURITY.md', 'SUPPORT.md',
            'agents', 'assets', 'references', 'scripts', 'benchmarks', 'docs')
        marketplaceShort = 'Remove AI-writing tells while preserving meaning and voice.'
        codexInterface   = [ordered]@{
            shortDescription = 'Remove AI-writing tells while preserving meaning and voice.'
            longDescription  = 'Slopbeth rewrites and reviews prose by preserving sourced facts, cutting unsupported claims, protecting voice, and avoiding detector-chasing tricks.'
            developerName    = 'ehmo'
            category         = 'Productivity'
            capabilities     = @('Read', 'Write')
            websiteURL       = 'https://github.com/ehmo/slopkit'
            defaultPrompt    = @(
                'Use Slopbeth to rewrite this while preserving facts, dates, numbers, uncertainty, and my voice.',
                'Use Slopbeth to review this for unsupported claims, bland-clean sentences, and AI-writing tells.'
            )
            brandColor       = '#111827'
        }
        doctorFiles      = @(
            'skills/slopbeth/README.md', 'skills/slopbeth/BENCHMARKS.md', 'skills/slopbeth/CONTRIBUTING.md', 'skills/slopbeth/SECURITY.md', 'skills/slopbeth/SKILL.md', 'skills/slopbeth/SUPPORT.md',
            'skills/slopbeth/assets/slopbeth.png',
            'skills/slopbeth/agents/claude-code.yaml', 'skills/slopbeth/agents/codex.yaml', 'skills/slopbeth/agents/hermes.yaml', 'skills/slopbeth/agents/openclaw.yaml', 'skills/slopbeth/agents/openai.yaml', 'skills/slopbeth/agents/opencode.yaml', 'skills/slopbeth/agents/pi.yaml',
            'skills/slopbeth/references/evaluation.md', 'skills/slopbeth/references/slop-taxonomy.md', 'skills/slopbeth/references/density-and-unsummarizability.md', 'skills/slopbeth/references/voice-and-preservation.md', 'skills/slopbeth/references/writing-system.md',
            'skills/slopbeth/benchmarks/benchmark-v2.jsonl', 'skills/slopbeth/benchmarks/independent-judge-rows-v2.jsonl', 'skills/slopbeth/benchmarks/span-annotations-v1.jsonl',
            'skills/slopbeth/benchmarks/false-positive-tracker-v1.jsonl', 'skills/slopbeth/benchmarks/competitor-output-runs-v1.jsonl', 'skills/slopbeth/benchmarks/competitor-agent-runs-v1.jsonl',
            'skills/slopbeth/benchmarks/orwell-writing-system-v1.jsonl',
            'skills/slopbeth/benchmarks/score-snapshot.md', 'skills/slopbeth/benchmarks/competitor-matrix-v2.md', 'skills/slopbeth/benchmarks/public-detector-panel-v1.md',
            'skills/slopbeth/docs/branch-protection.md', 'skills/slopbeth/docs/false-positive-tracker.md', 'skills/slopbeth/docs/literature-basis.md',
            'skills/slopbeth/scripts/Test-Attribution.ps1', 'skills/slopbeth/scripts/Test-Secret.ps1', 'skills/slopbeth/scripts/New-ScoreSnapshot.ps1', 'skills/slopbeth/scripts/SlopBeth.Common.ps1',
            'skills/slopbeth/scripts/Measure-Orwell.ps1', 'skills/slopbeth/scripts/Measure-OrwellBenchmark.ps1'
        )
    },
    [ordered]@{
        name             = 'slopgent'
        displayName      = 'Slopgent'
        description      = "Shape the agent's own replies so they are honest about what ran, action-first, and plain — without dropping load-bearing precision."
        keywords         = @('conversation', 'skill', 'anti-slop', 'honesty', 'agent-replies')
        installEntries   = @('SKILL.md', 'README.md', 'agents', 'scripts', 'benchmarks')
        marketplaceShort = 'Honest, action-first, plain agent replies.'
        codexInterface   = [ordered]@{
            shortDescription = 'Honest, action-first, plain agent replies.'
            longDescription  = "Slopgent shapes the agent's own replies to the user — status reports, explanations, errors, completion claims — so they are honest about what actually ran, lead with the action, and stay plain, without dropping load-bearing precision or real uncertainty. It does not rewrite the user's text; that is slopbeth."
            developerName    = 'ehmo'
            category         = 'Productivity'
            capabilities     = @('Read', 'Write')
            websiteURL       = 'https://github.com/ehmo/slopkit'
            defaultPrompt    = @(
                'Use Slopgent to keep your replies honest about what actually ran, action-first, and plain.',
                'Turn on Slopgent and shape every reply until I say stop slopgent.'
            )
            brandColor       = '#0B3D2E'
        }
        doctorFiles      = @(
            'skills/slopgent/SKILL.md', 'skills/slopgent/README.md',
            'skills/slopgent/agents/claude-code.yaml', 'skills/slopgent/agents/codex.yaml', 'skills/slopgent/agents/hermes.yaml', 'skills/slopgent/agents/openclaw.yaml', 'skills/slopgent/agents/openai.yaml', 'skills/slopgent/agents/opencode.yaml', 'skills/slopgent/agents/pi.yaml',
            'skills/slopgent/scripts/comms_lint.py', 'skills/slopgent/scripts/slopgent-memory.js',
            'skills/slopgent/benchmarks/corpus.jsonl', 'skills/slopgent/benchmarks/corpus_gates.jsonl', 'skills/slopgent/benchmarks/decoys.jsonl',
            'skills/slopgent/benchmarks/run_comms_benchmark.py', 'skills/slopgent/benchmarks/decoy_rejection.py', 'skills/slopgent/benchmarks/README.md',
            'skills/slopgent/benchmarks/judge/judge_aggregate.py'
        )
    }
)

$SkillNames = ($Skills | ForEach-Object { $_.name }) -join ', '

function Get-SkillRoot {
    param($Skill)
    return (Join-Path $Root 'skills' $Skill.name)
}

function Show-Usage {
    [Console]::Out.WriteLine(@"
slopkit $Version

slopkit ships two anti-slop skills that install by the same means:
  slopbeth  cleans the writing you ship (rewrites and reviews an artifact)
  slopgent  cleans the conversation (shapes the agent's own replies)

Usage:
  slopkit install [-All]             install into agent skill dirs (see below)
  slopkit install <target-dir>       install into <target-dir> (see below)
  slopkit installnpx [target-dir]    install into all supported agents (or a dir)
  slopkit install-plugin [all|claude|codex]
  slopkit plugin install [all|claude|codex]
  slopkit doctor
  slopkit benchmark
  slopkit smoke

Default install (no arguments):
  Installs both skills only into agent skill directories that already exist
  under your home (e.g. ~/.claude/skills/). Agents you do not use are skipped.
  Add -All to install into every supported agent (Codex, Claude Code, Hermes,
  OpenClaw, OpenCode, Pi) whether or not their directories exist yet. Both
  skills land as sibling subdirs (skills/slopbeth and skills/slopgent).

Custom install:
  slopkit install /path/to/dir
  If <dir> already contains agent config dirs (.claude, .codex, .agents,
  .hermes, .openclaw, .config/opencode, .pi), slopkit installs both skills into
  each of their skills/ subdirs. Otherwise <dir> is treated as a skills parent
  and both skills are written into <dir>/slopbeth and <dir>/slopgent.

Plugin install:
  Installs both skills as Claude Code skills-directory plugins and/or Codex
  personal plugins with marketplace metadata.
"@)
}

function Get-SlopkitHome {
    if ($env:HOME) { return $env:HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    return $HOME
}

function Get-XdgConfigHome {
    if ($env:XDG_CONFIG_HOME) { return $env:XDG_CONFIG_HOME }
    return (Join-Path (Get-SlopkitHome) '.config')
}

function Get-AgentSkillDirs {
    # Agent skills-parent dirs rooted at $BaseDir (OpenCode under $XdgDir). Each
    # carries a 'marker' path: the agent's root dir under the base. Both skills
    # install as subdirs of 'skillsDir'.
    param([string]$BaseDir, [string]$XdgDir)
    $dirs = [System.Collections.Generic.List[object]]::new()
    $dirs.Add(@{ agent = 'codex'; marker = (Join-Path $BaseDir '.agents'); skillsDir = (Join-Path $BaseDir '.agents' 'skills') })
    $dirs.Add(@{ agent = 'codex-legacy'; marker = (Join-Path $BaseDir '.codex'); skillsDir = (Join-Path $BaseDir '.codex' 'skills') })
    $dirs.Add(@{ agent = 'claude-code'; marker = (Join-Path $BaseDir '.claude'); skillsDir = (Join-Path $BaseDir '.claude' 'skills') })
    $dirs.Add(@{ agent = 'hermes'; marker = (Join-Path $BaseDir '.hermes'); skillsDir = (Join-Path $BaseDir '.hermes' 'skills') })
    $dirs.Add(@{ agent = 'openclaw'; marker = (Join-Path $BaseDir '.openclaw'); skillsDir = (Join-Path $BaseDir '.openclaw' 'skills') })
    $dirs.Add(@{ agent = 'opencode'; marker = (Join-Path $XdgDir 'opencode'); skillsDir = (Join-Path $XdgDir 'opencode' 'skills') })
    $dirs.Add(@{ agent = 'pi'; marker = (Join-Path $BaseDir '.pi'); skillsDir = (Join-Path $BaseDir '.pi' 'agent' 'skills') })

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $deduped = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $dirs) {
        $resolved = [System.IO.Path]::GetFullPath($item.skillsDir)
        if ($seen.Add($resolved)) { $deduped.Add($item) }
    }
    return $deduped
}

# Basenames carried in a skill's own directory but excluded from the trimmed
# plugin payload. Mirror of PLUGIN_EXCLUDED_BASENAMES / includeInPluginPayload
# in bin/slopkit.js; keep the two in sync.
$script:PluginExcludedBasenames = @('attribution_scan.py', 'ci_secret_scan.py', 'score_snapshot.py', 'install_smoke.py', '__pycache__')
$script:IncludeInPluginPayload = {
    param([string]$Name)
    if ($Name -like '*.ps1') { return $false }
    if ($Name -like '*.pyc') { return $false }
    return (-not ($script:PluginExcludedBasenames -contains $Name))
}

function Copy-Entry {
    param($Skill, [string]$Name, [string]$Dest, [scriptblock]$Include)
    $source = Join-Path (Get-SkillRoot $Skill) $Name
    $target = Join-Path $Dest $Name
    if (-not (Test-Path -LiteralPath $source)) { return }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    if (-not $Include) {
        Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
        return
    }
    # Filtered copy for the plugin payload: copy the tree, then prune excluded
    # names (PowerShell's Copy-Item has no per-item filter).
    if ((Get-Item -LiteralPath $source).PSIsContainer) {
        Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
        Get-ChildItem -LiteralPath $target -Recurse -Force |
            Where-Object { -not (& $Include $_.Name) } |
            ForEach-Object { if (Test-Path -LiteralPath $_.FullName) { Remove-Item -LiteralPath $_.FullName -Recurse -Force } }
    }
    elseif (& $Include $Name) {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

function Install-SkillInto {
    param($Skill, [string]$SkillsDir)
    $dest = Join-Path $SkillsDir $Skill.name
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($entry in $Skill.installEntries) { Copy-Entry $Skill $entry $dest }
}

function Install-AllSkillsInto {
    param([string]$SkillsDir)
    foreach ($skill in $Skills) { Install-SkillInto $skill $SkillsDir }
}

function Write-InstallSummary {
    param([object[]]$Dirs, [string]$Lead)
    $suffix = if ($Dirs.Count -eq 1) { '' } else { 's' }
    [Console]::Out.WriteLine("$Lead $($Dirs.Count) location${suffix} ($SkillNames):")
    foreach ($item in $Dirs) { [Console]::Out.WriteLine("- $($item.agent): $($item.skillsDir)") }
}

function Install-Slopkit {
    param([string]$Target, [switch]$All)
    if ($Target) {
        # If the target already contains agent config dirs, install both skills
        # into their skills/ subdirs; otherwise treat it as a skills parent.
        $agentDirs = Get-AgentSkillDirs -BaseDir $Target -XdgDir (Join-Path $Target '.config')
        $present = @($agentDirs | Where-Object { Test-Path -LiteralPath $_.marker })
        if ($present.Count -gt 0) {
            foreach ($item in $present) { Install-AllSkillsInto $item.skillsDir }
            Write-InstallSummary $present "Installed slopkit $Version into $Target across"
            return
        }
        Install-AllSkillsInto $Target
        [Console]::Out.WriteLine("Installed slopkit $Version ($SkillNames) to $Target")
        return
    }
    $homeDir = Get-SlopkitHome
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($item in (Get-AgentSkillDirs -BaseDir $homeDir -XdgDir (Get-XdgConfigHome))) { $list.Add($item) }
    $envDir = if ($env:SLOPKIT_SKILLS_DIR) { $env:SLOPKIT_SKILLS_DIR } elseif ($env:SLOPBETH_SKILLS_DIR) { $env:SLOPBETH_SKILLS_DIR } else { $null }
    if ($envDir) { $list.Add(@{ agent = 'custom'; marker = $envDir; skillsDir = $envDir }) }
    $dirs = $list
    if (-not $All) {
        $dirs = @($dirs | Where-Object { $_.agent -eq 'custom' -or (Test-Path -LiteralPath $_.marker) })
        if ($dirs.Count -eq 0) {
            [Console]::Out.WriteLine("No known agent directories found under $homeDir.")
            [Console]::Out.WriteLine("Use 'install -All' to install for every supported agent, or 'install <dir>' for a specific path.")
            return
        }
    }
    foreach ($item in $dirs) { Install-AllSkillsInto $item.skillsDir }
    Write-InstallSummary $dirs "Installed slopkit $Version to"
}

function Get-PluginManifest {
    param($Skill, [string]$Agent)
    $base = [ordered]@{
        name        = $Skill.name
        version     = $Version
        description = $Skill.description
        author      = [ordered]@{ name = 'ehmo'; url = 'https://github.com/ehmo' }
        homepage    = 'https://github.com/ehmo/slopkit#readme'
        repository  = 'https://github.com/ehmo/slopkit'
        license     = 'MIT'
        keywords    = $Skill.keywords
        skills      = './skills/'
    }
    if ($Agent -eq 'claude') {
        $base['displayName'] = $Skill.displayName
        return $base
    }
    $interface = [ordered]@{ displayName = $Skill.displayName }
    foreach ($key in $Skill.codexInterface.Keys) { $interface[$key] = $Skill.codexInterface[$key] }
    $base['interface'] = $interface
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
    param($Skill, [string]$Target)
    if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
    $payload = Join-Path $Target 'skills' $Skill.name
    New-Item -ItemType Directory -Force -Path $payload | Out-Null
    foreach ($entry in $Skill.installEntries) { Copy-Entry $Skill $entry $payload $script:IncludeInPluginPayload }
}

function Install-ClaudePlugin {
    $installed = [System.Collections.Generic.List[object]]::new()
    foreach ($skill in $Skills) {
        $target = Join-Path (Get-SlopkitHome) '.claude' 'skills' $skill.name
        Install-PluginSkill $skill $target
        Write-JsonFile (Join-Path $target '.claude-plugin' 'plugin.json') (Get-PluginManifest $skill 'claude')
        $installed.Add(@{ agent = "claude-code:$($skill.name)"; target = $target })
    }
    return $installed
}

function Get-CodexMarketplaceEntry {
    param($Skill)
    return [ordered]@{
        name      = $Skill.name
        source    = [ordered]@{ source = 'local'; path = "./.codex/plugins/$($Skill.name)" }
        policy    = [ordered]@{ installation = 'INSTALLED_BY_DEFAULT'; authentication = 'ON_INSTALL' }
        category  = 'Productivity'
        interface = [ordered]@{ displayName = $Skill.displayName; shortDescription = $Skill.marketplaceShort }
    }
}

function Update-CodexMarketplace {
    $marketplaceFile = Join-Path (Get-SlopkitHome) '.agents' 'plugins' 'marketplace.json'
    $marketplace = Read-JsonFile $marketplaceFile ([ordered]@{
            name      = 'personal-plugins'
            interface = [ordered]@{ displayName = 'Personal Plugins' }
            plugins   = @()
        })
    $existing = Get-DictValue $marketplace 'plugins' @()
    if ($existing -isnot [System.Collections.IEnumerable] -or $existing -is [string]) { $existing = @() }
    $ours = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($skill in $Skills) { [void]$ours.Add($skill.name) }
    $kept = @($existing | Where-Object { $_ -and -not $ours.Contains([string](Get-DictValue $_ 'name')) })
    foreach ($skill in $Skills) { $kept += , (Get-CodexMarketplaceEntry $skill) }
    $marketplace['plugins'] = $kept
    Write-JsonFile $marketplaceFile $marketplace
    return $marketplaceFile
}

function Install-CodexPlugin {
    $installed = [System.Collections.Generic.List[object]]::new()
    foreach ($skill in $Skills) {
        $target = Join-Path (Get-SlopkitHome) '.codex' 'plugins' $skill.name
        Install-PluginSkill $skill $target
        Write-JsonFile (Join-Path $target '.codex-plugin' 'plugin.json') (Get-PluginManifest $skill 'codex')
        $installed.Add(@{ agent = "codex:$($skill.name)"; target = $target })
        foreach ($stale in @((Join-Path (Get-SlopkitHome) '.agents' 'skills' $skill.name), (Join-Path (Get-SlopkitHome) '.codex' 'skills' $skill.name))) {
            if (Test-Path -LiteralPath $stale) { Remove-Item -LiteralPath $stale -Recurse -Force }
        }
    }
    $marketplaceFile = Update-CodexMarketplace
    $installed.Add(@{ agent = 'codex-marketplace'; target = $marketplaceFile })
    return $installed
}

function Install-Plugins {
    param([string]$Which = 'all')
    $normalized = ($Which ? $Which : 'all').ToLowerInvariant()
    if ($normalized -notin @('all', 'claude', 'codex')) {
        [Console]::Error.WriteLine("Unknown plugin target: $Which"); Show-Usage; exit 1
    }
    $installed = [System.Collections.Generic.List[object]]::new()
    if ($normalized -eq 'all' -or $normalized -eq 'claude') { foreach ($item in (Install-ClaudePlugin)) { $installed.Add($item) } }
    if ($normalized -eq 'all' -or $normalized -eq 'codex') { foreach ($item in (Install-CodexPlugin)) { $installed.Add($item) } }
    [Console]::Out.WriteLine("Installed slopkit $Version plugin support ($SkillNames):")
    foreach ($item in $installed) { [Console]::Out.WriteLine("- $($item.agent): $($item.target)") }
}

function Invoke-Doctor {
    $required = [System.Collections.Generic.List[string]]::new()
    foreach ($f in @('CODE_OF_CONDUCT.md', 'LICENSE', 'README.md',
            '.agents/plugins/marketplace.json', '.claude-plugin/marketplace.json',
            'bin/slopkit.js', 'bin/slopkit.ps1')) { $required.Add($f) }
    foreach ($skill in $Skills) {
        $required.Add("plugins/$($skill.name)/.claude-plugin/plugin.json")
        $required.Add("plugins/$($skill.name)/.codex-plugin/plugin.json")
        $required.Add("plugins/$($skill.name)/skills/$($skill.name)/SKILL.md")
        foreach ($f in $skill.doctorFiles) { $required.Add($f) }
    }
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Root $_)) })
    if ($missing.Count) {
        [Console]::Error.WriteLine("Missing files:`n$(($missing | ForEach-Object { "- $_" }) -join "`n")")
        exit 1
    }
    [Console]::Out.WriteLine("slopkit $Version package files are present ($SkillNames).")
}

function Invoke-PsCheck {
    param([string]$ScriptDir, [string]$Script, [string[]]$CheckArgs)
    $full = Join-Path $ScriptDir $Script
    # Preset a non-zero sentinel so a launch failure cannot inherit a stale exit 0.
    $global:LASTEXITCODE = 255
    $output = & pwsh -NoProfile -File $full @CheckArgs 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        foreach ($line in $output) { [Console]::Error.WriteLine([string]$line) }
        exit $code
    }
}

function Resolve-Python {
    # Return the first python that actually launches. PATH can front a dangling
    # symlink (e.g. a removed Homebrew Cellar target); Process.Start throws
    # cleanly on those, so we skip them without console noise or false positives.
    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($name in @('python3', 'python')) {
        foreach ($cmd in @(Get-Command $name -All -ErrorAction SilentlyContinue)) {
            if ($cmd.Source -and -not $candidates.Contains($cmd.Source)) { $candidates.Add($cmd.Source) }
        }
    }
    foreach ($src in $candidates) {
        try {
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = $src
            $psi.Arguments = '--version'
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $proc = [System.Diagnostics.Process]::Start($psi)
            $probe = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
            $proc.WaitForExit()
            if ($proc.ExitCode -eq 0 -and $probe -match 'Python') { return $src }
        }
        catch { continue }
    }
    return $null
}

function Invoke-PyCheck {
    param([string]$Python, [string]$WorkDir, [string[]]$CheckArgs)
    Push-Location $WorkDir
    try {
        # Preset a non-zero sentinel so a launch failure cannot inherit a stale exit 0.
        $global:LASTEXITCODE = 255
        $output = & $Python @CheckArgs 2>&1
        $code = $LASTEXITCODE
    }
    finally { Pop-Location }
    if ($code -ne 0) {
        foreach ($line in $output) { [Console]::Error.WriteLine([string]$line) }
        exit $code
    }
}

function Invoke-SlopbethBenchmark {
    param($Skill)
    $skillRoot = Get-SkillRoot $Skill
    $scriptDir = Join-Path $skillRoot 'scripts'
    $bm = Join-Path $skillRoot 'benchmarks'
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
    Invoke-PsCheck $scriptDir 'Run-Benchmark.ps1' @('--corpus', $corpus, '--summary-only', '--fail-release-gate')
    Invoke-PsCheck $scriptDir 'Measure-SemanticDrift.ps1' @('--corpus', $corpus, '--quiet', '--fail-gate')
    Invoke-PsCheck $scriptDir 'Measure-Signature.ps1' @('--corpus', $corpus, '--fail-gate', '--format', 'json')
    Invoke-PsCheck $scriptDir 'Measure-Cadence.ps1' @('--corpus', $corpus, '--fail-gate', '--format', 'json')
    Invoke-PsCheck $scriptDir 'Measure-Unsummarizability.ps1' @('--corpus', $corpus, '--fail-gate', '--require-summary-loss', '--format', 'json')
    Invoke-PsCheck $scriptDir 'Test-SpanAnnotation.ps1' @('--corpus', $corpus, '--annotations', (Join-Path $bm 'span-annotations-v1.jsonl'), '--fail-gate', '--format', 'json')
    Invoke-PsCheck $scriptDir 'Test-FalsePositive.ps1' @('--tracker', (Join-Path $bm 'false-positive-tracker-v1.jsonl'), '--fail-gate', '--format', 'json')
    Invoke-PsCheck $scriptDir 'Measure-CompetitorOutput.ps1' @('--corpus', $corpus, '--panel', (Join-Path $bm 'competitor-output-runs-v1.jsonl'), '--fail-gate', '--format', 'json')
    Invoke-PsCheck $scriptDir 'Measure-CompetitorOutput.ps1' @('--corpus', $corpus, '--panel', (Join-Path $bm 'competitor-agent-runs-v1.jsonl'), '--min-competitors', '5', '--min-cases', '25', '--max-average-deficit', '2.0', '--fail-gate', '--format', 'json')

    $orwellPack = Join-Path $bm 'orwell-writing-system-v1.jsonl'
    $orwellRows = ConvertFrom-Jsonl $orwellPack
    Invoke-PsCheck $scriptDir 'Measure-OrwellBenchmark.ps1' @('--corpus', $orwellPack, '--fail-gate', '--format', 'json')

    [Console]::Out.WriteLine("slopbeth: $($v2Rows.Count) v2 output-bearing cases, $($v2JudgeRows.Count) v2 judge rows, plus span, false-positive, cadence, competitor-output, competitor-agent, and Orwell writing-system ($($orwellRows.Count) before/after rows) gates.")
}

function Invoke-SlopgentBenchmark {
    param($Skill)
    # slopgent ships Python-only gates. Run them with a working python if one is
    # present; if none launches, skip without failing the PowerShell benchmark.
    $python = Resolve-Python
    if (-not $python) {
        [Console]::Out.WriteLine('slopgent: gates require Python; no working python found, skipping (run bin/slopkit.js benchmark to include them).')
        return
    }
    $bm = Join-Path (Get-SkillRoot $Skill) 'benchmarks'
    Invoke-PyCheck $python $bm @('run_comms_benchmark.py', '--fail-gate')
    Invoke-PyCheck $python $bm @('decoy_rejection.py', '--fail-gate')
    Invoke-PyCheck $python $bm @((Join-Path 'judge' 'judge_aggregate.py'), '--fail-gate')

    $cases = (ConvertFrom-Jsonl (Join-Path $bm 'corpus.jsonl')).Count
    $decoys = (ConvertFrom-Jsonl (Join-Path $bm 'decoys.jsonl')).Count
    [Console]::Out.WriteLine("slopgent: $cases comms cases and $decoys decoys, plus the deterministic lint gate, decoy-rejection gate, and blinded judge-panel gate.")
}

function Invoke-Benchmark {
    foreach ($skill in $Skills) {
        switch ($skill.name) {
            'slopbeth' { Invoke-SlopbethBenchmark $skill }
            'slopgent' { Invoke-SlopgentBenchmark $skill }
        }
    }
    [Console]::Out.WriteLine("Benchmark packs ready for slopkit $Version ($SkillNames).")
}

function Invoke-Smoke {
    $scriptDir = Join-Path $Root 'skills' 'slopbeth' 'scripts'
    Invoke-PsCheck $scriptDir 'Test-Install.ps1' @()
    [Console]::Out.WriteLine("slopkit $Version install smoke passed.")
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
    Install-Slopkit -Target $target -All:$all
}
elseif ($command -in @('install-plugin', 'plugin-install', 'install-plugins')) { Install-Plugins $maybeTarget }
elseif ($command -eq 'plugin' -and $maybeTarget -eq 'install') { Install-Plugins $extraTarget }
elseif ($command -eq 'doctor') { Invoke-Doctor }
elseif ($command -eq 'benchmark') { Invoke-Benchmark }
elseif ($command -eq 'smoke') { Invoke-Smoke }
elseif ($command -in @('--version', '-v')) { [Console]::Out.WriteLine($Version) }
else { [Console]::Error.WriteLine("Unknown command: $command"); Show-Usage; exit 1 }
