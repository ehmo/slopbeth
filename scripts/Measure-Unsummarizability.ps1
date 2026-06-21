# Measure-Unsummarizability.ps1 - Check mechanical unsummarizability signals.
# Port of unsummarizability_check.py. Dot-sources Measure-SemanticDrift for
# Test-ContainsFact.

. "$PSScriptRoot/SlopBeth.Common.ps1"
. "$PSScriptRoot/Measure-SemanticDrift.ps1"

$UnsWordPattern = "\b[\w'-]+\b"
$UnsNumberOrDate = [regex]::new(
    '(?:\b\d+(?:[.,:]\d+)*(?:%| percent|x|ms|s|m|h|kb|mb|gb|tb| users| rows| days| weeks| months| years)?\b|' +
    '\$[0-9][0-9,]*(?:\.\d+)?|' +
    '\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{1,2}\b)', 'IgnoreCase')
$UnsQuoteTerm = [regex]::new('["'']([^"'']{3,80})["'']')
$UnsCapitalizedTerm = [regex]::new('\b(?:[A-Z][a-z0-9]+(?:[- ][A-Z][a-z0-9]+){0,4}|[A-Z]{2,})\b')
$UnsLoadMarkers = [regex]::new(
    '\b(?:because|therefore|so|but|however|although|unless|if|when|while|before|after|' +
    'only|except|must|cannot|can''t|won''t|requires?|means?|causes?|prevents?|forces?|' +
    'risk|cost|gain|loss|tradeoff|constraint|evidence|mechanism|consequence|decision|' +
    'deadline|owner|scope|failure|blocks?|changes?|instead|rather|without)\b', 'IgnoreCase')
$UnsTopicSwapRisk = [regex]::new(
    '\b(?:important|significant|powerful|robust|seamless|dynamic|comprehensive|valuable|' +
    'meaningful|unique|innovative|transform|unlock|empower|enhance|elevate|leverage|' +
    'journey|landscape|ecosystem|alignment|stakeholders|outcomes?|impact|solution|' +
    'experience|capabilities|opportunities|potential)\b', 'IgnoreCase')
$UnsCapitalizedStopwords = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('A', 'An', 'And', 'As', 'At', 'Before', 'But', 'By', 'Do', 'For', 'From', 'I', 'If', 'In',
        'It', 'Keep', 'Make', 'No', 'On', 'Or', 'Say', 'Show', 'So', 'That', 'The', 'Then', 'There',
        'These', 'They', 'This', 'Those', 'To', 'Use', 'We', 'When', 'With', 'Without', 'You', 'Your'),
    [System.StringComparer]::Ordinal)

function Get-UnsCanonical {
    param([string]$Text)
    return ([regex]::Replace($Text.Trim().ToLowerInvariant(), '\s+', ' '))
}

function Get-UnsCapitalizedTerm {
    param([string]$Text)
    $terms = [System.Collections.Generic.List[string]]::new()
    foreach ($m in $UnsCapitalizedTerm.Matches($Text)) {
        $term = $m.Value.Trim()
        if ($UnsCapitalizedStopwords.Contains($term)) { continue }
        $isUpper = ($term -cmatch '[A-Z]') -and ($term -cnotmatch '[a-z]')
        if ($term.Length -lt 3 -and -not $isUpper) { continue }
        $terms.Add($term)
    }
    return @($terms)
}

function Get-UnsSentenceLoadMarkers {
    param([string]$Sentence, [string[]]$Facts)
    $markers = [System.Collections.Generic.List[string]]::new()
    $hasFact = $false
    foreach ($fact in $Facts) { if (Test-ContainsFact $Sentence $fact) { $hasFact = $true; break } }
    if ($hasFact) { $markers.Add('required_fact') }
    if ($UnsNumberOrDate.IsMatch($Sentence)) { $markers.Add('number_or_date') }
    if ((Get-UnsCapitalizedTerm $Sentence).Count) { $markers.Add('named_term') }
    if ($UnsLoadMarkers.IsMatch($Sentence)) { $markers.Add('claim_constraint_or_consequence') }
    if ($Sentence.Contains(':') -or $Sentence.Contains(';')) { $markers.Add('structured_clause') }
    if ($Sentence.Contains('?') -and (Get-WordCount $Sentence $UnsWordPattern) -ge 6) { $markers.Add('active_question') }
    return @($markers)
}

function Get-UnsSentenceLoad {
    param([string]$Sentence, [string[]]$Facts)
    $markerList = @(Get-UnsSentenceLoadMarkers $Sentence $Facts)
    $wordCount = Get-WordCount $Sentence $UnsWordPattern
    $topicSwapTerms = @($UnsTopicSwapRisk.Matches($Sentence) | ForEach-Object { $_.Value })
    $lowLoad = ($wordCount -ge 7 -and $markerList.Count -eq 0)
    $topicSwapRisk = ($topicSwapTerms.Count -gt 0 -and $markerList -notcontains 'number_or_date' -and $markerList -notcontains 'required_fact')
    $uniqueTopic = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($t in $topicSwapTerms) { [void]$uniqueTopic.Add($t.ToLowerInvariant()) }
    return [ordered]@{
        sentence        = $Sentence
        word_count      = $wordCount
        markers         = $markerList
        is_loaded       = ($markerList.Count -gt 0 -or $wordCount -le 6)
        low_load        = $lowLoad
        topic_swap_risk = $topicSwapRisk
        topic_swap_terms = @(@($uniqueTopic) | Sort-Object -CaseSensitive)
    }
}

function Get-UnsIdeaUnits {
    param([string]$Text, [string[]]$Facts)
    $units = [System.Collections.Generic.List[string]]::new()
    foreach ($fact in $Facts) { if (Test-ContainsFact $Text $fact) { $units.Add($fact) } }
    foreach ($m in $UnsNumberOrDate.Matches($Text)) { $units.Add($m.Value) }
    foreach ($m in $UnsQuoteTerm.Matches($Text)) { $units.Add($m.Groups[1].Value.Trim()) }
    foreach ($t in (Get-UnsCapitalizedTerm $Text)) { $units.Add($t) }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $unique = [System.Collections.Generic.List[string]]::new()
    foreach ($unit in $units) {
        $key = Get-UnsCanonical $unit
        if ($key.Length -lt 2 -or $seen.Contains($key)) { continue }
        [void]$seen.Add($key)
        $unique.Add($unit)
    }
    return @($unique)
}

function Get-UnsPrefixHalfText {
    param([string]$Text)
    $tokens = @(Get-Word $Text $UnsWordPattern)
    if ($tokens.Count -eq 0) { return '' }
    $halfCount = [math]::Max(1, [math]::Ceiling($tokens.Count * 0.5))
    return (@($tokens | Select-Object -First $halfCount) -join ' ')
}

function Get-UnsSummaryLoss {
    param([string]$Text, [string[]]$Facts)
    $units = @(Get-UnsIdeaUnits $Text $Facts)
    $wordCount = Get-WordCount $Text $UnsWordPattern
    if ($wordCount -lt 40 -or $units.Count -lt 4) {
        return [ordered]@{
            applicable      = $false
            reason          = 'needs_at_least_40_words_and_4_idea_units'
            word_count      = $wordCount
            idea_unit_count = $units.Count
            loss_ratio      = $null
            lost_units      = @()
        }
    }
    $compressed = Get-UnsCanonical (Get-UnsPrefixHalfText $Text)
    $lost = @($units | Where-Object { -not $compressed.Contains((Get-UnsCanonical $_)) })
    return [ordered]@{
        applicable      = $true
        word_count      = $wordCount
        idea_unit_count = $units.Count
        loss_ratio      = [math]::Round($lost.Count / [math]::Max(1, $units.Count), 3)
        lost_units      = $lost
    }
}

function Get-UnsEvaluateText {
    param([string]$SampleId, [string]$Text, [string[]]$Facts)
    $sentenceRows = @(Split-Sentence $Text | ForEach-Object { Get-UnsSentenceLoad $_ $Facts })
    $sentenceCount = $sentenceRows.Count
    $loadedCount = @($sentenceRows | Where-Object { $_['is_loaded'] }).Count
    $lowLoad = @($sentenceRows | Where-Object { $_['low_load'] })
    $topicSwap = @($sentenceRows | Where-Object { $_['topic_swap_risk'] })
    $loss = Get-UnsSummaryLoss $Text $Facts
    return [ordered]@{
        sample                    = $SampleId
        word_count                = (Get-WordCount $Text $UnsWordPattern)
        sentence_count            = $sentenceCount
        sentence_load_rate        = [math]::Round($loadedCount / [math]::Max(1, $sentenceCount), 3)
        low_load_sentence_count   = $lowLoad.Count
        low_load_sentences        = @(@($lowLoad | Select-Object -First 5) | ForEach-Object { $_['sentence'] })
        topic_swap_risk_count     = $topicSwap.Count
        topic_swap_risk_sentences = @(@($topicSwap | Select-Object -First 5) | ForEach-Object { $_['sentence'] })
        summary_loss              = $loss
    }
}

function Get-UnsRequiredFact {
    param($Record)
    $facts = Get-DictValue $Record 'required_exact_facts' @()
    if ($facts -isnot [System.Collections.IEnumerable] -or $facts -is [string]) { return @() }
    return @($facts | Where-Object { $_ -is [string] -and $_.Trim() })
}

function Get-UnsRecordFromCorpus {
    param([string]$Path)
    $records = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0
    foreach ($record in (ConvertFrom-Jsonl $Path)) {
        $lineNumber++
        $text = Get-DictValue $record 'output' ''
        if ($text -isnot [string] -or -not $text.Trim()) { continue }
        $records.Add([pscustomobject]@{ Id = [string](Get-DictValue $record 'id' "line-$lineNumber"); Text = $text; Facts = (Get-UnsRequiredFact $record) })
    }
    return $records
}

function Get-UnsGateSummary {
    param([object[]]$Rows, [double]$MinSentenceLoadRate, [double]$MinSummaryLossRatio, [bool]$RequireSummaryLoss)
    $sentenceRows = @($Rows | Where-Object { $_['sentence_count'] })
    $loadRates = @($sentenceRows | ForEach-Object { [double]$_['sentence_load_rate'] })
    $summaryRows = @($Rows | Where-Object { $_['summary_loss']['applicable'] })
    $summaryLossRatios = @($summaryRows | ForEach-Object { [double]$_['summary_loss']['loss_ratio'] })
    $lowLoadTotal = 0; foreach ($r in $Rows) { $lowLoadTotal += [int]$r['low_load_sentence_count'] }
    $topicSwapTotal = 0; foreach ($r in $Rows) { $topicSwapTotal += [int]$r['topic_swap_risk_count'] }
    $failures = @()
    $warnings = @()
    $overallSentenceLoadRate = if ($loadRates.Count) { [math]::Round((Get-Mean ([double[]]$loadRates)), 3) } else { 0.0 }
    $avgSummaryLossRatio = if ($summaryLossRatios.Count) { [math]::Round((Get-Mean ([double[]]$summaryLossRatios)), 3) } else { 0.0 }
    if ($Rows.Count -eq 0) { $failures += 'no_rows' }
    if ($overallSentenceLoadRate -lt $MinSentenceLoadRate) { $failures += 'sentence_load_rate_below_threshold' }
    if ($summaryRows.Count -eq 0) {
        $warning = 'no_summary_loss_applicable_rows'
        if ($RequireSummaryLoss) { $failures += $warning } else { $warnings += $warning }
    } elseif ($avgSummaryLossRatio -lt $MinSummaryLossRatio) {
        $failures += 'summary_loss_ratio_below_threshold'
    }
    return [ordered]@{
        rows                          = $Rows.Count
        overall_sentence_load_rate    = $overallSentenceLoadRate
        min_sentence_load_rate        = $MinSentenceLoadRate
        summary_loss_applicable_rows  = $summaryRows.Count
        avg_summary_loss_ratio        = $avgSummaryLossRatio
        min_summary_loss_ratio        = $MinSummaryLossRatio
        low_load_sentence_total       = $lowLoadTotal
        topic_swap_risk_total         = $topicSwapTotal
        warnings                      = $warnings
        failures                      = $failures
        gate_pass                     = ($failures.Count -eq 0)
    }
}

function Get-UnsRun {
    param([object[]]$Records, [double]$MinSentenceLoadRate, [double]$MinSummaryLossRatio, [bool]$RequireSummaryLoss)
    $rows = @($Records | ForEach-Object { Get-UnsEvaluateText $_.Id $_.Text $_.Facts })
    return [ordered]@{
        generated_at = Get-UtcTimestamp
        sample_count = $rows.Count
        gate_summary = (Get-UnsGateSummary $rows $MinSentenceLoadRate $MinSummaryLossRatio $RequireSummaryLoss)
        rows         = $rows
    }
}

function Invoke-MeasureUnsummarizabilityCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        corpus = 'value'; text = 'list'; format = 'value'; 'fail-gate' = 'switch'
        'require-summary-loss' = 'switch'; 'min-sentence-load-rate' = 'value'; 'min-summary-loss-ratio' = 'value'
    }
    $hasCorpus = [bool]$opts['corpus']
    $hasText = ($opts['text'].Count -gt 0)
    if ($hasCorpus -eq $hasText) { [Console]::Error.WriteLine('error: provide exactly one of --corpus or --text'); exit 2 }
    $format = if ($opts['format']) { $opts['format'] } else { 'json' }
    $minLoad = if ($null -ne $opts['min-sentence-load-rate']) { [double]$opts['min-sentence-load-rate'] } else { 0.75 }
    $minLoss = if ($null -ne $opts['min-summary-loss-ratio']) { [double]$opts['min-summary-loss-ratio'] } else { 0.25 }

    if ($hasCorpus) { $records = Get-UnsRecordFromCorpus $opts['corpus'] }
    else { $records = @($opts['text'] | ForEach-Object { [pscustomobject]@{ Id = (Split-Path $_ -Leaf); Text = (Read-TextFile $_); Facts = @() } }) }

    $result = Get-UnsRun ([object[]]$records) $minLoad $minLoss ([bool]$opts['require-summary-loss'])
    if ($format -eq 'json') { ConvertTo-StableJson $result } else { [Console]::Out.Write((Get-UnsMarkdown $result)) }
    if ($opts['fail-gate'] -and -not $result['gate_summary']['gate_pass']) { exit 2 }
    exit 0
}

function Get-UnsMarkdown {
    param($Result)
    $gate = $Result['gate_summary']
    $lines = [System.Collections.Generic.List[string]]::new()
    @(
        '# Unsummarizability Check', '',
        "- Generated: $($Result['generated_at'])",
        "- Samples: $($Result['sample_count'])",
        "- Gate pass: ``$($gate['gate_pass'].ToString().ToLowerInvariant())``",
        "- Sentence-load rate: ``$($gate['overall_sentence_load_rate'])`` (minimum ``$($gate['min_sentence_load_rate'])``)",
        "- Summary-loss rows: ``$($gate['summary_loss_applicable_rows'])``",
        "- Average summary-loss ratio: ``$($gate['avg_summary_loss_ratio'])`` (minimum ``$($gate['min_summary_loss_ratio'])``)",
        "- Low-load sentences: ``$($gate['low_load_sentence_total'])``",
        "- Topic-swap risk sentences: ``$($gate['topic_swap_risk_total'])``",
        "- Warnings: ``$(if ($gate['warnings'].Count) { $gate['warnings'] -join ', ' } else { 'none' })``",
        "- Failures: ``$(if ($gate['failures'].Count) { $gate['failures'] -join ', ' } else { 'none' })``", '',
        '| Sample | Words | Sentences | Load rate | Low-load | Topic-swap risk | Summary-loss |',
        '| --- | ---: | ---: | ---: | ---: | ---: | ---: |'
    ) | ForEach-Object { $lines.Add($_) }
    foreach ($row in $Result['rows']) {
        $loss = $row['summary_loss']
        $lossValue = if (-not $loss['applicable']) { 'n/a' } else { [string]$loss['loss_ratio'] }
        $lines.Add("| $($row['sample']) | $($row['word_count']) | $($row['sentence_count']) | $($row['sentence_load_rate']) | $($row['low_load_sentence_count']) | $($row['topic_swap_risk_count']) | $lossValue |")
    }
    $problemRows = @($Result['rows'] | Where-Object { $_['low_load_sentence_count'] -or $_['topic_swap_risk_count'] } | Select-Object -First 20)
    if ($problemRows.Count) {
        $lines.Add(''); $lines.Add('## Review Flags'); $lines.Add('')
        foreach ($row in $problemRows) {
            $lines.Add("### $($row['sample'])")
            foreach ($s in $row['low_load_sentences']) { $lines.Add("- Low-load: $s") }
            foreach ($s in $row['topic_swap_risk_sentences']) { $lines.Add("- Topic-swap risk: $s") }
            $lines.Add('')
        }
    }
    return (($lines -join "`n").TrimEnd() + "`n")
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureUnsummarizabilityCli -Argv $args
}
