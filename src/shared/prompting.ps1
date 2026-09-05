function Show-Banner {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "                ANTIGRAVITY PLUS                          " -ForegroundColor White
    Write-Host "     Enhanced Runtime & RTL Layer for Antigravity         " -ForegroundColor Gray
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$Choices,
        [int]$Default = 1
    )

    for ($i = 0; $i -lt $Choices.Count; $i++) {
        $num = $i + 1
        $marker = if ($num -eq $Default) { "*" } else { " " }
        Write-Host "  $num. $($Choices[$i]) $marker"
    }
    Write-Host ""
    $response = Read-Host "$Prompt [Default: $Default]"
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }
    $val = 0
    if ([int]::TryParse($response, [ref]$val) -and $val -ge 1 -and $val -le $Choices.Count) {
        return $val
    }
    return $Default
}

function Read-YesNo {
    param(
        [string]$Prompt,
        [bool]$Default = $true
    )

    $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }
    $response = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }
    return ($response.Trim().ToLowerInvariant().StartsWith('y'))
}
