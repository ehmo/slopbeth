# Measure-Orwell.ps1 - Deterministic Orwell writing-system lint for prose.
# Port of orwell_lint.py. Dual-purpose: defines Get-OrwellLint (importable) and
# runs a CLI when executed directly.
#
# Measures the five mechanically checkable rules from Orwell's "Politics and the
# English Language" (1946). Rule six ("break any of these rules sooner than say
# anything outright barbarous") is deliberately not mechanized: the score is a
# signal, not a verdict.

. "$PSScriptRoot/SlopBeth.Common.ps1"

# Rule 1: figures of speech "you are used to seeing in print" (Orwell's phrase).
$OrwellDeadMetaphors = @(
    "at the end of the day", "moving forward", "going forward",
    "low-hanging fruit", "low hanging fruit", "think outside the box",
    "hit the ground running", "move the needle", "boil the ocean",
    "circle back", "deep dive", "deep-dive", "north star", "paradigm shift",
    "best-in-class", "best in class", "table stakes", "in the weeds",
    "tip of the iceberg", "level the playing field", "elephant in the room",
    "double-edged sword", "when push comes to shove", "needle in a haystack",
    "the perfect storm", "a game of cat and mouse", "navigate the landscape",
    "navigating the landscape", "in the realm of", "a beacon of",
    "stands as a testament", "paving the way", "sets the stage",
    "a double click", "double-click on", "raise the bar", "push the envelope",
    "the road ahead", "a stone's throw", "bring to the table"
)

# Rule 2: long word -> short word. Everyday equivalent exists.
$OrwellLongWords = [ordered]@{
    "utilize" = "use"; "utilise" = "use"; "utilized" = "used"; "utilised" = "used"
    "utilization" = "use"; "utilisation" = "use"; "leverage" = "use"
    "leveraged" = "used"; "leveraging" = "using"; "facilitate" = "help"
    "facilitates" = "helps"; "facilitated" = "helped"; "demonstrated" = "showed"
    "demonstrates" = "shows"; "endeavor" = "try"; "endeavour" = "try"
    "commence" = "start"; "commencing" = "starting"; "terminate" = "end"
    "demonstrate" = "show"; "ascertain" = "find out"; "methodology" = "method"
    "functionality" = "features"; "individual" = "person"; "approximately" = "about"
    "additional" = "more"; "numerous" = "many"; "sufficient" = "enough"
    "initiate" = "start"; "subsequently" = "then"; "accordingly" = "so"
    "consequently" = "so"; "furthermore" = "also"; "moreover" = "also"
    "nevertheless" = "but"; "notwithstanding" = "despite"; "henceforth" = "from now on"
    "aforementioned" = "this"; "remuneration" = "pay"; "cognizant" = "aware"
    "expedite" = "speed up"; "elucidate" = "explain"; "encompass" = "cover"
    "necessitate" = "need"; "predominantly" = "mostly"; "utilizes" = "uses"
    "aggregate" = "total"; "optimal" = "best"; "myriad" = "many"; "plethora" = "plenty"
}

# Rule 3: deletable words and windy phrases. Cut or shorten.
$OrwellDeletablePhrases = [ordered]@{
    "in order to" = "to"; "due to the fact that" = "because"
    "in the event that" = "if"; "at this point in time" = "now"
    "at the present time" = "now"; "in spite of the fact that" = "although"
    "for the purpose of" = "to"; "with regard to" = "about"
    "with respect to" = "about"; "in terms of" = "(cut)"
    "it should be noted that" = "(cut)"; "it is important to note that" = "(cut)"
    "the fact that" = "that"; "a large number of" = "many"
    "in a timely manner" = "on time"; "on a daily basis" = "daily"
    "has the ability to" = "can"; "have the ability to" = "can"
    "is able to" = "can"; "are able to" = "can"; "the majority of" = "most"
    "a variety of" = "various"; "each and every" = "every"
    "first and foremost" = "first"; "in the near future" = "soon"
    "in conjunction with" = "with"; "in the process of" = "(cut)"
    "a wide range of" = "many"; "at all times" = "always"
    "in the context of" = "in"; "serves as a" = "is a"
    "plays a role in" = "affects"; "when it comes to" = "(cut)"
}

# Rule 5: foreign phrase, scientific/jargon word with an everyday equivalent.
$OrwellJargonTerms = [ordered]@{
    "synergy" = "fit"; "synergies" = "fit"; "operationalize" = "put to work"
    "incentivize" = "reward"; "ideate" = "think"; "actionable" = "usable"
    "bandwidth" = "time"; "vis-a-vis" = "about"; "vis-à-vis" = "about"
    "per se" = "itself"; "inter alia" = "among other things"
    "ipso facto" = "by that fact"; "de facto" = "in practice"
    "modus operandi" = "method"; "a priori" = "in advance"
    "ceteris paribus" = "all else equal"; "raison d'etre" = "purpose"
    "raison d'être" = "purpose"; "zeitgeist" = "mood"; "status quo" = "current state"
    "paradigm" = "model"; "holistic" = "whole"; "granular" = "detailed"
    "scalable" = "able to grow"; "frictionless" = "smooth"; "turnkey" = "ready to use"
    "low-hanging" = "easy"
}

# Auxiliary "be" forms for passive detection.
$OrwellBeForms = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("is", "are", "was", "were", "be", "been", "being", "get", "gets", "got", "getting"))

# Irregular past participles that do not end in -ed/-en.
$OrwellIrregularParticiples = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
    "built", "sent", "made", "done", "kept", "held", "told", "found", "left",
    "lost", "put", "set", "cut", "run", "led", "read", "paid", "meant", "dealt",
    "sold", "brought", "bought", "caught", "taught", "thought", "sought", "given",
    "taken", "shown", "known", "grown", "drawn", "thrown", "written", "driven",
    "chosen", "spoken", "broken", "frozen", "stolen", "hidden", "beaten", "seen",
    "won", "spent"))

# Past participles that are usually adjectival (skip to cut false positives).
$OrwellAdjectivalParticiples = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
    "interested", "excited", "concerned", "involved", "related", "based",
    "located", "aimed", "designed", "intended", "supposed", "used", "known",
    "committed", "dedicated", "limited", "detailed", "advanced", "experienced",
    "qualified", "skilled", "gifted", "tired", "pleased", "satisfied"))

$OrwellWordPattern = "[A-Za-z][A-Za-z'\-]*"

function Get-OrwellInputText {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path) -or $Path -eq '-') { return Read-StdinText }
    return Read-TextFile $Path
}

function Get-OrwellPhraseHit {
    # Substring counts, mirroring text_lower.count(key). Preserves key order.
    param([string]$TextLower, [string[]]$Phrases)
    $hits = [ordered]@{}
    foreach ($phrase in $Phrases) {
        $count = Get-SubstringCount $TextLower $phrase
        if ($count) { $hits[$phrase] = [int]$count }
    }
    return $hits
}

function Get-OrwellBoundaryHit {
    # Word-boundary regex counts, mirroring re.findall(rf"\b{escape}\b", lower).
    param([string]$TextLower, [string[]]$Terms)
    $hits = [ordered]@{}
    foreach ($term in $Terms) {
        $pattern = '\b' + [regex]::Escape($term) + '\b'
        $count = [regex]::Matches($TextLower, $pattern).Count
        if ($count) { $hits[$term] = [int]$count }
    }
    return $hits
}

function Test-OrwellParticiple {
    param([string]$Word)
    $lower = $Word.ToLowerInvariant()
    if ($OrwellAdjectivalParticiples.Contains($lower)) { return $false }
    if ($OrwellIrregularParticiples.Contains($lower)) { return $true }
    if ($lower.Length -gt 4 -and ($lower.EndsWith("ed") -or $lower.EndsWith("en"))) { return $true }
    return $false
}

function Get-OrwellPassiveSentence {
    # Flag sentences with a be-form followed within two tokens by a participle.
    # Conservative: skips adjectival participles; over-includes rather than misses.
    param([string[]]$Sentences)
    $flagged = [System.Collections.Generic.List[string]]::new()
    foreach ($sentence in $Sentences) {
        $tokens = @([regex]::Matches($sentence, $OrwellWordPattern) | ForEach-Object { $_.Value })
        $lowered = @($tokens | ForEach-Object { $_.ToLowerInvariant() })
        $flaggedThis = $false
        for ($index = 0; $index -lt $lowered.Count; $index++) {
            if (-not $OrwellBeForms.Contains($lowered[$index])) { continue }
            $windowEnd = [math]::Min($index + 3, $tokens.Count)
            $found = $false
            for ($w = $index + 1; $w -lt $windowEnd; $w++) {
                $candidate = $tokens[$w]
                if ($OrwellBeForms.Contains($candidate.ToLowerInvariant())) { continue }
                if (Test-OrwellParticiple $candidate) { $found = $true; break }
            }
            if ($found) { $flagged.Add($sentence.Trim()); $flaggedThis = $true; break }
        }
        if ($flaggedThis) { continue }
    }
    return $flagged
}

function Get-OrwellLint {
    param([string]$Text)

    $lower = $Text.ToLowerInvariant()
    $sentences = @(Split-Sentence $Text)
    $wordCount = [regex]::Matches($Text, $OrwellWordPattern).Count

    $metaphorHits = Get-OrwellPhraseHit $lower $OrwellDeadMetaphors
    $longWordHits = Get-OrwellBoundaryHit $lower ([string[]]@($OrwellLongWords.Keys))
    $deletableHits = Get-OrwellPhraseHit $lower ([string[]]@($OrwellDeletablePhrases.Keys))
    $jargonHits = Get-OrwellBoundaryHit $lower ([string[]]@($OrwellJargonTerms.Keys))

    $passive = Get-OrwellPassiveSentence $sentences

    $rule1 = 0; foreach ($v in $metaphorHits.Values) { $rule1 += $v }
    $rule2 = 0; foreach ($v in $longWordHits.Values) { $rule2 += $v }
    $rule3 = 0; foreach ($v in $deletableHits.Values) { $rule3 += $v }
    $rule4 = $passive.Count
    $rule5 = 0; foreach ($v in $jargonHits.Values) { $rule5 += $v }

    $denomSentences = [math]::Max(1, $sentences.Count)
    $per100 = 100.0 / [math]::Max(1, $wordCount)
    $passiveRatio = [math]::Round($rule4 / $denomSentences, 3)

    $penalty = $rule1 * 5 + $rule2 * 2 + $rule3 * 4 + $rule4 * 4 + $rule5 * 3
    $score = [math]::Max(0, 100 - $penalty)

    $suggestions = [ordered]@{}
    foreach ($k in $longWordHits.Keys) { $suggestions[$k] = "-> $($OrwellLongWords[$k])" }
    foreach ($k in $deletableHits.Keys) { $suggestions[$k] = "-> $($OrwellDeletablePhrases[$k])" }
    foreach ($k in $jargonHits.Keys) { $suggestions[$k] = "-> $($OrwellJargonTerms[$k])" }

    $passiveList = @($passive)
    if ($passiveList.Count -gt 20) { $passiveList = @($passiveList[0..19]) }

    return [ordered]@{
        word_count     = [int]$wordCount
        sentence_count = [int]$sentences.Count
        orwell_score   = [int]$score
        penalty        = [int]$penalty
        passive_ratio  = $passiveRatio
        rule_counts    = [ordered]@{
            rule1_dead_metaphor   = [int]$rule1
            rule2_long_word       = [int]$rule2
            rule3_deletable_words = [int]$rule3
            rule4_passive_voice   = [int]$rule4
            rule5_jargon_foreign  = [int]$rule5
        }
        per_100_words  = [ordered]@{
            dead_metaphor   = [math]::Round($rule1 * $per100, 2)
            long_word       = [math]::Round($rule2 * $per100, 2)
            deletable_words = [math]::Round($rule3 * $per100, 2)
            jargon_foreign  = [math]::Round($rule5 * $per100, 2)
        }
        dead_metaphor_hits = $metaphorHits
        long_word_hits     = $longWordHits
        deletable_hits     = $deletableHits
        jargon_hits        = $jargonHits
        passive_sentences  = $passiveList
        suggestions        = $suggestions
    }
}

function Format-OrwellFloat {
    # Render a double the way Python's str() does after round(x, n):
    # integral values keep a trailing ".0".
    param([double]$Value)
    $s = $Value.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
    if ($s -notmatch '[.eE]') { $s += '.0' }
    return $s
}

function Invoke-MeasureOrwellCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{
        format = 'value'; 'fail-under' = 'value'; 'max-passive-ratio' = 'value'
    }
    $format = if ($opts['format']) { $opts['format'] } else { 'text' }
    $path = if ($opts['_positional'].Count -gt 0) { $opts['_positional'][0] } else { $null }

    $result = Get-OrwellLint (Get-OrwellInputText $path)
    if ($format -eq 'json') {
        ConvertTo-StableJson $result
    } else {
        $counts = $result['rule_counts']
        "orwell_score: $($result['orwell_score'])"
        "passive_ratio: $(Format-OrwellFloat $result['passive_ratio'])"
        "rule1_dead_metaphor: $($counts['rule1_dead_metaphor'])"
        "rule2_long_word: $($counts['rule2_long_word'])"
        "rule3_deletable_words: $($counts['rule3_deletable_words'])"
        "rule4_passive_voice: $($counts['rule4_passive_voice'])"
        "rule5_jargon_foreign: $($counts['rule5_jargon_foreign'])"
    }

    $failed = $false
    if ($null -ne $opts['fail-under'] -and [int]$result['orwell_score'] -lt [int]$opts['fail-under']) {
        $failed = $true
    }
    if ($null -ne $opts['max-passive-ratio'] -and
        [double]$result['passive_ratio'] -gt [double]$opts['max-passive-ratio']) {
        $failed = $true
    }
    if ($failed) { exit 1 }
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MeasureOrwellCli -Argv $args
}
