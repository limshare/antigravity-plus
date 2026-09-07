function Create-AntigravityShortcut {
    param(
        [Parameter(Mandatory)][string]$ShortcutPath,
        [Parameter(Mandatory)][string]$TargetPath,
        [string]$Arguments = '',
        [string]$WorkingDirectory = '',
        [string]$IconLocation = '',
        [string]$Description = 'Antigravity Plus - Enhanced Runtime with RTL'
    )

    $parentDir = Split-Path -Parent $ShortcutPath
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    if ($Arguments) {
        $shortcut.Arguments = $Arguments
    }
    if ($WorkingDirectory) {
        $shortcut.WorkingDirectory = $WorkingDirectory
    }
    if ($IconLocation) {
        $shortcut.IconLocation = $IconLocation
    }
    $shortcut.Description = $Description
    $shortcut.WindowStyle = 7 # Minimized / background
    $shortcut.Save()
}

function Install-AntigravityPlusShortcuts {
    param(
        [Parameter(Mandatory)][string]$PatchScriptPath,
        [string]$ExeIconPath = ''
    )

    $desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Antigravity Plus.lnk'
    $startMenuDir = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'
    $startMenuShortcut = Join-Path $startMenuDir 'Antigravity Plus.lnk'

    $wscriptPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
    $launcherVbs = Get-AntigravityPlusLauncherVbsPath
    $launcherKey = "antigravity-plus"
    $desktopArgs = "`"$launcherVbs`" `"$launcherKey`" desktop"
    $startMenuArgs = "`"$launcherVbs`" `"$launcherKey`""
    $workDir = Get-AntigravityPlusRoot

    $icon = if ($ExeIconPath -and (Test-Path -LiteralPath $ExeIconPath)) {
        $ExeIconPath
    } else {
        $wscriptPath
    }

    $created = @()

    try {
        Create-AntigravityShortcut `
            -ShortcutPath $desktopShortcut `
            -TargetPath $wscriptPath `
            -Arguments $desktopArgs `
            -WorkingDirectory $workDir `
            -IconLocation "$icon,0"
        $created += $desktopShortcut
    } catch {
        Write-Warn "Could not create Desktop shortcut: $($_.Exception.Message)"
    }

    try {
        Create-AntigravityShortcut `
            -ShortcutPath $startMenuShortcut `
            -TargetPath $wscriptPath `
            -Arguments $startMenuArgs `
            -WorkingDirectory $workDir `
            -IconLocation "$icon,0"
        $created += $startMenuShortcut
    } catch {
        Write-Warn "Could not create Start Menu shortcut: $($_.Exception.Message)"
    }

    return $created
}

function Remove-AntigravityPlusShortcuts {
    param([string[]]$Shortcuts = @())

    $targets = if ($Shortcuts.Count -gt 0) { $Shortcuts } else {
        @(
            (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Antigravity Plus.lnk'),
            (Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\Antigravity Plus.lnk')
        )
    }

    $removed = 0
    foreach ($sc in $targets) {
        if ($sc -and (Test-Path -LiteralPath $sc)) {
            try {
                Remove-Item -LiteralPath $sc -Force -ErrorAction SilentlyContinue
                $removed++
            } catch {}
        }
    }
    return $removed
}
