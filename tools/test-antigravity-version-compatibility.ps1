param(
    [switch]$OfflineOnly
)

$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      ANTIGRAVITY PLUS COMPATIBILITY & REGRESSION GATE    " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$passed = 0
$failed = 0

function Assert-Check {
    param(
        [string]$Name,
        [scriptblock]$Block
    )

    try {
        . $Block
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $global:passed++
    } catch {
        Write-Host "[FAIL] ${Name}: $($_.Exception.Message)" -ForegroundColor Red
        $global:failed++
    }
}

# 1. Syntax check of all PS1 scripts
Assert-Check "PowerShell Syntax Validation" {
    $scripts = Get-ChildItem $rootDir -Filter "*.ps1" -Recurse
    foreach ($s in $scripts) {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($s.FullName, [ref]$null, [ref]$errors) | Out-Null
        if ($errors -and $errors.Count -gt 0) {
            throw "Syntax error in $($s.Name): $($errors[0].Message)"
        }
    }
}

# 2. Module loading and dependency integrity
. (Join-Path $rootDir 'src\shared\logging.ps1')
. (Join-Path $rootDir 'src\shared\prompting.ps1')
. (Join-Path $rootDir 'src\shared\asar.ps1')
. (Join-Path $rootDir 'src\shared\cdp.ps1')
. (Join-Path $rootDir 'src\antigravity\detection.ps1')
. (Join-Path $rootDir 'src\antigravity\rtl-shared.ps1')
. (Join-Path $rootDir 'src\antigravity\rtl-payload.ps1')
. (Join-Path $rootDir 'src\antigravity\ui-enhancements.ps1')
. (Join-Path $rootDir 'src\antigravity\context-badge.ps1')
. (Join-Path $rootDir 'src\antigravity\sidebar-enhancements.ps1')
. (Join-Path $rootDir 'src\antigravity\composer-top-bar.ps1')
. (Join-Path $rootDir 'src\antigravity\payload-bundle.ps1')
. (Join-Path $rootDir 'src\runtime\files.ps1')
. (Join-Path $rootDir 'src\runtime\state.ps1')
. (Join-Path $rootDir 'src\runtime\shortcuts.ps1')
. (Join-Path $rootDir 'src\runtime\launch.ps1')
. (Join-Path $rootDir 'src\runtime\patching.ps1')

Assert-Check "Module Loading & Dot-sourcing" {
    if (-not (Get-Command Get-AntigravityPayloadBundle -ErrorAction SilentlyContinue)) {
        throw "Get-AntigravityPayloadBundle command missing"
    }
    if (-not (Get-Command Get-AntigravityInstallInfo -ErrorAction SilentlyContinue)) {
        throw "Get-AntigravityInstallInfo command missing"
    }
}

# 3. Payload Bundle Generation
Assert-Check "Runtime Payload Bundle Assembly" {
    $bundle = Get-AntigravityPayloadBundle
    if ([string]::IsNullOrWhiteSpace($bundle)) {
        throw "Payload bundle is empty"
    }
    if (-not ($bundle -match 'ANTIGRAVITY_PLUS_RTL_INSTALLED')) {
        throw "Payload missing RTL installation marker"
    }
}

# 4. Antigravity Installation Detection
Assert-Check "Antigravity Installation Detection" {
    $install = Get-AntigravityInstallInfo
    if (-not $install.Installed) {
        throw "Antigravity executable not found"
    }
    if (-not $install.Version -or $install.Version -eq 'Unknown') {
        throw "Could not determine Antigravity version"
    }
}

# Live tests (skip if -OfflineOnly)
if (-not $OfflineOnly) {
    Assert-Check "Active DevTools Connection & Live Injected State" {
        $ports = @(Get-AntigravityActiveDevToolsPorts)
        if ($ports.Count -eq 0) {
            throw "No running Antigravity instance detected with DevTools enabled."
        }
        $tested = $false
        foreach ($port in $ports) {
            $page = Get-AntigravityActivePageTarget -Port $port -TimeoutSeconds 5
            if ($page -and $page.webSocketDebuggerUrl) {
                try {
                    $wsUrl = $page.webSocketDebuggerUrl
                    $res = Invoke-CdpEvaluate -WebSocketDebuggerUrl $wsUrl -Expression "({ title: document.title, hasRtlStyle: !!document.getElementById('antigravity-plus-rtl-style'), hasTopBar: !!document.querySelector('[data-gemini-plus-composer-top-bar]'), hasBadge: !!(document.querySelector('[data-gemini-plus-top-badge]') || document.querySelector('[data-antigravity-plus-context-badge]')) })" -TimeoutSeconds 5
                    if ($res -and $res.result -and $res.result.result) {
                        $tested = $true
                        break
                    }
                } catch {}
            }
        }
        if (-not $tested) {
            throw "DevTools evaluation failed across all active ports."
        }
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
$summaryColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host "SUMMARY: Passed: $passed, Failed: $failed" -ForegroundColor $summaryColor
Write-Host "==========================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
}
exit 0
