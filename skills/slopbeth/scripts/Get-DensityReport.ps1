# Get-DensityReport.ps1 - Report mechanical density signals for one text or a
# before/after pair. Port of density_report.py. Dual-purpose: defines
# Get-DensityMetric / Get-DensityReportData (importable) and a CLI.

. "$PSScriptRoot/SlopBeth.Common.ps1"

$DensityClaimMarkers = [regex]::new(
    '\b(?:because|therefore|so|but|however|although|unless|if|when|cost|risk|gain|lose|' +
    'percent|%|\d+|must|should|cannot|can|will|won''t|means|requires|causes|prevents)\b',
    'IgnoreCase')
$DensityWeakWords = [regex]::new(
    '\b(?:very|really|quite|rather|important|significant|powerful|robust|seamless|dynamic|' +
    'comprehensive|valuable|meaningful|interesting|unique)\b',
    'IgnoreCase')

function Get-DensityMetric {
    param([string]$Text)
    $wordCount = Get-WordCount $Text
    $sents = Split-Sentence $Text
    $claimHits = $DensityClaimMarkers.Matches($Text).Count
    $weakHits = $DensityWeakWords.Matches($Text).Count
    $removable = @()
    foreach ($s in $sents) {
        if (-not $DensityClaimMarkers.IsMatch($s) -and (Get-WordCount $s) -gt 8) {
            $removable += $s
        }
    }
    return [ordered]@{
        word_count                    = $wordCount
        sentence_count                = $sents.Count
        avg_sentence_words            = [math]::Round($wordCount / [math]::Max(1, $sents.Count), 2)
        claim_markers                 = $claimHits
        claim_markers_per_100_words   = [math]::Round(($claimHits * 100.0) / [math]::Max(1, $wordCount), 2)
        weak_word_count               = $weakHits
        removable_sentence_candidates = $removable
    }
}

function Get-DensityReportData {
    param([string]$Original, [AllowNull()][string]$Rewrite)
    $originalMetrics = Get-DensityMetric $Original
    $result = [ordered]@{ original = $originalMetrics }
    if ($null -ne $Rewrite) {
        $rewriteMetrics = Get-DensityMetric $Rewrite
        $result['rewrite'] = $rewriteMetrics
        $result['compression_ratio'] = [math]::Round($rewriteMetrics['word_count'] / [math]::Max(1, $originalMetrics['word_count']), 3)
        $result['claim_density_delta'] = [math]::Round($rewriteMetrics['claim_markers_per_100_words'] - $originalMetrics['claim_markers_per_100_words'], 2)
        $result['weak_word_delta'] = $rewriteMetrics['weak_word_count'] - $originalMetrics['weak_word_count']
    }
    return $result
}

function Invoke-GetDensityReportCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{ format = 'value' }
    $positional = $opts['_positional']
    if ($positional.Count -lt 1) { [Console]::Error.WriteLine('error: ORIGINAL is required'); exit 2 }
    $original = Read-TextFile $positional[0]
    $rewrite = if ($positional.Count -gt 1) { Read-TextFile $positional[1] } else { $null }
    $result = Get-DensityReportData $original $rewrite
    # Both json and text formats emit the same stable JSON, matching density_report.py.
    ConvertTo-StableJson $result
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-GetDensityReportCli -Argv $args
}
