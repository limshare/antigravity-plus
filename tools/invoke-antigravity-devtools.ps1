param(
    [int]$Port = 0,
    [string]$Expression = 'document.title',
    [string]$ScriptFile = '',
    [int]$TimeoutSeconds = 10
)

if ($ScriptFile -and (Test-Path $ScriptFile)) {
    $Expression = Get-Content -Raw $ScriptFile
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

. (Join-Path $rootDir 'src\shared\logging.ps1')
. (Join-Path $rootDir 'src\shared\asar.ps1')
. (Join-Path $rootDir 'src\shared\cdp.ps1')
. (Join-Path $rootDir 'src\antigravity\detection.ps1')

if ($Port -le 0) {
    $Port = Get-AntigravityActiveDevToolsPort
}

if ($Port -le 0) {
    Write-Err "No active Antigravity DevTools port detected. Is Antigravity running?"
    exit 1
}

$page = @(Get-AntigravityActivePageTarget -Port $Port -TimeoutSeconds $TimeoutSeconds) | Select-Object -First 1
if (-not $page -or -not $page.webSocketDebuggerUrl) {
    Write-Err "No active page target found on port $Port."
    exit 1
}

$wsUrl = [string]$page.webSocketDebuggerUrl
$res = Invoke-CdpEvaluate -WebSocketDebuggerUrl $wsUrl -Expression $Expression -TimeoutSeconds $TimeoutSeconds

if ($res -and $res.result) {
    if ($res.result.exceptionDetails) {
        $errMsg = if ($res.result.exceptionDetails.exception -and $res.result.exceptionDetails.exception.description) {
            $res.result.exceptionDetails.exception.description
        } elseif ($res.result.exceptionDetails.text) {
            $res.result.exceptionDetails.text
        } else {
            $res.result.exceptionDetails | ConvertTo-Json -Depth 5
        }
        Write-Err $errMsg
    }
    if ($res.result.result) {
        $val = $res.result.result.value
        if ($val -is [string]) {
            Write-Output $val
        } elseif ($null -ne $val) {
            $val | ConvertTo-Json -Depth 10
        } else {
            $res.result.result | ConvertTo-Json -Depth 10
        }
    }
} else {
    $res | ConvertTo-Json -Depth 10
}
