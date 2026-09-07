function Start-AntigravityWithDebug {
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][int]$Port,
        [string]$UserDataDir = ''
    )

    $argList = @(
        '--ignore-certificate-errors',
        "--remote-debugging-port=$Port",
        '--remote-debugging-address=127.0.0.1'
    )
    if ($UserDataDir) {
        $argList += "--user-data-dir=$UserDataDir"
    }

    $argsString = $argList -join ' '
    $workDir = Split-Path -Parent $ExePath

    # 1. Try launching via Explorer's out-of-process ShellWindows COM dispatch
    # This guarantees the process is spawned by Explorer.exe directly in the user's
    # desktop session and is detached from any runner Job Object.
    $launched = $false
    try {
        $shellWindows = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]'{9BA05972-F6A8-11CF-A442-00A0C90A8F39}'))
        $window = $shellWindows.Item()
        if ($window -and $window.Document -and $window.Document.Application) {
            $window.Document.Application.ShellExecute($ExePath, $argsString, $workDir, "open", 1)
            $launched = $true
        }
    } catch {}

    # 2. Fallback to Shell.Application
    if (-not $launched) {
        try {
            $shell = New-Object -ComObject Shell.Application
            $shell.ShellExecute($ExePath, $argsString, $workDir, "open", 1)
            $launched = $true
        } catch {}
    }

    # 3. Fallback to ProcessStartInfo
    if (-not $launched) {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $ExePath
        $psi.Arguments = $argsString
        $psi.WorkingDirectory = $workDir
        $psi.UseShellExecute = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    }
}

function Format-AntigravityUsageWindowDetail {
    param(
        [Parameter(Mandatory)][double]$UsedPercent,
        [Parameter(Mandatory)][long]$ResetsAt,
        [int]$WindowMinutes = 10080,
        [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow
    )

    $resetAt = [DateTimeOffset]::FromUnixTimeSeconds($ResetsAt)
    $effectiveWindowMinutes = if ($WindowMinutes -gt 0) { $WindowMinutes } else { 10080 }
    $windowStart = $resetAt.AddMinutes(-$effectiveWindowMinutes)
    $windowDuration = ($resetAt - $windowStart).TotalSeconds
    $elapsedSeconds = [Math]::Max(0, [Math]::Min($windowDuration, ($Now - $windowStart).TotalSeconds))
    $elapsedPercent = [Math]::Floor(($elapsedSeconds / $windowDuration) * 100)
    $remaining = $resetAt - $Now
    if ($remaining.TotalSeconds -le 0) {
        return ('{0}% used · resets now, {1}% passed' -f $UsedPercent.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture), $elapsedPercent)
    }

    if ($remaining.TotalDays -ge 1) {
        $value = [Math]::Max(1, [int][Math]::Round($remaining.TotalDays, 0, [MidpointRounding]::AwayFromZero))
        $unit = if ($value -eq 1) { 'day' } else { 'days' }
    } elseif ($remaining.TotalHours -ge 1) {
        $value = [Math]::Max(1, [int][Math]::Ceiling($remaining.TotalHours))
        $unit = if ($value -eq 1) { 'hour' } else { 'hours' }
    } else {
        $value = [Math]::Max(1, [int][Math]::Ceiling($remaining.TotalMinutes))
        $unit = if ($value -eq 1) { 'minute' } else { 'minutes' }
    }

    return ('{0}% used · resets in {1} {2}, {3}% passed' -f
        $UsedPercent.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture),
        $value,
        $unit,
        $elapsedPercent)
}

function Format-AntigravityUsageWindowsTitle {
    param(
        $PrimaryWindow,
        $SecondaryWindow,
        [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow
    )

    $windows = @(@($PrimaryWindow, $SecondaryWindow) | Where-Object {
        $_ -and $null -ne $_.used_percent -and $null -ne $_.resets_at
    })
    if ($windows.Count -eq 0) { return 'Plus Antigravity' }

    if ($windows.Count -eq 1) {
        $windowMinutes = if ($null -ne $windows[0].window_minutes) { [int]$windows[0].window_minutes } else { 10080 }
        $detail = Format-AntigravityUsageWindowDetail -UsedPercent ([double]$windows[0].used_percent) -ResetsAt ([long]$windows[0].resets_at) -WindowMinutes $windowMinutes -Now $Now
        return "Plus Antigravity - $detail"
    }

    $details = @($windows | Sort-Object @{ Expression = {
        if ($null -ne $_.window_minutes) { [int]$_.window_minutes } else { [int]::MaxValue }
    } } | ForEach-Object {
        $windowMinutes = if ($null -ne $_.window_minutes) { [int]$_.window_minutes } else { 10080 }
        $label = if ($windowMinutes -eq 300) {
            '5h'
        } elseif ($windowMinutes -eq 10080) {
            'Weekly'
        } else {
            "${windowMinutes}m"
        }
        $detail = Format-AntigravityUsageWindowDetail -UsedPercent ([double]$_.used_percent) -ResetsAt ([long]$_.resets_at) -WindowMinutes $windowMinutes -Now $Now
        "${label}: $detail"
    })
    return 'Plus Antigravity - ' + ($details -join ' | ')
}

function Invoke-AntigravityPlusTargetInjection {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$Payload
    )

    $wsUrl = [string]$Target.webSocketDebuggerUrl
    if (-not $wsUrl) {
        throw "No webSocketDebuggerUrl on target $($Target.id)"
    }

    $commands = @(
        (New-CdpCommand -Id 1 -Method 'Page.enable'),
        (New-CdpCommand -Id 2 -Method 'Page.addScriptToEvaluateOnNewDocument' -Params @{
            source = $Payload
            runImmediately = $true
        }),
        (New-CdpCommand -Id 3 -Method 'Runtime.evaluate' -Params @{
            expression = $Payload
            awaitPromise = $true
            returnByValue = $true
        })
    )

    return Invoke-CdpCommands -WebSocketDebuggerUrl $wsUrl -Commands $commands -TimeoutSeconds 5
}

function Invoke-AntigravityPlusInjectionOnPort {
    param(
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutSeconds = 30
    )

    $payload = Get-AntigravityPayloadBundle
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $injectedCount = 0

    while ([DateTime]::UtcNow -lt $deadline) {
        $targets = @(Get-AntigravityDevToolsTargets -Port $Port -TimeoutSeconds 1)
        $pageTargets = @($targets | Where-Object {
            $_.type -eq 'page' -and
            $_.webSocketDebuggerUrl
        })

        if ($pageTargets.Count -gt 0) {
            foreach ($target in $pageTargets) {
                try {
                    Invoke-AntigravityPlusTargetInjection -Target $target -Payload $payload | Out-Null
                    $injectedCount++
                } catch {
                }
            }

            $realTargets = @($pageTargets | Where-Object { $_.url -notlike 'data:text/html*' })
            if ($realTargets.Count -gt 0) {
                return $true
            }
        }
        Start-Sleep -Milliseconds 60
    }

    return ($injectedCount -gt 0)
}

function Show-AntigravityLaunchSplash {
    param(
        [AllowEmptyString()][string]$LauncherKey,
        [int]$PreferredPort = 0,
        [int]$TimeoutSeconds = 20
    )

    try {
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop
    } catch {
        return $false
    }

    $window = [System.Windows.Window]::new()
    $window.Title = 'Antigravity Plus'
    $window.WindowStyle = [System.Windows.WindowStyle]::None
    $window.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $window.AllowsTransparency = $true
    $window.Background = [System.Windows.Media.Brushes]::Transparent
    $window.ShowInTaskbar = $false
    $window.Topmost = $true
    $window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    $window.ShowActivated = $true

    $border = [System.Windows.Controls.Border]::new()
    $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#131316")
    $border.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10b981")
    $border.BorderThickness = [System.Windows.Thickness]::new(1.5)
    $border.CornerRadius = [System.Windows.CornerRadius]::new(14)
    $border.Padding = [System.Windows.Thickness]::new(28, 20, 28, 20)

    $stack = [System.Windows.Controls.StackPanel]::new()
    $stack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $stack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    $canvas = [System.Windows.Controls.Canvas]::new()
    $canvas.Width = 32
    $canvas.Height = 32
    $canvas.Margin = [System.Windows.Thickness]::new(0, 0, 16, 0)

    $spinner = [System.Windows.Shapes.Ellipse]::new()
    $spinner.Width = 28
    $spinner.Height = 28
    $spinner.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10b981")
    $spinner.StrokeThickness = 3
    $spinner.StrokeDashArray = [System.Windows.Media.DoubleCollection]::new(@(4, 2))
    $spinner.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
    $rotation = [System.Windows.Media.RotateTransform]::new()
    $spinner.RenderTransform = $rotation

    $anim = [System.Windows.Media.Animation.DoubleAnimation]::new(0, 360, [System.Windows.Duration]::new([TimeSpan]::FromSeconds(1)))
    $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $rotation.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $anim)

    $canvas.Children.Add($spinner) | Out-Null
    $stack.Children.Add($canvas) | Out-Null

    $textStack = [System.Windows.Controls.StackPanel]::new()
    $textStack.Orientation = [System.Windows.Controls.Orientation]::Vertical

    $title = [System.Windows.Controls.TextBlock]::new()
    $title.Text = "ANTIGRAVITY PLUS"
    $title.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI Semibold")
    $title.FontSize = 16
    $title.FontWeight = [System.Windows.FontWeights]::Bold
    $title.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34d399")

    $sub = [System.Windows.Controls.TextBlock]::new()
    $sub.Text = "Starting with RTL & Enhancements..."
    $sub.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI")
    $sub.FontSize = 11
    $sub.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#a1a1aa")
    $sub.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)

    $textStack.Children.Add($title) | Out-Null
    $textStack.Children.Add($sub) | Out-Null
    $stack.Children.Add($textStack) | Out-Null

    $border.Child = $stack
    $window.Content = $border

    $window.Show()

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $minDisplayUntil = [DateTime]::UtcNow.AddMilliseconds(1200)

    while ([DateTime]::UtcNow -lt $deadline -and $window.IsVisible) {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [action]{}
        )

        if ([DateTime]::UtcNow -ge $minDisplayUntil -and $PreferredPort -gt 0) {
            try {
                $raw = @(Invoke-RestMethod -Uri "http://127.0.0.1:$PreferredPort/json/list" -TimeoutSec 1 -ErrorAction SilentlyContinue)
                $realPage = $raw | Where-Object { $_.type -eq 'page' -and $_.url -notlike 'data:text/html*' }
                if ($realPage) {
                    Start-Sleep -Milliseconds 250
                    break
                }
            } catch {}
        }

        Start-Sleep -Milliseconds 60
    }

    try { $window.Close() } catch {}
    return $true
}

function Start-AntigravityPortMonitor {
    param(
        [Parameter(Mandatory)][int]$Port,
        [AllowEmptyString()][string]$LauncherKey
    )

    $payload = Get-AntigravityPayloadBundle
    $consecutiveFailures = 0
    $maxFailures = 6
    $startTime = [DateTime]::UtcNow

    while ($true) {
        $isSettling = ([DateTime]::UtcNow -lt $startTime.AddSeconds(12))
        $pollInterval = if ($isSettling) { 60 } else { 1000 }

        $targets = $null
        try {
            $targets = @(Get-AntigravityDevToolsTargets -Port $Port -TimeoutSeconds 1)
            $consecutiveFailures = 0
        } catch {
            $consecutiveFailures++
            if ($consecutiveFailures -ge $maxFailures) {
                # Window was closed
                break
            }
            Start-Sleep -Milliseconds $pollInterval
            continue
        }

        $pageTargets = @($targets | Where-Object {
            $_.type -eq 'page' -and
            $_.webSocketDebuggerUrl
        })

        if ($pageTargets.Count -eq 0) {
            $consecutiveFailures++
            if ($consecutiveFailures -ge $maxFailures) {
                break
            }
        } else {
            $consecutiveFailures = 0
            foreach ($target in $pageTargets) {
                $wsUrl = [string]$target.webSocketDebuggerUrl
                if (-not $wsUrl) { continue }

                # If it's early loading overlay, register addScriptToEvaluateOnNewDocument
                if ($target.url -like 'data:text/html*') {
                    try {
                        Invoke-AntigravityPlusTargetInjection -Target $target -Payload $payload | Out-Null
                    } catch {}
                    continue
                }

                # Check if payload is already running in this document
                $needsInjection = $true
                try {
                    $probe = Invoke-CdpEvaluate -WebSocketDebuggerUrl $wsUrl -Expression "Boolean(window.__ANTIGRAVITY_PLUS_RTL_INSTALLED && window.__GEMINI_PLUS_CONTEXT_BADGE)" -TimeoutSeconds 1
                    if ($probe -and $probe.result -and $probe.result.result -and [bool]$probe.result.result.value) {
                        $needsInjection = $false
                    }
                } catch {
                    $needsInjection = $true
                }

                if ($needsInjection) {
                    try {
                        Invoke-AntigravityPlusTargetInjection -Target $target -Payload $payload | Out-Null
                    } catch {}
                }
            }
        }

        Start-Sleep -Milliseconds $pollInterval
    }
}

function Launch-AntigravityPlus {
    param(
        [int]$PreferredPort = 0,
        [AllowEmptyString()][string]$LauncherKey,
        [switch]$NoMonitor
    )

    $installInfo = Get-AntigravityInstallInfo
    if (-not $installInfo.Installed) {
        throw 'Antigravity was not found. Please install Google Antigravity first.'
    }

    if ([string]::IsNullOrWhiteSpace($LauncherKey)) {
        $LauncherKey = $env:ANTIGRAVITY_PLUS_LAUNCHER_KEY
        if ([string]::IsNullOrWhiteSpace($LauncherKey)) {
            $LauncherKey = "plus-" + [System.Guid]::NewGuid().ToString('N').Substring(0, 12)
        }
    }

    $port = if ($PreferredPort -gt 0) { $PreferredPort } else { Get-AntigravityAvailablePort }

    # Setup isolated profile directory
    $userDataDir = Get-AntigravityPlusUserDataDirectory -LauncherKey $LauncherKey
    if (-not (Test-Path -LiteralPath $userDataDir)) {
        New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null
    }

    # Pre-seed app_storage.json in ASCII (NO UTF-8 BOM) to ensure runInBackground and skip setup wizard
    $storageFile = Join-Path $userDataDir 'app_storage.json'
    $storageJson = '{"runInBackground":"true","ide-install-wizard-shown":"true","autoCheckForUpdates":"false"}'
    [System.IO.File]::WriteAllText($storageFile, $storageJson, [System.Text.Encoding]::ASCII)

    # Fallback pre-seed in default local data dir
    $fallbackDir = Join-Path $env:LOCALAPPDATA 'Antigravity'
    if (-not (Test-Path -LiteralPath $fallbackDir)) {
        New-Item -ItemType Directory -Force -Path $fallbackDir | Out-Null
    }
    $fallbackStorage = Join-Path $fallbackDir 'app_storage.json'
    if (-not (Test-Path -LiteralPath $fallbackStorage)) {
        [System.IO.File]::WriteAllText($fallbackStorage, $storageJson, [System.Text.Encoding]::ASCII)
    }

    Write-Info "Launching fresh Antigravity window on loopback debug port $port..."
    Start-AntigravityWithDebug -ExePath $installInfo.ExePath -Port $port -UserDataDir $userDataDir

    Write-Info "Waiting for Antigravity window to become ready..."
    $injected = Invoke-AntigravityPlusInjectionOnPort -Port $port -TimeoutSeconds 30

    if ($injected) {
        # Trigger visual toast in the new window
        try {
            $page = Get-AntigravityActivePageTarget -Port $port -TimeoutSeconds 3
            if ($page) {
                Invoke-CdpEvaluate -WebSocketDebuggerUrl $page.webSocketDebuggerUrl -Expression "typeof showLaunchToast === 'function' ? showLaunchToast('✨ <b>Antigravity Plus</b> Active &amp; RTL Ready!') : null" | Out-Null
            }
        } catch {}
        Write-Success "Antigravity Plus launched with full RTL & enhancement layer active (Port $port)!"
    } else {
        Write-Warn "Antigravity window launched, but target injection timed out on port $port."
    }

    # Output machine-readable port for parent callers (such as install.ps1 / .bat)
    Write-Output "ANTIGRAVITY_PLUS_LAUNCH_PORT=$port"

    # Start persistent port monitor
    if (-not $NoMonitor) {
        Start-AntigravityPortMonitor -Port $port -LauncherKey $LauncherKey
    }
}
