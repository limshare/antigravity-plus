# PowerShell Execution & System Rules for Antigravity

- When executing PowerShell via CLI/tools, avoid nested double quotes (`"..."`) with `\"` which trigger `TerminatorExpectedAtEndOfString` parser errors.
- Always wrap script blocks in single quotes: `powershell -NoProfile -ExecutionPolicy Bypass -Command '& { ... }'`
- In PowerShell strings, use the backtick (`` ` ``) for escaping (e.g., `` `$var ``, `` `"quote`" ``), not the backslash (`\`).
- Prefer `-File <script.ps1>` for executing PowerShell scripts.
- Prefer `grep_search` over shell searching tools.
- Maintain `runInBackground: false` in `app_storage.json` for all Antigravity instances.
- Never reset consecutive failure counts in port monitoring loops without verifying active page target count (`$pageTargets.Count -gt 0`).
