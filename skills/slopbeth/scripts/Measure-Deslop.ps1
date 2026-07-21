# Measure-Deslop.ps1 - Deterministic slop-marker lint for prose.
# Port of deslop_lint.py. Dual-purpose: defines Get-SlopLint (importable) and
# runs a CLI when executed directly.

. "$PSScriptRoot/SlopBeth.Common.ps1"

$DeslopFillerPhrases = @(
    "it is important to note", "in today's fast-paced", "in the ever-evolving",
    "in conclusion", "ultimately", "at its core", "delve into", "dive into",
    "let's explore", "here's why", "this guide will", "plays a crucial role",
    "a crucial role", "more than just", "not just", "game changer",
    "game-changing", "unlock", "elevate", "empower", "supercharge", "seamless",
    "robust", "dynamic", "comprehensive", "transformative", "landscape",
    "ecosystem", "journey", "tapestry", "realm"
)

$DeslopAbstractWords = @(
    "important", "significant", "impactful", "innovative", "powerful", "valuable",
    "meaningful", "essential", "critical", "key", "vital", "enhance", "optimize",
    "streamline", "underscore", "highlight", "showcase"
)

$DeslopGenericClosers = @(
    "the future", "the possibilities are endless", "stands as a testament",
    "paving the way", "sets the stage"
)

# Structure patterns: name -> compiled regex. Order preserved for output stability.
$DeslopStructurePatterns = [ordered]@{
    not_just_but = [regex]::new('\bnot\s+(?:just|only)\b.{0,90}\bbut\b', 'IgnoreCase, Singleline')
    whether_or   = [regex]::new('\bwhether\b.{0,90}\bor\b', 'IgnoreCase, Singleline')
    from_to      = [regex]::new('\bfrom\b.{1,60}\bto\b', 'IgnoreCase, Singleline')
    at_core      = [regex]::new('\bat (?:its|the) core\b', 'IgnoreCase')
    generic_here = [regex]::new("\bhere'?s (?:why|how|what)\b", 'IgnoreCase')
    passiveish   = [regex]::new('\b(?:is|are|was|were|be|been|being)\s+\w+(?:ed|en)\b', 'IgnoreCase')
}

$DeslopEmphasisPattern = [regex]::new('\*\*[^*\n]{1,80}\*\*')
# Emoji code points U+1F300..U+1FAFF expressed as UTF-16 surrogate pairs.
$DeslopEmojiPattern = [regex]::new('(?:\uD83C[\uDF00-\uDFFF])|(?:\uD83D[\uDC00-\uDFFF])|(?:\uD83E[\uDC00-\uDEFF])')
$DeslopTriadPattern = [regex]::new('\b\w+\s*,\s*\w+\s*,\s*(?:and|or)\s+\w+\b')

function Get-DeslopInputText {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path) -or $Path -eq '-') { return Read-StdinText }
    return Read-TextFile $Path
}

function Get-DeslopPhraseHit {
    param([string]$Text, [string[]]$Phrases)
    $lower = $Text.ToLowerInvariant()
    $hits = [ordered]@{}
    foreach ($phrase in $Phrases) {
        $count = Get-SubstringCount $lower $phrase
        if ($count) { $hits[$phrase] = $count }
    }
    return $hits
}

function Get-DeslopTitleCaseHeadingCount {
    param([string]$Text)
    $count = 0
    foreach ($line in ($Text -split "`n")) {
        $line = $line -replace "`r$", ''
        $stripped = $line.Trim([char[]]('#', '*', ' '))
        $tokens = @($stripped -split '\s+' | Where-Object { $_ })
        if (-not $stripped -or $tokens.Count -lt 2) { continue }
        $words = @([regex]::Matches($stripped, '[A-Za-z]+') | ForEach-Object { $_.Value } | Where-Object { $_.Length -gt 2 })
        if ($words.Count -eq 0) { continue }
        $upper = @($words | Where-Object { [char]::IsUpper($_[0]) }).Count
        if (($upper / $words.Count) -ge 0.75) { $count++ }
    }
    return $count
}

function Get-DeslopRepeatedStart {
    param([string[]]$Sentences)
    $starts = @{}
    foreach ($sentence in $Sentences) {
        $words = @([regex]::Matches($sentence.ToLowerInvariant(), "[A-Za-z']+") | ForEach-Object { $_.Value })
        $words = @($words | Select-Object -First 3)
        if ($words.Count -ge 2) {
            $key = ($words[0..1] -join ' ')
            if ($starts.ContainsKey($key)) { $starts[$key]++ } else { $starts[$key] = 1 }
        }
    }
    $result = [ordered]@{}
    foreach ($key in $starts.Keys) { if ($starts[$key] -gt 1) { $result[$key] = $starts[$key] } }
    return $result
}

function Get-SlopLint {
    param([string]$Text)

    $sentences = Split-Sentence $Text
    $phraseHits = Get-DeslopPhraseHit $Text $DeslopFillerPhrases
    $closerHits = Get-DeslopPhraseHit $Text $DeslopGenericClosers
    $abstractHits = Get-DeslopPhraseHit $Text $DeslopAbstractWords

    $structureHits = [ordered]@{}
    foreach ($name in $DeslopStructurePatterns.Keys) {
        $structureHits[$name] = $DeslopStructurePatterns[$name].Matches($Text).Count
    }

    $emphasisCount = $DeslopEmphasisPattern.Matches($Text).Count
    $emojiCount = $DeslopEmojiPattern.Matches($Text).Count
    $dashCount = (Get-SubstringCount $Text ([string][char]0x2014)) + (Get-SubstringCount $Text ([string][char]0x2013))
    $triadCount = $DeslopTriadPattern.Matches($Text).Count
    $titleCaseHeadings = Get-DeslopTitleCaseHeadingCount $Text

    $structureSum = 0
    foreach ($v in $structureHits.Values) { $structureSum += $v }
    $phraseSum = 0; foreach ($v in $phraseHits.Values) { $phraseSum += $v }
    $closerSum = 0; foreach ($v in $closerHits.Values) { $closerSum += $v }
    $abstractSum = 0; foreach ($v in $abstractHits.Values) { $abstractSum += $v }

    $suspectTotal = $phraseSum + $closerSum + $abstractSum + $structureSum +
        $emphasisCount + $emojiCount + $dashCount + $triadCount + $titleCaseHeadings

    $wordCount = Get-WordCount $Text
    $score = [math]::Max(0, 100 - $suspectTotal * 4 - [math]::Max(0, $structureHits['passiveish'] - 2) * 2)

    return [ordered]@{
        word_count               = $wordCount
        sentence_count           = $sentences.Count
        slop_score               = [int]$score
        suspect_total            = [int]$suspectTotal
        phrase_hits              = $phraseHits
        abstract_hits            = $abstractHits
        generic_closer_hits      = $closerHits
        structure_hits           = $structureHits
        formatting               = [ordered]@{
            emphasis_count           = $emphasisCount
            emoji_count              = $emojiCount
            dash_count               = $dashCount
            title_case_heading_count = $titleCaseHeadings
        }
        triad_count              = $triadCount
        repeated_sentence_starts = (Get-DeslopRepeatedStart $sentences)
    }
}

function Invoke-MeasureDeslopCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{ format = 'value'; 'fail-under' = 'value' }
    $format = if ($opts['format']) { $opts['format'] } else { 'text' }
    $path = if ($opts['_positional'].Count -gt 0) { $opts['_positional'][0] } else { $null }

    $result = Get-SlopLint (Get-DeslopInputText $path)
    if ($format -eq 'json') {
        ConvertTo-StableJson $result
    } else {
        "slop_score: $($result['slop_score'])"
        "suspect_total: $($result['suspect_total'])"
        "word_count: $($result['word_count'])"
        "sentence_count: $($result['sentence_count'])"
    }
    if ($null -ne $opts['fail-under'] -and [int]$result['slop_score'] -lt [int]$opts['fail-under']) {
        exit 1
    }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureDeslopCli -Argv $args
}
