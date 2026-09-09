function Install-AntigravityPlus {
    $installInfo = Get-AntigravityInstallInfo
    if (-not $installInfo.Installed) {
        throw 'Antigravity was not found on this system.'
    }

    # Clean up any leftover orphaned background processes
    Clear-AntigravityOrphanedProcesses | Out-Null

    $sourceRoot = if ($PSScriptRoot) {
        Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    } else {
        (Get-Location).Path
    }

    Write-Info "Installing Antigravity Plus runtime files..."
    $runtimeRoot = Install-AntigravityPlusRuntimeFiles -SourceRoot $sourceRoot
    $runtimePatchScript = Join-Path $runtimeRoot 'patch.ps1'

    Write-Info "Creating launcher scripts..."
    $launcherBatch = Install-AntigravityPlusLauncherBatch -PatchScriptPath $runtimePatchScript
    $launcherScript = Install-AntigravityPlusLauncherScript -PatchScriptPath $runtimePatchScript

    Write-Info "Creating Antigravity Plus shortcuts..."
    $ownedShortcuts = @(Install-AntigravityPlusShortcuts -PatchScriptPath $runtimePatchScript -ExeIconPath $installInfo.ExePath)

    $activePort = Get-AntigravityActiveDevToolsPort
    $state = New-AntigravityPlusState -InstallInfo $installInfo -Port $activePort -OwnedShortcuts $ownedShortcuts
    Save-AntigravityPlusState -State $state

    Write-Success "Antigravity Plus installed successfully!"
    Write-Success "Created $($ownedShortcuts.Count) shortcut(s):"
    foreach ($sc in $ownedShortcuts) {
        Write-Host "    $sc" -ForegroundColor Cyan
    }

    Write-Info "Antigravity Plus runtime synchronized and launcher shortcuts ready."
}

function Restore-AntigravityPlus {
    Write-Info "Restoring Antigravity to original unpatched state..."
    Clear-AntigravityOrphanedProcesses | Out-Null

    $state = Read-AntigravityPlusState
    $ownedShortcuts = if ($state -and $state.OwnedShortcuts) { @($state.OwnedShortcuts) } else { @() }

    $removed = Remove-AntigravityPlusShortcuts -Shortcuts $ownedShortcuts
    Write-Success "Removed $removed owned Antigravity Plus shortcut(s)."

    $statePath = Get-AntigravityPlusStatePath
    if (Test-Path -LiteralPath $statePath) {
        Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    }

    $launcherBatch = Get-AntigravityPlusLauncherScriptPath
    if (Test-Path -LiteralPath $launcherBatch) {
        Remove-Item -LiteralPath $launcherBatch -Force -ErrorAction SilentlyContinue
    }

    Write-Success "Antigravity Plus runtime removed."
    Write-Info "You can now open Antigravity normally via its default shortcut."
}

function Invoke-AntigravityPlusLiveInject {
    $activePorts = @(Get-AntigravityActiveDevToolsPorts)
    if ($activePorts.Count -eq 0) {
        $fallbackPort = Get-AntigravityActiveDevToolsPort
        if ($fallbackPort -gt 0) {
            $activePorts = @($fallbackPort)
        }
    }

    if ($activePorts.Count -eq 0) {
        throw "No active Antigravity DevTools session was found. Make sure Antigravity is running."
    }

    $totalSuccess = 0
    foreach ($port in $activePorts) {
        Write-Info "Connecting to Antigravity on DevTools port $port..."
        $success = Invoke-AntigravityPlusInjectionOnPort -Port $port -TimeoutSeconds 10
        if ($success) {
            $totalSuccess++
            Write-Success "Antigravity Plus enhancements successfully injected into window on port $port!"
        }
    }

    if ($totalSuccess -eq 0) {
        Write-Err "Could not inject into running Antigravity targets."
    }
}
