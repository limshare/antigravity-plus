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
$payload = Get-AntigravityThinkingTranslatorPayload
if ([string]::IsNullOrWhiteSpace($payload)) {
    throw "Get-AntigravityThinkingTranslatorPayload returned empty payload"
}

# 2. Verify payload contains essential logic
if (-not $payload.Contains('translateToHebrew')) {
    throw "Thinking translator payload missing translateToHebrew function"
}
if (-not $payload.Contains('agy-thinking-translated')) {
    throw "Thinking translator payload missing agy-thinking-translated class"
}
if (-not $payload.Contains('extractCleanThinkingText')) {
    throw "Thinking translator payload missing extractCleanThinkingText helper"
}

# 3. Verify bundle integration
$bundle = Get-AntigravityPayloadBundle
if (-not $bundle.Contains('Thinking translator payload error')) {
    throw "Payload bundle missing thinking translator integration block"
}

Write-Output "thinking-translator.tests.ps1 passed"
