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

function Get-AntigravityPlusLauncherVbsPath {
    return (Join-Path (Get-AntigravityPlusRuntimeRoot) 'launch-antigravity-plus.vbs')
}

function New-AntigravityPlusLauncherVbsContent {
    param([Parameter(Mandatory)][string]$PatchScriptPath)

    $escapedPatchScriptPath = $PatchScriptPath.Replace('"', '""')
@"
Set shell = CreateObject("WScript.Shell")
launcherKey = ""
desktopLaunch = False
If WScript.Arguments.Count > 0 Then
    launcherKey = WScript.Arguments(0)
End If
If WScript.Arguments.Count > 1 Then
    desktopLaunch = (LCase(WScript.Arguments(1)) = "desktop")
End If
preferredPort = 0
portFromEnvironment = shell.Environment("Process")("ANTIGRAVITY_PLUS_REQUESTED_PORT")
If portFromEnvironment <> "" Then
    On Error Resume Next
    preferredPort = CLng(portFromEnvironment)
    On Error GoTo 0
End If
For argumentIndex = 1 To WScript.Arguments.Count - 1
    If IsNumeric(WScript.Arguments(argumentIndex)) Then
        On Error Resume Next
        preferredPort = CLng(WScript.Arguments(argumentIndex))
        On Error GoTo 0
        Exit For
    End If
Next
If preferredPort = 0 Then
    Randomize
    preferredPort = Int((45000 - 20000 + 1) * Rnd + 20000)
End If
guidStr = Mid(CreateObject("Scriptlet.TypeLib").Guid, 2, 36)
If launcherKey <> "" Then
    instanceKey = launcherKey & "-" & guidStr
    shell.Environment("Process")("ANTIGRAVITY_PLUS_LAUNCHER_KEY") = instanceKey
Else
    instanceKey = guidStr
    shell.Environment("Process")("ANTIGRAVITY_PLUS_LAUNCHER_KEY") = instanceKey
End If
If desktopLaunch Then
    shell.Environment("Process")("ANTIGRAVITY_PLUS_DESKTOP_LAUNCH") = "1"
End If
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & "$escapedPatchScriptPath" & Chr(34) & " -Launch"
launchSplashCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & "$escapedPatchScriptPath" & Chr(34) & " -ShowLaunchSplash"
If preferredPort > 0 Then
    command = command & " -Port " & CStr(preferredPort)
    launchSplashCommand = launchSplashCommand & " -Port " & CStr(preferredPort)
End If
If instanceKey <> "" Then
    command = command & " -LauncherKey " & Chr(34) & instanceKey & Chr(34)
    launchSplashCommand = launchSplashCommand & " -LauncherKey " & Chr(34) & instanceKey & Chr(34)
End If
shell.Run launchSplashCommand, 0, False
shell.Run command, 0, False
"@
}

function Install-AntigravityPlusLauncherScript {
    param([Parameter(Mandatory)][string]$PatchScriptPath)

    $launcherPath = Get-AntigravityPlusLauncherVbsPath
    $launcherDir = Split-Path -Parent $launcherPath
    if (-not (Test-Path -LiteralPath $launcherDir)) {
        New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
    }
    New-AntigravityPlusLauncherVbsContent -PatchScriptPath $PatchScriptPath |
        Set-Content -LiteralPath $launcherPath -Encoding ASCII
    return $launcherPath
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
