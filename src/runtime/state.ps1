function Read-AntigravityPlusState {
    $statePath = Get-AntigravityPlusStatePath
    if (-not (Test-Path -LiteralPath $statePath)) {
        return $null
    }
    try {
        $content = [System.IO.File]::ReadAllText($statePath, [System.Text.Encoding]::UTF8)
        return ($content | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Save-AntigravityPlusState {
    param([Parameter(Mandatory)]$State)

    $statePath = Get-AntigravityPlusStatePath
    $parent = Split-Path -Parent $statePath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $json = $State | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($statePath, $json, [System.Text.Encoding]::UTF8)
}

function New-AntigravityPlusState {
    param(
        [Parameter(Mandatory)]$InstallInfo,
        [int]$Port = 0,
        [string[]]$OwnedShortcuts = @(),
        [string]$LastCommitSha = '',
        [switch]$NoUpdate
    )

    return [pscustomobject]@{
        Installed = $true
        AppVersion = $InstallInfo.Version
        AppExe = $InstallInfo.ExePath
        Port = $Port
        OwnedShortcuts = @($OwnedShortcuts)
        NoUpdate = [bool]$NoUpdate
        LastCommitSha = $LastCommitSha
        LastUpdateCheck = [DateTimeOffset]::Now.ToString('o')
        LastUpdated = [DateTimeOffset]::Now.ToString('o')
        CreatedAt = [DateTimeOffset]::Now.ToString('o')
        UpdatedAt = [DateTimeOffset]::Now.ToString('o')
    }
}

function Get-AntigravityPlusUserDataDirectory {
    param([AllowEmptyString()][string]$LauncherKey)

    $profileRoot = Join-Path $env:LOCALAPPDATA 'AntigravityPlus\profile'
    $profilePath = if ([string]::IsNullOrWhiteSpace($LauncherKey)) {
        $profileRoot
    } else {
        Join-Path $profileRoot $LauncherKey
    }
    if (-not (Test-Path -LiteralPath $profilePath)) {
        New-Item -ItemType Directory -Force -Path $profilePath | Out-Null
    }
    return $profilePath
}
