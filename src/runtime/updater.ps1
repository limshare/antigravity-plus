function Get-AntigravityPlusTrackedFiles {
    return @(
        'patch.ps1',
        'src\shared\logging.ps1',
        'src\shared\prompting.ps1',
        'src\shared\asar.ps1',
        'src\shared\cdp.ps1',
        'src\antigravity\detection.ps1',
        'src\antigravity\rtl-shared.ps1',
        'src\antigravity\rtl-payload.ps1',
        'src\antigravity\ui-enhancements.ps1',
        'src\antigravity\context-badge.ps1',
        'src\antigravity\sidebar-enhancements.ps1',
        'src\antigravity\composer-top-bar.ps1',
        'src\antigravity\payload-bundle.ps1',
        'src\runtime\files.ps1',
        'src\runtime\state.ps1',
        'src\runtime\shortcuts.ps1',
        'src\runtime\launch.ps1',
        'src\runtime\patching.ps1',
        'src\runtime\updater.ps1',
        'src\ui\menu.ps1'
    )
}

function Get-AntigravityPlusGitHubRepoInfo {
    $repo = if ($env:ANTIGRAVITY_PLUS_REPO) { $env:ANTIGRAVITY_PLUS_REPO } else { 'limshare/antigravity-plus' }
    $branch = if ($env:ANTIGRAVITY_PLUS_BRANCH) { $env:ANTIGRAVITY_PLUS_BRANCH } else { 'main' }
    return [pscustomobject]@{
        Repo = $repo
        Branch = $branch
        RawBaseUrl = "https://raw.githubusercontent.com/$repo/$branch"
        ApiCommitUrl = "https://api.github.com/repos/$repo/commits/$branch"
    }
}

function Get-AntigravityPlusRemoteCommitSha {
    param([int]$TimeoutSeconds = 3)

    $repoInfo = Get-AntigravityPlusGitHubRepoInfo
    try {
        $headers = @{
            'User-Agent' = 'AntigravityPlus-Updater'
            'Accept' = 'application/vnd.github.v3+json'
        }
        $response = Invoke-RestMethod -Uri $repoInfo.ApiCommitUrl -Headers $headers -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        if ($response -and $response.sha) {
            return [string]$response.sha
        }
    } catch {
        # Quietly handle rate limit or offline
    }
    return $null
}

function Test-AntigravityPlusUpdateAvailable {
    param([int]$TimeoutSeconds = 3)

    $state = Read-AntigravityPlusState
    $currentSha = if ($state -and $state.LastCommitSha) { [string]$state.LastCommitSha } else { '' }
    $remoteSha = Get-AntigravityPlusRemoteCommitSha -TimeoutSeconds $TimeoutSeconds

    $isAvailable = ($null -ne $remoteSha -and $remoteSha -ne '' -and $remoteSha -ne $currentSha)
    return [pscustomobject]@{
        UpdateAvailable = $isAvailable
        RemoteSha = $remoteSha
        CurrentSha = $currentSha
    }
}

function Update-AntigravityPlus {
    param(
        [string]$TargetDirectory = '',
        [switch]$Force,
        [switch]$Silent,
        [int]$TimeoutSeconds = 5
    )

    if ([string]::IsNullOrWhiteSpace($TargetDirectory)) {
        $TargetDirectory = Get-AntigravityPlusRuntimeRoot
    }

    $repoInfo = Get-AntigravityPlusGitHubRepoInfo
    $state = Read-AntigravityPlusState
    $currentSha = if ($state -and $state.LastCommitSha) { [string]$state.LastCommitSha } else { '' }

    if (-not $Silent) {
        Write-Info "Checking for Antigravity Plus updates from $($repoInfo.Repo) ($($repoInfo.Branch))..."
    }

    $remoteSha = Get-AntigravityPlusRemoteCommitSha -TimeoutSeconds $TimeoutSeconds

    if (-not $Force -and $remoteSha -and $currentSha -and ($remoteSha -eq $currentSha)) {
        if (-not $Silent) {
            $shortSha = $remoteSha.Substring(0, [Math]::Min(7, $remoteSha.Length))
            Write-Success "Antigravity Plus is already up to date ($shortSha)."
        }
        if ($state) {
            $state | Add-Member -NotePropertyName 'LastUpdateCheck' -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
            Save-AntigravityPlusState -State $state
        }
        return $false
    }

    if (-not $Silent) {
        Write-Info "Downloading updated components from GitHub..."
    }

    $stageDir = Join-Path $env:TEMP ("antigravity-plus-update-" + [guid]::NewGuid().ToString('N'))
    $files = Get-AntigravityPlusTrackedFiles

    try {
        New-Item -Path $stageDir -ItemType Directory -Force | Out-Null
        $downloadedCount = 0

        foreach ($relPath in $files) {
            $urlPath = $relPath.Replace('\', '/')
            $destFile = Join-Path $stageDir $relPath
            $parentDir = Split-Path -Parent $destFile
            if (-not (Test-Path -LiteralPath $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }
            $url = "$($repoInfo.RawBaseUrl)/$urlPath"
            try {
                Invoke-WebRequest -Uri $url -OutFile $destFile -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
                $downloadedCount++
            } catch {
                $statusCode = try { [int]$_.Exception.Response.StatusCode } catch { 0 }
                if ($statusCode -eq 404 -or $_.Exception.Message -match '\b404\b') {
                    # Skip optional or newly added local files not yet on remote
                } else {
                    throw $_
                }
            }
        }

        if ($downloadedCount -eq 0) {
            throw "No files were downloaded."
        }

        # Copy files into TargetDirectory
        if (-not (Test-Path -LiteralPath $TargetDirectory)) {
            New-Item -Path $TargetDirectory -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path "$stageDir\*" -Destination $TargetDirectory -Recurse -Force | Out-Null

        # Refresh launcher scripts in runtime root
        $runtimePatchScript = Join-Path $TargetDirectory 'patch.ps1'
        if (Test-Path -LiteralPath $runtimePatchScript) {
            Install-AntigravityPlusLauncherBatch -PatchScriptPath $runtimePatchScript | Out-Null
            Install-AntigravityPlusLauncherScript -PatchScriptPath $runtimePatchScript | Out-Null
        }

        # Update state
        if (-not $state) {
            $installInfo = Get-AntigravityInstallInfo
            $state = New-AntigravityPlusState -InstallInfo $installInfo
        }
        if ($remoteSha) {
            $state | Add-Member -NotePropertyName 'LastCommitSha' -NotePropertyValue $remoteSha -Force
        }
        $state | Add-Member -NotePropertyName 'LastUpdateCheck' -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
        $state | Add-Member -NotePropertyName 'LastUpdated' -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
        $state | Add-Member -NotePropertyName 'UpdatedAt' -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
        Save-AntigravityPlusState -State $state

        if (-not $Silent) {
            $shaText = if ($remoteSha) { " (" + $remoteSha.Substring(0, [Math]::Min(7, $remoteSha.Length)) + ")" } else { "" }
            Write-Success "Antigravity Plus successfully updated from GitHub$shaText!"
        }

        return $true
    } catch {
        if (-not $Silent) {
            Write-Warn "Could not update Antigravity Plus: $($_.Exception.Message)"
        }
        return $false
    } finally {
        if (Test-Path -LiteralPath $stageDir) {
            Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-AntigravityPlusStartupUpdate {
    param(
        [string]$TargetDirectory = '',
        [int]$TimeoutSeconds = 3
    )

    # Fast non-blocking update attempt for startup
    try {
        $updated = Update-AntigravityPlus -TargetDirectory $TargetDirectory -Silent -TimeoutSeconds $TimeoutSeconds
        if ($updated) {
            Write-Info "Antigravity Plus updated to latest version from GitHub."
        }
    } catch {
        # Ensure update never blocks startup on network errors
    }
}
