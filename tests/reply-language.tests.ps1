$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../src/runtime/reply-language.ps1')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('antigravity-language-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$path = Join-Path $testRoot 'GEMINI.md'
try {
    $original = "# My rules`nKeep my formatting and instructions."
    [IO.File]::WriteAllText($path, $original)
    Set-AntigravityPlusReplyLanguage -ReplyLanguage Hebrew -RulesPath $path
    $enabled = [IO.File]::ReadAllText($path)
    if (-not $enabled.Contains('Reply in Hebrew by default.')) { throw 'Hebrew rule missing' }
    Set-AntigravityPlusReplyLanguage -ReplyLanguage Hebrew -RulesPath $path
    if ([IO.File]::ReadAllText($path) -cne $enabled) { throw 'Enable must be idempotent' }
    Set-AntigravityPlusReplyLanguage -ReplyLanguage Off -RulesPath $path
    if ([IO.File]::ReadAllText($path) -cne $original) { throw 'Off must preserve existing rules exactly' }
    Set-AntigravityPlusReplyLanguage -ReplyLanguage Off -RulesPath $path
    if ([IO.File]::ReadAllText($path) -cne $original) { throw 'Off must be idempotent' }
    Write-Output 'reply-language.tests.ps1 passed'
} finally {
    Remove-Item -LiteralPath $path -Force
    Remove-Item -LiteralPath $testRoot
}
