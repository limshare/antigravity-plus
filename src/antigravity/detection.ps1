function Get-AntigravityInstallInfo {
    $defaultPath = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
    $candidatePaths = @(
        $defaultPath,
        (Join-Path $env:ProgramFiles 'Antigravity\Antigravity.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Antigravity\Antigravity.exe')
    )

    $exePath = $null
    foreach ($cand in $candidatePaths) {
        if ($cand -and (Test-Path -LiteralPath $cand)) {
            $exePath = $cand
            break
        }
    }

    if (-not $exePath) {
        # Check uninstall registry keys
        $uninstallKeys = @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        foreach ($key in $uninstallKeys) {
            $found = Get-ItemProperty $key -ErrorAction SilentlyContinue | Where-Object {
                $_.DisplayName -eq 'Antigravity' -or $_.DisplayName -like '*Antigravity*'
            } | Select-Object -First 1
            if ($found -and $found.InstallLocation) {
                $testPath = Join-Path $found.InstallLocation 'Antigravity.exe'
                if (Test-Path -LiteralPath $testPath) {
                    $exePath = $testPath
                    break
                }
            }
        }
    }

    if (-not $exePath) {
        return [pscustomobject]@{
            Installed = $false
            ExePath = $null
            InstallDir = $null
            AsarPath = $null
            Version = $null
        }
    }

    $installDir = Split-Path -Parent $exePath
    $asarPath = Join-Path $installDir 'resources\app.asar'
    $version = 'Unknown'

    if (Test-Path -LiteralPath $asarPath) {
        try {
            $info = Read-AsarHeaderInfo -AsarPath $asarPath
            $pkgJsonText = Get-AsarEntryText -AsarPath $asarPath -HeaderInfo $info -ArchivePath 'package.json'
            if ($pkgJsonText) {
                $pkg = $pkgJsonText | ConvertFrom-Json
                if ($pkg.version) {
                    $version = [string]$pkg.version
                }
            }
        } catch {}
    }

    return [pscustomobject]@{
        Installed = $true
        ExePath = $exePath
        InstallDir = $installDir
        AsarPath = $asarPath
        Version = $version
    }
}

function Get-AntigravityProcesses {
    try {
        return @(Get-CimInstance Win32_Process -Filter "Name like '%antigravity%'" -ErrorAction Stop)
    } catch {
        return @(Get-Process | Where-Object { $_.ProcessName -like '*antigravity*' })
    }
}

function Get-AntigravityBrowserProcess {
    $procs = Get-AntigravityProcesses
    foreach ($p in $procs) {
        $cmd = [string]$p.CommandLine
        if (-not ($cmd -match '(^|\s)--type=')) {
            return $p
        }
    }
    return ($procs | Select-Object -First 1)
}

function Test-AntigravityPortResponding {
    param(
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutMs = 400
    )
    try {
        $req = [System.Net.WebRequest]::Create("http://127.0.0.1:$Port/json/list")
        $req.Timeout = $TimeoutMs
        $resp = $req.GetResponse()
        $stream = $resp.GetResponseStream()
        $reader = [System.IO.StreamReader]::new($stream)
        $json = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()

        if ($json -and $json -match '"type":\s*"page"') {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Get-AntigravityActiveDevToolsPorts {
    $ports = [System.Collections.Generic.List[int]]::new()
    $procs = Get-AntigravityProcesses
    foreach ($p in $procs) {
        $cmd = [string]$p.CommandLine
        $match = [regex]::Match($cmd, '--remote-debugging-port=(\d+)')
        if ($match.Success) {
            $val = [int]$match.Groups[1].Value
            if ($val -gt 0 -and -not $ports.Contains($val) -and (Test-AntigravityPortResponding -Port $val)) {
                $ports.Add($val)
            }
        }
    }

    $activePortFile = Join-Path $env:APPDATA 'Antigravity\DevToolsActivePort'
    if (Test-Path -LiteralPath $activePortFile) {
        try {
            $lines = Get-Content -LiteralPath $activePortFile -ErrorAction Stop
            if ($lines.Count -ge 1) {
                $port = 0
                if ([int]::TryParse($lines[0].Trim(), [ref]$port) -and $port -gt 0 -and -not $ports.Contains($port) -and (Test-AntigravityPortResponding -Port $port)) {
                    $ports.Add($port)
                }
            }
        } catch {}
    }

    return @($ports)
}

function Get-AntigravityActiveDevToolsPort {
    $ports = @(Get-AntigravityActiveDevToolsPorts)
    if ($ports.Count -gt 0) {
        return $ports[0]
    }
    return 0
}

function Test-PortAvailable {
    param([int]$Port)
    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), $Port)
        $listener.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($listener) { $listener.Stop() }
    }
}

function Get-AntigravityAvailablePort {
    param([int]$PreferredPort = 52400)
    for ($p = $PreferredPort; $p -lt ($PreferredPort + 100); $p++) {
        if (Test-PortAvailable -Port $p) {
            return $p
        }
    }
    return 52400
}
