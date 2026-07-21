# Test-Secret.ps1 - Small CI secret-pattern scan for public package files.
# Port of ci_secret_scan.py.

. "$PSScriptRoot/SlopBeth.Common.ps1"

$SecretRoot = Split-Path $PSScriptRoot -Parent
$SecretSkipParts = [System.Collections.Generic.HashSet[string]]::new([string[]]@('.git', '__pycache__', 'node_modules'), [System.StringComparer]::Ordinal)
$SecretSkipSuffixes = [System.Collections.Generic.HashSet[string]]::new([string[]]@('.pyc', '.tgz'), [System.StringComparer]::OrdinalIgnoreCase)
$SecretSelf = 'Test-Secret.ps1'
$SecretPatterns = @(
    [regex]::new('-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'),
    [regex]::new('\bghp_[A-Za-z0-9_]{20,}\b'),
    [regex]::new('\bgithub_pat_[A-Za-z0-9_]{20,}\b'),
    [regex]::new('\bsk-[A-Za-z0-9]{20,}\b'),
    [regex]::new('\b(?:api[_-]?key|secret|token|password)\s*[:=]\s*[''"][^''"\s]{12,}[''"]', 'IgnoreCase')
)
$SecretThrowingUtf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Test-SecretSkip {
    param([string]$RelativePath)
    foreach ($part in ($RelativePath -split '[\\/]')) { if ($SecretSkipParts.Contains($part)) { return $true } }
    return $SecretSkipSuffixes.Contains([System.IO.Path]::GetExtension($RelativePath))
}

function Get-SecretHits {
    param([string]$Root)
    $hits = [System.Collections.Generic.List[string]]::new()
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName)
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
        if (Test-SecretSkip $relative) { continue }
        if ($file.Name -eq $SecretSelf) { continue }
        try { $text = [System.IO.File]::ReadAllText($file.FullName, $SecretThrowingUtf8) }
        catch { continue }
        $lineNumber = 0
        foreach ($line in ($text -split "`n")) {
            $lineNumber++
            $line = $line -replace "`r$", ''
            foreach ($pattern in $SecretPatterns) {
                if ($pattern.IsMatch($line)) { $hits.Add("${relative}:${lineNumber}"); break }
            }
        }
    }
    return @($hits.ToArray())
}

function Invoke-TestSecretCli {
    param([string[]]$Argv)
    $opts = ConvertFrom-CliArgs -Argv $Argv -Options @{ root = 'value' }
    $root = if ($opts['root']) { $opts['root'] } else { $SecretRoot }
    $hits = @(Get-SecretHits $root)
    if ($hits.Count) {
        [Console]::Out.WriteLine('Potential secret patterns found:')
        foreach ($hit in $hits) { [Console]::Out.WriteLine("- $hit") }
        exit 1
    }
    [Console]::Out.WriteLine('Secret scan passed.')
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-TestSecretCli -Argv $args
}
