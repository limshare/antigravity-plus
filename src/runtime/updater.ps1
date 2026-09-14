function Get-AntigravityPlusTrackedFiles {
    @(
        'patch.ps1', 'src/shared/logging.ps1', 'src/shared/prompting.ps1', 'src/shared/asar.ps1', 'src/shared/cdp.ps1',
        'src/antigravity/detection.ps1', 'src/antigravity/rtl-shared.ps1', 'src/antigravity/rtl-payload.ps1',
        'src/antigravity/ui-enhancements.ps1', 'src/antigravity/context-badge.ps1', 'src/antigravity/sidebar-enhancements.ps1',
        'src/antigravity/composer-top-bar.ps1', 'src/antigravity/payload-bundle.ps1', 'src/runtime/files.ps1',
        'src/runtime/state.ps1', 'src/runtime/shortcuts.ps1', 'src/runtime/launch.ps1', 'src/runtime/patching.ps1',
        'src/runtime/updater.ps1', 'src/ui/menu.ps1'
    )
}

function Get-AntigravityPlusGitHubRepoInfo {
    $repo = if ($env:ANTIGRAVITY_PLUS_REPO) { $env:ANTIGRAVITY_PLUS_REPO } else { 'limshare/antigravity-plus' }
    $branch = if ($env:ANTIGRAVITY_PLUS_BRANCH) { $env:ANTIGRAVITY_PLUS_BRANCH } else { 'main' }
    [pscustomobject]@{ Repo = $repo; Branch = $branch; ApiCommitUrl = "https://api.github.com/repos/$repo/commits/$branch" }
}

function Get-AntigravityPlusRemoteBytes {
    param([Parameter(Mandatory)][string]$Url, [int]$TimeoutSeconds = 5)
    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
    $client = [System.Net.Http.HttpClient]::new()
    try {
        $client.Timeout = [TimeSpan]::FromSeconds([Math]::Max(1, $TimeoutSeconds))
        $client.DefaultRequestHeaders.UserAgent.ParseAdd('AntigravityPlus-Updater')
        $response = $client.GetAsync($Url).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode()
        try { return $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult() } finally { $response.Dispose() }
    } finally { $client.Dispose() }
}

function Get-AntigravityPlusRemoteCommitSha {
    param([int]$TimeoutSeconds = 3)
    try {
        $repoInfo = Get-AntigravityPlusGitHubRepoInfo
        $response = [Text.Encoding]::UTF8.GetString((Get-AntigravityPlusRemoteBytes -Url $repoInfo.ApiCommitUrl -TimeoutSeconds $TimeoutSeconds)) | ConvertFrom-Json
        if ($response -and $response.sha -match '^[0-9a-fA-F]{40}$') { return [string]$response.sha }
    } catch {}
    return $null
}

function Get-AntigravityPlusSha256Bytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() } finally { $algorithm.Dispose() }
}

function Test-AntigravityPlusSafeRelativePath {
    param([Parameter(Mandatory)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path)) { return $false }
    $normalized = $Path.Replace('\', '/')
    return -not ($normalized.StartsWith('/') -or $normalized -match '(^|/)\.\.(\/|$)' -or $normalized -match '^[A-Za-z]:')
}

function Test-AntigravityPlusStagedPowerShellFile {
    param([Parameter(Mandatory)][string]$Path)
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count -gt 0) { throw "Downloaded PowerShell file failed validation: $Path" }
}

function Get-AntigravityPlusRemoteManifest {
    param([Parameter(Mandatory)][string]$RawBaseUrl, [int]$TimeoutSeconds = 5)
    $bytes = Get-AntigravityPlusRemoteBytes -Url "$RawBaseUrl/runtime-manifest.json" -TimeoutSeconds $TimeoutSeconds
    $manifest = ([Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)) | ConvertFrom-Json
    if (-not $manifest -or [int]$manifest.schema -ne 1 -or @($manifest.files).Count -eq 0) { throw 'The remote Antigravity Plus runtime manifest is invalid.' }
    [pscustomobject]@{ Manifest = $manifest; Bytes = $bytes }
}

function Update-AntigravityPlusRuntimeFilesFromCommit {
    param([Parameter(Mandatory)][string]$TargetDirectory, [Parameter(Mandatory)][string]$CommitSha, [int]$TimeoutSeconds = 5)

    $repoInfo = Get-AntigravityPlusGitHubRepoInfo
    $rawBaseUrl = "https://raw.githubusercontent.com/$($repoInfo.Repo)/$CommitSha"
    $remoteManifest = Get-AntigravityPlusRemoteManifest -RawBaseUrl $rawBaseUrl -TimeoutSeconds $TimeoutSeconds
    $parent = Split-Path -Parent $TargetDirectory
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $stageDir = Join-Path $parent ('.antigravity-plus-update-' + [guid]::NewGuid().ToString('N'))
    $backupDir = Join-Path $parent ('.antigravity-plus-backup-' + [guid]::NewGuid().ToString('N'))
    $stageMoved = $false
    try {
        New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
        foreach ($entry in @($remoteManifest.Manifest.files)) {
            $sourcePath = [string]$entry.path
            $targetPath = if ($entry.target) { [string]$entry.target } else { $sourcePath }
            if (-not (Test-AntigravityPlusSafeRelativePath -Path $sourcePath) -or -not (Test-AntigravityPlusSafeRelativePath -Path $targetPath)) { throw "Unsafe path in the remote runtime manifest: $sourcePath" }
            if ($entry.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "Missing SHA-256 for remote runtime file: $sourcePath" }
            $destination = Join-Path $stageDir ($targetPath.Replace('/', '\'))
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            $bytes = Get-AntigravityPlusRemoteBytes -Url "$rawBaseUrl/$($sourcePath.Replace('\', '/'))" -TimeoutSeconds $TimeoutSeconds
            if ($entry.size -ne $null -and [int64]$entry.size -ne $bytes.Length) { throw "Size mismatch for remote runtime file: $sourcePath" }
            if ((Get-AntigravityPlusSha256Bytes -Bytes $bytes) -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "SHA-256 mismatch for remote runtime file: $sourcePath" }
            [IO.File]::WriteAllBytes($destination, $bytes)
            if ([IO.Path]::GetExtension($destination) -ieq '.ps1') { Test-AntigravityPlusStagedPowerShellFile -Path $destination }
        }
        [IO.File]::WriteAllBytes((Join-Path $stageDir 'runtime-manifest.json'), $remoteManifest.Bytes)
        $patchPath = Join-Path $stageDir 'patch.ps1'
        if (-not (Test-Path -LiteralPath $patchPath -PathType Leaf)) { throw 'The update did not contain patch.ps1.' }
        if (Test-Path -LiteralPath $TargetDirectory) { Move-Item -LiteralPath $TargetDirectory -Destination $backupDir -Force }
        Move-Item -LiteralPath $stageDir -Destination $TargetDirectory -Force
        $stageMoved = $true
        $newFiles = Join-Path $TargetDirectory 'src\runtime\files.ps1'
        if (Test-Path -LiteralPath $newFiles) { . $newFiles }
        $newPatchPath = $patchPath.Replace($stageDir, $TargetDirectory)
        Install-AntigravityPlusLauncherBatch -PatchScriptPath $newPatchPath | Out-Null
        Install-AntigravityPlusLauncherScript -PatchScriptPath $newPatchPath | Out-Null
        if (Test-Path -LiteralPath $backupDir) { Remove-Item -LiteralPath $backupDir -Recurse -Force }
        return $true
    } catch {
        if ($stageMoved -and (Test-Path -LiteralPath $TargetDirectory)) { Remove-Item -LiteralPath $TargetDirectory -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $backupDir) {
            try { Move-Item -LiteralPath $backupDir -Destination $TargetDirectory -Force -ErrorAction Stop }
            catch { Write-Warn "Antigravity Plus rollback could not restore the previous runtime: $($_.Exception.Message)" }
        }
        throw
    } finally {
        if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Test-AntigravityPlusUpdateAvailable {
    param([int]$TimeoutSeconds = 3)
    $state = Read-AntigravityPlusState
    $currentSha = if ($state -and $state.LastCommitSha) { [string]$state.LastCommitSha } else { '' }
    $remoteSha = Get-AntigravityPlusRemoteCommitSha -TimeoutSeconds $TimeoutSeconds
    [pscustomobject]@{ UpdateAvailable = ($remoteSha -and $remoteSha -ne $currentSha); RemoteSha = $remoteSha; CurrentSha = $currentSha }
}

function Update-AntigravityPlus {
    param([string]$TargetDirectory = '', [switch]$Force, [switch]$Silent, [int]$TimeoutSeconds = 5)
    if ([string]::IsNullOrWhiteSpace($TargetDirectory)) { $TargetDirectory = Get-AntigravityPlusRuntimeRoot }
    $repoInfo = Get-AntigravityPlusGitHubRepoInfo
    $state = Read-AntigravityPlusState
    $currentSha = if ($state -and $state.LastCommitSha) { [string]$state.LastCommitSha } else { '' }
    if (-not $Silent) { Write-Info "Checking for Antigravity Plus updates from $($repoInfo.Repo) ($($repoInfo.Branch))..." }
    $remoteSha = Get-AntigravityPlusRemoteCommitSha -TimeoutSeconds ([Math]::Min(3, $TimeoutSeconds))
    if (-not $remoteSha) { throw 'Could not resolve the latest Antigravity Plus commit from GitHub.' }
    if (-not $Force -and $currentSha -and $remoteSha -eq $currentSha) {
        if ($state) { $state | Add-Member -NotePropertyName 'LastUpdateCheck' -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force; Save-AntigravityPlusState -State $state }
        if (-not $Silent) { Write-Success "Antigravity Plus is already up to date ($($remoteSha.Substring(0, 7)))." }
        return $false
    }
    try {
        Update-AntigravityPlusRuntimeFilesFromCommit -TargetDirectory $TargetDirectory -CommitSha $remoteSha -TimeoutSeconds $TimeoutSeconds | Out-Null
        if (-not $state) { $state = New-AntigravityPlusState -InstallInfo (Get-AntigravityInstallInfo) }
        $state | Add-Member -NotePropertyName 'LastCommitSha' -NotePropertyValue $remoteSha -Force
        $state | Add-Member -NotePropertyName 'LastUpdateCheck' -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
        $state | Add-Member -NotePropertyName 'LastUpdated' -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
        Save-AntigravityPlusState -State $state
        if (-not $Silent) { Write-Success "Antigravity Plus updated from GitHub ($($remoteSha.Substring(0, 7)))." }
        return $true
    } catch {
        if (-not $Silent) { Write-Warn "Antigravity Plus update failed; the previous runtime was kept: $($_.Exception.Message)" }
        return $false
    }
}

function Invoke-AntigravityPlusStartupUpdate {
    param([string]$TargetDirectory = '', [switch]$NoUpdate, [int]$TimeoutSeconds = 3)
    if ($NoUpdate -or $env:ANTIGRAVITY_PLUS_NO_UPDATE -eq '1') { return $false }
    try { return [bool](Update-AntigravityPlus -TargetDirectory $TargetDirectory -Silent -TimeoutSeconds $TimeoutSeconds) } catch { return $false }
}
