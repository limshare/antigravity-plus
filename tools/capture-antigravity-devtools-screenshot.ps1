param(
    [Parameter(Mandatory)][string]$OutputPath,
    [int]$Port = 0,
    [string]$Id = '',
    [int]$TimeoutSeconds = 15
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
    throw "No active Antigravity DevTools port detected. Is Antigravity running with debugging enabled?"
}

$rawList = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/list" -UseBasicParsing -TimeoutSec $TimeoutSeconds).Content
$decoded = $rawList | ConvertFrom-Json
if ($decoded -is [System.Array]) {
    $targets = @($decoded)
} else {
    $properties = @($decoded.PSObject.Properties)
    $targetCount = ($properties | ForEach-Object { @($_.Value).Count } | Measure-Object -Maximum).Maximum
    if ($targetCount -le 1) {
        $targets = @($decoded)
    } else {
        $targets = @(
            for ($index = 0; $index -lt $targetCount; $index++) {
                $target = [ordered]@{}
                foreach ($property in $properties) {
                    $values = @($property.Value)
                    $target[$property.Name] = if ($values.Count -gt 1) { $values[$index] } else { $values[0] }
                }
                [pscustomobject]$target
            }
        )
    }
}

$page = if ($Id) {
    $targets | Where-Object { $_.id -eq $Id } | Select-Object -First 1
} else {
    $targets | Where-Object { $_.type -eq 'page' -and $_.webSocketDebuggerUrl -and $_.url -notlike 'data:text/html*' } | Select-Object -First 1
}

if (-not $page) {
    throw "No debugger page target found on port $Port $(if ($Id) { "with id '$Id'" } else { '' })."
}

$client = [System.Net.WebSockets.ClientWebSocket]::new()
$cts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))

try {
    $client.ConnectAsync([Uri]$page.webSocketDebuggerUrl, $cts.Token).GetAwaiter().GetResult() | Out-Null

    $command = @{
        id = 1
        method = 'Page.captureScreenshot'
        params = @{
            format = 'png'
            captureBeyondViewport = $true
        }
    } | ConvertTo-Json -Depth 10 -Compress

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($command)
    $client.SendAsync(
        [ArraySegment[byte]]::new($bytes),
        [System.Net.WebSockets.WebSocketMessageType]::Text,
        $true,
        $cts.Token
    ).GetAwaiter().GetResult() | Out-Null

    $buffer = New-Object byte[] 65536
    $segment = [ArraySegment[byte]]::new($buffer)
    $message = New-Object System.Collections.Generic.List[byte]

    while ($client.State -eq [System.Net.WebSockets.WebSocketState]::Open -and -not $cts.IsCancellationRequested) {
        $result = $client.ReceiveAsync($segment, $cts.Token).GetAwaiter().GetResult()
        if ($result.Count -gt 0) {
            $message.AddRange([byte[]]$buffer[0..($result.Count - 1)])
        }
        if ($result.EndOfMessage) {
            $responseText = [System.Text.Encoding]::UTF8.GetString($message.ToArray())
            $message.Clear()
            try {
                $response = $responseText | ConvertFrom-Json
                if ($response.id -eq 1) {
                    if ($response.error) { throw ($response.error.message) }
                    $parentDir = Split-Path -Parent $OutputPath
                    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
                        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    }
                    [System.IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($response.result.data))
                    Write-Output $OutputPath
                    break
                }
            } catch {
                # Ignore non-matching frames
            }
        }
    }
} finally {
    if ($client.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
        try {
            $client.CloseAsync(
                [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                'done',
                [System.Threading.CancellationToken]::None
            ).GetAwaiter().GetResult() | Out-Null
        } catch {}
    }
    $client.Dispose()
    $cts.Dispose()
}
