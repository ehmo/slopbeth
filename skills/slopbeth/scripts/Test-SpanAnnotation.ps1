# Test-SpanAnnotation.ps1 - Validate span annotations against the v2 benchmark
# corpus. Port of span_annotation_check.py.

. "$PSScriptRoot/SlopBeth.Common.ps1"

$SpanRequiredLabels = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('unsupported_claim', 'generic_reassurance', 'overclaim', 'formula', 'preserved_fact', 'policy_boundary', 'voice_detail'),
    [System.StringComparer]::Ordinal)

function Get-SpanRepr {
    param($Value)
    if ($null -eq $Value) { return 'None' }
    if ($Value -is [string]) { return "'$Value'" }
    return [string]$Value
}

function Get-SpanCorpus {
    param([string]$Path)
    $map = @{}
    foreach ($row in (ConvertFrom-Jsonl $Path)) { $map[[string]$row['id']] = $row }
    return $map
}

function Test-SpanList {
    param($Row, [string]$Field, [string]$SourceText, [string]$LineId, [System.Collections.Generic.List[string]]$Errors)
    $spans = Get-DictValue $Row $Field
    if (($spans -isnot [System.Collections.IEnumerable]) -or ($spans -is [string]) -or (@($spans).Count -eq 0)) {
        $Errors.Add("${LineId}: $Field must contain at least one span")
        return 0
    }
    $checked = 0
    $index = 0
    foreach ($span in $spans) {
        $index++
        if ($span -isnot [System.Collections.IDictionary]) { $Errors.Add("${LineId}: $Field[$index] must be an object"); continue }
        $text = Get-DictValue $span 'text'
        $label = Get-DictValue $span 'label'
        $reason = Get-DictValue $span 'reason'
        if ($text -isnot [string] -or -not $text.Trim()) { $Errors.Add("${LineId}: $Field[$index] missing text"); continue }
        if (-not $SourceText.Contains($text)) { $Errors.Add("${LineId}: $Field[$index] span not found exactly: $(Get-SpanRepr $text)") }
        if (-not ($label -is [string] -and $SpanRequiredLabels.Contains($label))) { $Errors.Add("${LineId}: $Field[$index] unknown label $(Get-SpanRepr $label)") }
        $reasonWords = if ($reason -is [string]) { @($reason -split '\s+' | Where-Object { $_ }) } else { @() }
        if ($reason -isnot [string] -or $reasonWords.Count -lt 3) { $Errors.Add("${LineId}: $Field[$index] needs a concrete reason") }
        $checked++
    }
    return $checked
}

function Get-SpanRun {
    param([string]$CorpusPath, [string]$AnnotationsPath, [int]$MinRows)
    $corpus = Get-SpanCorpus $CorpusPath
    $rows = ConvertFrom-Jsonl $AnnotationsPath
    $errors = [System.Collections.Generic.List[string]]::new()
    $annotatedCases = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $badCount = 0
    $preservedCount = 0
    $labelCounts = [ordered]@{}

    $lineNumber = 0
    foreach ($row in $rows) {
        $lineNumber++
        $caseId = Get-DictValue $row 'case_id'
        $lineId = "${AnnotationsPath}:${lineNumber}"
        if ($caseId -isnot [string] -or -not $corpus.ContainsKey($caseId)) {
            $errors.Add("${lineId}: unknown case_id $(Get-SpanRepr $caseId)")
            continue
        }
        [void]$annotatedCases.Add($caseId)
        $source = $corpus[$caseId]
        $badCount += Test-SpanList $row 'bad_spans' ([string](Get-DictValue $source 'input' '')) $lineId $errors
        $preservedCount += Test-SpanList $row 'preserved_spans' ([string](Get-DictValue $source 'output' '')) $lineId $errors
        foreach ($field in @('bad_spans', 'preserved_spans')) {
            $spans = Get-DictValue $row $field
            if ($spans -is [System.Collections.IEnumerable] -and $spans -isnot [string]) {
                foreach ($span in $spans) {
                    if ($span -is [System.Collections.IDictionary] -and (Get-DictValue $span 'label') -is [string]) {
                        $label = [string]$span['label']
                        if (-not $labelCounts.Contains($label)) { $labelCounts[$label] = 0 }
                        $labelCounts[$label] += 1
                    }
                }
            }
        }
    }

    $failures = @()
    if ($rows.Count -lt $MinRows) { $failures += 'too_few_annotation_rows' }
    if ($annotatedCases.Count -lt $MinRows) { $failures += 'too_few_annotated_cases' }
    if ($badCount -lt $MinRows * 2) { $failures += 'too_few_bad_spans' }
    if ($preservedCount -lt $MinRows * 2) { $failures += 'too_few_preserved_spans' }
    if ($errors.Count) { $failures += 'annotation_errors' }

    return [ordered]@{
        generated_at        = Get-UtcTimestamp
        corpus              = $CorpusPath
        annotations         = $AnnotationsPath
        annotation_rows     = $rows.Count
        annotated_cases     = $annotatedCases.Count
        bad_span_count      = $badCount
        preserved_span_count = $preservedCount
        label_counts        = $labelCounts
        errors              = @(@($errors.ToArray()) | Select-Object -First 50)
        failures            = $failures
        gate_pass           = ($failures.Count -eq 0)
    }
}

function Invoke-TestSpanAnnotationCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{ corpus = 'value'; annotations = 'value'; 'min-rows' = 'value'; format = 'value'; 'fail-gate' = 'switch' }
    if (-not $opts['corpus'] -or -not $opts['annotations']) { [Console]::Error.WriteLine('error: --corpus and --annotations are required'); exit 2 }
    $minRows = if ($null -ne $opts['min-rows']) { [int]$opts['min-rows'] } else { 8 }
    $result = Get-SpanRun $opts['corpus'] $opts['annotations'] $minRows
    ConvertTo-StableJson $result
    if ($opts['fail-gate'] -and -not $result['gate_pass']) { exit 2 }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-TestSpanAnnotationCli -Argv $args
}
