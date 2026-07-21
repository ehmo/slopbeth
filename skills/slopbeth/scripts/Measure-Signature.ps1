# Measure-Signature.ps1 - Score higher-level AI-writing signature residue.
# Port of signature_score.py. Dual-purpose: defines Get-SignatureScore
# (importable by Measure-CompetitorOutput) and a CLI.

. "$PSScriptRoot/SlopBeth.Common.ps1"

$SigWordPattern = "\b[\w'-]+\b"

$SigPromotionalTerms = @(
    "unlock", "elevate", "empower", "supercharge", "game-changing", "transformative",
    "seamless", "robust", "dynamic", "comprehensive", "meaningful", "valuable",
    "powerful", "innovative", "landscape", "ecosystem", "journey", "tapestry", "realm"
)
$SigBlandTerms = @(
    "better", "clearer", "clarity", "effective", "efficient", "helpful", "improve",
    "improved", "improves", "improvement", "impact", "outcome", "outcomes", "people",
    "process", "results", "stronger", "success", "support", "supports", "teams", "value", "work"
)
$SigFillerPhrases = @(
    "it is important to note", "in today's fast-paced", "in the ever-evolving",
    "at its core", "plays a crucial role", "a crucial role", "more than just",
    "not just", "set the stage", "paving the way", "stands as a testament",
    "the possibilities are endless"
)
$SigCannedOpeners = @(
    [regex]::new('^\s*in (?:today''s|the) .{0,60}\b(?:landscape|world|era)\b', 'IgnoreCase'),
    [regex]::new('^\s*(?:this|these) (?:article|guide|post|piece) (?:will|explores?)\b', 'IgnoreCase'),
    [regex]::new('^\s*(?:when it comes to|there is no denying that)\b', 'IgnoreCase')
)
$SigGenericClosers = @(
    [regex]::new('\b(?:the future|possibilities are endless|paving the way)\b', 'IgnoreCase'),
    [regex]::new('\b(?:in conclusion|ultimately),?\s+(?:this|these|the)\b', 'IgnoreCase'),
    [regex]::new('\bstands as a testament\b', 'IgnoreCase')
)
$SigFormulaPatterns = [ordered]@{
    not_just_but = [regex]::new('\bnot\s+(?:just|only)\b.{0,90}\bbut\b', 'IgnoreCase, Singleline')
    whether_or   = [regex]::new('\bwhether\b.{0,90}\bor\b', 'IgnoreCase, Singleline')
    from_to      = [regex]::new('\bfrom\b.{1,60}\bto\b', 'IgnoreCase, Singleline')
    here_is      = [regex]::new('\bhere''?s (?:why|how|what)\b', 'IgnoreCase')
}
$SigProblemContext = [regex]::new(
    '\b(?:claim|claims|claimed|claiming|copy|draft|pitch|slogan|phrase|word|' +
    'language|should prove|needs proof|needs evidence|before claiming|rather than|' +
    'do not need|does not need|without evidence|unsupported|source|sourced)\b', 'IgnoreCase')
$SigDateOrRangeContext = [regex]::new('\b\d{4}-\d{2}-\d{2}\b|\b\d+(?:\.\d+)?%?\b', 'IgnoreCase')
$SigCapitalizedTerm = [regex]::new('\b(?:[A-Z][a-z0-9]+(?:[- ][A-Z][a-z0-9]+){0,4}|[A-Z]{2,})\b')
$SigCapitalizedStopwords = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('A', 'An', 'And', 'As', 'At', 'But', 'By', 'For', 'From', 'I', 'If', 'In', 'It', 'Its',
        'On', 'Or', 'That', 'The', 'This', 'To', 'We', 'When', 'With', 'Without', 'You'),
    [System.StringComparer]::Ordinal)
$SigLoadMarker = [regex]::new(
    '\b(?:because|but|unless|if|when|except|requires?|must|cannot|risk|cost|' +
    'constraint|evidence|proof|metric|owner|deadline|failure|tradeoff|specific|' +
    'number|example|workflow|source|sourced)\b', 'IgnoreCase')
$SigNumberPattern = [regex]::new('\b\d+(?:[.,:]\d+)*(?:%| percent|x|ms|s|m|h| days| years)?\b', 'IgnoreCase')

function Get-SigCanonical {
    param([string]$Text)
    return ([regex]::Replace($Text.Trim().ToLowerInvariant(), '\s+', ' '))
}

function Get-SigLiteralTerm {
    param([string]$Sentence, [string[]]$Terms)
    $lower = $Sentence.ToLowerInvariant()
    return @($Terms | Where-Object { [regex]::IsMatch($lower, "(?<!\w)$([regex]::Escape($_))(?!\w)") })
}

function Get-SigSentenceAnchorCount {
    param([string]$Sentence, [string[]]$RequiredFacts)
    $lower = Get-SigCanonical $Sentence
    $count = 0
    foreach ($fact in $RequiredFacts) { if ($lower.Contains((Get-SigCanonical $fact))) { $count++ } }
    $count += $SigNumberPattern.Matches($Sentence).Count
    foreach ($m in $SigCapitalizedTerm.Matches($Sentence)) { if (-not $SigCapitalizedStopwords.Contains($m.Value)) { $count++ } }
    $count += $SigLoadMarker.Matches($Sentence).Count
    return $count
}

function Get-SigDocumentAnchorCount {
    param([string]$Text, [string[]]$RequiredFacts)
    $lower = Get-SigCanonical $Text
    $count = 0
    foreach ($fact in $RequiredFacts) { if ($lower.Contains((Get-SigCanonical $fact))) { $count++ } }
    $count += $SigNumberPattern.Matches($Text).Count
    $count += $SigCapitalizedTerm.Matches($Text).Count
    $count += $SigLoadMarker.Matches($Text).Count
    return $count
}

function Get-SigSentenceSignature {
    param([string]$Sentence, [bool]$IsFirst, [bool]$IsLast, [string[]]$RequiredFacts)
    $hits = [System.Collections.Generic.List[string]]::new()
    $reviewHits = [System.Collections.Generic.List[string]]::new()
    $problemContext = $SigProblemContext.IsMatch($Sentence)
    $blandTerms = Get-SigLiteralTerm $Sentence $SigBlandTerms
    $anchors = Get-SigSentenceAnchorCount $Sentence $RequiredFacts

    foreach ($term in (Get-SigLiteralTerm $Sentence $SigPromotionalTerms)) {
        if ($problemContext) { $reviewHits.Add("promotional:$term") } else { $hits.Add("promotional:$term") }
    }
    foreach ($phrase in (Get-SigLiteralTerm $Sentence $SigFillerPhrases)) {
        if ($problemContext) { $reviewHits.Add("filler:$phrase") } else { $hits.Add("filler:$phrase") }
    }
    if ($IsFirst) {
        foreach ($pattern in $SigCannedOpeners) { if ($pattern.IsMatch($Sentence)) { $hits.Add('canned_opener') } }
    }
    if ($IsLast) {
        foreach ($pattern in $SigGenericClosers) {
            if ($pattern.IsMatch($Sentence)) {
                if ($problemContext) { $reviewHits.Add('generic_closer') } else { $hits.Add('generic_closer') }
            }
        }
    }
    foreach ($name in $SigFormulaPatterns.Keys) {
        if (-not $SigFormulaPatterns[$name].IsMatch($Sentence)) { continue }
        if ($name -eq 'from_to' -and $SigDateOrRangeContext.IsMatch($Sentence)) { $reviewHits.Add("formula:$name") }
        elseif ($problemContext) { $reviewHits.Add("formula:$name") }
        else { $hits.Add("formula:$name") }
    }
    if ((Get-WordCount $Sentence $SigWordPattern) -ge 8 -and $blandTerms.Count -ge 2 -and $anchors -eq 0) {
        $hits.Add('bland_clean_sentence')
    }

    return [ordered]@{
        sentence        = $Sentence
        hard_hits       = @($hits | Sort-Object -CaseSensitive)
        review_hits     = @($reviewHits | Sort-Object -CaseSensitive)
        problem_context = $problemContext
        anchor_count    = $anchors
        bland_terms     = @($blandTerms | Sort-Object -CaseSensitive)
    }
}

function Get-SigFirstStart {
    param([string]$Sentence, [int]$Size = 3)
    $tokens = @([regex]::Matches($Sentence, $SigWordPattern) | ForEach-Object { $_.Value.ToLowerInvariant() } | Select-Object -First $Size)
    return ($tokens -join ' ')
}

function ConvertTo-SigCounterItems {
    # Mirrors sorted(Counter(items).items()): list of [key, count] sorted by key.
    param([string[]]$Items)
    $counts = @{}
    foreach ($item in $Items) { if ($counts.ContainsKey($item)) { $counts[$item]++ } else { $counts[$item] = 1 } }
    $pairs = [System.Collections.Generic.List[object]]::new()
    foreach ($key in @($counts.Keys | Sort-Object -CaseSensitive)) { $pairs.Add(@($key, $counts[$key])) }
    return $pairs
}

function Get-SignatureScore {
    param([string]$SampleId, [string]$Text, [string[]]$RequiredFacts = @())
    $sentenceRows = Split-Sentence $Text
    $scoredSentences = @()
    for ($i = 0; $i -lt $sentenceRows.Count; $i++) {
        $scoredSentences += Get-SigSentenceSignature $sentenceRows[$i] ($i -eq 0) ($i -eq ($sentenceRows.Count - 1)) $RequiredFacts
    }
    $hardHits = @($scoredSentences | ForEach-Object { $_['hard_hits'] })
    $reviewHits = @($scoredSentences | ForEach-Object { $_['review_hits'] })
    $tokenCount = Get-WordCount $Text $SigWordPattern
    $hardPer100 = [math]::Round($hardHits.Count / [math]::Max(1, $tokenCount) * 100, 3)
    $anchors = Get-SigDocumentAnchorCount $Text $RequiredFacts
    $anchorRate = [math]::Round($anchors / [math]::Max(1, $tokenCount) * 100, 3)
    $blandCleanCount = @($scoredSentences | Where-Object { $_['hard_hits'] -contains 'bland_clean_sentence' }).Count
    $flagged = @($scoredSentences | Where-Object { $_['hard_hits'].Count -or $_['review_hits'].Count } | Select-Object -First 8)

    return [ordered]@{
        sample                        = $SampleId
        word_count                    = $tokenCount
        sentence_count                = $sentenceRows.Count
        hard_signature_count          = $hardHits.Count
        hard_signatures_per_100_words = $hardPer100
        review_signature_count        = $reviewHits.Count
        bland_clean_sentence_count    = $blandCleanCount
        anchor_count                  = $anchors
        anchor_rate_per_100_words     = $anchorRate
        first_sentence_start          = if ($sentenceRows.Count) { Get-SigFirstStart $sentenceRows[0] } else { '' }
        hard_hits                     = (ConvertTo-SigCounterItems ([string[]]$hardHits))
        review_hits                   = (ConvertTo-SigCounterItems ([string[]]$reviewHits))
        flagged_sentences             = @($flagged)
    }
}

function Get-SigRequiredFact {
    param($Row)
    $facts = Get-DictValue $Row 'required_exact_facts' @()
    if ($facts -isnot [System.Collections.IEnumerable] -or $facts -is [string]) { return @() }
    return @($facts | Where-Object { $_ -is [string] -and $_.Trim() })
}

function Get-SigRecordFromCorpus {
    param([string]$Path)
    $records = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0
    foreach ($row in (ConvertFrom-Jsonl $Path)) {
        $lineNumber++
        $text = Get-DictValue $row 'output' ''
        if ($text -isnot [string] -or -not $text.Trim()) { continue }
        $records.Add([pscustomobject]@{ Id = [string](Get-DictValue $row 'id' "line-$lineNumber"); Text = $text; Facts = (Get-SigRequiredFact $row) })
    }
    return $records
}

function Get-SigGateSummary {
    param([object[]]$Rows, [double]$MaxHardPer100, [int]$MaxRowHardCount, [int]$MaxRowBlandClean, [int]$MaxRepeatedStart)
    $hardRates = @($Rows | ForEach-Object { [double]$_['hard_signatures_per_100_words'] })
    $rowHardFailures = @($Rows | Where-Object { [int]$_['hard_signature_count'] -gt $MaxRowHardCount } | ForEach-Object { [string]$_['sample'] })
    $blandCleanFailures = @($Rows | Where-Object { [int]$_['bland_clean_sentence_count'] -gt $MaxRowBlandClean } | ForEach-Object { [string]$_['sample'] })

    $startCounts = @{}
    $startOrder = [System.Collections.Generic.List[string]]::new()
    foreach ($row in $Rows) {
        $start = [string]$row['first_sentence_start']
        if (-not $start.Trim()) { continue }
        if ($startCounts.ContainsKey($start)) { $startCounts[$start]++ } else { $startCounts[$start] = 1; $startOrder.Add($start) }
    }
    $repeatedStartFailures = [ordered]@{}
    foreach ($start in @($startCounts.Keys | Sort-Object -CaseSensitive)) {
        $words = @($start -split '\s+' | Where-Object { $_ })
        if ($startCounts[$start] -gt $MaxRepeatedStart -and $words.Count -ge 2) { $repeatedStartFailures[$start] = $startCounts[$start] }
    }
    # most_common(10): count desc, ties keep first-seen order.
    $ordered = @($startOrder | Sort-Object @{ Expression = { $startCounts[$_] }; Descending = $true })
    $topRepeated = [System.Collections.Generic.List[object]]::new()
    foreach ($start in (@($ordered) | Select-Object -First 10)) { $topRepeated.Add(@($start, $startCounts[$start])) }

    $averageHardPer100 = if ($hardRates.Count) { [math]::Round((Get-Mean ([double[]]$hardRates)), 3) } else { 0.0 }
    $failures = @()
    if ($Rows.Count -eq 0) { $failures += 'no_rows' }
    if ($averageHardPer100 -gt $MaxHardPer100) { $failures += 'average_hard_signature_rate' }
    if ($rowHardFailures.Count) { $failures += 'row_hard_signature_count' }
    if ($blandCleanFailures.Count) { $failures += 'bland_clean_sentence_count' }
    if ($repeatedStartFailures.Count) { $failures += 'repeated_sentence_start' }

    $totalHard = 0; foreach ($r in $Rows) { $totalHard += [int]$r['hard_signature_count'] }
    $totalReview = 0; foreach ($r in $Rows) { $totalReview += [int]$r['review_signature_count'] }

    return [ordered]@{
        rows                                = $Rows.Count
        average_hard_signatures_per_100_words = $averageHardPer100
        max_hard_signatures_per_100_words   = $MaxHardPer100
        max_row_hard_signature_count        = $MaxRowHardCount
        row_hard_signature_failures         = $rowHardFailures
        max_row_bland_clean_sentences       = $MaxRowBlandClean
        bland_clean_sentence_failures       = $blandCleanFailures
        max_repeated_start                  = $MaxRepeatedStart
        repeated_start_failures             = $repeatedStartFailures
        top_repeated_starts                 = @($topRepeated.ToArray())
        total_hard_signatures               = $totalHard
        total_review_signatures             = $totalReview
        failures                            = $failures
        gate_pass                           = ($failures.Count -eq 0)
    }
}

function Get-SignatureRun {
    param([object[]]$Records, [double]$MaxHardPer100, [int]$MaxRowHardCount, [int]$MaxRowBlandClean, [int]$MaxRepeatedStart)
    $rows = @($Records | ForEach-Object { Get-SignatureScore $_.Id $_.Text $_.Facts })
    return [ordered]@{
        generated_at = Get-UtcTimestamp
        sample_count = $rows.Count
        gate_summary = (Get-SigGateSummary $rows $MaxHardPer100 $MaxRowHardCount $MaxRowBlandClean $MaxRepeatedStart)
        rows         = $rows
    }
}

function Invoke-MeasureSignatureCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        corpus = 'value'; text = 'list'; format = 'value'; 'fail-gate' = 'switch'
        'max-hard-per-100' = 'value'; 'max-row-hard-count' = 'value'
        'max-row-bland-clean-sentences' = 'value'; 'max-repeated-start' = 'value'
    }
    $hasCorpus = [bool]$opts['corpus']
    $hasText = ($opts['text'].Count -gt 0)
    if ($hasCorpus -eq $hasText) { [Console]::Error.WriteLine('error: provide exactly one of --corpus or --text'); exit 2 }
    $format = if ($opts['format']) { $opts['format'] } else { 'json' }
    $maxHard = if ($null -ne $opts['max-hard-per-100']) { [double]$opts['max-hard-per-100'] } else { 0.55 }
    $maxRowHard = if ($null -ne $opts['max-row-hard-count']) { [int]$opts['max-row-hard-count'] } else { 2 }
    $maxBland = if ($null -ne $opts['max-row-bland-clean-sentences']) { [int]$opts['max-row-bland-clean-sentences'] } else { 1 }
    $maxRepeated = if ($null -ne $opts['max-repeated-start']) { [int]$opts['max-repeated-start'] } else { 8 }

    if ($hasCorpus) { $records = Get-SigRecordFromCorpus $opts['corpus'] }
    else { $records = @($opts['text'] | ForEach-Object { [pscustomobject]@{ Id = (Split-Path $_ -Leaf); Text = (Read-TextFile $_); Facts = @() } }) }

    $result = Get-SignatureRun ([object[]]$records) $maxHard $maxRowHard $maxBland $maxRepeated
    if ($format -eq 'json') { ConvertTo-StableJson $result }
    else { Write-SignatureMarkdown $result }
    if ($opts['fail-gate'] -and -not $result['gate_summary']['gate_pass']) { exit 2 }
    exit 0
}

function Write-SignatureMarkdown {
    param($Result)
    $gate = $Result['gate_summary']
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Signature Score'); $lines.Add('')
    $lines.Add("- Generated: $($Result['generated_at'])")
    $lines.Add("- Samples: $($Result['sample_count'])")
    $lines.Add("- Gate pass: ``$($gate['gate_pass'].ToString().ToLowerInvariant())``")
    $lines.Add("- Average hard signatures per 100 words: ``$($gate['average_hard_signatures_per_100_words'])`` (maximum ``$($gate['max_hard_signatures_per_100_words'])``)")
    $lines.Add("- Total hard signatures: ``$($gate['total_hard_signatures'])``")
    $lines.Add("- Total review signatures: ``$($gate['total_review_signatures'])``")
    $rowHard = if ($gate['row_hard_signature_failures'].Count) { $gate['row_hard_signature_failures'] -join ', ' } else { 'none' }
    $lines.Add("- Row hard-signature failures: ``$rowHard``")
    $blandF = if ($gate['bland_clean_sentence_failures'].Count) { $gate['bland_clean_sentence_failures'] -join ', ' } else { 'none' }
    $lines.Add("- Bland-clean failures: ``$blandF``")
    $repF = if ($gate['repeated_start_failures'].Count) { (ConvertTo-StableJson $gate['repeated_start_failures']) } else { 'none' }
    $lines.Add("- Repeated-start failures: ``$repF``")
    $fail = if ($gate['failures'].Count) { $gate['failures'] -join ', ' } else { 'none' }
    $lines.Add("- Failures: ``$fail``")
    $lines.Add(''); $lines.Add('## Top Repeated Starts'); $lines.Add(''); $lines.Add('| Start | Count |'); $lines.Add('| --- | ---: |')
    foreach ($pair in $gate['top_repeated_starts']) { $lines.Add("| $($pair[0]) | $($pair[1]) |") }
    $lines.Add(''); $lines.Add('## Rows'); $lines.Add('')
    $lines.Add('| Sample | Words | Hard | Hard/100 | Review | Anchors/100 | First start |')
    $lines.Add('| --- | ---: | ---: | ---: | ---: | ---: | --- |')
    foreach ($row in $Result['rows']) {
        $lines.Add("| $($row['sample']) | $($row['word_count']) | $($row['hard_signature_count']) | $($row['hard_signatures_per_100_words']) | $($row['review_signature_count']) | $($row['anchor_rate_per_100_words']) | $($row['first_sentence_start']) |")
    }
    [Console]::Out.WriteLine(($lines -join "`n"))
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureSignatureCli -Argv $args
}
