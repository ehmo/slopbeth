# Measure-CompetitorOutput.ps1 - Score competitor outputs on shared benchmark
# cases. Port of competitor_output_score.py. Dot-sources the metric scripts and
# exposes Get-CompetitorOutputScore (imported by New-ScoreSnapshot).

. "$PSScriptRoot/SlopBeth.Common.ps1"
. "$PSScriptRoot/Measure-Deslop.ps1"
. "$PSScriptRoot/Get-DensityReport.ps1"
. "$PSScriptRoot/Compare-Preservation.ps1"
. "$PSScriptRoot/Measure-Signature.ps1"

function Get-CompCorpusById {
    param([string]$Path)
    $map = @{}
    foreach ($row in (ConvertFrom-Jsonl $Path)) { $map[[string]$row['id']] = $row }
    return $map
}

function Get-CompRequiredFact {
    param($Row)
    $facts = Get-DictValue $Row 'required_exact_facts' @()
    if ($facts -isnot [System.Collections.IEnumerable] -or $facts -is [string]) { return @() }
    return @($facts | Where-Object { $_ -is [string] -and $_.Trim() } | ForEach-Object { [string]$_ })
}

function Get-CompForbiddenTerm {
    param($Row)
    $terms = Get-DictValue $Row 'forbidden_output_terms' @()
    if ($terms -isnot [System.Collections.IEnumerable] -or $terms -is [string]) { return @() }
    return @($terms | Where-Object { $_ -is [string] -and $_.Trim() } | ForEach-Object { [string]$_ })
}

function Get-CompMissingRequiredFacts {
    param([string[]]$Facts, [string]$Output)
    $lower = $Output.ToLowerInvariant()
    return @($Facts | Where-Object { -not $lower.Contains($_.ToLowerInvariant()) })
}

function Get-CompForbiddenHits {
    param([string[]]$Terms, [string]$Output)
    $lower = $Output.ToLowerInvariant()
    return @($Terms | Where-Object { $lower.Contains($_.ToLowerInvariant()) })
}

function Get-CompScoreRow {
    param($Row, [hashtable]$Corpus)
    $caseId = [string](Get-DictValue $Row 'case_id' '')
    $competitor = [string](Get-DictValue $Row 'competitor' '')
    $output = [string](Get-DictValue $Row 'output' '')
    $source = if ($Corpus.ContainsKey($caseId)) { $Corpus[$caseId] } else { $null }
    $failures = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $source) {
        $failures.Add('unknown_case'); $inputText = ''; $facts = @(); $forbidden = @()
    } else {
        $inputText = [string](Get-DictValue $source 'input' ''); $facts = Get-CompRequiredFact $source; $forbidden = Get-CompForbiddenTerm $source
    }
    if (-not $competitor) { $failures.Add('missing_competitor') }
    if (-not $output.Trim()) { $failures.Add('missing_output') }

    $preservation = if ($source) { Compare-PreservationToken $inputText $output } else { @{ critical_missing_count = 99 } }
    $missing = @(Get-CompMissingRequiredFacts ([string[]]$facts) $output)
    $forbiddenHits = @(Get-CompForbiddenHits ([string[]]$forbidden) $output)
    $schemaFailures = @($failures)
    $lint = Get-SlopLint $output
    $density = Get-DensityMetric $output
    $signatures = Get-SignatureScore $caseId $output ([string[]]$facts)
    $hard = [int]$signatures['hard_signature_count']
    $totalScore = [int]$lint['slop_score'] +
        [math]::Min(20.0, [double]$density['claim_markers_per_100_words'] * 4) -
        $missing.Count * 12 - $forbiddenHits.Count * 20 -
        [int]$preservation['critical_missing_count'] * 15 - $hard * 8

    return [ordered]@{
        case_id                     = $caseId
        competitor                  = $competitor
        source_type                 = (Get-DictValue $Row 'source_type' '')
        slop_score                  = $lint['slop_score']
        claim_markers_per_100_words = $density['claim_markers_per_100_words']
        hard_signature_count        = $hard
        critical_missing_count      = $preservation['critical_missing_count']
        missing_required_facts      = $missing
        forbidden_output_hits       = $forbiddenHits
        score                       = [math]::Round($totalScore, 2)
        schema_failures             = $schemaFailures
    }
}

function Get-CompetitorOutputScore {
    param([string]$CorpusPath, [string]$PanelPath, [int]$MinCompetitors, [int]$MinCases, $MinSlopbethCaseWinRate)
    $corpus = Get-CompCorpusById $CorpusPath
    $rowList = [System.Collections.Generic.List[object]]::new()
    foreach ($panelRow in (ConvertFrom-Jsonl $PanelPath)) { $rowList.Add((Get-CompScoreRow $panelRow $corpus)) }
    $rows = @($rowList.ToArray())

    $byCompetitor = @{}
    $byCase = @{}
    foreach ($row in $rows) {
        $c = [string]$row['competitor']; if (-not $byCompetitor.ContainsKey($c)) { $byCompetitor[$c] = [System.Collections.Generic.List[object]]::new() }; $byCompetitor[$c].Add($row)
        $k = [string]$row['case_id']; if (-not $byCase.ContainsKey($k)) { $byCase[$k] = [System.Collections.Generic.List[object]]::new() }; $byCase[$k].Add($row)
    }

    $summary = [ordered]@{}
    foreach ($competitor in @($byCompetitor.Keys | Sort-Object -CaseSensitive)) {
        $items = $byCompetitor[$competitor]
        $scores = @($items | ForEach-Object { [double]$_['score'] })
        $missingFacts = 0; $forbiddenHits = 0; $hardSigs = 0
        foreach ($item in $items) { $missingFacts += $item['missing_required_facts'].Count; $forbiddenHits += $item['forbidden_output_hits'].Count; $hardSigs += [int]$item['hard_signature_count'] }
        $summary[$competitor] = [ordered]@{
            case_count            = $items.Count
            average_score         = [math]::Round((Get-Mean ([double[]]$scores)), 2)
            missing_required_facts = $missingFacts
            forbidden_output_hits = $forbiddenHits
            hard_signatures       = $hardSigs
        }
    }

    $slopbethAverage = if ($summary.Contains('slopbeth')) { $summary['slopbeth']['average_score'] } else { $null }
    $bestAverage = 0
    $first = $true
    foreach ($competitor in $summary.Keys) {
        $avg = $summary[$competitor]['average_score']
        if ($first -or $avg -gt $bestAverage) { $bestAverage = $avg; $first = $false }
    }
    if ($summary.Count -eq 0) { $bestAverage = 0 }

    $caseWinners = [ordered]@{}
    foreach ($caseId in $byCase.Keys) {
        $best = $null
        foreach ($item in $byCase[$caseId]) { if ($null -eq $best -or [double]$item['score'] -gt [double]$best['score']) { $best = $item } }
        $caseWinners[$caseId] = [string]$best['competitor']
    }
    $slopbethCaseWins = @($caseWinners.Values | Where-Object { $_ -eq 'slopbeth' }).Count
    $slopbethCaseWinRate = [math]::Round($slopbethCaseWins / [math]::Max(1, $byCase.Count), 3)

    $failures = @()
    if ($summary.Count -lt $MinCompetitors) { $failures += 'too_few_competitors' }
    if ($byCase.Count -lt $MinCases) { $failures += 'too_few_cases' }
    if ($null -eq $slopbethAverage) { $failures += 'missing_slopbeth' }
    elseif ($null -ne $MinSlopbethCaseWinRate) {
        if ($slopbethCaseWinRate -lt [double]$MinSlopbethCaseWinRate) { $failures += 'slopbeth_case_win_rate' }
    } elseif ([double]$slopbethAverage -lt [double]$bestAverage) { $failures += 'slopbeth_not_top_average' }
    if (@($rows | Where-Object { $_['schema_failures'].Count }).Count) { $failures += 'row_failures' }

    return [ordered]@{
        generated_at              = Get-UtcTimestamp
        corpus                    = $CorpusPath
        panel                     = $PanelPath
        competitor_count          = $summary.Count
        case_count                = $byCase.Count
        summary                   = $summary
        case_winners              = $caseWinners
        slopbeth_case_wins        = $slopbethCaseWins
        slopbeth_case_win_rate    = $slopbethCaseWinRate
        min_slopbeth_case_win_rate = $MinSlopbethCaseWinRate
        failures                  = $failures
        gate_pass                 = ($failures.Count -eq 0)
        rows                      = $rows
    }
}

function Invoke-MeasureCompetitorOutputCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        corpus = 'value'; panel = 'value'; 'min-competitors' = 'value'; 'min-cases' = 'value'
        'min-slopbeth-case-win-rate' = 'value'; format = 'value'; 'fail-gate' = 'switch'
    }
    if (-not $opts['corpus'] -or -not $opts['panel']) { [Console]::Error.WriteLine('error: --corpus and --panel are required'); exit 2 }
    $minCompetitors = if ($null -ne $opts['min-competitors']) { [int]$opts['min-competitors'] } else { 4 }
    $minCases = if ($null -ne $opts['min-cases']) { [int]$opts['min-cases'] } else { 5 }
    $minWinRate = if ($null -ne $opts['min-slopbeth-case-win-rate']) { [double]$opts['min-slopbeth-case-win-rate'] } else { $null }
    $result = Get-CompetitorOutputScore $opts['corpus'] $opts['panel'] $minCompetitors $minCases $minWinRate
    ConvertTo-StableJson $result
    if ($opts['fail-gate'] -and -not $result['gate_pass']) { exit 2 }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureCompetitorOutputCli -Argv $args
}
