# Measure-Cadence.ps1 - Score sentence cadence problems in benchmark outputs.
# Port of cadence_score.py.

. "$PSScriptRoot/SlopBeth.Common.ps1"

$CadenceWordPattern = "\b[\w']+\b"
$CadencePolishedTransitions = @(
    "additionally", "moreover", "furthermore", "in addition", "as a result",
    "ultimately", "therefore", "this means", "overall"
)

function Get-CadenceTransitionCount {
    param([string]$Sentence)
    $lower = $Sentence.ToLowerInvariant()
    $count = 0
    foreach ($term in $CadencePolishedTransitions) {
        if ([regex]::IsMatch($lower, "\b$([regex]::Escape($term))\b")) { $count++ }
    }
    return $count
}

function Get-CadenceSameLengthRuns {
    param([int[]]$Lengths)
    $runs = 0
    $current = 1
    for ($i = 1; $i -lt $Lengths.Count; $i++) {
        if ([math]::Abs($Lengths[$i - 1] - $Lengths[$i]) -le 2) { $current++ }
        else { if ($current -ge 3) { $runs++ }; $current = 1 }
    }
    if ($current -ge 3) { $runs++ }
    return $runs
}

function Get-CadenceScore {
    param([string]$SampleId, [string]$Text)
    $sentenceRows = Split-Sentence $Text
    $lengths = @($sentenceRows | ForEach-Object { Get-WordCount $_ $CadenceWordPattern })
    $tokenCount = 0; foreach ($l in $lengths) { $tokenCount += $l }
    $average = if ($lengths.Count -gt 0) { Get-Mean ([double[]]$lengths) } else { 0.0 }
    $deviation = if ($lengths.Count -gt 1) { Get-PopulationStdev ([double[]]$lengths) } else { 0.0 }
    $coefficient = if ($average) { $deviation / $average } else { 0.0 }

    $transitions = 0
    foreach ($s in $sentenceRows) { $transitions += Get-CadenceTransitionCount $s }

    $startCounts = @{}
    foreach ($s in $sentenceRows) {
        $w = @([regex]::Matches($s.ToLowerInvariant(), $CadenceWordPattern) | ForEach-Object { $_.Value } | Select-Object -First 2)
        $start = ($w -join ' ')
        if ($startCounts.ContainsKey($start)) { $startCounts[$start]++ } else { $startCounts[$start] = 1 }
    }
    $repeatedStarts = [ordered]@{}
    foreach ($key in $startCounts.Keys) { if ($key -and $startCounts[$key] -gt 1) { $repeatedStarts[$key] = $startCounts[$key] } }
    $repeatedSum = 0; foreach ($v in $repeatedStarts.Values) { $repeatedSum += $v }

    $monotony = Get-CadenceSameLengthRuns ([int[]]$lengths)
    $longSentenceCount = @($lengths | Where-Object { $_ -gt 34 }).Count

    $roughness = 0
    if ($lengths.Count -ge 4 -and $coefficient -lt 0.28) { $roughness += 2 }
    $roughness += $monotony * 2
    $roughness += $transitions
    $roughness += $repeatedSum
    $roughness += $longSentenceCount

    return [ordered]@{
        sample                            = $SampleId
        sentence_count                    = $sentenceRows.Count
        word_count                        = $tokenCount
        sentence_lengths                  = @($lengths)
        length_cv                         = [math]::Round($coefficient, 3)
        same_length_runs                  = $monotony
        polished_transition_count         = $transitions
        repeated_starts                   = $repeatedStarts
        long_sentence_count               = $longSentenceCount
        cadence_roughness                 = $roughness
        cadence_roughness_per_100_words   = [math]::Round($roughness / [math]::Max(1, $tokenCount) * 100, 3)
    }
}

function Get-CadenceRun {
    param([string]$Corpus, [double]$MaxAverageRoughness, [int]$MaxRowRoughness)
    $scored = [System.Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($row in (ConvertFrom-Jsonl $Corpus)) {
        $index++
        $output = [string](Get-DictValue $row 'output' '')
        if (-not $output.Trim()) { continue }
        $id = [string](Get-DictValue $row 'id' "row-$index")
        $scored.Add((Get-CadenceScore $id $output))
    }
    $rates = @($scored | ForEach-Object { [double]$_['cadence_roughness_per_100_words'] })
    $averageRate = if ($rates.Count) { [math]::Round((Get-Mean ([double[]]$rates)), 3) } else { [double]::PositiveInfinity }
    $rowFailures = @($scored | Where-Object { [int]$_['cadence_roughness'] -gt $MaxRowRoughness } | ForEach-Object { [string]$_['sample'] })

    $failures = @()
    if ($scored.Count -eq 0) { $failures += 'no_rows' }
    if ($averageRate -gt $MaxAverageRoughness) { $failures += 'average_cadence_roughness' }
    if ($rowFailures.Count) { $failures += 'row_cadence_roughness' }

    return [ordered]@{
        generated_at                              = Get-UtcTimestamp
        corpus                                    = $Corpus
        sample_count                              = $scored.Count
        average_cadence_roughness_per_100_words   = $averageRate
        max_average_roughness_per_100_words       = $MaxAverageRoughness
        max_row_roughness                         = $MaxRowRoughness
        row_failures                              = $rowFailures
        failures                                  = $failures
        gate_pass                                 = ($failures.Count -eq 0)
        rows                                      = @($scored.ToArray())
    }
}

function Invoke-MeasureCadenceCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        corpus = 'value'; 'max-average-roughness' = 'value'; 'max-row-roughness' = 'value'
        format = 'value'; 'fail-gate' = 'switch'
    }
    if (-not $opts['corpus']) { [Console]::Error.WriteLine('error: --corpus is required'); exit 2 }
    $maxAvg = if ($null -ne $opts['max-average-roughness']) { [double]$opts['max-average-roughness'] } else { 3.5 }
    $maxRow = if ($null -ne $opts['max-row-roughness']) { [int]$opts['max-row-roughness'] } else { 5 }
    $result = Get-CadenceRun $opts['corpus'] $maxAvg $maxRow
    ConvertTo-StableJson $result
    if ($opts['fail-gate'] -and -not $result['gate_pass']) { exit 2 }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureCadenceCli -Argv $args
}
