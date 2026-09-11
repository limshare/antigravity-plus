[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Restore,
    [switch]$Launch,
    [switch]$Update,
    [switch]$ShowLaunchSplash,
    [switch]$LiveInject,
    [switch]$Menu,
    [AllowEmptyString()][string]$LauncherKey,
    [int]$Port = 0,
    [switch]$Silent,
    [switch]$SkipMain,
    [switch]$NoUpdate
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load all required modules
$modules = @(
    'src\shared\logging.ps1',
    'src\shared\prompting.ps1',
    'src\shared\asar.ps1',
    'src\shared\cdp.ps1',
    'src\antigravity\detection.ps1',
    'src\antigravity\rtl-shared.ps1',
    'src\antigravity\rtl-payload.ps1',
    'src\antigravity\ui-enhancements.ps1',
    'src\antigravity\context-badge.ps1',
    'src\antigravity\sidebar-enhancements.ps1',
    'src\antigravity\composer-top-bar.ps1',
    'src\antigravity\payload-bundle.ps1',
    'src\runtime\files.ps1',
    'src\runtime\state.ps1',
    'src\runtime\shortcuts.ps1',
    'src\runtime\launch.ps1',
    'src\runtime\patching.ps1',
    'src\runtime\updater.ps1',
    'src\ui\menu.ps1'
)

foreach ($mod in $modules) {
    $modPath = Join-Path $scriptDir $mod
    if (-not (Test-Path -LiteralPath $modPath)) {
        throw "Required module missing: $modPath"
    }
    . $modPath
}

if ($ShowLaunchSplash) {
    Show-AntigravityLaunchSplash -LauncherKey $LauncherKey -PreferredPort $Port
    exit 0
}

if ($SkipMain) {
    return
}

# Process command-line flags
if ($Update) {
    Update-AntigravityPlus -Force
    exit 0
}

if ($Install) {
    Install-AntigravityPlus -NoUpdate:$NoUpdate
    exit 0
}

if ($Restore) {
    Restore-AntigravityPlus
    exit 0
}

if ($Launch) {
    Launch-AntigravityPlus -PreferredPort $Port -LauncherKey $LauncherKey -NoUpdate:$NoUpdate
    exit 0
}

if ($LiveInject) {
    Invoke-AntigravityPlusLiveInject
    exit 0
}

if ($Menu) {
    Show-AntigravityPlusMenu
    exit 0
}

# Default action: Install and create desktop/start menu shortcuts
Install-AntigravityPlus -NoUpdate:$NoUpdate
exit 0
