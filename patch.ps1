[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Restore,
    [switch]$Launch,
    [switch]$LiveInject,
    [switch]$NewWindow,
    [int]$Port = 0,
    [switch]$Silent
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
    'src\antigravity\payload-bundle.ps1',
    'src\runtime\files.ps1',
    'src\runtime\state.ps1',
    'src\runtime\shortcuts.ps1',
    'src\runtime\launch.ps1',
    'src\runtime\patching.ps1',
    'src\ui\menu.ps1'
)

foreach ($mod in $modules) {
    $modPath = Join-Path $scriptDir $mod
    if (-not (Test-Path -LiteralPath $modPath)) {
        throw "Required module missing: $modPath"
    }
    . $modPath
}

# Process command-line flags
if ($Install) {
    Install-AntigravityPlus
    exit 0
}

if ($Restore) {
    Restore-AntigravityPlus
    exit 0
}

if ($Launch) {
    Launch-AntigravityPlus -PreferredPort $Port -NewWindow:$NewWindow
    exit 0
}

if ($LiveInject) {
    Invoke-AntigravityPlusLiveInject
    exit 0
}

# Default interactive menu
Show-AntigravityPlusMenu
