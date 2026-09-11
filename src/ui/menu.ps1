function Show-AntigravityPlusMenu {
    $installInfo = Get-AntigravityInstallInfo
    $activePort = Get-AntigravityActiveDevToolsPort

    Show-Banner

    $statusColor = if ($installInfo.Installed) { "Green" } else { "Red" }
    $statusText = if ($installInfo.Installed) { "Found ($($installInfo.Version))" } else { "Not Found" }
    Write-Host "Antigravity Desktop: " -NoNewline
    Write-Host $statusText -ForegroundColor $statusColor

    if ($activePort -gt 0) {
        Write-Host "Active Session:      " -NoNewline
        Write-Host "Running (Port $activePort)" -ForegroundColor Green
    } else {
        Write-Host "Active Session:      " -NoNewline
        Write-Host "Not Running" -ForegroundColor Gray
    }
    $state = Read-AntigravityPlusState
    $updateStatus = if ($state -and $state.NoUpdate -eq $true) { "Disabled (-NoUpdate)" } else { "Enabled (GitHub)" }
    Write-Host "Auto-Update:         " -NoNewline
    Write-Host $updateStatus -ForegroundColor Cyan

    $choices = @(
        "Patch / Install Antigravity Plus",
        "Live Inject into Running Antigravity",
        "Launch Antigravity Plus",
        "Check for Updates / Update from GitHub",
        "Restore Antigravity Plus",
        "Clean Orphaned Background Processes",
        "Exit"
    )

    $selected = Read-Choice -Prompt "Select an option" -Choices $choices -Default 1

    switch ($selected) {
        1 {
            Install-AntigravityPlus
        }
        2 {
            Invoke-AntigravityPlusLiveInject
        }
        3 {
            Launch-AntigravityPlus
        }
        4 {
            Update-AntigravityPlus -Force
        }
        5 {
            Restore-AntigravityPlus
        }
        6 {
            $count = Clear-AntigravityOrphanedProcesses
            Write-Success "Cleaned up $count orphaned background process(es)."
        }
        7 {
            Write-Host "Exiting." -ForegroundColor Gray
            return
        }
    }
}
