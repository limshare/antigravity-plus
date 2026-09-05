# Antigravity Plus Web / Local Bootstrap Installer
$ErrorActionPreference = 'Stop'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "                ANTIGRAVITY PLUS INSTALLER                " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$localPatch = Join-Path $PSScriptRoot 'patch.ps1'
if (Test-Path -LiteralPath $localPatch) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $localPatch -Install
    exit $LASTEXITCODE
}

# If running remotely via irm | iex:
$stageDir = Join-Path $env:TEMP 'AntigravityPlus-Install'
if (-not (Test-Path $stageDir)) {
    New-Item -Path $stageDir -ItemType Directory -Force | Out-Null
}

$repoBase = "https://raw.githubusercontent.com/limudim972/antigravity-plus/main"
$files = @(
    'patch.ps1',
    'src/shared/logging.ps1',
    'src/shared/prompting.ps1',
    'src/shared/asar.ps1',
    'src/shared/cdp.ps1',
    'src/antigravity/detection.ps1',
    'src/antigravity/rtl-shared.ps1',
    'src/antigravity/rtl-payload.ps1',
    'src/antigravity/ui-enhancements.ps1',
    'src/antigravity/payload-bundle.ps1',
    'src/runtime/files.ps1',
    'src/runtime/state.ps1',
    'src/runtime/shortcuts.ps1',
    'src/runtime/launch.ps1',
    'src/runtime/patching.ps1',
    'src/ui/menu.ps1'
)

Write-Host "Downloading Antigravity Plus components..." -ForegroundColor Cyan
foreach ($f in $files) {
    $dest = Join-Path $stageDir $f.Replace('/', '\')
    $dir = Split-Path -Parent $dest
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    $url = "$repoBase/$f"
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

$downloadedPatch = Join-Path $stageDir 'patch.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $downloadedPatch -Install
