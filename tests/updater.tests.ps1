$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $repoRoot 'runtime-manifest.json') -Raw | ConvertFrom-Json
if ([int]$manifest.schema -ne 1 -or $manifest.runtime -ne 'antigravity-plus') { throw 'Antigravity runtime manifest metadata is invalid.' }
if (@($manifest.files).Count -lt 15) { throw 'Antigravity runtime manifest is missing managed files.' }
$algorithm = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($entry in @($manifest.files)) {
        $source = Join-Path $repoRoot ([string]$entry.path).Replace('/', '\')
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Manifest source is missing: $source" }
        $actual = ([BitConverter]::ToString($algorithm.ComputeHash([IO.File]::ReadAllBytes($source)))).Replace('-', '').ToLowerInvariant()
        if ($actual -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Manifest hash mismatch: $source" }
    }
} finally { $algorithm.Dispose() }
$updater = Get-Content (Join-Path $repoRoot 'src/runtime/updater.ps1') -Raw
foreach ($needle in @('runtime-manifest.json', 'Get-AntigravityPlusRemoteCommitSha', 'SHA-256 mismatch', 'Move-Item -LiteralPath $TargetDirectory', 'previous runtime was kept')) {
    if ($updater -notlike "*$needle*") { throw "Antigravity updater is missing: $needle" }
}
Write-Host 'updater.tests.ps1 passed'
