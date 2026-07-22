# New-ScoreSnapshot.ps1 - Write a compact benchmark score snapshot for CI
# summaries and release notes. Port of score_snapshot.py. Dot-sources
# Measure-CompetitorOutput for Get-CompetitorOutputScore.

. "$PSScriptRoot/SlopBeth.Common.ps1"
. "$PSScriptRoot/Measure-CompetitorOutput.ps1"

# Payload root (skills/slopbeth) holds scripts/ and benchmarks/; the repo root
# (up two more levels) holds package.json.
$SnapRoot = Split-Path $PSScriptRoot -Parent
$SnapRepoRoot = Split-Path (Split-Path $SnapRoot -Parent) -Parent

function Get-SnapCompetitorSummary {
    param([string]$Panel, [int]$MinCompetitors, [int]$MinCases, $MaxDeficit)
    return Get-CompetitorOutputScore `
        (Join-Path $SnapRoot 'benchmarks/benchmark-v2.jsonl') `
        (Join-Path $SnapRoot "benchmarks/$Panel") `
        $MinCompetitors $MinCases $MaxDeficit $null
}

function Get-SnapMarkdown {
    $version = (Read-TextFile (Join-Path $SnapRepoRoot 'package.json') | ConvertFrom-Json).version
    $v2Cases = Get-JsonlCount (Join-Path $SnapRoot 'benchmarks/benchmark-v2.jsonl')
    $v2Judges = Get-JsonlCount (Join-Path $SnapRoot 'benchmarks/independent-judge-rows-v2.jsonl')
    $spans = Get-JsonlCount (Join-Path $SnapRoot 'benchmarks/span-annotations-v1.jsonl')
    $falsePositives = Get-JsonlCount (Join-Path $SnapRoot 'benchmarks/false-positive-tracker-v1.jsonl')
    $proxy = Get-SnapCompetitorSummary 'competitor-output-runs-v1.jsonl' 4 5 2.0
    $agent = Get-SnapCompetitorSummary 'competitor-agent-runs-v1.jsonl' 5 25 2.0

    $lines = [System.Collections.Generic.List[string]]::new()
    @(
        '# Slopbeth score snapshot', '',
        "- Generated: $(Get-UtcTimestamp)",
        "- Version: ``$version``",
        "- v2 output-bearing cases: ``$v2Cases``",
        "- v2 judge rows: ``$v2Judges``",
        "- span annotation rows: ``$spans``",
        "- false-positive rows: ``$falsePositives``", '',
        '## competitor gates', '',
        "Diagnostic parity gates, not a quality ranking. The composite score is built from",
        "Slopbeth's own instruments, so scoring other tools with it is circular. The gate asks",
        'whether Slopbeth stays within 2.0 points of the best peer, not whether it wins.',
        'Ties are reported as ties: on the real-agent panel almost every case is a five-way tie,',
        'so outright wins is the honest count and a per-case win rate carries no signal.',
        '',
        '| Panel | Cases | Competitors | Gate | Slopbeth avg | Best peer avg | Deficit | Outright wins | Tied at top |',
        '| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |',
        "| public-rule proxy | $($proxy['case_count']) | $($proxy['competitor_count']) | $(if ($proxy['gate_pass']) { 'pass' } else { 'fail' }) | $($proxy['slopbeth_average']) | $($proxy['best_average']) | $('{0:F2}' -f [double]$proxy['slopbeth_average_deficit']) | $($proxy['slopbeth_outright_wins']) | $($proxy['slopbeth_tied_top']) |",
        "| real agent outputs | $($agent['case_count']) | $($agent['competitor_count']) | $(if ($agent['gate_pass']) { 'pass' } else { 'fail' }) | $($agent['slopbeth_average']) | $($agent['best_average']) | $('{0:F2}' -f [double]$agent['slopbeth_average_deficit']) | $($agent['slopbeth_outright_wins']) | $($agent['slopbeth_tied_top']) |",
        '',
        "The public-rule panel is $(Get-DictValue $proxy['panel_source_types'] 'public-rule-proxy' 0) in-house rows written to other",
        "projects' published rules plus $(Get-DictValue $proxy['panel_source_types'] 'shipped-v2-output' 0) shipped Slopbeth outputs. It illustrates",
        'rulesets; it is not a competitor result, and its wide spread is an artifact of that.',
        'Only the real-agent panel contains outputs those tools produced.',
        '',
        '## real agent summary', '',
        '| Competitor | Cases | Average diagnostic score | Missing facts | Forbidden hits | Hard signatures |',
        '| --- | ---: | ---: | ---: | ---: | ---: |'
    ) | ForEach-Object { $lines.Add($_) }
    foreach ($name in $agent['summary'].Keys) {
        $row = $agent['summary'][$name]
        $lines.Add("| $name | $($row['case_count']) | $($row['average_score']) | $($row['missing_required_facts']) | $($row['forbidden_output_hits']) | $($row['hard_signatures']) |")
    }
    @(
        '', '## real agent top scorers', '',
        'A tie means the tools scored identically on this diagnostic, so the case has no',
        'winner. Near-identical peer output makes ties the norm here, not the exception.',
        '', '| Case | Top scorer |', '| --- | --- |'
    ) | ForEach-Object { $lines.Add($_) }
    foreach ($caseId in $agent['case_winners'].Keys) {
        $winners = @($agent['case_winners'][$caseId])
        $cell = if ($winners.Count -eq 1) { $winners[0] } else { "tie ($($winners.Count)-way): $($winners -join ', ')" }
        $lines.Add("| $caseId | $cell |")
    }
    return (($lines -join "`n") + "`n")
}

function Invoke-NewScoreSnapshotCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{ output = 'value' }
    $text = Get-SnapMarkdown
    if ($opts['output']) { Write-TextFile $opts['output'] $text }
    else { [Console]::Out.Write($text) }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-NewScoreSnapshotCli -Argv $args
}
