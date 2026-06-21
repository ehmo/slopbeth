# New-ScoreSnapshot.ps1 - Write a compact benchmark score snapshot for CI
# summaries and release notes. Port of score_snapshot.py. Dot-sources
# Measure-CompetitorOutput for Get-CompetitorOutputScore.

. "$PSScriptRoot/SlopBeth.Common.ps1"
. "$PSScriptRoot/Measure-CompetitorOutput.ps1"

$SnapRoot = Split-Path $PSScriptRoot -Parent

function Get-SnapCompetitorSummary {
    param([string]$Panel, [int]$MinCompetitors, [int]$MinCases, $WinRate)
    return Get-CompetitorOutputScore `
        (Join-Path $SnapRoot 'benchmarks/benchmark-v2.jsonl') `
        (Join-Path $SnapRoot "benchmarks/$Panel") `
        $MinCompetitors $MinCases $WinRate
}

function Get-SnapMarkdown {
    $version = (Read-TextFile (Join-Path $SnapRoot 'package.json') | ConvertFrom-Json).version
    $v2Cases = Get-JsonlCount (Join-Path $SnapRoot 'benchmarks/benchmark-v2.jsonl')
    $v2Judges = Get-JsonlCount (Join-Path $SnapRoot 'benchmarks/independent-judge-rows-v2.jsonl')
    $spans = Get-JsonlCount (Join-Path $SnapRoot 'benchmarks/span-annotations-v1.jsonl')
    $falsePositives = Get-JsonlCount (Join-Path $SnapRoot 'benchmarks/false-positive-tracker-v1.jsonl')
    $proxy = Get-SnapCompetitorSummary 'competitor-output-runs-v1.jsonl' 4 5 $null
    $agent = Get-SnapCompetitorSummary 'competitor-agent-runs-v1.jsonl' 5 25 0.7

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
        '| Panel | Cases | Competitors | Gate | Slopbeth wins | Slopbeth win rate |',
        '| --- | ---: | ---: | --- | ---: | ---: |',
        "| public-rule outputs | $($proxy['case_count']) | $($proxy['competitor_count']) | $(if ($proxy['gate_pass']) { 'pass' } else { 'fail' }) | $($proxy['slopbeth_case_wins']) | $($proxy['slopbeth_case_win_rate']) |",
        "| real agent outputs | $($agent['case_count']) | $($agent['competitor_count']) | $(if ($agent['gate_pass']) { 'pass' } else { 'fail' }) | $($agent['slopbeth_case_wins']) | $($agent['slopbeth_case_win_rate']) |",
        '',
        '## real agent summary', '',
        '| Competitor | Cases | Average diagnostic score | Missing facts | Forbidden hits | Hard signatures |',
        '| --- | ---: | ---: | ---: | ---: | ---: |'
    ) | ForEach-Object { $lines.Add($_) }
    foreach ($name in $agent['summary'].Keys) {
        $row = $agent['summary'][$name]
        $lines.Add("| $name | $($row['case_count']) | $($row['average_score']) | $($row['missing_required_facts']) | $($row['forbidden_output_hits']) | $($row['hard_signatures']) |")
    }
    @('', '## real agent case winners', '', '| Case | Winner |', '| --- | --- |') | ForEach-Object { $lines.Add($_) }
    foreach ($caseId in $agent['case_winners'].Keys) {
        $lines.Add("| $caseId | $($agent['case_winners'][$caseId]) |")
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
