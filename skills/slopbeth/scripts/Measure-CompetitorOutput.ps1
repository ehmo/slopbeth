# Measure-CompetitorOutput.ps1 - Diagnostic self-instrument for competitor
# outputs on shared benchmark cases. Port of competitor_output_score.py.
# Dot-sources the metric scripts and exposes Get-CompetitorOutputScore
# (imported by New-ScoreSnapshot).
#
# The composite score is built from SlopBeth's own instruments, so scoring other
# tools with it is circular: it measures agreement with SlopBeth's rules, not
# writing quality. Ties are reported as ties rather than awarded to whichever
# tool the panel happens to list first, and the gate asserts PARITY with the
# best peer (-MaxAverageDeficit), never superiority. See the Python twin's
# module docstring for the full rationale.

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

function Get-CompNormalizedText {
    # Fold quote characters and list commas so punctuation is not a fact drop.
    param([string]$Text)
    return ([regex]::Replace($Text, '[“”‘’"'',]', '')).ToLowerInvariant()
}

function Get-CompDateVariant {
    # Equivalent spellings of a date-like fact, or $null when it is not a date.
    param([string]$Fact)
    $text = $Fact.Trim()
    $monthNames = [cultureinfo]::InvariantCulture.DateTimeFormat.MonthNames
    $iso = [regex]::Match($text, '^(\d{4})-(\d{2})-(\d{2})$')
    if ($iso.Success) {
        $year = [int]$iso.Groups[1].Value; $month = [int]$iso.Groups[2].Value; $day = [int]$iso.Groups[3].Value
    } else {
        $written = [regex]::Match($text, '^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$')
        if (-not $written.Success) { return $null }
        $monthIndex = -1
        for ($i = 0; $i -lt 12; $i++) {
            if ($monthNames[$i].ToLowerInvariant() -eq $written.Groups[1].Value.ToLowerInvariant()) { $monthIndex = $i; break }
        }
        if ($monthIndex -lt 0) { return $null }
        $year = [int]$written.Groups[3].Value; $month = $monthIndex + 1; $day = [int]$written.Groups[2].Value
    }
    if ($month -lt 1 -or $month -gt 12) { return $null }
    $name = $monthNames[$month - 1].ToLowerInvariant()
    return @(
        ('{0}-{1:d2}-{2:d2}' -f $year, $month, $day)
        ("$name $day $year")
        ("$name $day")
        ("$day $name $year")
    )
}

function Test-CompFactRetained {
    # True when the fact survives in meaning, not merely as an exact substring.
    # A raw substring test counts faithful paraphrase - a reformatted date, a
    # changed quote character, a clause reordered inside a list - as a dropped
    # fact, and every -12 penalty those artifacts produce is unearned.
    param([string]$Fact, [string]$Output)
    $haystack = Get-CompNormalizedText $Output
    if ($haystack.Contains((Get-CompNormalizedText $Fact))) { return $true }
    $variants = Get-CompDateVariant $Fact
    if ($null -ne $variants) {
        foreach ($variant in $variants) { if ($haystack.Contains((Get-CompNormalizedText $variant))) { return $true } }
    }
    $tokens = @([regex]::Matches((Get-CompNormalizedText $Fact), '[a-z0-9]+') | ForEach-Object { $_.Value } | Where-Object { $_.Length -gt 2 })
    if ($tokens.Count -eq 0) { return $false }
    foreach ($token in $tokens) { if (-not $haystack.Contains($token)) { return $false } }
    return $true
}

function Get-CompMissingRequiredFacts {
    param([string[]]$Facts, [string]$Output)
    return @($Facts | Where-Object { -not (Test-CompFactRetained $_ $Output) })
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
    # Circular by construction: every term below is one of SlopBeth's own rules.
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
    param([string]$CorpusPath, [string]$PanelPath, [int]$MinCompetitors, [int]$MinCases, $MaxAverageDeficit, $MinSlopbethCaseWinRate)
    $corpus = Get-CompCorpusById $CorpusPath
    $rowList = [System.Collections.Generic.List[object]]::new()
    # ConvertFrom-Jsonl returns ", $array"; wrapping that in @() nests it instead
    # of enumerating it, so assign it directly.
    $panelRows = ConvertFrom-Jsonl $PanelPath
    foreach ($panelRow in $panelRows) { $rowList.Add((Get-CompScoreRow $panelRow $corpus)) }
    $rows = @($rowList.ToArray())

    $byCompetitor = @{}
    # Ordered so case output follows panel order, matching the Python twin.
    $byCase = [ordered]@{}
    foreach ($row in $rows) {
        $c = [string]$row['competitor']; if (-not $byCompetitor.ContainsKey($c)) { $byCompetitor[$c] = [System.Collections.Generic.List[object]]::new() }; $byCompetitor[$c].Add($row)
        $k = [string]$row['case_id']; if (-not $byCase.Contains($k)) { $byCase[$k] = [System.Collections.Generic.List[object]]::new() }; $byCase[$k].Add($row)
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

    # Ties have no winner. Listing every tied tool keeps a 5-way tie from being
    # read as a SlopBeth win just because SlopBeth appears first in the panel.
    $caseWinners = [ordered]@{}
    foreach ($caseId in @($byCase.Keys)) {
        $top = $null
        foreach ($item in $byCase[$caseId]) { if ($null -eq $top -or [double]$item['score'] -gt $top) { $top = [double]$item['score'] } }
        $caseWinners[$caseId] = @($byCase[$caseId] | Where-Object { [double]$_['score'] -eq $top } | ForEach-Object { [string]$_['competitor'] } | Sort-Object -CaseSensitive)
    }
    $slopbethOutrightWins = 0
    $slopbethTiedTop = 0
    foreach ($caseId in $caseWinners.Keys) {
        $winners = @($caseWinners[$caseId])
        if ($winners.Count -eq 1 -and $winners[0] -eq 'slopbeth') { $slopbethOutrightWins++ }
        elseif ($winners.Count -gt 1 -and $winners -contains 'slopbeth') { $slopbethTiedTop++ }
    }
    $caseCount = [math]::Max(1, $byCase.Count)
    $slopbethCaseWinRate = [math]::Round($slopbethOutrightWins / $caseCount, 3)
    $slopbethTopOrTiedRate = [math]::Round(($slopbethOutrightWins + $slopbethTiedTop) / $caseCount, 3)

    $sourceTypes = [ordered]@{}
    foreach ($panelRow in $panelRows) {
        $st = [string](Get-DictValue $panelRow 'source_type' '')
        if (-not $sourceTypes.Contains($st)) { $sourceTypes[$st] = 0 }
        $sourceTypes[$st]++
    }
    $proxyRows = 0
    foreach ($st in $sourceTypes.Keys) { if ($st -in @('public-rule-proxy', 'shipped-v2-output')) { $proxyRows += $sourceTypes[$st] } }

    $failures = @()
    $deprecatedFlags = @()
    if ($summary.Count -lt $MinCompetitors) { $failures += 'too_few_competitors' }
    if ($byCase.Count -lt $MinCases) { $failures += 'too_few_cases' }
    $deficit = $null
    if ($null -eq $slopbethAverage) { $failures += 'missing_slopbeth' }
    else {
        $deficit = [math]::Round([double]$bestAverage - [double]$slopbethAverage, 2)
        # Parity gate. It always runs; nothing can substitute for it.
        if ($null -ne $MaxAverageDeficit -and $deficit -gt [double]$MaxAverageDeficit) { $failures += 'slopbeth_average_deficit' }
    }
    if ($null -ne $MinSlopbethCaseWinRate) {
        $deprecatedFlags += '--min-slopbeth-case-win-rate is deprecated and non-gating: with near-identical peer outputs almost every case ties, so a per-case win rate measured tie-award order, not quality. Use --max-average-deficit.'
    }
    if (@($rows | Where-Object { $_['schema_failures'].Count }).Count) { $failures += 'row_failures' }

    return [ordered]@{
        generated_at              = Get-UtcTimestamp
        corpus                    = $CorpusPath
        panel                     = $PanelPath
        competitor_count          = $summary.Count
        case_count                = $byCase.Count
        summary                   = $summary
        case_winners              = $caseWinners
        slopbeth_average          = $slopbethAverage
        best_average              = $bestAverage
        slopbeth_average_deficit  = $deficit
        max_average_deficit       = $MaxAverageDeficit
        slopbeth_outright_wins    = $slopbethOutrightWins
        slopbeth_tied_top         = $slopbethTiedTop
        slopbeth_case_wins        = $slopbethOutrightWins
        slopbeth_case_win_rate    = $slopbethCaseWinRate
        slopbeth_top_or_tied_rate = $slopbethTopOrTiedRate
        panel_source_types        = $sourceTypes
        panel_proxy_row_count     = $proxyRows
        deprecated_flags          = $deprecatedFlags
        interpretation            = "Diagnostic only. The composite score is built from Slopbeth's own instruments, so scoring other tools with it is circular and cannot rank writing quality. Ties are reported as ties. Panels whose source_type is public-rule-proxy are text written in-house to another project's published rules, not that project's own output."
        failures                  = $failures
        gate_pass                 = ($failures.Count -eq 0)
        rows                      = $rows
    }
}

function Invoke-MeasureCompetitorOutputCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        corpus = 'value'; panel = 'value'; 'min-competitors' = 'value'; 'min-cases' = 'value'
        'max-average-deficit' = 'value'; 'min-slopbeth-case-win-rate' = 'value'
        format = 'value'; 'fail-gate' = 'switch'
    }
    if (-not $opts['corpus'] -or -not $opts['panel']) { [Console]::Error.WriteLine('error: --corpus and --panel are required'); exit 2 }
    $minCompetitors = if ($null -ne $opts['min-competitors']) { [int]$opts['min-competitors'] } else { 4 }
    $minCases = if ($null -ne $opts['min-cases']) { [int]$opts['min-cases'] } else { 5 }
    $maxDeficit = if ($null -ne $opts['max-average-deficit']) { [double]$opts['max-average-deficit'] } else { $null }
    $minWinRate = if ($null -ne $opts['min-slopbeth-case-win-rate']) { [double]$opts['min-slopbeth-case-win-rate'] } else { $null }
    $result = Get-CompetitorOutputScore $opts['corpus'] $opts['panel'] $minCompetitors $minCases $maxDeficit $minWinRate
    ConvertTo-StableJson $result
    if ($opts['fail-gate'] -and -not $result['gate_pass']) { exit 2 }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureCompetitorOutputCli -Argv $args
}
