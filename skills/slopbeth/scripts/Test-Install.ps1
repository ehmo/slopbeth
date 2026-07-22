# Test-Install.ps1 - Smoke-test the slopkit installer in temporary skill
# directories. PowerShell twin of install_smoke.py; drives bin/slopkit.ps1.
#
# slopkit ships two skills (slopbeth, slopgent) that install by the same means.
# Every install path drops both as sibling subdirs of a skills parent
# (skills/slopbeth and skills/slopgent), so the smoke validates both everywhere.

. "$PSScriptRoot/SlopBeth.Common.ps1"

# Repo root: skills/slopbeth/scripts -> up three levels. bin/ and package.json
# live at the repo root, so the installer smoke must drive the root CLI.
$SmokeRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$SmokeCli = Join-Path $SmokeRoot 'bin' 'slopkit.ps1'

$SmokeSkillNames = @('slopbeth', 'slopgent')

# Files each skill must carry after an install, relative to its own skill dir.
$SmokeRequiredFiles = @{
    slopbeth = @(
        'SKILL.md', 'BENCHMARKS.md', 'CONTRIBUTING.md', 'SECURITY.md', 'SUPPORT.md',
        'agents/claude-code.yaml', 'agents/codex.yaml', 'agents/hermes.yaml', 'agents/openclaw.yaml',
        'agents/openai.yaml', 'agents/opencode.yaml', 'agents/pi.yaml',
        'references/evaluation.md', 'references/slop-taxonomy.md',
        'benchmarks/benchmark-v2.jsonl', 'benchmarks/competitor-agent-runs-v1.jsonl', 'benchmarks/score-snapshot.md',
        'docs/false-positive-tracker.md', 'docs/literature-basis.md',
        'scripts/Compare-Preservation.ps1', 'scripts/Get-DensityReport.ps1', 'scripts/Measure-Deslop.ps1',
        'scripts/Run-Benchmark.ps1', 'scripts/SlopBeth.Common.ps1', 'scripts/Test-Install.ps1',
        'scripts/run_benchmark.py', 'scripts/competitor_output_score.py', 'scripts/score_snapshot.py'
    )
    slopgent = @(
        'SKILL.md', 'README.md',
        'agents/claude-code.yaml', 'agents/codex.yaml', 'agents/hermes.yaml', 'agents/openclaw.yaml',
        'agents/openai.yaml', 'agents/opencode.yaml', 'agents/pi.yaml',
        'scripts/comms_lint.py', 'scripts/slopgent-memory.js',
        'benchmarks/corpus.jsonl', 'benchmarks/corpus_gates.jsonl', 'benchmarks/decoys.jsonl',
        'benchmarks/run_comms_benchmark.py', 'benchmarks/decoy_rejection.py', 'benchmarks/README.md',
        'benchmarks/judge/judge_aggregate.py'
    )
}

# Agent skills-parent dirs, relative to a home. Both skills install underneath.
$SmokeRequiredAgentSkillsDirs = @(
    '.codex/skills', '.agents/skills', '.claude/skills', '.hermes/skills',
    '.openclaw/skills', '.config/opencode/skills', '.pi/agent/skills'
)

function Invoke-SmokeInstall {
    param([string[]]$CliArgs)
    $global:LASTEXITCODE = 255
    $output = & pwsh -NoProfile -File $SmokeCli @CliArgs 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Test-SkillInstalled {
    param([string]$SkillDir, [string]$Skill, [string]$Version)
    $missing = @($SmokeRequiredFiles[$Skill] | Where-Object { -not (Test-Path -LiteralPath (Join-Path $SkillDir $_)) })
    if ($missing.Count) { return @($missing | ForEach-Object { "${SkillDir}: missing $_" }) }
    $skillText = Read-TextFile (Join-Path $SkillDir 'SKILL.md')
    if (-not $skillText.Contains("version: $Version")) { return @("${SkillDir}: SKILL.md does not report version $Version") }
    return @()
}

function Test-SkillsDirInstalled {
    param([string]$SkillsDir, [string]$Version)
    $failures = @()
    foreach ($skill in $SmokeSkillNames) { $failures += Test-SkillInstalled (Join-Path $SkillsDir $skill) $skill $Version }
    return $failures
}

function Test-SmokeJsonFile {
    param([string]$Path)
    try { [void](Read-TextFile $Path | ConvertFrom-Json -AsHashtable -Depth 100); return @() }
    catch { return @("${Path}: invalid JSON: $($_.Exception.Message)") }
}

function Test-SmokeMissing {
    param([string]$Path, [string]$Label)
    if (Test-Path -LiteralPath $Path) { return @("${Label}: unexpectedly exists at ${Path}") }
    return @()
}

function Set-SmokeEnv {
    param([string]$HomeDir, [string]$ConfigDir, [hashtable]$Extra)
    $env:HOME = $HomeDir
    $env:USERPROFILE = $HomeDir
    $env:XDG_CONFIG_HOME = $ConfigDir
    Remove-Item Env:\SLOPKIT_SKILLS_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:\SLOPBETH_SKILLS_DIR -ErrorAction SilentlyContinue
    if ($Extra) { foreach ($k in $Extra.Keys) { Set-Item -Path "Env:\$k" -Value $Extra[$k] } }
}

function Restore-SmokeEnv {
    param([AllowNull()][string]$HomeDir, [AllowNull()][string]$UserProfile, [AllowNull()][string]$XdgConfigHome, [AllowNull()][string]$SlopkitDir, [AllowNull()][string]$SlopbethDir)
    if ($null -eq $HomeDir) { Remove-Item Env:\HOME -ErrorAction SilentlyContinue } else { $env:HOME = $HomeDir }
    if ($null -eq $UserProfile) { Remove-Item Env:\USERPROFILE -ErrorAction SilentlyContinue } else { $env:USERPROFILE = $UserProfile }
    if ($null -eq $XdgConfigHome) { Remove-Item Env:\XDG_CONFIG_HOME -ErrorAction SilentlyContinue } else { $env:XDG_CONFIG_HOME = $XdgConfigHome }
    if ($null -eq $SlopkitDir) { Remove-Item Env:\SLOPKIT_SKILLS_DIR -ErrorAction SilentlyContinue } else { $env:SLOPKIT_SKILLS_DIR = $SlopkitDir }
    if ($null -eq $SlopbethDir) { Remove-Item Env:\SLOPBETH_SKILLS_DIR -ErrorAction SilentlyContinue } else { $env:SLOPBETH_SKILLS_DIR = $SlopbethDir }
}

function Invoke-SmokeTest {
    param([bool]$Keep)
    $version = (Read-TextFile (Join-Path $SmokeRoot 'package.json') | ConvertFrom-Json).version
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('slopkit-install-' + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $temp | Out-Null

    $savedHome = $env:HOME; $savedUserProfile = $env:USERPROFILE; $savedXdg = $env:XDG_CONFIG_HOME
    $savedSlopkit = $env:SLOPKIT_SKILLS_DIR; $savedSlopbeth = $env:SLOPBETH_SKILLS_DIR
    try {
        # 1. Bare-dir custom install: target is a skills parent, both skills land under it.
        $customTarget = Join-Path $temp 'custom-skills'
        $result = Invoke-SmokeInstall @('install', $customTarget)
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = Test-SkillsDirInstalled $customTarget $version
        if ($failures.Count) { [Console]::Out.WriteLine('Custom install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        # 2. Default install with no existing agents: nothing installed, clear message.
        $emptyHome = Join-Path $temp 'empty-home'
        $emptyConfig = Join-Path $emptyHome '.config'
        New-Item -ItemType Directory -Force -Path $emptyHome | Out-Null
        Set-SmokeEnv $emptyHome $emptyConfig
        $result = Invoke-SmokeInstall @('install')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = @()
        foreach ($skillsDir in $SmokeRequiredAgentSkillsDirs) { $failures += Test-SmokeMissing (Join-Path $emptyHome $skillsDir) 'Default install without existing agents' }
        if (-not $result.Output.Contains('No known agent directories found')) {
            $failures += 'Default install without existing agents should explain that no agent directories were found'
        }
        if ($failures.Count) { [Console]::Out.WriteLine('Existing-agent default skip failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        # 3. Default install with one existing agent: only that agent gets both skills.
        $existingHome = Join-Path $temp 'studio-home'
        $existingConfig = Join-Path $existingHome '.config'
        New-Item -ItemType Directory -Force -Path (Join-Path $existingHome '.claude') | Out-Null
        New-Item -ItemType Directory -Force -Path $existingConfig | Out-Null
        Set-SmokeEnv $existingHome $existingConfig
        $result = Invoke-SmokeInstall @('install')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = Test-SkillsDirInstalled (Join-Path $existingHome '.claude/skills') $version
        $failures += Test-SmokeMissing (Join-Path $existingHome '.agents/skills/slopbeth') 'Existing-agent default'
        $failures += Test-SmokeMissing (Join-Path $existingConfig 'opencode/skills/slopbeth') 'Plain XDG config without opencode'
        if ($failures.Count) { [Console]::Out.WriteLine('Existing-agent default install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        # 4. SLOPKIT_SKILLS_DIR env override: both skills under the named parent.
        $customEnvTarget = Join-Path $temp 'custom-env-skills'
        Set-SmokeEnv (Join-Path $temp 'custom-env-home') (Join-Path $temp 'custom-env-config') @{ SLOPKIT_SKILLS_DIR = $customEnvTarget }
        $result = Invoke-SmokeInstall @('install')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = Test-SkillsDirInstalled $customEnvTarget $version
        if ($failures.Count) { [Console]::Out.WriteLine('SLOPKIT_SKILLS_DIR install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        # 5. Back-compat SLOPBETH_SKILLS_DIR still works.
        $legacyEnvTarget = Join-Path $temp 'legacy-env-skills'
        Set-SmokeEnv (Join-Path $temp 'legacy-env-home') (Join-Path $temp 'legacy-env-config') @{ SLOPBETH_SKILLS_DIR = $legacyEnvTarget }
        $result = Invoke-SmokeInstall @('install')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = Test-SkillsDirInstalled $legacyEnvTarget $version
        if ($failures.Count) { [Console]::Out.WriteLine('SLOPBETH_SKILLS_DIR (back-compat) install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        # 6. Smart custom install: agent dirs present, both skills into each skills subdir.
        $smartTarget = Join-Path $temp 'smart-target'
        New-Item -ItemType Directory -Force -Path (Join-Path $smartTarget '.claude') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $smartTarget '.config/opencode') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $smartTarget '.pi') | Out-Null
        $result = Invoke-SmokeInstall @('install', $smartTarget)
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = @()
        foreach ($skillsDir in @('.claude/skills', '.config/opencode/skills', '.pi/agent/skills')) {
            $failures += Test-SkillsDirInstalled (Join-Path $smartTarget $skillsDir) $version
        }
        $failures += Test-SmokeMissing (Join-Path $smartTarget 'slopbeth') 'Smart custom install root'
        if ($failures.Count) { [Console]::Out.WriteLine('Smart custom install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        # 7. Full multi-agent install (-All).
        $home = Join-Path $temp 'home'
        $configHome = Join-Path $home '.config'
        New-Item -ItemType Directory -Force -Path $home | Out-Null
        Set-SmokeEnv $home $configHome
        $result = Invoke-SmokeInstall @('install', '-All')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = @()
        foreach ($skillsDir in $SmokeRequiredAgentSkillsDirs) { $failures += Test-SkillsDirInstalled (Join-Path $home $skillsDir) $version }
        if ($failures.Count) { [Console]::Out.WriteLine('Default multi-agent install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        # 8. installnpx alias installs into every supported agent.
        $installnpxHome = Join-Path $temp 'installnpx-home'
        $installnpxConfig = Join-Path $installnpxHome '.config'
        New-Item -ItemType Directory -Force -Path $installnpxHome | Out-Null
        Set-SmokeEnv $installnpxHome $installnpxConfig
        $result = Invoke-SmokeInstall @('installnpx')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = @()
        foreach ($skillsDir in $SmokeRequiredAgentSkillsDirs) { $failures += Test-SkillsDirInstalled (Join-Path $installnpxHome $skillsDir) $version }
        if ($failures.Count) { [Console]::Out.WriteLine('installnpx multi-agent install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        # 9. Plugin install for both skills (Claude + Codex).
        Set-SmokeEnv $home $configHome
        $result = Invoke-SmokeInstall @('install-plugin')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return $result.ExitCode }
        $failures = @()
        foreach ($skill in $SmokeSkillNames) {
            $pluginFiles = @(
                ".claude/skills/$skill/.claude-plugin/plugin.json",
                ".claude/skills/$skill/skills/$skill/SKILL.md",
                ".codex/plugins/$skill/.codex-plugin/plugin.json",
                ".codex/plugins/$skill/skills/$skill/SKILL.md"
            )
            foreach ($relativeFile in $pluginFiles) {
                $file = Join-Path $home $relativeFile
                if (-not (Test-Path -LiteralPath $file)) { $failures += "${file}: missing" }
                elseif ((Split-Path $file -Leaf) -eq 'plugin.json') { $failures += Test-SmokeJsonFile $file }
            }
        }
        $marketplaceFile = Join-Path $home '.agents/plugins/marketplace.json'
        if (-not (Test-Path -LiteralPath $marketplaceFile)) { $failures += "${marketplaceFile}: missing" }
        else {
            $failures += Test-SmokeJsonFile $marketplaceFile
            $marketplace = Read-TextFile $marketplaceFile | ConvertFrom-Json -AsHashtable -Depth 100
            $plugins = Get-DictValue $marketplace 'plugins' @()
            foreach ($skill in $SmokeSkillNames) {
                $entries = @($plugins | Where-Object { (Get-DictValue $_ 'name') -eq $skill })
                if ($entries.Count -ne 1) { $failures += "Codex marketplace must contain exactly one $skill plugin entry" }
                elseif ((Get-DictValue (Get-DictValue $entries[0] 'source' @{}) 'path') -ne "./.codex/plugins/$skill") { $failures += "Codex marketplace $skill source path is wrong" }
            }
        }
        foreach ($skill in $SmokeSkillNames) {
            if ((Test-Path -LiteralPath (Join-Path $home ".agents/skills/$skill")) -or (Test-Path -LiteralPath (Join-Path $home ".codex/skills/$skill"))) {
                $failures += "Codex plugin install must remove plain Codex skill targets for $skill"
            }
        }
        if ($failures.Count) { [Console]::Out.WriteLine('Plugin install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1 }

        [Console]::Out.WriteLine("Install smoke passed: both skills across $($SmokeRequiredAgentSkillsDirs.Count) agent skills dirs, env overrides, and Claude/Codex plugin targets")
        return 0
    }
    finally {
        Restore-SmokeEnv $savedHome $savedUserProfile $savedXdg $savedSlopkit $savedSlopbeth
        if ($Keep) { [Console]::Out.WriteLine("Kept temporary install: $temp") }
        else { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Invoke-TestInstallCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{ keep = 'switch' }
    exit (Invoke-SmokeTest ([bool]$opts['keep']))
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-TestInstallCli -Argv $args
}
