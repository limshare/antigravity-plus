if (-not ('AntigravityNativeWindows' -as [type])) {
    $nativeCode = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class AntigravityNativeWindows {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr hDesktop);
    [DllImport("user32.dll")] public static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumWindowsProc lpfn, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", EntryPoint = "GetClassNameW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll", EntryPoint = "GetWindowTextW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);

    public const int SW_HIDE = 0;
    public const int SW_SHOWNORMAL = 1;
    public const int SW_SHOW = 5;
    public const int SW_RESTORE = 9;

    public static List<IntPtr> GetProcessWindowHandles(int[] processIds) {
        var set = new HashSet<int>(processIds);
        var handles = new List<IntPtr>();
        var seen = new HashSet<IntPtr>();

        EnumWindowsProc proc = (hWnd, lParam) => {
            if (seen.Contains(hWnd)) return true;
            seen.Add(hWnd);

            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            if (set.Contains((int)pid)) {
                handles.Add(hWnd);
            }
            return true;
        };

        IntPtr hDesk = OpenInputDesktop(0, false, 0x0100);
        if (hDesk != IntPtr.Zero) {
            EnumDesktopWindows(hDesk, proc, IntPtr.Zero);
            CloseDesktop(hDesk);
        }
        EnumWindows(proc, IntPtr.Zero);

        return handles;
    }

    public static int HideProcessWindows(int[] processIds) {
        if (processIds == null || processIds.Length == 0) return 0;
        var handles = GetProcessWindowHandles(processIds);
        int count = 0;
        foreach (var hWnd in handles) {
            if (IsWindowVisible(hWnd)) {
                ShowWindow(hWnd, SW_HIDE);
                count++;
            }
        }
        return count;
    }

    public static int ShowProcessWindows(int[] processIds, bool foreground = true) {
        if (processIds == null || processIds.Length == 0) return 0;
        var handles = GetProcessWindowHandles(processIds);
        int count = 0;
        foreach (var hWnd in handles) {
            var sbClass = new StringBuilder(256);
            GetClassName(hWnd, sbClass, 256);
            string cls = sbClass.ToString();
            if (cls == "Chrome_WidgetWin_1") {
                ShowWindow(hWnd, SW_RESTORE);
                ShowWindow(hWnd, SW_SHOW);
                if (foreground) {
                    SetForegroundWindow(hWnd);
                    BringWindowToTop(hWnd);
                }
                count++;
            }
        }
        return count;
    }
}
'@
    Add-Type -TypeDefinition $nativeCode -IgnoreWarnings
}

function Get-AntigravityMatchingProcessIds {
    param(
        [int]$Port = 0,
        [AllowEmptyString()][string]$LauncherKey = ''
    )

    $procs = Get-AntigravityProcesses
    $matched = [System.Collections.Generic.List[int]]::new()

    foreach ($p in $procs) {
        $cmd = [string]$p.CommandLine
        $isMatch = $false

        if ($Port -gt 0 -and $cmd -match [regex]::Escape("--remote-debugging-port=$Port")) {
            $isMatch = $true
        }
        if (-not $isMatch -and $LauncherKey -and ($cmd -match "(^|[\s""'=])$([regex]::Escape($LauncherKey))($|[\s""'])")) {
            $isMatch = $true
        }

        if ($isMatch) {
            $pidVal = if ($p.ProcessId) { [int]$p.ProcessId } elseif ($p.Id) { [int]$p.Id } else { 0 }
            if ($pidVal -gt 0 -and -not $matched.Contains($pidVal)) {
                $matched.Add($pidVal)
            }
        }
    }

    if ($matched.Count -gt 0) {
        $parentSet = [System.Collections.Generic.HashSet[int]]::new($matched)
        foreach ($p in $procs) {
            $pidVal = if ($p.ProcessId) { [int]$p.ProcessId } elseif ($p.Id) { [int]$p.Id } else { 0 }
            $parentVal = if ($p.ParentProcessId) { [int]$p.ParentProcessId } else { 0 }
            if ($parentVal -gt 0 -and $parentSet.Contains($parentVal)) {
                if (-not $matched.Contains($pidVal)) {
                    $matched.Add($pidVal)
                }
            }
        }
    }

    return @($matched)
}

function Stop-AntigravityMatchingProcesses {
    param(
        [int]$Port = 0,
        [AllowEmptyString()][string]$LauncherKey = '',
        [int[]]$KnownProcessIds = @()
    )

    # Closing an Antigravity window does not necessarily terminate Electron:
    # runInBackground keeps the browser, utility processes, and language server
    # alive. Once the DevTools monitor knows the window is gone, terminate only
    # this launcher instance and all of its descendants.
    $allProcesses = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    if ($allProcesses.Count -eq 0) { return }

    $matchedRootIds = @(
        @(Get-AntigravityMatchingProcessIds -Port $Port -LauncherKey $LauncherKey) +
        @($KnownProcessIds | ForEach-Object { try { [int]$_ } catch { 0 } })
    ) | Where-Object { $_ -gt 0 } | Select-Object -Unique
    if ($matchedRootIds.Count -eq 0) { return }

    $selectedIds = @{}
    foreach ($processId in $matchedRootIds) {
        if ([int]$processId -gt 0) {
            $selectedIds[[string][int]$processId] = $true
        }
    }

    # Walk the complete process tree so that language_server.exe and any
    # non-Antigravity helpers launched by this Electron instance are included.
    do {
        $added = $false
        foreach ($process in $allProcesses) {
            $processId = try { [int]$process.ProcessId } catch { 0 }
            $parentId = try { [int]$process.ParentProcessId } catch { 0 }
            if ($processId -gt 0 -and $parentId -gt 0 -and
                -not $selectedIds.ContainsKey([string]$processId) -and
                $selectedIds.ContainsKey([string]$parentId)) {
                $selectedIds[[string]$processId] = $true
                $added = $true
            }
        }
    } while ($added)

    $parentById = @{}
    foreach ($process in $allProcesses) {
        $processId = try { [int]$process.ProcessId } catch { 0 }
        if ($processId -gt 0) {
            $parentById[[string]$processId] = try { [int]$process.ParentProcessId } catch { 0 }
        }
    }

    $selectedProcesses = @($allProcesses | Where-Object {
        $selectedIds.ContainsKey([string][int]$_.ProcessId)
    })
    $orderedProcesses = @(
        foreach ($process in $selectedProcesses) {
            $depth = 0
            $cursor = [int]$process.ProcessId
            while ($parentById.ContainsKey([string]$cursor) -and $depth -lt 128) {
                $parentId = [int]$parentById[[string]$cursor]
                if ($parentId -le 0 -or $parentId -eq $cursor) { break }
                $depth++
                $cursor = $parentId
            }
            [pscustomobject]@{ Process = $process; Depth = $depth }
        }
    ) | Sort-Object Depth -Descending

    foreach ($entry in $orderedProcesses) {
        try {
            Stop-Process -Id ([int]$entry.Process.ProcessId) -Force -ErrorAction SilentlyContinue
        } catch { }
    }
}

function Hide-AntigravityWindows {
    param(
        [int]$Port = 0,
        [AllowEmptyString()][string]$LauncherKey = ''
    )
    $pids = Get-AntigravityMatchingProcessIds -Port $Port -LauncherKey $LauncherKey
    if ($pids.Count -gt 0) {
        [AntigravityNativeWindows]::HideProcessWindows($pids) | Out-Null
    }
}

function Show-AntigravityWindows {
    param(
        [int]$Port = 0,
        [AllowEmptyString()][string]$LauncherKey = '',
        [switch]$Foreground
    )
    $pids = Get-AntigravityMatchingProcessIds -Port $Port -LauncherKey $LauncherKey
    if ($pids.Count -gt 0) {
        [AntigravityNativeWindows]::ShowProcessWindows($pids, [bool]$Foreground) | Out-Null
    }
}

function Test-AntigravityPlusInjected {
    param(
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutSeconds = 2
    )

    try {
        $page = Get-AntigravityActivePageTarget -Port $Port -TimeoutSeconds $TimeoutSeconds
        if (-not $page -or -not $page.webSocketDebuggerUrl) {
            return $false
        }
        $wsUrl = [string]$page.webSocketDebuggerUrl
        $expr = "Boolean(window.__ANTIGRAVITY_PLUS_RTL_INSTALLED && window.__GEMINI_PLUS_SIDEBAR_ENHANCEMENTS && window.__GEMINI_PLUS_INJECTION_READY)"
        $res = Invoke-CdpEvaluate -WebSocketDebuggerUrl $wsUrl -Expression $expr -TimeoutSeconds $TimeoutSeconds
        if ($res -and $res.result -and $res.result.result -and [bool]$res.result.result.value) {
            return $true
        }
    } catch {}
    return $false
}

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
        [AllowEmptyString()][string]$LauncherKey = '',
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

            if (Test-AntigravityPlusInjected -Port $Port -TimeoutSeconds 1) {
                return $true
            }
        }
        Start-Sleep -Milliseconds 250
    }

    return ($injectedCount -gt 0)
}

function Show-AntigravityLaunchSplash {
    param(
        [AllowEmptyString()][string]$LauncherKey,
        [int]$PreferredPort = 0,
        [int]$TimeoutSeconds = 15
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
            if (Test-AntigravityPlusInjected -Port $PreferredPort -TimeoutSeconds 1) {
                Start-Sleep -Milliseconds 200
                break
            }
        }

        Start-Sleep -Milliseconds 50
    }

    try { $window.Close() } catch {}
    return $true
}

function Clear-AntigravityOrphanedProcesses {
    [CmdletBinding()]
    param()

    $cleaned = 0
    $now = [DateTime]::UtcNow

    # 1. Terminate orphaned PowerShell monitor processes whose targets/ports are inactive (> 30s old)
    $monitorPowershell = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -match 'patch\.ps1["\s]+-Launch'
    })

    foreach ($ps in $monitorPowershell) {
        if ($ps.CreationDate) {
            $ageSec = ($now - $ps.CreationDate.ToUniversalTime()).TotalSeconds
            if ($ageSec -lt 30) { continue }
        }

        $cmd = [string]$ps.CommandLine
        $portMatch = [regex]::Match($cmd, '-Port\s+(\d+)')
        $isPortActive = $false
        if ($portMatch.Success) {
            $p = [int]$portMatch.Groups[1].Value
            if ($p -gt 0) {
                $isPortActive = Test-AntigravityPortResponding -Port $p -TimeoutMs 300
            }
        }

        if (-not $isPortActive) {
            try {
                Stop-Process -Id ([int]$ps.ProcessId) -Force -ErrorAction SilentlyContinue
                $cleaned++
            } catch {}
        }
    }

    # 2. Terminate orphaned Antigravity Plus instances (root process and all descendants) (> 30s old)
    $antigravityRoots = @(Get-CimInstance Win32_Process -Filter "Name = 'Antigravity.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $cmd = [string]$_.CommandLine
        ($cmd -like '*AntigravityPlus\profile*' -or $cmd -like '*--remote-debugging-port=*') -and
        ($cmd -notmatch '--type=')
    })

    foreach ($root in $antigravityRoots) {
        if ($root.CreationDate) {
            $ageSec = ($now - $root.CreationDate.ToUniversalTime()).TotalSeconds
            if ($ageSec -lt 30) { continue }
        }

        $rootPid = [int]$root.ProcessId
        $cmd = [string]$root.CommandLine

        # Check if root has any visible windows
        $hasVisibleWindow = $false
        try {
            $handles = [AntigravityNativeWindows]::GetProcessWindowHandles(@($rootPid))
            foreach ($h in $handles) {
                if ([AntigravityNativeWindows]::IsWindowVisible($h)) {
                    $hasVisibleWindow = $true
                    break
                }
            }
        } catch {}

        if (-not $hasVisibleWindow) {
            $portVal = 0
            $portMatch = [regex]::Match($cmd, '--remote-debugging-port=(\d+)')
            if ($portMatch.Success) {
                $portVal = [int]$portMatch.Groups[1].Value
            }

            $isActive = ($portVal -gt 0 -and (Test-AntigravityPortResponding -Port $portVal -TimeoutMs 300))
            if (-not $isActive) {
                Stop-AntigravityMatchingProcesses -Port $portVal -KnownProcessIds @($rootPid)
                $cleaned++
            }
        }
    }

    # 3. Clean up any leftover child processes belonging to AntigravityPlus profiles whose root PID is gone
    $leftoverChildren = @(Get-CimInstance Win32_Process -Filter "Name = 'Antigravity.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $cmd = [string]$_.CommandLine
        $cmd -like '*AntigravityPlus\profile*' -and ($cmd -match '--type=')
    })
    foreach ($child in $leftoverChildren) {
        if ($child.CreationDate) {
            $ageSec = ($now - $child.CreationDate.ToUniversalTime()).TotalSeconds
            if ($ageSec -lt 30) { continue }
        }

        $parentPid = try { [int]$child.ParentProcessId } catch { 0 }
        $parentAlive = $false
        if ($parentPid -gt 0) {
            $parentProc = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
            if ($parentProc) { $parentAlive = $true }
        }

        if (-not $parentAlive) {
            try {
                Stop-Process -Id ([int]$child.ProcessId) -Force -ErrorAction SilentlyContinue
                $cleaned++
            } catch {}
        }
    }

    return $cleaned
}

function Start-AntigravityPortMonitor {
    param(
        [Parameter(Mandatory)][int]$Port,
        [AllowEmptyString()][string]$LauncherKey,
        [int[]]$KnownProcessIds = @()
    )

    $payload = Get-AntigravityPayloadBundle
    $consecutiveFailures = 0
    $maxFailures = 8
    $startTime = [DateTime]::UtcNow
    $hasEstablishedActiveSession = $false

    if (-not $KnownProcessIds -or $KnownProcessIds.Count -eq 0) {
        $KnownProcessIds = @(Get-AntigravityMatchingProcessIds -Port $Port -LauncherKey $LauncherKey)
    }

    while ($true) {
        # Keep known process IDs updated while the instance is running
        $currentIds = @(Get-AntigravityMatchingProcessIds -Port $Port -LauncherKey $LauncherKey)
        if ($currentIds.Count -gt 0) {
            $KnownProcessIds = @(@($KnownProcessIds) + @($currentIds) | Select-Object -Unique)
        }

        # Check if known root processes are still alive
        if ($KnownProcessIds.Count -gt 0) {
            $alive = @(Get-Process -Id $KnownProcessIds -ErrorAction SilentlyContinue)
            if ($alive.Count -eq 0) {
                # All root processes have terminated
                break
            }
        }

        # Check for DevTools targets
        $targets = $null
        try {
            $targets = @(Get-AntigravityDevToolsTargets -Port $Port -TimeoutSeconds 1)
        } catch {
            $targets = @()
        }

        $pageTargets = @($targets | Where-Object {
            $_.type -eq 'page' -and
            $_.webSocketDebuggerUrl
        })

        $hasRealAppPage = @($pageTargets | Where-Object { $_.url -notlike 'data:text/html*' }).Count -gt 0
        if ($hasRealAppPage) {
            $hasEstablishedActiveSession = $true
        }

        if ($pageTargets.Count -eq 0) {
            $isGracePeriod = ([DateTime]::UtcNow -lt $startTime.AddSeconds(20))
            if (-not $isGracePeriod -and $hasEstablishedActiveSession) {
                $hasVisibleWindow = $false
                try {
                    $handles = [AntigravityNativeWindows]::GetProcessWindowHandles($KnownProcessIds)
                    foreach ($h in $handles) {
                        if ([AntigravityNativeWindows]::IsWindowVisible($h)) {
                            $hasVisibleWindow = $true
                            break
                        }
                    }
                } catch {}

                if (-not $hasVisibleWindow) {
                    $consecutiveFailures++
                    if ($consecutiveFailures -ge $maxFailures) {
                        break
                    }
                } else {
                    $consecutiveFailures = 0
                }
            }
            Start-Sleep -Milliseconds 1000
            continue
        }

        # Reset consecutive failures when valid page targets are active
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

        Start-Sleep -Milliseconds 1000
    }

    # The window is gone or processes terminated. Clean up this exact instance.
    Stop-AntigravityMatchingProcesses -Port $Port -LauncherKey $LauncherKey -KnownProcessIds $KnownProcessIds
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

    # Prune old orphaned zombies (>30s old with no window/targets) before starting
    Clear-AntigravityOrphanedProcesses | Out-Null

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

    # Pre-seed app_storage.json in ASCII (NO UTF-8 BOM) with runInBackground: false to ensure process exits on window close
    $storageFile = Join-Path $userDataDir 'app_storage.json'
    $storageJson = '{"runInBackground":"false","ide-install-wizard-shown":"true","autoCheckForUpdates":"false"}'
    [System.IO.File]::WriteAllText($storageFile, $storageJson, [System.Text.Encoding]::ASCII)

    # Fallback pre-seed in default local data dir
    $fallbackDir = Join-Path $env:LOCALAPPDATA 'Antigravity'
    if (-not (Test-Path -LiteralPath $fallbackDir)) {
        New-Item -ItemType Directory -Force -Path $fallbackDir | Out-Null
    }
    $fallbackStorage = Join-Path $fallbackDir 'app_storage.json'
    if (Test-Path -LiteralPath $fallbackStorage) {
        try {
            $existing = [System.IO.File]::ReadAllText($fallbackStorage)
            if ($existing -match '"runInBackground"\s*:\s*"true"') {
                $updated = $existing -replace '"runInBackground"\s*:\s*"true"', '"runInBackground":"false"'
                [System.IO.File]::WriteAllText($fallbackStorage, $updated, [System.Text.Encoding]::ASCII)
            }
        } catch {}
    } else {
        [System.IO.File]::WriteAllText($fallbackStorage, $storageJson, [System.Text.Encoding]::ASCII)
    }

    Write-Info "Launching fresh Antigravity window on loopback debug port $port..."
    Start-AntigravityWithDebug -ExePath $installInfo.ExePath -Port $port -UserDataDir $userDataDir

    Write-Info "Waiting for Antigravity window to become ready..."
    $injected = Invoke-AntigravityPlusInjectionOnPort -Port $port -LauncherKey $LauncherKey -TimeoutSeconds 30

    if ($injected) {
        Write-Success "Antigravity Plus launched with full RTL & enhancement layer active (Port $port)!"
    } else {
        Write-Warn "Antigravity window launched, but target injection timed out on port $port."
    }

    # Output machine-readable port for parent callers (such as install.ps1 / .bat)
    Write-Output "ANTIGRAVITY_PLUS_LAUNCH_PORT=$port"

    # Start persistent port monitor
    if (-not $NoMonitor) {
        $knownProcessIds = @(Get-AntigravityMatchingProcessIds -Port $port -LauncherKey $LauncherKey)
        Start-AntigravityPortMonitor -Port $port -LauncherKey $LauncherKey -KnownProcessIds $knownProcessIds
    }
}
