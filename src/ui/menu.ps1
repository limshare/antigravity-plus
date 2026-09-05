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
    Write-Host ""

    $choices = @(
        "Patch / Install Antigravity Plus",
        "Live Inject into Running Antigravity",
        "Launch Antigravity Plus",
        "Restore Antigravity Plus",
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
            Restore-AntigravityPlus
        }
        5 {
            Write-Host "Exiting." -ForegroundColor Gray
            return
        }
    }
}
