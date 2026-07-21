# Run-Benchmark.ps1 - Run local deslop benchmark suites.
# Port of run_benchmark.py. Dot-sources Measure-Deslop, Get-DensityReport,
# Compare-Preservation.

. "$PSScriptRoot/SlopBeth.Common.ps1"
. "$PSScriptRoot/Measure-Deslop.ps1"
. "$PSScriptRoot/Get-DensityReport.ps1"
. "$PSScriptRoot/Compare-Preservation.ps1"

$BenchRequiredCorpusFields = @('id', 'category', 'task_type', 'risk', 'input', 'output',
    'preserved_facts', 'required_exact_facts', 'voice_notes', 'expected_edit_depth', 'reviewer_notes')
$BenchKnownCategories = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('ai_marketing', 'ai_essay', 'technical_policy', 'email_memo_support', 'paired_voice',
        'human_control', 'dense_risky', 'adversarial_no_phrase'), [System.StringComparer]::Ordinal)
$BenchKnownEditDepths = [System.Collections.Generic.HashSet[string]]::new([string[]]@('none', 'light', 'medium', 'heavy'), [System.StringComparer]::Ordinal)
$BenchKnownTaskTypes = [System.Collections.Generic.HashSet[string]]::new([string[]]@('faithful_rewrite', 'critique', 'rewrite_with_context', 'control'), [System.StringComparer]::Ordinal)
$BenchContextTaskTypes = [System.Collections.Generic.HashSet[string]]::new([string[]]@('critique', 'rewrite_with_context', 'control'), [System.StringComparer]::Ordinal)

function Get-BenchSha256 {
    param([string]$Text)
    $bytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Text))
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

function Get-BenchRowForPair {
    param([string]$SampleName, [string]$Original, [AllowNull()]$Rewrite)
    $row = [ordered]@{
        sample        = $SampleName
        input_sha256  = (Get-BenchSha256 $Original)
        input_lint    = (Get-SlopLint $Original)
        input_density = (Get-DensityMetric $Original)
    }
    if ($null -ne $Rewrite) {
        $row['output_sha256'] = (Get-BenchSha256 $Rewrite)
        $row['output_lint'] = (Get-SlopLint $Rewrite)
        $row['density_pair'] = (Get-DensityReportData $Original $Rewrite)
        $row['preservation'] = (Compare-PreservationToken $Original $Rewrite)
    }
    return $row
}

function Get-BenchLengthBucket {
    param([string]$Text)
    $count = Get-WordCount $Text
    if ($count -lt 120) { return 'short' }
    if ($count -lt 400) { return 'medium' }
    return 'long'
}

function Get-BenchDeclaredFactCheck {
    param([string[]]$Facts, [string]$Rewrite)
    $lower = $Rewrite.ToLowerInvariant()
    $missing = @($Facts | Where-Object { -not $lower.Contains($_.ToLowerInvariant()) })
    return [ordered]@{
        declared_count        = $Facts.Count
        missing_declared_facts = $missing
        missing_declared_count = $missing.Count
        exact_match_only      = $true
    }
}

function Get-BenchUnsupportedAdditions {
    param($Preservation, [bool]$AllowAddedFacts)
    if ($AllowAddedFacts) { return [ordered]@{ count = 0; items = [ordered]@{}; allowed = $true } }
    $added = Get-DictValue $Preservation 'added' @{}
    $items = [ordered]@{}
    $total = 0
    foreach ($key in @('urls', 'emails', 'numbers', 'dates', 'quoted_terms')) {
        $values = Get-DictValue $added $key @()
        if ($values -and @($values).Count) { $items[$key] = @($values); $total += @($values).Count }
    }
    return [ordered]@{ count = $total; items = $items; allowed = $false }
}

function Get-BenchCorpusSchemaError {
    param($Record, [int]$LineNumber, [System.Collections.Generic.HashSet[string]]$SeenIds)
    $errors = [System.Collections.Generic.List[string]]::new()
    $missing = @($BenchRequiredCorpusFields | Where-Object { -not $Record.Contains($_) } | Sort-Object -CaseSensitive)
    if ($missing.Count) { $errors.Add("line ${LineNumber}: missing fields $($missing -join ', ')") }
    $sampleId = Get-DictValue $Record 'id'
    if ($sampleId -isnot [string] -or -not $sampleId) { $errors.Add("line ${LineNumber}: id must be a nonempty string") }
    elseif ($SeenIds.Contains($sampleId)) { $errors.Add("line ${LineNumber}: duplicate id $sampleId") }
    $category = Get-DictValue $Record 'category'
    if (-not ($category -is [string] -and $BenchKnownCategories.Contains($category))) { $errors.Add("line ${LineNumber}: unknown category $(Format-BenchRepr $category)") }
    $depth = Get-DictValue $Record 'expected_edit_depth'
    if (-not ($depth -is [string] -and $BenchKnownEditDepths.Contains($depth))) { $errors.Add("line ${LineNumber}: unknown expected_edit_depth $(Format-BenchRepr $depth)") }
    $taskType = Get-DictValue $Record 'task_type'
    if (-not ($taskType -is [string] -and $BenchKnownTaskTypes.Contains($taskType))) { $errors.Add("line ${LineNumber}: unknown task_type $(Format-BenchRepr $taskType)") }
    if (-not (Test-BenchStringList (Get-DictValue $Record 'preserved_facts'))) { $errors.Add("line ${LineNumber}: preserved_facts must be a list of nonempty strings") }
    if (-not (Test-BenchStringList (Get-DictValue $Record 'required_exact_facts'))) { $errors.Add("line ${LineNumber}: required_exact_facts must be a list of nonempty strings") }
    return $errors
}

function Test-BenchStringList {
    param($Value)
    if ($Value -isnot [System.Collections.IEnumerable] -or $Value -is [string]) { return $false }
    foreach ($item in $Value) { if ($item -isnot [string] -or -not $item) { return $false } }
    return $true
}

function Format-BenchRepr {
    param($Value)
    if ($null -eq $Value) { return 'None' }
    if ($Value -is [string]) { return "'$Value'" }
    return [string]$Value
}

function Get-BenchRunCorpus {
    param([string]$CorpusPath)
    $rows = [System.Collections.Generic.List[object]]::new()
    $schemaErrors = [System.Collections.Generic.List[string]]::new()
    $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadAllLines($CorpusPath, [System.Text.UTF8Encoding]::new($false))) {
        $lineNumber++
        if (-not $line.Trim()) { continue }
        $record = $line | ConvertFrom-Json -AsHashtable -Depth 100
        foreach ($e in (Get-BenchCorpusSchemaError $record $lineNumber $seenIds)) { $schemaErrors.Add($e) }
        $idVal = Get-DictValue $record 'id'
        if ($idVal -is [string]) { [void]$seenIds.Add($idVal) }
        if (-not $record.Contains('input')) { throw "${CorpusPath}:${lineNumber} missing input" }
        $sampleId = Get-DictValue $record 'id' "line-$lineNumber"
        $row = Get-BenchRowForPair $sampleId ([string]$record['input']) (Get-DictValue $record 'output')
        $exactFacts = Get-DictValue $record 'required_exact_facts' @()
        $taskType = Get-DictValue $record 'task_type' ''
        if ($row.Contains('preservation') -and ($exactFacts -is [System.Collections.IEnumerable] -and $exactFacts -isnot [string])) {
            $row['declared_fact_check'] = Get-BenchDeclaredFactCheck (@($exactFacts | ForEach-Object { [string]$_ })) ([string](Get-DictValue $record 'output' ''))
            $allow = ([bool](Get-DictValue $record 'allow_added_facts' $false)) -or $BenchContextTaskTypes.Contains([string]$taskType)
            $row['unsupported_additions'] = Get-BenchUnsupportedAdditions $row['preservation'] $allow
        }
        $row['category'] = Get-DictValue $record 'category' 'uncategorized'
        $row['task_type'] = $taskType
        $row['risk'] = Get-DictValue $record 'risk' ''
        $row['expected_edit_depth'] = Get-DictValue $record 'expected_edit_depth' ''
        $row['preserved_facts'] = @(Get-DictValue $record 'preserved_facts' @())
        $row['required_exact_facts'] = @(Get-DictValue $record 'required_exact_facts' @())
        $row['voice_notes'] = Get-DictValue $record 'voice_notes' ''
        $row['reviewer_notes'] = Get-DictValue $record 'reviewer_notes' ''
        $row['length_bucket'] = Get-BenchLengthBucket ([string]$record['input'])
        $rows.Add($row)
    }
    $rowArray = @($rows.ToArray())
    $gateSummary = Get-BenchReleaseGateSummary $rowArray (@($schemaErrors.ToArray()))
    return [ordered]@{
        generated_at      = Get-UtcTimestamp
        mode              = 'corpus'
        corpus            = $CorpusPath
        sample_count      = $rowArray.Count
        rows              = $rowArray
        category_summary  = (Get-BenchCategorySummary $rowArray)
        gate_summary      = $gateSummary
        release_gate_pass = $gateSummary['release_gate_pass']
    }
}

function Get-BenchRunDirectory {
    param([string]$Inputs, [AllowNull()][string]$Outputs)
    $samples = @(Get-ChildItem -LiteralPath $Inputs -Filter '*.txt' -File | Sort-Object Name)
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($sample in $samples) {
        $original = Read-TextFile $sample.FullName
        $rewrite = $null
        if ($Outputs) {
            $rewritePath = Join-Path $Outputs $sample.Name
            if (Test-Path -LiteralPath $rewritePath) { $rewrite = Read-TextFile $rewritePath }
        }
        $rows.Add((Get-BenchRowForPair $sample.Name $original $rewrite))
    }
    return [ordered]@{
        generated_at = Get-UtcTimestamp
        mode         = 'directory'
        input_dir    = $Inputs
        output_dir   = if ($Outputs) { $Outputs } else { $null }
        sample_count = $rows.Count
        rows         = @($rows.ToArray())
    }
}

function Get-BenchCategorySummary {
    param([object[]]$Rows)
    $summary = [ordered]@{}
    foreach ($row in $Rows) {
        $category = [string](Get-DictValue $row 'category' 'uncategorized')
        if (-not $summary.Contains($category)) {
            $summary[$category] = [ordered]@{ count = 0; avg_input_slop = 0.0; avg_output_slop = 0.0; critical_missing = 0 }
        }
        $bucket = $summary[$category]
        $bucket['count'] += 1
        $bucket['avg_input_slop'] += $row['input_lint']['slop_score']
        $outputLint = Get-DictValue $row 'output_lint'
        if ($outputLint) { $bucket['avg_output_slop'] += $outputLint['slop_score'] }
        $preservation = Get-DictValue $row 'preservation'
        if ($preservation) { $bucket['critical_missing'] += $preservation['critical_missing_count'] }
    }
    foreach ($category in $summary.Keys) {
        $bucket = $summary[$category]
        $count = [math]::Max(1, [int]$bucket['count'])
        $bucket['avg_input_slop'] = [math]::Round([double]$bucket['avg_input_slop'] / $count, 2)
        $bucket['avg_output_slop'] = [math]::Round([double]$bucket['avg_output_slop'] / $count, 2)
    }
    return $summary
}

function Get-BenchReleaseGateSummary {
    param([object[]]$Rows, [string[]]$SchemaErrors)
    $lengthCounts = [ordered]@{ short = 0; medium = 0; long = 0 }
    $missingOutputs = 0; $criticalMissing = 0; $missingDeclared = 0; $unsupportedAdded = 0
    $taskCounts = [ordered]@{}
    foreach ($row in $Rows) {
        $bucket = [string](Get-DictValue $row 'length_bucket' 'short')
        $lengthCounts[$bucket] += 1
        $taskType = [string](Get-DictValue $row 'task_type' 'unknown')
        if (-not $taskCounts.Contains($taskType)) { $taskCounts[$taskType] = 0 }
        $taskCounts[$taskType] += 1
        if (-not $row.Contains('output_lint')) { $missingOutputs += 1 }
        $preservation = Get-DictValue $row 'preservation'
        if ($preservation) { $criticalMissing += $preservation['critical_missing_count'] }
        $declared = Get-DictValue $row 'declared_fact_check'
        if ($declared) { $missingDeclared += $declared['missing_declared_count'] }
        $unsupported = Get-DictValue $row 'unsupported_additions'
        if ($unsupported) { $unsupportedAdded += $unsupported['count'] }
    }
    $failures = @()
    if ($SchemaErrors.Count) { $failures += 'schema_errors' }
    if ($Rows.Count -lt 60) { $failures += 'sample_count_below_60' }
    if ($missingOutputs) { $failures += 'missing_outputs' }
    if ($lengthCounts['medium'] -eq 0 -or $lengthCounts['long'] -eq 0) { $failures += 'missing_medium_or_long_samples' }
    if ($criticalMissing) { $failures += 'critical_missing_facts' }
    if ($missingDeclared) { $failures += 'missing_declared_facts' }
    if ($unsupportedAdded) { $failures += 'unsupported_added_facts' }
    return [ordered]@{
        schema_errors          = @($SchemaErrors)
        length_counts          = $lengthCounts
        task_counts            = $taskCounts
        missing_outputs        = $missingOutputs
        critical_missing       = $criticalMissing
        missing_declared_facts = $missingDeclared
        unsupported_added_facts = $unsupportedAdded
        failures               = $failures
        release_gate_pass      = ($failures.Count -eq 0)
    }
}

function Get-BenchSummaryResult {
    param($Result)
    $copy = [ordered]@{}
    foreach ($key in $Result.Keys) { if ($key -ne 'rows') { $copy[$key] = $Result[$key] } }
    return $copy
}

function Invoke-RunBenchmarkCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        inputs = 'value'; outputs = 'value'; corpus = 'value'; format = 'value'
        'summary-only' = 'switch'; 'fail-release-gate' = 'switch'
    }
    $hasCorpus = [bool]$opts['corpus']
    $hasInputs = [bool]$opts['inputs']
    if ($hasCorpus -eq $hasInputs) { [Console]::Error.WriteLine('error: provide exactly one of --corpus or --inputs'); exit 2 }
    $format = if ($opts['format']) { $opts['format'] } else { 'json' }
    if ($hasCorpus) { $result = Get-BenchRunCorpus $opts['corpus'] }
    else { $result = Get-BenchRunDirectory $opts['inputs'] $opts['outputs'] }
    $outputResult = if ($opts['summary-only']) { Get-BenchSummaryResult $result } else { $result }
    if ($format -eq 'json') { ConvertTo-StableJson $outputResult } else { [Console]::Out.WriteLine((Get-BenchMarkdown $outputResult)) }
    if ($opts['fail-release-gate'] -and -not (Get-DictValue $result 'release_gate_pass' $true)) { exit 2 }
    exit 0
}

function Get-BenchMarkdown {
    param($Result)
    $lines = [System.Collections.Generic.List[string]]::new()
    @(
        '# Slopbeth Benchmark Run', '',
        "- Generated: $($Result['generated_at'])",
        "- Mode: ``$(Get-DictValue $Result 'mode' 'directory')``",
        "- Samples: $($Result['sample_count'])",
        "- Inputs: ``$(if ($Result.Contains('input_dir')) { $Result['input_dir'] } else { Get-DictValue $Result 'corpus' })``",
        "- Outputs: ``$(Get-DictValue $Result 'output_dir')``"
    ) | ForEach-Object { $lines.Add($_) }
    if ($Result.Contains('rows')) {
        $lines.Add(''); $lines.Add('| Sample | Category | Input slop | Output slop | Suspects delta | Claim density delta | Critical missing |')
        $lines.Add('| --- | --- | ---: | ---: | ---: | ---: | ---: |')
        foreach ($row in $Result['rows']) {
            $inputLint = $row['input_lint']
            $outputLint = Get-DictValue $row 'output_lint'
            $category = Get-DictValue $row 'category' ''
            if ($outputLint) {
                $suspectsDelta = $outputLint['suspect_total'] - $inputLint['suspect_total']
                $densityDelta = $row['density_pair']['claim_density_delta']
                $missing = $row['preservation']['critical_missing_count']
                $lines.Add("| $($row['sample']) | $category | $($inputLint['slop_score']) | $($outputLint['slop_score']) | $suspectsDelta | $densityDelta | $missing |")
            } else {
                $lines.Add("| $($row['sample']) | $category | $($inputLint['slop_score']) | n/a | n/a | n/a | n/a |")
            }
        }
    }
    if ($Result.Contains('category_summary')) {
        $lines.Add(''); $lines.Add('## Category Summary'); $lines.Add('')
        $lines.Add('| Category | Count | Avg input slop | Avg output slop | Critical missing |'); $lines.Add('| --- | ---: | ---: | ---: | ---: |')
        foreach ($category in @($Result['category_summary'].Keys | Sort-Object -CaseSensitive)) {
            $bucket = $Result['category_summary'][$category]
            $lines.Add("| $category | $($bucket['count']) | $($bucket['avg_input_slop']) | $($bucket['avg_output_slop']) | $($bucket['critical_missing']) |")
        }
    }
    if ($Result.Contains('gate_summary')) {
        $gate = $Result['gate_summary']
        $lines.Add(''); $lines.Add('## Release Gate Signals'); $lines.Add('')
        $lines.Add("- Release gate pass: ``$($Result['release_gate_pass'].ToString().ToLowerInvariant())``")
        $lines.Add("- Length counts: ``$(ConvertTo-StableJson $gate['length_counts'] | ForEach-Object { $_ })``".Replace("`n", ' '))
        $lines.Add("- Task counts: ``$((ConvertTo-StableJson $gate['task_counts']).Replace("`n",' '))``")
        $lines.Add("- Missing outputs: ``$($gate['missing_outputs'])``")
        $lines.Add("- Critical missing facts: ``$($gate['critical_missing'])``")
        $lines.Add("- Missing declared facts: ``$($gate['missing_declared_facts'])``")
        $lines.Add("- Unsupported added facts: ``$($gate['unsupported_added_facts'])``")
        $lines.Add("- Failures: ``$(if ($gate['failures'].Count) { $gate['failures'] -join ', ' } else { 'none' })``")
        if ($gate['schema_errors'].Count) {
            $lines.Add(''); $lines.Add('### Schema Errors'); $lines.Add('')
            foreach ($e in (@($gate['schema_errors']) | Select-Object -First 50)) { $lines.Add("- $e") }
        }
    }
    return (($lines -join "`n") + "`n")
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-RunBenchmarkCli -Argv $args
}
