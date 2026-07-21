# Measure-OrwellBenchmark.ps1 - Score an Orwell before/after benchmark corpus.
# Port of orwell_benchmark.py. Dot-sources Measure-Orwell for Get-OrwellLint.
#
# Reads a JSONL corpus with `before` and `after` fields, runs the Orwell lint on
# each, and reports per-rule deltas plus a preservation check. It measures one
# dimension: whether a rewrite follows Orwell's five mechanical rules more
# closely while keeping the declared facts. It does not judge meaning, voice, or
# density. Rule six is not scored; rows tagged `rules_targeted: []` are controls
# where near-zero change is expected, not a failure.

. "$PSScriptRoot/SlopBeth.Common.ps1"
. "$PSScriptRoot/Measure-Orwell.ps1"

$OrwellBenchRuleKeys = @(
    "rule1_dead_metaphor",
    "rule2_long_word",
    "rule3_deletable_words",
    "rule4_passive_voice",
    "rule5_jargon_foreign"
)

function Test-OrwellBenchTruthy {
    # Mirrors Python truthiness for the rules_targeted control check.
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [bool]) { return $Value }
    if ($Value -is [string]) { return $Value.Length -gt 0 }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value).Count -gt 0 }
    return $true
}

function Get-OrwellBenchLoad {
    param([string]$Path)
    $rows = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.UTF8Encoding]::new($false))) {
        $lineNumber++
        if (-not $line.Trim()) { continue }
        $record = $line | ConvertFrom-Json -AsHashtable -Depth 100
        foreach ($field in @('id', 'before', 'after')) {
            if (-not $record.Contains($field)) { throw "${Path}:${lineNumber} missing $field" }
        }
        $rows.Add($record)
    }
    return $rows
}

function Get-OrwellBenchScoreRow {
    param($Record)
    $before = Get-OrwellLint ([string]$Record['before'])
    $after = Get-OrwellLint ([string]$Record['after'])
    $facts = @(Get-DictValue $Record 'preserved_facts' @())
    $afterLower = ([string]$Record['after']).ToLowerInvariant()
    $missing = @($facts | Where-Object { -not $afterLower.Contains(([string]$_).ToLowerInvariant()) })
    $isControl = -not (Test-OrwellBenchTruthy (Get-DictValue $Record 'rules_targeted'))

    $beforeCounts = $before['rule_counts']
    $afterCounts = $after['rule_counts']
    $ruleDeltas = [ordered]@{}
    $violationTotal = 0
    foreach ($key in $OrwellBenchRuleKeys) {
        $delta = [int]$afterCounts[$key] - [int]$beforeCounts[$key]
        $ruleDeltas[$key] = $delta
        $violationTotal += $delta
    }

    return [ordered]@{
        id                    = [string]$Record['id']
        category              = Get-DictValue $Record 'category' 'uncategorized'
        is_control            = $isControl
        before_score          = [int]$before['orwell_score']
        after_score           = [int]$after['orwell_score']
        score_delta           = [int]$after['orwell_score'] - [int]$before['orwell_score']
        before_passive_ratio  = $before['passive_ratio']
        after_passive_ratio   = $after['passive_ratio']
        rule_deltas           = $ruleDeltas
        total_violation_delta = $violationTotal
        missing_facts         = $missing
        note                  = Get-DictValue $Record 'note' ''
    }
}

function Get-OrwellBenchRun {
    param([string]$Path)
    $rows = @(Get-OrwellBenchLoad $Path | ForEach-Object { Get-OrwellBenchScoreRow $_ })
    $targeted = @($rows | Where-Object { -not $_['is_control'] })
    $controls = @($rows | Where-Object { $_['is_control'] })

    $ruleDeltaTotals = [ordered]@{}
    foreach ($key in $OrwellBenchRuleKeys) {
        $sum = 0
        foreach ($r in $rows) { $sum += [int]$r['rule_deltas'][$key] }
        $ruleDeltaTotals[$key] = $sum
    }

    $failures = [System.Collections.Generic.List[string]]::new()
    $worsened = @($targeted | Where-Object { $_['total_violation_delta'] -gt 0 } | ForEach-Object { $_['id'] })
    if ($worsened.Count) { $failures.Add("targeted_rows_added_violations:$($worsened -join ',')") }
    $noImprovement = @($targeted | Where-Object { $_['total_violation_delta'] -eq 0 } | ForEach-Object { $_['id'] })
    if ($noImprovement.Count) { $failures.Add("targeted_rows_no_improvement:$($noImprovement -join ',')") }
    $droppedFacts = @($rows | Where-Object { @($_['missing_facts']).Count } | ForEach-Object { $_['id'] })
    if ($droppedFacts.Count) { $failures.Add("rows_dropped_declared_facts:$($droppedFacts -join ',')") }
    $overEdited = @($controls | Where-Object {
            [math]::Abs([int]$_['score_delta']) -gt 3 -or [int]$_['total_violation_delta'] -lt -2
        } | ForEach-Object { $_['id'] })
    if ($overEdited.Count) { $failures.Add("controls_over_edited:$($overEdited -join ',')") }

    $avgTargetedBefore = if ($targeted.Count) { [math]::Round((Get-Mean @($targeted | ForEach-Object { [double]$_['before_score'] })), 2) } else { $null }
    $avgTargetedAfter = if ($targeted.Count) { [math]::Round((Get-Mean @($targeted | ForEach-Object { [double]$_['after_score'] })), 2) } else { $null }

    return [ordered]@{
        corpus                   = $Path
        row_count                = $rows.Count
        targeted_count           = $targeted.Count
        control_count            = $controls.Count
        avg_before_score         = [math]::Round((Get-Mean @($rows | ForEach-Object { [double]$_['before_score'] })), 2)
        avg_after_score          = [math]::Round((Get-Mean @($rows | ForEach-Object { [double]$_['after_score'] })), 2)
        avg_targeted_before_score = $avgTargetedBefore
        avg_targeted_after_score = $avgTargetedAfter
        rule_delta_totals        = $ruleDeltaTotals
        avg_passive_ratio_before = [math]::Round((Get-Mean @($rows | ForEach-Object { [double]$_['before_passive_ratio'] })), 3)
        avg_passive_ratio_after  = [math]::Round((Get-Mean @($rows | ForEach-Object { [double]$_['after_passive_ratio'] })), 3)
        gate_pass                = ($failures.Count -eq 0)
        failures                 = @($failures.ToArray())
        rows                     = $rows
    }
}

function Get-OrwellBenchMarkdown {
    param($Result)
    $labels = [ordered]@{
        rule1_dead_metaphor   = "1 dead metaphor"
        rule2_long_word       = "2 long word"
        rule3_deletable_words = "3 deletable words"
        rule4_passive_voice   = "4 passive voice"
        rule5_jargon_foreign  = "5 jargon/foreign"
    }
    $failuresText = if (@($Result['failures']).Count) { @($Result['failures']) -join ', ' } else { 'none' }
    $lines = [System.Collections.Generic.List[string]]::new()
    @(
        "# Orwell Writing-System Benchmark", "",
        "- Corpus: ``$($Result['corpus'])``",
        "- Rows: $($Result['row_count']) ($($Result['targeted_count']) targeted, $($Result['control_count']) control)",
        "- Avg Orwell score before -> after: $($Result['avg_before_score']) -> $($Result['avg_after_score'])",
        "- Targeted rows before -> after: $($Result['avg_targeted_before_score']) -> $($Result['avg_targeted_after_score'])",
        "- Gate pass: ``$($Result['gate_pass'].ToString().ToLowerInvariant())``",
        "- Failures: ``$failuresText``",
        "",
        "## Rule violation deltas (after minus before, negative is better)", "",
        "| Rule | Total delta |",
        "| --- | ---: |"
    ) | ForEach-Object { $lines.Add($_) }
    foreach ($key in $OrwellBenchRuleKeys) {
        $lines.Add("| $($labels[$key]) | $($Result['rule_delta_totals'][$key]) |")
    }
    @(
        "",
        "## Rows", "",
        "| ID | Category | Control | Score before -> after | Passive before -> after | Violation delta | Missing facts |",
        "| --- | --- | :---: | --- | --- | ---: | --- |"
    ) | ForEach-Object { $lines.Add($_) }
    foreach ($r in $Result['rows']) {
        $controlMark = if ($r['is_control']) { 'yes' } else { '' }
        $missingText = if (@($r['missing_facts']).Count) { @($r['missing_facts']) -join ', ' } else { '-' }
        $lines.Add(
            "| $($r['id']) | $($r['category']) | $controlMark | " +
            "$($r['before_score']) -> $($r['after_score']) | " +
            "$(Format-OrwellFloat $r['before_passive_ratio']) -> $(Format-OrwellFloat $r['after_passive_ratio']) | " +
            "$($r['total_violation_delta']) | $missingText |")
    }
    return (($lines -join "`n") + "`n")
}

function Invoke-MeasureOrwellBenchmarkCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        corpus = 'value'; format = 'value'; 'fail-gate' = 'switch'
    }
    if (-not $opts['corpus']) { [Console]::Error.WriteLine('error: --corpus is required'); exit 2 }
    $format = if ($opts['format']) { $opts['format'] } else { 'markdown' }

    $result = Get-OrwellBenchRun $opts['corpus']
    if ($format -eq 'json') {
        ConvertTo-StableJson $result
    } else {
        [Console]::Out.WriteLine((Get-OrwellBenchMarkdown $result))
    }
    if ($opts['fail-gate'] -and -not $result['gate_pass']) { exit 2 }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureOrwellBenchmarkCli -Argv $args
}
