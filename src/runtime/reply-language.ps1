function Set-AntigravityPlusReplyLanguage {
    param(
        [Parameter(Mandatory)][ValidateSet('Hebrew', 'Off')][string]$ReplyLanguage,
        [string]$RulesPath = (Join-Path $env:USERPROFILE '.gemini\GEMINI.md')
    )

    $begin = '<!-- Antigravity Plus reply language -->'
    $end = '<!-- /Antigravity Plus reply language -->'
    $existing = if (Test-Path -LiteralPath $RulesPath) { [IO.File]::ReadAllText($RulesPath) } else { '' }
    $pattern = '(?m)^' + [regex]::Escape($begin) + '\r?\n[\s\S]*?^' + [regex]::Escape($end) + '(?:\r?\n)?'
    $clean = [regex]::Replace($existing, $pattern, '')
    if ($ReplyLanguage -eq 'Hebrew') {
        # Prepend the owned block, leaving all existing user rules byte-for-byte intact.
        $content = $begin + "`r`nReply in Hebrew by default. Preserve code, commands, paths, URLs, and product names unchanged.`r`n" + $end + "`r`n" + $clean
    } else {
        $content = $clean
    }
    if ($content -ceq $existing) { return }
    $parent = Split-Path -Parent $RulesPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [IO.File]::WriteAllText($RulesPath, $content, [Text.UTF8Encoding]::new($false))
}

