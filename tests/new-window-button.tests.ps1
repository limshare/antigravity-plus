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

# 3. Test Get-AntigravityNewWindowButtonPayload function
if (-not (Get-Command -Name Get-AntigravityNewWindowButtonPayload -CommandType Function -ErrorAction SilentlyContinue)) {
    throw 'Get-AntigravityNewWindowButtonPayload function is not defined.'
}

$payload = Get-AntigravityNewWindowButtonPayload
if ([string]::IsNullOrWhiteSpace($payload)) {
    throw 'Get-AntigravityNewWindowButtonPayload returned empty string.'
}

$requiredPayloadSnippets = @(
    'data-antigravity-plus-shared-window-button',
    'data-gemini-plus-shared-window-button',
    'data-antigravity-plus-project-window-button',
    'title-menu-bar',
    'hasInstalledButtons()',
    'launchSharedWindow',
    'New window',
    'MutationObserver'
)

foreach ($snippet in $requiredPayloadSnippets) {
    if (-not $payload.Contains($snippet)) {
        throw "New window payload is missing required snippet: '$snippet'"
    }
}

# 4. Test Get-AntigravityPayloadBundle inclusion
$bundle = Get-AntigravityPayloadBundle
if (-not $bundle.Contains('data-antigravity-plus-shared-window-button')) {
    throw 'Payload bundle does not contain new window button payload.'
}
if (-not $bundle.Contains('New window button payload error')) {
    throw 'Payload bundle does not contain new window button error handler.'
}

# 5. Test runtime manifest entry
$manifest = Get-Content (Join-Path $repoRoot 'runtime-manifest.json') -Raw | ConvertFrom-Json
$entry = $manifest.files | Where-Object { $_.path -eq 'src/antigravity/new-window-button.ps1' }
if (-not $entry) {
    throw 'runtime-manifest.json does not contain entry for src/antigravity/new-window-button.ps1'
}

$algorithm = [Security.Cryptography.SHA256]::Create()
try {
    $source = Join-Path $repoRoot 'src\antigravity\new-window-button.ps1'
    $actualHash = ([BitConverter]::ToString($algorithm.ComputeHash([IO.File]::ReadAllBytes($source)))).Replace('-', '').ToLowerInvariant()
    if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) {
        throw "runtime-manifest.json hash mismatch for src/antigravity/new-window-button.ps1. Expected $($entry.sha256), got $actualHash."
    }
} finally {
    $algorithm.Dispose()
}

Write-Host 'new-window-button.tests.ps1 passed'
