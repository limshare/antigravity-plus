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

function Launch-AntigravityPlus {
    param(
        [int]$PreferredPort = 0
    )

    $installInfo = Get-AntigravityInstallInfo
    if (-not $installInfo.Installed) {
        throw 'Antigravity was not found. Please install Google Antigravity first.'
    }

    # If Antigravity is already running with an active DevTools port, inject into it!
    $activePort = Get-AntigravityActiveDevToolsPort
    if ($activePort -gt 0) {
        Write-Info "Found active Antigravity session on DevTools port $activePort. Injecting enhancements..."
        $success = Invoke-AntigravityPlusInjectionOnPort -Port $activePort -TimeoutSeconds 10
        if ($success) {
            Write-Success "Antigravity Plus enhancements successfully injected into active session!"
            return
        }
    }

    # Otherwise, launch a fresh instance with remote debugging enabled
    $port = if ($PreferredPort -gt 0) { $PreferredPort } else { Get-AntigravityAvailablePort }
    Write-Info "Launching Antigravity on loopback port $port..."

    $proc = Start-AntigravityWithDebug -ExePath $installInfo.ExePath -Port $port
    Write-Info "Waiting for Antigravity window to initialize..."

    $success = Invoke-AntigravityPlusInjectionOnPort -Port $port -TimeoutSeconds 30
    if ($success) {
        Write-Success "Antigravity Plus launched with full RTL & enhancement layer active (Port $port)!"
    } else {
        Write-Warn "Antigravity process launched, but DevTools targets took longer than expected to appear."
    }
}
