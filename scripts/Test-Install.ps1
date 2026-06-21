# Test-Install.ps1 - Smoke-test the package installer in temporary skill
# directories. Port of install_smoke.py. Drives bin/slopbeth.ps1 (PowerShell CLI).

. "$PSScriptRoot/SlopBeth.Common.ps1"

$SmokeRoot = Split-Path $PSScriptRoot -Parent
$SmokeCli = Join-Path $SmokeRoot 'bin' 'slopbeth.ps1'

$SmokeRequiredInstalledFiles = @(
    'SKILL.md', 'BENCHMARKS.md', 'CONTRIBUTING.md', 'SECURITY.md', 'SUPPORT.md',
    'agents/claude-code.yaml', 'agents/codex.yaml', 'agents/hermes.yaml', 'agents/openclaw.yaml',
    'agents/openai.yaml', 'agents/opencode.yaml', 'agents/pi.yaml',
    'references/evaluation.md', 'references/slop-taxonomy.md',
    'benchmarks/benchmark-v2.jsonl', 'benchmarks/competitor-agent-runs-v1.jsonl', 'benchmarks/score-snapshot.md',
    'docs/false-positive-tracker.md', 'docs/literature-basis.md',
    'scripts/Run-Benchmark.ps1', 'scripts/Measure-CompetitorOutput.ps1', 'scripts/New-ScoreSnapshot.ps1'
)
$SmokeRequiredAgentTargets = @(
    '.codex/skills/slopbeth', '.agents/skills/slopbeth', '.claude/skills/slopbeth', '.hermes/skills/slopbeth',
    '.openclaw/skills/slopbeth', '.config/opencode/skills/slopbeth', '.pi/agent/skills/slopbeth'
)
$SmokeRequiredPluginFiles = @(
    '.claude/skills/slopbeth/.claude-plugin/plugin.json',
    '.claude/skills/slopbeth/skills/slopbeth/SKILL.md',
    '.claude/skills/slopbeth/skills/slopbeth/references/evaluation.md',
    '.claude/skills/slopbeth/skills/slopbeth/scripts/Run-Benchmark.ps1',
    '.codex/plugins/slopbeth/.codex-plugin/plugin.json',
    '.codex/plugins/slopbeth/skills/slopbeth/SKILL.md',
    '.codex/plugins/slopbeth/skills/slopbeth/references/evaluation.md',
    '.codex/plugins/slopbeth/skills/slopbeth/scripts/Run-Benchmark.ps1',
    '.agents/plugins/marketplace.json'
)

function Invoke-SmokeInstall {
    param([string[]]$CliArgs)
    $output = & pwsh -NoProfile -File $SmokeCli @CliArgs 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Test-SmokeInstalled {
    param([string]$Target, [string]$Version)
    $missing = @($SmokeRequiredInstalledFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Target $_)) })
    if ($missing.Count) { return @($missing | ForEach-Object { "${Target}: missing $_" }) }
    $skillText = Read-TextFile (Join-Path $Target 'SKILL.md')
    if (-not $skillText.Contains("version: $Version")) { return @("${Target}: SKILL.md does not report version $Version") }
    return @()
}

function Test-SmokeJsonFile {
    param([string]$Path)
    try { [void](Read-TextFile $Path | ConvertFrom-Json -AsHashtable -Depth 100); return @() }
    catch { return @("${Path}: invalid JSON: $($_.Exception.Message)") }
}

function Invoke-SmokeTest {
    param([bool]$Keep)
    $version = (Read-TextFile (Join-Path $SmokeRoot 'package.json') | ConvertFrom-Json).version
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('slopbeth-install-' + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    $customTarget = Join-Path $temp 'skills' 'slopbeth'

    $savedHome = $env:HOME; $savedUserProfile = $env:USERPROFILE; $savedXdg = $env:XDG_CONFIG_HOME; $savedSkillsDir = $env:SLOPBETH_SKILLS_DIR
    try {
        $result = Invoke-SmokeInstall @('install', $customTarget)
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return ($result.ExitCode) }

        $failures = Test-SmokeInstalled $customTarget $version
        if ($failures.Count) {
            [Console]::Out.WriteLine('Custom install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1
        }

        $smokeHome = Join-Path $temp 'home'
        $configHome = Join-Path $smokeHome '.config'
        New-Item -ItemType Directory -Force -Path $smokeHome | Out-Null
        $env:HOME = $smokeHome; $env:USERPROFILE = $smokeHome; $env:XDG_CONFIG_HOME = $configHome
        Remove-Item Env:\SLOPBETH_SKILLS_DIR -ErrorAction SilentlyContinue

        $result = Invoke-SmokeInstall @('installnpx')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return ($result.ExitCode) }

        $failures = @()
        foreach ($relativeTarget in $SmokeRequiredAgentTargets) { $failures += Test-SmokeInstalled (Join-Path $smokeHome $relativeTarget) $version }
        if ($failures.Count) {
            [Console]::Out.WriteLine('Default multi-agent install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1
        }

        $result = Invoke-SmokeInstall @('install-plugin')
        if ($result.ExitCode -ne 0) { [Console]::Out.Write($result.Output); return ($result.ExitCode) }

        $failures = @()
        foreach ($relativeFile in $SmokeRequiredPluginFiles) {
            $file = Join-Path $smokeHome $relativeFile
            if (-not (Test-Path -LiteralPath $file)) { $failures += "${file}: missing" }
        }
        foreach ($relativeFile in @('.claude/skills/slopbeth/.claude-plugin/plugin.json', '.codex/plugins/slopbeth/.codex-plugin/plugin.json', '.agents/plugins/marketplace.json')) {
            $file = Join-Path $smokeHome $relativeFile
            if (Test-Path -LiteralPath $file) { $failures += Test-SmokeJsonFile $file }
        }

        $marketplace = Read-TextFile (Join-Path $smokeHome '.agents/plugins/marketplace.json') | ConvertFrom-Json -AsHashtable -Depth 100
        $slopbethPlugins = @((Get-DictValue $marketplace 'plugins' @()) | Where-Object { (Get-DictValue $_ 'name') -eq 'slopbeth' })
        if ($slopbethPlugins.Count -ne 1) {
            $failures += 'Codex marketplace must contain exactly one slopbeth plugin entry'
        } elseif ((Get-DictValue (Get-DictValue $slopbethPlugins[0] 'source' @{}) 'path') -ne './.codex/plugins/slopbeth') {
            $failures += 'Codex marketplace slopbeth source path is wrong'
        }

        if ((Test-Path -LiteralPath (Join-Path $smokeHome '.agents/skills/slopbeth')) -or (Test-Path -LiteralPath (Join-Path $smokeHome '.codex/skills/slopbeth'))) {
            $failures += 'Codex plugin install must remove plain Codex skill targets to avoid duplicate Slopbeth entries'
        }

        if ($failures.Count) {
            [Console]::Out.WriteLine('Plugin install failed:'); foreach ($f in $failures) { [Console]::Out.WriteLine("- $f") }; return 1
        }

        [Console]::Out.WriteLine("Install smoke passed: $customTarget, $($SmokeRequiredAgentTargets.Count) agent targets, and Claude/Codex plugin targets")
        return 0
    }
    finally {
        $env:HOME = $savedHome; $env:USERPROFILE = $savedUserProfile; $env:XDG_CONFIG_HOME = $savedXdg; $env:SLOPBETH_SKILLS_DIR = $savedSkillsDir
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
