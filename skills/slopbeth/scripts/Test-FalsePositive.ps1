# Test-FalsePositive.ps1 - Check examples that Slopbeth should leave alone or
# edit lightly. Port of false_positive_check.py. Dot-sources Measure-Deslop and
# Compare-Preservation.

. "$PSScriptRoot/SlopBeth.Common.ps1"
. "$PSScriptRoot/Measure-Deslop.ps1"
. "$PSScriptRoot/Compare-Preservation.ps1"

function Get-FpCheckRow {
    param($Row)
    $sampleId = [string](Get-DictValue $Row 'id' "line-$(Get-DictValue $Row '_line_number' '?')")
    $inputText = [string](Get-DictValue $Row 'input' '')
    $outputText = [string](Get-DictValue $Row 'expected_output' '')
    $action = Get-DictValue $Row 'expected_action'
    $forbidden = Get-DictValue $Row 'forbidden_additions' @()
    $failures = [System.Collections.Generic.List[string]]::new()

    if ($action -ne 'leave_alone' -and $action -ne 'light_copyedit') { $failures.Add('bad_expected_action') }
    if (-not $inputText.Trim() -or -not $outputText.Trim()) { $failures.Add('missing_text') }
    $forbiddenOk = ($forbidden -is [System.Collections.IEnumerable] -and $forbidden -isnot [string])
    if ($forbiddenOk) { foreach ($item in $forbidden) { if ($item -isnot [string] -or -not $item) { $forbiddenOk = $false; break } } }
    if (-not $forbiddenOk) { $failures.Add('bad_forbidden_additions') }

    $inputWords = Get-WordCount $inputText
    $outputWords = Get-WordCount $outputText
    $growth = [math]::Round($outputWords / [math]::Max(1, $inputWords), 3)
    if ($action -eq 'leave_alone' -and $inputText -cne $outputText) { $failures.Add('changed_leave_alone_text') }
    if ($action -eq 'light_copyedit' -and $growth -gt 1.15) { $failures.Add('light_edit_grew_too_much') }

    $lowerOutput = $outputText.ToLowerInvariant()
    $addedForbidden = @()
    if ($forbidden -is [System.Collections.IEnumerable] -and $forbidden -isnot [string]) {
        $addedForbidden = @($forbidden | Where-Object { $_ -is [string] -and $lowerOutput.Contains($_.ToLowerInvariant()) })
    }
    if ($addedForbidden.Count) { $failures.Add('forbidden_addition') }

    $preservation = Compare-PreservationToken $inputText $outputText
    if ([int]$preservation['critical_missing_count']) { $failures.Add('critical_missing_facts') }

    return [ordered]@{
        id                     = $sampleId
        expected_action        = $action
        input_words            = $inputWords
        output_words           = $outputWords
        growth_ratio           = $growth
        input_slop_score       = (Get-SlopLint $inputText)['slop_score']
        output_slop_score      = (Get-SlopLint $outputText)['slop_score']
        added_forbidden        = $addedForbidden
        critical_missing_count = $preservation['critical_missing_count']
        failures               = @($failures)
    }
}

function Get-FpRun {
    param([string]$Path, [int]$MinRows)
    $rowList = [System.Collections.Generic.List[object]]::new()
    foreach ($row in (ConvertFrom-Jsonl $Path -AttachLineNumber)) { $rowList.Add((Get-FpCheckRow $row)) }
    $rows = @($rowList.ToArray())
    $failingRows = @($rows | Where-Object { $_['failures'].Count } | ForEach-Object { $_['id'] })
    $actions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($row in $rows) { [void]$actions.Add([string]$row['expected_action']) }
    $failures = @()
    if ($rows.Count -lt $MinRows) { $failures += 'too_few_rows' }
    if (-not $actions.Contains('leave_alone') -or -not $actions.Contains('light_copyedit')) { $failures += 'missing_action_mix' }
    if ($failingRows.Count) { $failures += 'row_failures' }
    return [ordered]@{
        generated_at = Get-UtcTimestamp
        tracker      = $Path
        row_count    = $rows.Count
        failing_rows = $failingRows
        failures     = $failures
        gate_pass    = ($failures.Count -eq 0)
        rows         = $rows
    }
}

function Invoke-TestFalsePositiveCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{ tracker = 'value'; 'min-rows' = 'value'; format = 'value'; 'fail-gate' = 'switch' }
    if (-not $opts['tracker']) { [Console]::Error.WriteLine('error: --tracker is required'); exit 2 }
    $minRows = if ($null -ne $opts['min-rows']) { [int]$opts['min-rows'] } else { 10 }
    $result = Get-FpRun $opts['tracker'] $minRows
    ConvertTo-StableJson $result
    if ($opts['fail-gate'] -and -not $result['gate_pass']) { exit 2 }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-TestFalsePositiveCli -Argv $args
}
