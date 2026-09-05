param(
    [int]$Port = 0,
    [string]$Expression = 'document.title',
    [int]$TimeoutSeconds = 10
)

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

$page = Get-AntigravityActivePageTarget -Port $Port -TimeoutSeconds $TimeoutSeconds
if (-not $page) {
    Write-Err "No active page target found on port $Port."
    exit 1
}

$wsUrl = $page.webSocketDebuggerUrl
$res = Invoke-CdpEvaluate -WebSocketDebuggerUrl $wsUrl -Expression $Expression -TimeoutSeconds $TimeoutSeconds

if ($res -and $res.result -and $res.result.result) {
    $val = $res.result.result.value
    if ($val -is [string]) {
        Write-Output $val
    } else {
        $val | ConvertTo-Json -Depth 10
    }
} else {
    $res | ConvertTo-Json -Depth 10
}
