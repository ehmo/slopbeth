# Measure-SemanticDrift.ps1 - Detect mechanical semantic-drift risks.
# Port of semantic_drift.py. Dual-purpose: defines Test-ContainsFact
# (importable by Measure-Unsummarizability) and a CLI.

. "$PSScriptRoot/SlopBeth.Common.ps1"

$DriftRequiredFields = @('id', 'input', 'output')
$DriftWordPattern = "\b[\w'-]+\b"
$DriftArticles = [System.Collections.Generic.HashSet[string]]::new([string[]]@('a', 'an', 'the'), [System.StringComparer]::Ordinal)
$DriftNegationTerms = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('no', 'not', 'never', 'cannot', "can't", 'dont', "don't", 'doesnt', "doesn't", 'didnt', "didn't", 'without'),
    [System.StringComparer]::Ordinal)
$DriftReviewGroups = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('negation', 'obligation_permission', 'scope_exclusivity', 'condition_time', 'causality'),
    [System.StringComparer]::Ordinal)
$DriftStrictTaskTypes = [System.Collections.Generic.HashSet[string]]::new([string[]]@('control', 'light_edit'), [System.StringComparer]::Ordinal)
$DriftStrictCategories = [System.Collections.Generic.HashSet[string]]::new([string[]]@('technical_policy', 'human_control', 'dense_risky'), [System.StringComparer]::Ordinal)
$DriftReportLimit = 50

# Marker groups: ordered group name -> array of {Label; Pattern} (hashtables avoid
# PowerShell's nested-array flattening).
$DriftMarkerGroupDefs = @(
    @{ group = 'negation'; markers = @(
            @{ label = 'no'; pattern = '\bno\b' }, @{ label = 'not'; pattern = '\bnot\b' },
            @{ label = 'never'; pattern = '\bnever\b' }, @{ label = 'cannot'; pattern = "\bcannot\b|\bcan't\b" },
            @{ label = 'without'; pattern = '\bwithout\b' }, @{ label = 'unaffected'; pattern = '\bunaffected\b' }) }
    @{ group = 'obligation_permission'; markers = @(
            @{ label = 'must'; pattern = '\bmust\b' }, @{ label = 'may'; pattern = '\bmay\b' },
            @{ label = 'can'; pattern = '\bcan\b' }, @{ label = 'cannot'; pattern = "\bcannot\b|\bcan't\b" },
            @{ label = 'required'; pattern = '\brequir(?:e|es|ed|ing)\b' }, @{ label = 'needs'; pattern = '\bneeds?\b' },
            @{ label = 'should'; pattern = '\bshould\b' }) }
    @{ group = 'scope_exclusivity'; markers = @(
            @{ label = 'only'; pattern = '\bonly\b' }, @{ label = 'all'; pattern = '\ball\b' },
            @{ label = 'every'; pattern = '\bevery\b' }, @{ label = 'each'; pattern = '\beach\b' },
            @{ label = 'any'; pattern = '\bany\b' }, @{ label = 'none'; pattern = '\bnone\b' },
            @{ label = 'except'; pattern = '\bexcept(?:ion|ions)?\b' }) }
    @{ group = 'condition_time'; markers = @(
            @{ label = 'if'; pattern = '\bif\b' }, @{ label = 'unless'; pattern = '\bunless\b' },
            @{ label = 'when'; pattern = '\bwhen\b' }, @{ label = 'before'; pattern = '\bbefore\b' },
            @{ label = 'after'; pattern = '\bafter\b' }, @{ label = 'until'; pattern = '\buntil\b' },
            @{ label = 'from_to'; pattern = '\bfrom\b.{0,80}\bto\b' }, @{ label = 'expire'; pattern = '\bexpir(?:e|es|ed|y|ation)\b' }) }
    @{ group = 'causality'; markers = @(
            @{ label = 'because'; pattern = '\bbecause\b' }, @{ label = 'caused'; pattern = '\bcaus(?:e|es|ed|ing)\b' },
            @{ label = 'due_to'; pattern = '\bdue to\b' }, @{ label = 'therefore'; pattern = '\btherefore\b' },
            @{ label = 'means'; pattern = '\bmeans?\b' }, @{ label = 'so_that'; pattern = '\bso that\b' },
            @{ label = 'failed_because'; pattern = '\bfailed because\b' }) }
    @{ group = 'uncertainty'; markers = @(
            @{ label = 'might'; pattern = '\bmight\b' }, @{ label = 'could'; pattern = '\bcould\b' },
            @{ label = 'likely'; pattern = '\blikely\b' }, @{ label = 'possible'; pattern = '\bpossible\b' },
            @{ label = 'claim'; pattern = "\bclaims?\b|\bclaimed\b" }, @{ label = 'evidence'; pattern = '\bevidence\b|\bprove\b|\bproof\b' }) }
    @{ group = 'promise_intensity'; markers = @(
            @{ label = 'guarantee'; pattern = '\bguarantee(?:d|s)?\b' }, @{ label = 'ensure'; pattern = '\bensure(?:s|d)?\b' },
            @{ label = 'promise'; pattern = '\bpromise(?:d|s)?\b' }, @{ label = 'always'; pattern = '\balways\b' },
            @{ label = 'seamless'; pattern = '\bseamless\b' }, @{ label = 'world_class'; pattern = '\bworld[- ]class\b' }) }
)
$DriftMarkerGroups = [ordered]@{}
foreach ($def in $DriftMarkerGroupDefs) {
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($m in $def.markers) {
        $list.Add([pscustomobject]@{ Label = $m.label; Pattern = [regex]::new($m.pattern, 'IgnoreCase, Singleline') })
    }
    $DriftMarkerGroups[$def.group] = $list.ToArray()
}

function Get-DriftWords {
    param([string]$Text)
    return @([regex]::Matches($Text, $DriftWordPattern) | ForEach-Object { $_.Value.ToLowerInvariant() })
}

function Get-DriftWordVariant {
    param([string]$Word)
    $variants = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    [void]$variants.Add($Word)
    if ($Word -match '^\p{L}+$' -and $Word.Length -gt 2) {
        [void]$variants.Add("${Word}s")
        [void]$variants.Add("${Word}ed")
        [void]$variants.Add("${Word}ing")
        if ($Word.EndsWith('y')) { [void]$variants.Add($Word.Substring(0, $Word.Length - 1) + 'ies') }
        if ($Word.EndsWith('e')) {
            [void]$variants.Add("${Word}d")
            [void]$variants.Add($Word.Substring(0, $Word.Length - 1) + 'ing')
        }
    }
    return @($variants | Sort-Object @{ Expression = { $_.Length }; Descending = $true })
}

function Get-DriftFactPattern {
    param([string]$Fact)
    $factWords = @(Get-DriftWords $Fact)
    if ($factWords.Count -eq 0) { return [regex]::new('$^') }
    $tokens = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $factWords.Count - 1; $i++) { $tokens.Add([regex]::Escape($factWords[$i])) }
    $variants = @(Get-DriftWordVariant $factWords[$factWords.Count - 1])
    $final = (($variants | ForEach-Object { [regex]::Escape($_) }) -join '|')
    $tokens.Add("(?:$final)")
    $escaped = ($tokens -join '[^\w]+')
    return [regex]::new("(?<!\w)$escaped(?!\w)", 'IgnoreCase')
}

function Test-ContainsFact {
    param([string]$Text, [string]$Fact)
    if (-not $Fact.Trim()) { return $false }
    return (Get-DriftFactPattern $Fact).IsMatch($Text)
}

function Test-DriftNegationInFact {
    param([string]$Fact)
    foreach ($w in (Get-DriftWords $Fact)) { if ($DriftNegationTerms.Contains($w)) { return $true } }
    return $false
}

function Test-DriftNegatedFact {
    param([string]$Text, [string]$Fact)
    if (Test-DriftNegationInFact $Fact) { return $false }
    $textWords = @(Get-DriftWords $Text)
    $factWords = @(Get-DriftWords $Fact)
    if ($textWords.Count -eq 0 -or $factWords.Count -eq 0) { return $false }
    $width = $factWords.Count
    for ($index = 0; $index -le $textWords.Count - $width; $index++) {
        $match = $true
        for ($k = 0; $k -lt $width; $k++) { if ($textWords[$index + $k] -cne $factWords[$k]) { $match = $false; break } }
        if (-not $match) { continue }
        $startPrev = [math]::Max(0, $index - 3)
        $previousAnchor = ''
        for ($p = $index - 1; $p -ge $startPrev; $p--) {
            if (-not $DriftArticles.Contains($textWords[$p])) { $previousAnchor = $textWords[$p]; break }
        }
        if ($DriftNegationTerms.Contains($previousAnchor)) { return $true }
    }
    return $false
}

function Get-DriftSchemaError {
    param([object[]]$Rows, [string]$Path)
    $errors = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($row in $Rows) {
        $lineNumber = Get-DictValue $row '_line_number' '?'
        $missing = @($DriftRequiredFields | Where-Object { -not $row.Contains($_) } | Sort-Object -CaseSensitive)
        if ($missing.Count) { $errors.Add("${Path}:${lineNumber}: missing fields $($missing -join ', ')") }
        $sampleId = Get-DictValue $row 'id'
        if ($sampleId -isnot [string] -or -not $sampleId.Trim()) { $errors.Add("${Path}:${lineNumber}: id must be a nonempty string") }
        elseif ($seen.Contains($sampleId)) { $errors.Add("${Path}:${lineNumber}: duplicate id $sampleId") }
        else { [void]$seen.Add($sampleId) }
        foreach ($field in @('input', 'output')) {
            if ($row.Contains($field) -and $row[$field] -isnot [string]) { $errors.Add("${Path}:${lineNumber}: $field must be a string") }
        }
        foreach ($field in @('required_exact_facts', 'forbidden_output_terms')) {
            if ($row.Contains($field)) {
                $value = $row[$field]
                $ok = ($value -is [System.Collections.IEnumerable] -and $value -isnot [string])
                if ($ok) { foreach ($item in $value) { if ($item -isnot [string]) { $ok = $false; break } } }
                if (-not $ok) { $errors.Add("${Path}:${lineNumber}: $field must be a list of strings") }
            }
        }
    }
    return $errors
}

function Get-DriftMarker {
    param([string]$Text)
    $found = [ordered]@{}
    foreach ($group in $DriftMarkerGroups.Keys) {
        $hits = [System.Collections.Generic.List[string]]::new()
        foreach ($pair in $DriftMarkerGroups[$group]) { if ($pair.Pattern.IsMatch($Text)) { $hits.Add($pair.Label) } }
        if ($hits.Count) { $found[$group] = @($hits | Sort-Object -Unique -CaseSensitive) }
    }
    return $found
}

function Get-DriftExactFactMissing {
    param($Row)
    $output = [string](Get-DictValue $Row 'output' '')
    $facts = Get-DictValue $Row 'required_exact_facts' @()
    if ($facts -isnot [System.Collections.IEnumerable] -or $facts -is [string]) { return @() }
    return @($facts | Where-Object { -not (Test-ContainsFact $output ([string]$_)) } | ForEach-Object { [string]$_ })
}

function Get-DriftForbiddenHits {
    param($Row)
    $output = [string](Get-DictValue $Row 'output' '')
    $terms = Get-DictValue $Row 'forbidden_output_terms' @()
    if ($terms -isnot [System.Collections.IEnumerable] -or $terms -is [string]) { return @() }
    return @($terms | Where-Object { Test-ContainsFact $output ([string]$_) } | ForEach-Object { [string]$_ })
}

function Get-DriftNegatedInversions {
    param($Row)
    $inputText = [string](Get-DictValue $Row 'input' '')
    $outputText = [string](Get-DictValue $Row 'output' '')
    $facts = Get-DictValue $Row 'required_exact_facts' @()
    if ($facts -isnot [System.Collections.IEnumerable] -or $facts -is [string]) { return @() }
    $inversions = [System.Collections.Generic.List[string]]::new()
    foreach ($fact in $facts) {
        $factText = [string]$fact
        if (-not (Test-ContainsFact $outputText $factText)) { continue }
        if ((Test-DriftNegatedFact $outputText $factText) -and -not (Test-DriftNegatedFact $inputText $factText)) { $inversions.Add($factText) }
    }
    return @($inversions)
}

function Test-DriftStrictRow {
    param($Row)
    return ($DriftStrictTaskTypes.Contains([string](Get-DictValue $Row 'task_type' '')) -or
        $DriftStrictCategories.Contains([string](Get-DictValue $Row 'category' '')))
}

function Get-DriftGroupDiff {
    param($InputMarkers, $OutputMarkers)
    $inputGroups = [System.Collections.Generic.HashSet[string]]::new([string[]]@($InputMarkers.Keys), [System.StringComparer]::Ordinal)
    $outputGroups = [System.Collections.Generic.HashSet[string]]::new([string[]]@($OutputMarkers.Keys), [System.StringComparer]::Ordinal)
    $missingGroups = @(@($InputMarkers.Keys) | Where-Object { -not $outputGroups.Contains($_) } | Sort-Object -CaseSensitive)
    $addedGroups = @(@($OutputMarkers.Keys) | Where-Object { -not $inputGroups.Contains($_) } | Sort-Object -CaseSensitive)
    $changed = [ordered]@{}
    foreach ($group in (@($InputMarkers.Keys) | Where-Object { $outputGroups.Contains($_) } | Sort-Object -CaseSensitive)) {
        $outSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($OutputMarkers[$group]), [System.StringComparer]::Ordinal)
        $inSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($InputMarkers[$group]), [System.StringComparer]::Ordinal)
        $missingTerms = @(@($InputMarkers[$group]) | Where-Object { -not $outSet.Contains($_) } | Sort-Object -CaseSensitive)
        $addedTerms = @(@($OutputMarkers[$group]) | Where-Object { -not $inSet.Contains($_) } | Sort-Object -CaseSensitive)
        if ($missingTerms.Count -or $addedTerms.Count) {
            $changed[$group] = [ordered]@{ missing_terms = $missingTerms; added_terms = $addedTerms }
        }
    }
    return [ordered]@{ missing_groups = $missingGroups; added_groups = $addedGroups; changed_groups = $changed }
}

function Get-DriftRiskClassification {
    param($Row, $Diff, [string[]]$MissingFacts, [string[]]$ForbiddenTerms, [string[]]$NegatedFacts)
    $strict = Test-DriftStrictRow $Row
    $reasons = [System.Collections.Generic.List[string]]::new()
    $missingGroups = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Diff['missing_groups']), [System.StringComparer]::Ordinal)
    $addedGroups = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Diff['added_groups']), [System.StringComparer]::Ordinal)
    $changedGroups = $Diff['changed_groups']

    if ($MissingFacts.Count) { $reasons.Add('missing_required_exact_facts') }
    if ($ForbiddenTerms.Count) { $reasons.Add('forbidden_output_terms') }
    if ($NegatedFacts.Count) { $reasons.Add('negated_required_exact_facts') }
    if ($strict -and $addedGroups.Contains('promise_intensity')) { $reasons.Add('strict_row_added_promise_intensity') }
    if ($MissingFacts.Count -or $ForbiddenTerms.Count -or $NegatedFacts.Count -or $reasons.Contains('strict_row_added_promise_intensity')) {
        return [pscustomobject]@{ Risk = 'high'; Reasons = @($reasons) }
    }
    if ($strict -and (@($missingGroups) | Where-Object { $DriftReviewGroups.Contains($_) }).Count) { $reasons.Add('strict_row_lost_marker_group') }
    if ($strict -and (@($addedGroups) | Where-Object { $DriftReviewGroups.Contains($_) }).Count) { $reasons.Add('strict_row_added_marker_group') }
    if ($strict) {
        foreach ($group in $changedGroups.Keys) {
            $change = $changedGroups[$group]
            if ($DriftReviewGroups.Contains($group) -and ($change['missing_terms'].Count -or $change['added_terms'].Count)) {
                $reasons.Add("strict_row_changed_${group}_terms"); break
            }
        }
    }
    if ($missingGroups.Count -or $addedGroups.Count -or $changedGroups.Count) {
        if ($reasons.Count) { return [pscustomobject]@{ Risk = 'review'; Reasons = @($reasons) } }
        return [pscustomobject]@{ Risk = 'review'; Reasons = @('marker_distribution_changed') }
    }
    return [pscustomobject]@{ Risk = 'none'; Reasons = @() }
}

function Get-DriftEvaluateRow {
    param($Row)
    $inputText = [string](Get-DictValue $Row 'input' '')
    $outputText = [string](Get-DictValue $Row 'output' '')
    $inputMarkers = Get-DriftMarker $inputText
    $outputMarkers = Get-DriftMarker $outputText
    $diff = Get-DriftGroupDiff $inputMarkers $outputMarkers
    $missingFacts = Get-DriftExactFactMissing $Row
    $forbiddenTerms = Get-DriftForbiddenHits $Row
    $negatedFacts = Get-DriftNegatedInversions $Row
    $classified = Get-DriftRiskClassification $Row $diff ([string[]]$missingFacts) ([string[]]$forbiddenTerms) ([string[]]$negatedFacts)
    $lineNumber = Get-DictValue $Row '_line_number' '?'
    return [ordered]@{
        id                           = [string](Get-DictValue $Row 'id' "line-$lineNumber")
        line_number                  = (Get-DictValue $Row '_line_number')
        category                     = [string](Get-DictValue $Row 'category' '')
        task_type                    = [string](Get-DictValue $Row 'task_type' '')
        strict_row                   = (Test-DriftStrictRow $Row)
        input_markers                = $inputMarkers
        output_markers               = $outputMarkers
        missing_groups               = $diff['missing_groups']
        added_groups                 = $diff['added_groups']
        changed_groups               = $diff['changed_groups']
        missing_required_exact_facts = $missingFacts
        forbidden_output_terms       = $forbiddenTerms
        negated_required_exact_facts = $negatedFacts
        risk                         = $classified.Risk
        reasons                      = @($classified.Reasons)
        input_excerpt                = $inputText.Substring(0, [math]::Min(180, $inputText.Length))
        output_excerpt               = $outputText.Substring(0, [math]::Min(180, $outputText.Length))
    }
}

function Get-DriftScore {
    param([string]$Path)
    $rawRows = ConvertFrom-Jsonl $Path -AttachLineNumber
    $errors = Get-DriftSchemaError $rawRows $Path
    # rows for evaluation: only those with all required fields present
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $rawRows) {
        $missing = @($DriftRequiredFields | Where-Object { -not $row.Contains($_) })
        if ($missing.Count -eq 0) { $rows.Add((Get-DriftEvaluateRow $row)) }
    }
    $riskCounts = @{}
    foreach ($row in $rows) { $r = [string]$row['risk']; if ($riskCounts.ContainsKey($r)) { $riskCounts[$r]++ } else { $riskCounts[$r] = 1 } }
    $riskCountsOrdered = [ordered]@{}
    foreach ($k in @($riskCounts.Keys | Sort-Object -CaseSensitive)) { $riskCountsOrdered[$k] = $riskCounts[$k] }
    $strictCount = @($rows | Where-Object { $_['strict_row'] }).Count
    $highRows = @($rows | Where-Object { $_['risk'] -eq 'high' } | ForEach-Object { $_['id'] })
    $reviewRows = @($rows | Where-Object { $_['risk'] -eq 'review' } | ForEach-Object { $_['id'] })
    $strictReviewRows = @($rows | Where-Object { $_['risk'] -eq 'review' -and $_['strict_row'] } | ForEach-Object { $_['id'] })
    $hardAlarmPass = ($highRows.Count -eq 0 -and $errors.Count -eq 0)
    return [ordered]@{
        generated_at                    = Get-UtcTimestamp
        suite                           = $Path
        sample_count                    = $rawRows.Count
        scored_sample_count             = $rows.Count
        strict_sample_count             = $strictCount
        risk_counts                     = $riskCountsOrdered
        high_risk_ids                   = $highRows
        review_ids                      = $reviewRows
        strict_review_ids               = $strictReviewRows
        review_row_count                = $reviewRows.Count
        strict_review_row_count         = $strictReviewRows.Count
        schema_errors                   = @($errors)
        semantic_marker_hard_alarm_pass = $hardAlarmPass
        semantic_drift_gate_pass        = $hardAlarmPass
        rows                            = @($rows.ToArray())
    }
}

function Invoke-MeasureSemanticDriftCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        corpus = 'value'; format = 'value'; 'json-output' = 'value'; 'markdown-output' = 'value'
        quiet = 'switch'; 'fail-gate' = 'switch'; 'fail-strict-review' = 'switch'
    }
    if (-not $opts['corpus']) { [Console]::Error.WriteLine('error: --corpus is required'); exit 2 }
    $format = if ($opts['format']) { $opts['format'] } else { 'json' }
    $result = Get-DriftScore $opts['corpus']
    if ($opts['json-output']) { Write-TextFile $opts['json-output'] ((ConvertTo-StableJson $result) + "`n") }
    if ($opts['markdown-output']) { Write-TextFile $opts['markdown-output'] (Get-DriftMarkdown $result) }
    if (-not $opts['quiet']) {
        if ($format -eq 'json') { ConvertTo-StableJson $result } else { [Console]::Out.WriteLine((Get-DriftMarkdown $result)) }
    }
    if ($opts['fail-gate'] -and -not $result['semantic_marker_hard_alarm_pass']) { exit 2 }
    if ($opts['fail-strict-review'] -and $result['strict_review_ids'].Count) { exit 2 }
    exit 0
}

function Get-DriftEscapeCell {
    param($Value)
    return ([string]$Value).Replace('|', '\|').Replace("`n", ' ')
}

function Get-DriftFormatChangedGroups {
    param($ChangedGroups)
    if ($ChangedGroups.Count -eq 0) { return 'none' }
    $parts = foreach ($group in $ChangedGroups.Keys) {
        $change = $ChangedGroups[$group]
        $missing = if ($change['missing_terms'].Count) { $change['missing_terms'] -join ', ' } else { 'none' }
        $added = if ($change['added_terms'].Count) { $change['added_terms'] -join ', ' } else { 'none' }
        "$group (missing: $missing; added: $added)"
    }
    return ($parts -join '; ')
}

function Get-DriftMarkdown {
    param($Result)
    $lines = [System.Collections.Generic.List[string]]::new()
    @(
        '# Semantic Drift Report', '',
        "- Generated: $($Result['generated_at'])",
        "- Suite: ``$($Result['suite'])``",
        "- Samples: $($Result['sample_count'])",
        "- Scored samples: $($Result['scored_sample_count'])",
        "- Strict samples: $($Result['strict_sample_count'])",
        "- Hard-alarm gate pass: ``$($Result['semantic_marker_hard_alarm_pass'].ToString().ToLowerInvariant())``",
        "- High-confidence drift rows: ``$($Result['high_risk_ids'].Count)``",
        "- Marker-review rows: ``$($Result['review_row_count'])``",
        "- Strict marker-review rows: ``$($Result['strict_review_row_count'])``", '',
        'Interpretation: this is a marker-level semantic drift review, not proof of semantic equivalence. Passing means no configured high-confidence alarm fired; review rows still need human or judge context.', '',
        '## Risk Counts', '', '| Risk | Count |', '| --- | ---: |'
    ) | ForEach-Object { $lines.Add($_) }
    foreach ($risk in $Result['risk_counts'].Keys) { $lines.Add("| $risk | $($Result['risk_counts'][$risk]) |") }
    if ($Result['schema_errors'].Count) {
        $lines.Add(''); $lines.Add('## Schema Errors'); $lines.Add('')
        foreach ($schemaError in $Result['schema_errors']) { $lines.Add("- $schemaError") }
    }
    $ordered = @($Result['rows'] | Where-Object { $_['risk'] -ne 'none' } | Sort-Object `
            @{ Expression = { if ($_['risk'] -eq 'high') { 0 } else { 1 } } },
        @{ Expression = { -not $_['strict_row'] } },
        @{ Expression = { $_['id'] } })
    $reportRows = @($ordered | Select-Object -First $DriftReportLimit)
    if ($reportRows.Count) {
        $lines.Add(''); $lines.Add('## Review Rows'); $lines.Add('')
        $lines.Add('| Sample | Risk | Strict | Missing groups | Added groups | Changed marker terms | Reasons |')
        $lines.Add('| --- | --- | --- | --- | --- | --- | --- |')
        foreach ($row in $reportRows) {
            $mg = if ($row['missing_groups'].Count) { $row['missing_groups'] -join ', ' } else { 'none' }
            $ag = if ($row['added_groups'].Count) { $row['added_groups'] -join ', ' } else { 'none' }
            $rs = if ($row['reasons'].Count) { $row['reasons'] -join ', ' } else { 'none' }
            $lines.Add("| $(Get-DriftEscapeCell $row['id']) | $(Get-DriftEscapeCell $row['risk']) | $($row['strict_row'].ToString().ToLowerInvariant()) | $(Get-DriftEscapeCell $mg) | $(Get-DriftEscapeCell $ag) | $(Get-DriftEscapeCell (Get-DriftFormatChangedGroups $row['changed_groups'])) | $(Get-DriftEscapeCell $rs) |")
        }
    }
    if ($ordered.Count -gt $DriftReportLimit) { $lines.Add(''); $lines.Add("_Only first $DriftReportLimit non-clean rows shown._") }
    return (($lines -join "`n") + "`n")
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureSemanticDriftCli -Argv $args
}
