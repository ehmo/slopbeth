# Compare-Preservation.ps1 - Compare preservation-sensitive tokens between a
# source and a rewrite. Port of preservation_check.py. Dual-purpose: defines
# Get-PreservationToken / Compare-PreservationToken (importable) and a CLI.

. "$PSScriptRoot/SlopBeth.Common.ps1"

$PreservationPatterns = [ordered]@{
    urls         = [regex]::new('https?://[^\s)]+')
    emails       = [regex]::new('\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b')
    numbers      = [regex]::new('\b\d+(?:[.,]\d+)*(?:%|[a-zA-Z]+)?\b')
    dates        = [regex]::new('\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},?\s+\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b', 'IgnoreCase')
    quoted_terms = [regex]::new('[''"][^''"]{2,80}[''"]')
    capitalized_terms = [regex]::new('\b(?:[A-Z][A-Za-z0-9&.-]+(?:\s+[A-Z][A-Za-z0-9&.-]+){0,4})\b')
}

$PreservationCapitalizedStopwords = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@('A', 'An', 'And', 'Because', 'But', 'For', 'If', 'Keep', 'Or', 'So', 'The', 'This', 'When'),
    [System.StringComparer]::Ordinal)

$PreservationStripChars = [char[]]('.', ',', ';', ':')

function Get-PreservationToken {
    param([string]$Text)
    $data = [ordered]@{}
    foreach ($name in $PreservationPatterns.Keys) {
        $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($m in $PreservationPatterns[$name].Matches($Text)) {
            [void]$set.Add($m.Value.Trim($PreservationStripChars))
        }
        $values = @($set)
        if ($name -eq 'capitalized_terms') {
            $values = @($values | Where-Object {
                    -not $PreservationCapitalizedStopwords.Contains($_) -and $_.ToLowerInvariant() -ne 'i' -and $_.Length -gt 1
                })
        }
        $data[$name] = @($values | Sort-Object -CaseSensitive)
    }
    return $data
}

function Compare-PreservationToken {
    param([string]$Original, [string]$Rewrite)
    $before = Get-PreservationToken $Original
    $after = Get-PreservationToken $Rewrite

    $missing = [ordered]@{}
    $added = [ordered]@{}
    foreach ($name in $PreservationPatterns.Keys) {
        $afterSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($after[$name]), [System.StringComparer]::Ordinal)
        $beforeSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($before[$name]), [System.StringComparer]::Ordinal)
        $missing[$name] = @($before[$name] | Where-Object { -not $afterSet.Contains($_) })
        $added[$name] = @($after[$name] | Where-Object { -not $beforeSet.Contains($_) })
    }

    $criticalMissing = $missing['urls'].Count + $missing['emails'].Count + $missing['numbers'].Count +
        $missing['dates'].Count + $missing['quoted_terms'].Count

    $missingNonEmpty = [ordered]@{}
    foreach ($name in $PreservationPatterns.Keys) { if ($missing[$name].Count) { $missingNonEmpty[$name] = $missing[$name] } }
    $addedNonEmpty = [ordered]@{}
    foreach ($name in $PreservationPatterns.Keys) { if ($added[$name].Count) { $addedNonEmpty[$name] = $added[$name] } }

    return [ordered]@{
        missing               = $missingNonEmpty
        added                 = $addedNonEmpty
        critical_missing_count = $criticalMissing
        review_required       = ($criticalMissing -gt 0) -or ($missing['capitalized_terms'].Count -gt 0)
    }
}

function Invoke-ComparePreservationCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{ format = 'value' }
    $format = if ($opts['format']) { $opts['format'] } else { 'text' }
    $positional = $opts['_positional']
    if ($positional.Count -lt 2) { [Console]::Error.WriteLine('error: ORIGINAL and REWRITE are required'); exit 2 }
    $result = Compare-PreservationToken (Read-TextFile $positional[0]) (Read-TextFile $positional[1])
    if ($format -eq 'json') {
        ConvertTo-StableJson $result
    } else {
        "critical_missing_count: $($result['critical_missing_count'])"
        "review_required: $($result['review_required'].ToString().ToLowerInvariant())"
        foreach ($key in $result['missing'].Keys) {
            "missing_${key}: $($result['missing'][$key] -join ', ')"
        }
    }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ComparePreservationCli -Argv $args
}
