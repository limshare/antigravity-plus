$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

# 1. Syntax validation of all PowerShell files in repo
$psFiles = @(Get-ChildItem -LiteralPath $repoRoot -Recurse -File | Where-Object { $_.Extension -ieq '.ps1' })
foreach ($file in $psFiles) {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count -gt 0) {
        throw "PowerShell syntax error in file $($file.FullName): $($errors[0].Message)"
    }
}

# 2. Test dot-sourcing patch.ps1 with -SkipMain
. (Join-Path $repoRoot 'patch.ps1') -SkipMain

# 3. Test Get-AntigravityUiEnhancementsPayload function
if (-not (Get-Command -Name Get-AntigravityUiEnhancementsPayload -CommandType Function -ErrorAction SilentlyContinue)) {
    throw 'Get-AntigravityUiEnhancementsPayload function is not defined.'
}

$payload = Get-AntigravityUiEnhancementsPayload
if ([string]::IsNullOrWhiteSpace($payload)) {
    throw 'Get-AntigravityUiEnhancementsPayload returned empty string.'
}

# Verify user messages are NOT hidden or collapsed:
# Must not contain generic -step pre-hide rules that would catch user-input-step
if ($payload -match '\[data-testid\$\="(-step|-input-step)"\]') {
    throw 'UI enhancements payload contains overly generic -step CSS selector that would match user-input-step.'
}

# Must contain explicit guard against user steps
if (-not $payload.Contains("testId.includes('user')")) {
    throw 'UI enhancements payload missing guard against user steps.'
}

# 4. Test runtime manifest entry
$manifest = Get-Content (Join-Path $repoRoot 'runtime-manifest.json') -Raw | ConvertFrom-Json
$entry = $manifest.files | Where-Object { $_.path -eq 'src/antigravity/ui-enhancements.ps1' }
if (-not $entry) {
    throw 'runtime-manifest.json does not contain entry for src/antigravity/ui-enhancements.ps1'
}

$algorithm = [Security.Cryptography.SHA256]::Create()
try {
    $source = Join-Path $repoRoot 'src\antigravity\ui-enhancements.ps1'
    $actualHash = ([BitConverter]::ToString($algorithm.ComputeHash([IO.File]::ReadAllBytes($source)))).Replace('-', '').ToLowerInvariant()
    if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) {
        throw "runtime-manifest.json hash mismatch for src/antigravity/ui-enhancements.ps1. Expected $($entry.sha256), got $actualHash."
    }
} finally {
    $algorithm.Dispose()
}

Write-Host 'ui-enhancements.tests.ps1 passed'
