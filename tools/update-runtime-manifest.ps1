param([string]$OutputPath = '')

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $repoRoot 'runtime-manifest.json' }
$files = @(
    'patch.ps1', 'src/shared/logging.ps1', 'src/shared/prompting.ps1', 'src/shared/asar.ps1', 'src/shared/cdp.ps1',
    'src/antigravity/detection.ps1', 'src/antigravity/rtl-shared.ps1', 'src/antigravity/rtl-payload.ps1',
    'src/antigravity/ui-enhancements.ps1', 'src/antigravity/context-badge.ps1', 'src/antigravity/sidebar-enhancements.ps1',
    'src/antigravity/composer-top-bar.ps1', 'src/antigravity/payload-bundle.ps1', 'src/runtime/files.ps1',
    'src/runtime/reply-language.ps1', 'src/runtime/state.ps1', 'src/runtime/shortcuts.ps1', 'src/runtime/launch.ps1', 'src/runtime/patching.ps1',
    'src/runtime/updater.ps1', 'src/ui/menu.ps1'
)
$algorithm = [Security.Cryptography.SHA256]::Create()
try {
    $entries = foreach ($relative in $files) {
        $source = Join-Path $repoRoot ($relative.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Manifest source file not found: $source" }
        $hash = ([BitConverter]::ToString($algorithm.ComputeHash([IO.File]::ReadAllBytes($source)))).Replace('-', '').ToLowerInvariant()
        [ordered]@{ path = $relative; target = $relative; size = (Get-Item -LiteralPath $source).Length; sha256 = $hash }
    }
} finally { $algorithm.Dispose() }
[ordered]@{ schema = 1; runtime = 'antigravity-plus'; files = @($entries) } |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $OutputPath
