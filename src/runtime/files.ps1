function Get-AntigravityPlusRoot {
    return (Join-Path $env:LOCALAPPDATA 'Antigravity Plus')
}

function Get-AntigravityPlusRuntimeRoot {
    return (Join-Path (Get-AntigravityPlusRoot) 'runtime')
}

function Get-AntigravityPlusStatePath {
    return (Join-Path (Get-AntigravityPlusRoot) 'state.json')
}

function Get-AntigravityPlusLauncherScriptPath {
    return (Join-Path (Get-AntigravityPlusRoot) 'launch.bat')
}

function Install-AntigravityPlusRuntimeFiles {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $runtimeRoot = Get-AntigravityPlusRuntimeRoot
    if (-not (Test-Path -LiteralPath $runtimeRoot)) {
        New-Item -Path $runtimeRoot -ItemType Directory -Force | Out-Null
    }

    # Copy src files into runtime
    $srcSource = Join-Path $SourceRoot 'src'
    $srcDest = Join-Path $runtimeRoot 'src'
    if (Test-Path -LiteralPath $srcSource) {
        Copy-Item -Path $srcSource -Destination $runtimeRoot -Recurse -Force | Out-Null
    }

    # Copy patch.ps1 into runtime
    $patchSource = Join-Path $SourceRoot 'patch.ps1'
    if (Test-Path -LiteralPath $patchSource) {
        Copy-Item -Path $patchSource -Destination $runtimeRoot -Force | Out-Null
    }

    return $runtimeRoot
}

function Install-AntigravityPlusLauncherBatch {
    param([Parameter(Mandatory)][string]$PatchScriptPath)

    $launcherPath = Get-AntigravityPlusLauncherScriptPath
    $content = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PatchScriptPath" -Launch %*
"@
    [System.IO.File]::WriteAllText($launcherPath, $content, [System.Text.Encoding]::ASCII)
    return $launcherPath
}
