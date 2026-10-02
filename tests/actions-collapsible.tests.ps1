$ErrorActionPreference = 'Stop'

$rootDir = Split-Path -Parent $PSScriptRoot
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
. (Join-Path $rootDir 'src\antigravity\new-window-button.ps1')
. (Join-Path $rootDir 'src\antigravity\thinking-translator.ps1')
. (Join-Path $rootDir 'src\antigravity\actions-collapsible.ps1')
. (Join-Path $rootDir 'src\antigravity\payload-bundle.ps1')

# 1. Verify function exists and returns non-empty payload
$payload = Get-AntigravityActionsCollapsiblePayload
if ([string]::IsNullOrWhiteSpace($payload)) {
    throw "Get-AntigravityActionsCollapsiblePayload returned empty payload"
}

# 2. Verify payload contains essential logic
if (-not $payload.Contains('agy-actions-group-wrapper')) {
    throw "Actions collapsible payload missing agy-actions-group-wrapper class"
}
if (-not $payload.Contains('agy-actions-group-header')) {
    throw "Actions collapsible payload missing agy-actions-group-header class"
}
if (-not $payload.Contains('groupActionsInContainer')) {
    throw "Actions collapsible payload missing groupActionsInContainer function"
}

# 3. Verify bundle integration
$bundle = Get-AntigravityPayloadBundle
if (-not $bundle.Contains('Actions collapsible payload error')) {
    throw "Payload bundle missing actions collapsible integration block"
}

Write-Output "actions-collapsible.tests.ps1 passed"
