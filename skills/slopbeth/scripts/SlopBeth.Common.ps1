# SlopBeth.Common.ps1
# Shared primitives for the PowerShell port of the SlopBeth tooling.
# Dot-source this file from any script: . "$PSScriptRoot/SlopBeth.Common.ps1"
# Every function here is safe to (re)dot-source: it only defines functions and
# never executes work at import time, so consumers never collide or run a "main".

$script:SbUtf8NoBom = [System.Text.UTF8Encoding]::new($false)

# ---------------------------------------------------------------------------
# File IO (UTF-8, no BOM, matching Python's encoding="utf-8")
# ---------------------------------------------------------------------------

function Read-TextFile {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, $script:SbUtf8NoBom)
}

function Write-TextFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyString()][string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $script:SbUtf8NoBom)
}

function Read-StdinText {
    return [System.Console]::In.ReadToEnd()
}

# ---------------------------------------------------------------------------
# Dictionary helpers (rows are read as hashtables via ConvertFrom-Json -AsHashtable)
# ---------------------------------------------------------------------------

function Get-DictValue {
    # Mirrors Python dict.get(key, default).
    param($Dict, [string]$Key, $Default = $null)
    if ($Dict -is [System.Collections.IDictionary] -and $Dict.Contains($Key)) {
        return $Dict[$Key]
    }
    return $Default
}

function Test-DictHasKey {
    param($Dict, [string]$Key)
    return ($Dict -is [System.Collections.IDictionary] -and $Dict.Contains($Key))
}

# ---------------------------------------------------------------------------
# JSONL reader (mirrors the read_jsonl helpers in the Python scripts)
# ---------------------------------------------------------------------------

function ConvertFrom-Jsonl {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$AttachLineNumber
    )
    $rows = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadAllLines($Path, $script:SbUtf8NoBom)) {
        $lineNumber++
        if (-not $line.Trim()) { continue }
        try {
            $obj = $line | ConvertFrom-Json -AsHashtable -Depth 100
        } catch {
            throw "${Path}:${lineNumber}: invalid JSON"
        }
        if ($obj -isnot [System.Collections.IDictionary]) {
            throw "${Path}:${lineNumber}: expected JSON object"
        }
        if ($AttachLineNumber) { $obj['_line_number'] = $lineNumber }
        $rows.Add($obj)
    }
    return , $rows.ToArray()
}

function Get-JsonlCount {
    param([Parameter(Mandatory)][string]$Path)
    $count = 0
    foreach ($line in [System.IO.File]::ReadAllLines($Path, $script:SbUtf8NoBom)) {
        if ($line.Trim()) { $count++ }
    }
    return $count
}

# ---------------------------------------------------------------------------
# Text primitives
# ---------------------------------------------------------------------------

function Get-Word {
    # Returns the list of word tokens. Default pattern matches Python \b[\w']+\b.
    param([string]$Text, [string]$Pattern = "\b[\w']+\b")
    if ([string]::IsNullOrEmpty($Text)) { return @() }
    return @([regex]::Matches($Text, $Pattern) | ForEach-Object { $_.Value })
}

function Get-WordCount {
    param([string]$Text, [string]$Pattern = "\b[\w']+\b")
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return [regex]::Matches($Text, $Pattern).Count
}

function Split-Sentence {
    # Mirrors: [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return @() }
    $parts = [regex]::Split($Text.Trim(), '(?<=[.!?])\s+')
    return @($parts | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-SubstringCount {
    # Non-overlapping occurrence count, matching Python str.count.
    param([string]$Haystack, [string]$Needle)
    if ([string]::IsNullOrEmpty($Needle) -or [string]::IsNullOrEmpty($Haystack)) { return 0 }
    return $Haystack.Split([string[]]@($Needle), [System.StringSplitOptions]::None).Length - 1
}

# ---------------------------------------------------------------------------
# Statistics (replace statistics.mean / statistics.pstdev)
# ---------------------------------------------------------------------------

function Get-Mean {
    param([double[]]$Values)
    if ($null -eq $Values -or $Values.Count -eq 0) { return 0.0 }
    $sum = 0.0
    foreach ($v in $Values) { $sum += $v }
    return $sum / $Values.Count
}

function Get-PopulationStdev {
    param([double[]]$Values)
    $n = if ($null -eq $Values) { 0 } else { $Values.Count }
    if ($n -le 1) { return 0.0 }
    $mean = Get-Mean $Values
    $ss = 0.0
    foreach ($v in $Values) { $ss += ($v - $mean) * ($v - $mean) }
    return [math]::Sqrt($ss / $n)
}

# ---------------------------------------------------------------------------
# Timestamp (ISO-8601 UTC, matching datetime.now(timezone.utc).isoformat())
# ---------------------------------------------------------------------------

function Get-UtcTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.ffffffzzz", [System.Globalization.CultureInfo]::InvariantCulture)
}

# ---------------------------------------------------------------------------
# Stable JSON serializer (approximates json.dumps(indent=2, sort_keys=True))
# Sorted keys + 2-space indent. Output is for humans/agents; gates use exit codes.
# ---------------------------------------------------------------------------

function ConvertTo-StableJson {
    param([Parameter(Mandatory)][AllowNull()]$InputObject, [int]$IndentSize = 2)
    return (Write-SbJsonValue -Value $InputObject -Level 0 -IndentSize $IndentSize)
}

function Write-SbJsonString {
    param([AllowEmptyString()][string]$Text)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('"')
    foreach ($ch in $Text.ToCharArray()) {
        switch ($ch) {
            '"'  { [void]$sb.Append('\"'); continue }
            '\'  { [void]$sb.Append('\\'); continue }
            "`b" { [void]$sb.Append('\b'); continue }
            "`f" { [void]$sb.Append('\f'); continue }
            "`n" { [void]$sb.Append('\n'); continue }
            "`r" { [void]$sb.Append('\r'); continue }
            "`t" { [void]$sb.Append('\t'); continue }
            default {
                $code = [int][char]$ch
                if ($code -lt 32) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
                else { [void]$sb.Append($ch) }
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Write-SbJsonValue {
    param([AllowNull()]$Value, [int]$Level, [int]$IndentSize)

    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }
    if ($Value -is [string]) { return (Write-SbJsonString $Value) }
    if ($Value -is [char]) { return (Write-SbJsonString ([string]$Value)) }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [System.Int16] -or $Value -is [byte] -or $Value -is [System.UInt32] -or $Value -is [System.UInt64]) {
        return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        return ([double]$Value).ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
    }

    $pad = ' ' * ($IndentSize * $Level)
    $padIn = ' ' * ($IndentSize * ($Level + 1))

    if ($Value -is [System.Collections.IDictionary]) {
        $keys = @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)
        if ($keys.Count -eq 0) { return '{}' }
        $parts = foreach ($key in $keys) {
            $rendered = Write-SbJsonValue -Value $Value[$key] -Level ($Level + 1) -IndentSize $IndentSize
            "$padIn$(Write-SbJsonString $key): $rendered"
        }
        return "{`n" + ($parts -join ",`n") + "`n$pad}"
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $props = @($Value.PSObject.Properties | Sort-Object Name -CaseSensitive)
        if ($props.Count -eq 0) { return '{}' }
        $parts = foreach ($prop in $props) {
            $rendered = Write-SbJsonValue -Value $prop.Value -Level ($Level + 1) -IndentSize $IndentSize
            "$padIn$(Write-SbJsonString $prop.Name): $rendered"
        }
        return "{`n" + ($parts -join ",`n") + "`n$pad}"
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @($Value)
        if ($items.Count -eq 0) { return '[]' }
        $parts = foreach ($item in $items) {
            "$padIn$(Write-SbJsonValue -Value $item -Level ($Level + 1) -IndentSize $IndentSize)"
        }
        return "[`n" + ($parts -join ",`n") + "`n$pad]"
    }

    return (Write-SbJsonString ([string]$Value))
}

# ---------------------------------------------------------------------------
# CLI argument parser (mirrors the argparse contracts of the Python scripts).
# Spec maps option name (without leading --) to a type: 'value' | 'switch' | 'list'.
# Returns a hashtable: option values keyed by name, plus '_positional' (array).
# ---------------------------------------------------------------------------

function ConvertFrom-CliArgs {
    param(
        [string[]]$Argv,
        [hashtable]$Options = @{}
    )
    $result = @{ _positional = @() }
    foreach ($name in $Options.Keys) {
        switch ($Options[$name]) {
            'switch' { $result[$name] = $false }
            'list'   { $result[$name] = @() }
            default  { $result[$name] = $null }
        }
    }
    if ($null -eq $Argv) { return $result }

    $i = 0
    while ($i -lt $Argv.Count) {
        $token = [string]$Argv[$i]
        if ($token.StartsWith('--')) {
            $name = $token.Substring(2)
            $inlineValue = $null
            $eq = $name.IndexOf('=')
            if ($eq -ge 0) {
                $inlineValue = $name.Substring($eq + 1)
                $name = $name.Substring(0, $eq)
            }
            if (-not $Options.ContainsKey($name)) { throw "unrecognized argument: --$name" }
            switch ($Options[$name]) {
                'switch' { $result[$name] = $true; $i++ }
                'list' {
                    $values = @()
                    if ($null -ne $inlineValue) { $values += $inlineValue; $i++ }
                    else {
                        $i++
                        while ($i -lt $Argv.Count -and -not ([string]$Argv[$i]).StartsWith('--')) {
                            $values += [string]$Argv[$i]; $i++
                        }
                    }
                    $result[$name] = $values
                }
                default {
                    if ($null -ne $inlineValue) { $result[$name] = $inlineValue; $i++ }
                    else {
                        if ($i + 1 -ge $Argv.Count -or ([string]$Argv[$i + 1]).StartsWith('--')) {
                            throw "argument --${name}: expected one value"
                        }
                        $result[$name] = [string]$Argv[$i + 1]; $i += 2
                    }
                }
            }
        } else {
            $result['_positional'] += $token
            $i++
        }
    }
    return $result
}
