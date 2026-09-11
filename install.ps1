# Antigravity Plus installer.
param(
    [switch]$LocalDev,
    [ValidateRange(1024, 65535)]
    [int]$Port = 0,
    [switch]$NoUpdate
)

function Test-InstallerPortAvailable {
    param([Parameter(Mandatory)][int]$Port)

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new(
            [System.Net.IPAddress]::Parse('127.0.0.1'),
            $Port
        )
        $listener.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($listener) { $listener.Stop() }
    }
}

function Get-RandomInstallerPort {
    param(
        [int]$Minimum = 20000,
        [int]$Maximum = 45000,
        [int]$Attempts = 100
    )

    for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
        $candidate = Get-Random -Minimum $Minimum -Maximum ($Maximum + 1)
        if (Test-InstallerPortAvailable -Port $candidate) {
            return $candidate
        }
    }

    throw "Could not find an available Antigravity Plus port between $Minimum and $Maximum after $Attempts attempts."
}

function Start-AntigravityPlusAfterInstall {
    param([int]$Port = 0)

    $shortcutCandidates = @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Antigravity Plus.lnk'),
        (Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\Antigravity Plus.lnk')
    )
    $shortcutPath = $shortcutCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $shortcutPath) {
        Write-Host 'Antigravity Plus installed, but no launcher shortcut was found.' -ForegroundColor Yellow
        return
    }

    Write-Host "Launching Antigravity Plus from $shortcutPath ..." -ForegroundColor Green
    Write-Host "Using requested Antigravity Plus port $Port." -ForegroundColor Green
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    if ([string]::IsNullOrWhiteSpace($shortcut.TargetPath)) {
        throw "Antigravity Plus shortcut target could not be resolved: $shortcutPath"
    }

    $launcherArguments = [string]$shortcut.Arguments
    if (-not [string]::IsNullOrWhiteSpace($launcherArguments)) { $launcherArguments += ' ' }
    $launcherArguments += [string]$Port
    $previousRequestedPort = [Environment]::GetEnvironmentVariable('ANTIGRAVITY_PLUS_REQUESTED_PORT', 'Process')
    try {
        $env:ANTIGRAVITY_PLUS_REQUESTED_PORT = [string]$Port

        # Launch shortcut via Explorer dispatch to detach from runner Job Object
        $launched = $false
        try {
            $shellWindows = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]'{9BA05972-F6A8-11CF-A442-00A0C90A8F39}'))
            $window = $shellWindows.Item()
            if ($window -and $window.Document -and $window.Document.Application) {
                $window.Document.Application.ShellExecute($shortcut.TargetPath, $launcherArguments, $shortcut.WorkingDirectory, "open", 1)
                $launched = $true
            }
        } catch {}

        if (-not $launched) {
            Start-Process -FilePath $shortcut.TargetPath -ArgumentList $launcherArguments -WorkingDirectory $shortcut.WorkingDirectory | Out-Null
        }

        Start-Sleep -Seconds 6
    } finally {
        if ($null -eq $previousRequestedPort) {
            Remove-Item Env:ANTIGRAVITY_PLUS_REQUESTED_PORT -ErrorAction SilentlyContinue
        } else {
            $env:ANTIGRAVITY_PLUS_REQUESTED_PORT = $previousRequestedPort
        }
    }

    # Machine-readable output so callers such as the local .bat launcher can capture port
    Write-Output "ANTIGRAVITY_PLUS_LAUNCH_PORT=$Port"
}

if ($env:OS -ne 'Windows_NT') {
    Write-Host "Antigravity Plus is Windows-only. Please run it on Windows 10/11." -ForegroundColor Red
    exit 1
}

$requestedPort = $Port
if ($requestedPort -le 0 -and -not [string]::IsNullOrWhiteSpace($env:ANTIGRAVITY_PLUS_REQUESTED_PORT)) {
    $parsedPort = 0
    if (-not [int]::TryParse($env:ANTIGRAVITY_PLUS_REQUESTED_PORT, [ref]$parsedPort)) {
        throw "ANTIGRAVITY_PLUS_REQUESTED_PORT '$($env:ANTIGRAVITY_PLUS_REQUESTED_PORT)' is not a valid TCP port."
    }
    if ($parsedPort -lt 1024 -or $parsedPort -gt 65535) {
        throw "ANTIGRAVITY_PLUS_REQUESTED_PORT '$parsedPort' is outside valid TCP port range."
    }
    $requestedPort = $parsedPort
}

if ($requestedPort -le 0) {
    $requestedPort = Get-RandomInstallerPort
    Write-Host "Selected random Antigravity Plus port $requestedPort." -ForegroundColor Green
}

if ($requestedPort -gt 0 -and -not (Test-InstallerPortAvailable -Port $requestedPort)) {
    throw "Requested Antigravity Plus port $requestedPort is already in use. Choose another port and retry."
}

$LocalRepoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

if ($LocalDev -or (Test-Path -LiteralPath (Join-Path $LocalRepoRoot 'patch.ps1'))) {
    Write-Host "Launching local Antigravity Plus installer..." -ForegroundColor Green
    & (Join-Path $LocalRepoRoot 'patch.ps1') -Install -NoUpdate:$NoUpdate
    Write-Host "Antigravity Plus installer finished." -ForegroundColor Green
    Start-AntigravityPlusAfterInstall -Port $requestedPort
    exit 0
}

# Web installer fallback
$stageDir = Join-Path $env:TEMP 'AntigravityPlus-Install'
if (-not (Test-Path $stageDir)) {
    New-Item -Path $stageDir -ItemType Directory -Force | Out-Null
}

$repoBase = "https://raw.githubusercontent.com/limshare/antigravity-plus/main"
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
    'src/antigravity/context-badge.ps1',
    'src/antigravity/sidebar-enhancements.ps1',
    'src/antigravity/composer-top-bar.ps1',
    'src/antigravity/payload-bundle.ps1',
    'src/runtime/files.ps1',
    'src/runtime/state.ps1',
    'src/runtime/shortcuts.ps1',
    'src/runtime/launch.ps1',
    'src/runtime/patching.ps1',
    'src/runtime/updater.ps1',
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
$updateArgs = if ($NoUpdate) { @('-NoUpdate') } else { @() }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $downloadedPatch -Install @updateArgs
Start-AntigravityPlusAfterInstall -Port $requestedPort
