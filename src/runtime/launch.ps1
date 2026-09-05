function Start-AntigravityWithDebug {
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][int]$Port,
        [string]$UserDataDir = ''
    )

    $argList = @(
        "--remote-debugging-port=$Port",
        '--remote-debugging-address=127.0.0.1'
    )
    if ($UserDataDir) {
        $argList += "--user-data-dir=$UserDataDir"
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $ExePath
    $psi.Arguments = ($argList -join ' ')
    $psi.UseShellExecute = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    return $proc
}

function Invoke-AntigravityPlusTargetInjection {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$Payload
    )

    $wsUrl = $Target.webSocketDebuggerUrl
    if (-not $wsUrl) {
        throw "No webSocketDebuggerUrl on target $($Target.id)"
    }

    # Install for future navigations
    try {
        Invoke-CdpAddScriptOnNewDocument -WebSocketDebuggerUrl $wsUrl -Source $Payload -TimeoutSeconds 10 | Out-Null
    } catch {
        Write-Warn "Could not register script on new document: $($_.Exception.Message)"
    }

    # Evaluate on the currently open document
    $evalRes = Invoke-CdpEvaluate -WebSocketDebuggerUrl $wsUrl -Expression $Payload -TimeoutSeconds 10
    return $evalRes
}

function Invoke-AntigravityPlusInjectionOnPort {
    param(
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutSeconds = 25
    )

    $payload = Get-AntigravityPayloadBundle
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $injectedCount = 0

    while ([DateTime]::UtcNow -lt $deadline) {
        $targets = @(Get-AntigravityDevToolsTargets -Port $Port -TimeoutSeconds 2)
        $pageTargets = @($targets | Where-Object { $_.type -eq 'page' })

        if ($pageTargets.Count -gt 0) {
            foreach ($target in $pageTargets) {
                try {
                    Invoke-AntigravityPlusTargetInjection -Target $target -Payload $payload | Out-Null
                    $injectedCount++
                } catch {
                    Write-Warn "Injection attempt failed on target $($target.id): $($_.Exception.Message)"
                }
            }
            if ($injectedCount -gt 0) {
                return $true
            }
        }
        Start-Sleep -Milliseconds 500
    }

    return ($injectedCount -gt 0)
}

function Show-AntigravityLaunchSplash {
    param([int]$DurationSeconds = 2)

    try {
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop

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
        $border.CornerRadius = [System.Windows.CornerRadius]::new(12)
        $border.Padding = [System.Windows.Thickness]::new(32, 18, 32, 18)

        $stack = [System.Windows.Controls.StackPanel]::new()
        $stack.Orientation = [System.Windows.Controls.Orientation]::Vertical
        $stack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

        $title = [System.Windows.Controls.TextBlock]::new()
        $title.Text = "ANTIGRAVITY PLUS"
        $title.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI Semibold")
        $title.FontSize = 18
        $title.FontWeight = [System.Windows.FontWeights]::Bold
        $title.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34d399")
        $title.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

        $sub = [System.Windows.Controls.TextBlock]::new()
        $sub.Text = "RTL & Enhancements Active"
        $sub.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI")
        $sub.FontSize = 12
        $sub.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#a1a1aa")
        $sub.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
        $sub.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

        $stack.Children.Add($title) | Out-Null
        $stack.Children.Add($sub) | Out-Null
        $border.Child = $stack
        $window.Content = $border

        $window.Show()
        $deadline = [DateTime]::UtcNow.AddSeconds($DurationSeconds)
        while ([DateTime]::UtcNow -lt $deadline -and $window.IsVisible) {
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{}
            )
            Start-Sleep -Milliseconds 100
        }
        $window.Close()
    } catch {}
}

function Launch-AntigravityPlus {
    param(
        [int]$PreferredPort = 0,
        [switch]$NewWindow
    )

    Show-AntigravityLaunchSplash -DurationSeconds 2

    $installInfo = Get-AntigravityInstallInfo
    if (-not $installInfo.Installed) {
        throw 'Antigravity was not found. Please install Google Antigravity first.'
    }

    # If Antigravity is already running and NewWindow is NOT requested, inject and notify!
    $activePort = Get-AntigravityActiveDevToolsPort
    if ($activePort -gt 0 -and -not $NewWindow) {
        Write-Info "Found active Antigravity session on DevTools port $activePort. Injecting enhancements..."
        $success = Invoke-AntigravityPlusInjectionOnPort -Port $activePort -TimeoutSeconds 10
        if ($success) {
            # Trigger visual toast in the open window
            try {
                $page = Get-AntigravityActivePageTarget -Port $activePort -TimeoutSeconds 2
                if ($page) {
                    Invoke-CdpEvaluate -WebSocketDebuggerUrl $page.webSocketDebuggerUrl -Expression "typeof showLaunchToast === 'function' ? showLaunchToast('✨ <b>Antigravity Plus</b> Active &amp; RTL Ready!') : null" | Out-Null
                }
            } catch {}
            Write-Success "Antigravity Plus enhancements successfully injected into active session!"
            return
        }
    }

    # Otherwise, launch an instance with remote debugging enabled
    $port = if ($PreferredPort -gt 0) { $PreferredPort } else { Get-AntigravityAvailablePort }
    $userDataDir = if ($NewWindow) { Join-Path (Get-AntigravityPlusRoot) 'profile' } else { '' }

    Write-Info "Launching Antigravity on loopback port $port..."
    $proc = Start-AntigravityWithDebug -ExePath $installInfo.ExePath -Port $port -UserDataDir $userDataDir
    Write-Info "Waiting for Antigravity window to initialize..."

    $success = Invoke-AntigravityPlusInjectionOnPort -Port $port -TimeoutSeconds 30
    if ($success) {
        Write-Success "Antigravity Plus launched with full RTL & enhancement layer active (Port $port)!"
    } else {
        Write-Warn "Antigravity process launched, but DevTools targets took longer than expected to appear."
    }
}
