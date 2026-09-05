function Install-AntigravityPlus {
    $installInfo = Get-AntigravityInstallInfo
    if (-not $installInfo.Installed) {
        throw 'Antigravity was not found on this system.'
    }

    $sourceRoot = if ($PSScriptRoot) {
        Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    } else {
        (Get-Location).Path
    }

    Write-Info "Installing Antigravity Plus runtime files..."
    $runtimeRoot = Install-AntigravityPlusRuntimeFiles -SourceRoot $sourceRoot
    $runtimePatchScript = Join-Path $runtimeRoot 'patch.ps1'

    Write-Info "Creating launcher batch script..."
    $launcherBatch = Install-AntigravityPlusLauncherBatch -PatchScriptPath $runtimePatchScript

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

    # If Antigravity is currently running, inject right now!
    if ($activePort -gt 0) {
        Write-Info "Detected running Antigravity instance on port $activePort. Performing immediate live injection..."
        $injected = Invoke-AntigravityPlusInjectionOnPort -Port $activePort -TimeoutSeconds 10
        if ($injected) {
            Write-Success "Enhancements live-injected into running Antigravity window!"
        }
    } else {
        Write-Info "Launch Antigravity using your new 'Antigravity Plus' shortcut to activate enhancements."
    }
}

function Restore-AntigravityPlus {
    Write-Info "Restoring Antigravity to original unpatched state..."
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
    $activePort = Get-AntigravityActiveDevToolsPort
    if ($activePort -le 0) {
        throw "No active Antigravity DevTools session was found. Make sure Antigravity is running."
    }

    Write-Info "Connecting to Antigravity on DevTools port $activePort..."
    $success = Invoke-AntigravityPlusInjectionOnPort -Port $activePort -TimeoutSeconds 10
    if ($success) {
        Write-Success "Antigravity Plus enhancements successfully injected into running window!"
    } else {
        Write-Err "Could not inject into running Antigravity targets."
    }
}
