function Get-AntigravityDevToolsTargets {
    param(
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutSeconds = 10
    )

    $url = "http://127.0.0.1:$Port/json/list"
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $raw = Invoke-RestMethod -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($raw) {
                $list = [System.Collections.Generic.List[object]]::new()
                foreach ($item in $raw) {
                    if ($item -and $item.id) {
                        $list.Add($item)
                    }
                }
                if ($list.Count -gt 0) {
                    return $list.ToArray()
                }
            }
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }
    return @()
}

function Get-AntigravityActivePageTarget {
    param(
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutSeconds = 10
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $targets = Get-AntigravityDevToolsTargets -Port $Port -TimeoutSeconds 2
        foreach ($t in $targets) {
            if ($t.type -eq 'page' -and $t.url -notlike 'data:text/html*' -and $t.webSocketDebuggerUrl) {
                return $t
            }
        }
        Start-Sleep -Milliseconds 300
    }
    return $null
}

function New-CdpCommand {
    param(
        [Parameter(Mandatory)][int]$Id,
        [Parameter(Mandatory)][string]$Method,
        [hashtable]$Params = @{}
    )

    return @{
        id = $Id
        method = $Method
        params = $Params
    }
}

function Invoke-CdpWebSocket {
    param(
        [Parameter(Mandatory)][string]$WebSocketDebuggerUrl,
        [Parameter(Mandatory)]$Command,
        [int]$TimeoutSeconds = 15
    )

    $cleanWsUrl = if ($WebSocketDebuggerUrl -is [array]) { [string]$WebSocketDebuggerUrl[0] } else { [string]$WebSocketDebuggerUrl }
    $client = [System.Net.WebSockets.ClientWebSocket]::new()
    $cts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))

    try {
        $client.ConnectAsync([Uri]$cleanWsUrl, $cts.Token).GetAwaiter().GetResult() | Out-Null

        $json = if ($Command -is [string]) { $Command } else { $Command | ConvertTo-Json -Depth 20 -Compress }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $client.SendAsync(
            [ArraySegment[byte]]::new($bytes),
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            $cts.Token
        ).GetAwaiter().GetResult() | Out-Null

        $buffer = New-Object byte[] 65536
        $segment = [ArraySegment[byte]]::new($buffer)
        $expectedId = if ($Command -is [hashtable] -and $Command.ContainsKey('id')) { $Command['id'] } elseif ($Command.id) { $Command.id } else { $null }

        while ($client.State -eq [System.Net.WebSockets.WebSocketState]::Open -and -not $cts.IsCancellationRequested) {
            $message = New-Object System.Collections.Generic.List[byte]
            $result = $client.ReceiveAsync($segment, $cts.Token).GetAwaiter().GetResult()
            if ($result.Count -gt 0) {
                $message.AddRange([byte[]]$buffer[0..($result.Count - 1)])
            }

            while (-not $result.EndOfMessage) {
                $result = $client.ReceiveAsync($segment, $cts.Token).GetAwaiter().GetResult()
                if ($result.Count -gt 0) {
                    $message.AddRange([byte[]]$buffer[0..($result.Count - 1)])
                }
            }

            $text = [System.Text.Encoding]::UTF8.GetString($message.ToArray())
            if ([string]::IsNullOrWhiteSpace($text)) {
                continue
            }

            try {
                $payload = $text | ConvertFrom-Json
                if ($null -eq $expectedId -or $payload.id -eq $expectedId) {
                    return $payload
                }
            } catch {
                # Ignore non-json frames / CDP events until matching ID is received
            }
        }
        return $null
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
}

function Invoke-CdpEvaluate {
    param(
        [Parameter(Mandatory)][string]$WebSocketDebuggerUrl,
        [Parameter(Mandatory)][string]$Expression,
        [int]$CommandId = 1,
        [int]$TimeoutSeconds = 15
    )

    $cmd = New-CdpCommand -Id $CommandId -Method 'Runtime.evaluate' -Params @{
        expression = $Expression
        awaitPromise = $true
        returnByValue = $true
    }
    return Invoke-CdpWebSocket -WebSocketDebuggerUrl $WebSocketDebuggerUrl -Command $cmd -TimeoutSeconds $TimeoutSeconds
}

function Invoke-CdpAddScriptOnNewDocument {
    param(
        [Parameter(Mandatory)][string]$WebSocketDebuggerUrl,
        [Parameter(Mandatory)][string]$Source,
        [int]$CommandId = 2,
        [int]$TimeoutSeconds = 15
    )

    $cmd = New-CdpCommand -Id $CommandId -Method 'Page.addScriptToEvaluateOnNewDocument' -Params @{
        source = $Source
        runImmediately = $true
    }
    return Invoke-CdpWebSocket -WebSocketDebuggerUrl $WebSocketDebuggerUrl -Command $cmd -TimeoutSeconds $TimeoutSeconds
}

function Invoke-CdpCommands {
    param(
        [Parameter(Mandatory)][string]$WebSocketDebuggerUrl,
        [Parameter(Mandatory)][array]$Commands,
        [int]$TimeoutSeconds = 10
    )

    $cleanWsUrl = if ($WebSocketDebuggerUrl -is [array]) { [string]$WebSocketDebuggerUrl[0] } else { [string]$WebSocketDebuggerUrl }
    $client = [System.Net.WebSockets.ClientWebSocket]::new()
    $cts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))

    try {
        $client.ConnectAsync([Uri]$cleanWsUrl, $cts.Token).GetAwaiter().GetResult() | Out-Null

        foreach ($cmd in $Commands) {
            $json = if ($cmd -is [string]) { $cmd } else { $cmd | ConvertTo-Json -Depth 20 -Compress }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $client.SendAsync(
                [ArraySegment[byte]]::new($bytes),
                [System.Net.WebSockets.WebSocketMessageType]::Text,
                $true,
                $cts.Token
            ).GetAwaiter().GetResult() | Out-Null
        }

        $lastCmd = $Commands[-1]
        $expectedId = if ($lastCmd -is [hashtable] -and $lastCmd.ContainsKey('id')) { $lastCmd['id'] } elseif ($lastCmd.id) { $lastCmd.id } else { $null }

        $buffer = New-Object byte[] 65536
        $segment = [ArraySegment[byte]]::new($buffer)

        while ($client.State -eq [System.Net.WebSockets.WebSocketState]::Open -and -not $cts.IsCancellationRequested) {
            $message = New-Object System.Collections.Generic.List[byte]
            $result = $client.ReceiveAsync($segment, $cts.Token).GetAwaiter().GetResult()
            if ($result.Count -gt 0) {
                $message.AddRange([byte[]]$buffer[0..($result.Count - 1)])
            }

            while (-not $result.EndOfMessage) {
                $result = $client.ReceiveAsync($segment, $cts.Token).GetAwaiter().GetResult()
                if ($result.Count -gt 0) {
                    $message.AddRange([byte[]]$buffer[0..($result.Count - 1)])
                }
            }

            $text = [System.Text.Encoding]::UTF8.GetString($message.ToArray())
            if ([string]::IsNullOrWhiteSpace($text)) {
                continue
            }

            try {
                $payload = $text | ConvertFrom-Json
                if ($null -eq $expectedId -or $payload.id -eq $expectedId) {
                    return $payload
                }
            } catch {
            }
        }
        return $null
    } finally {
        if ($client.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            try {
                $client.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
            } catch {}
        }
        $client.Dispose()
        $cts.Dispose()
    }
}
