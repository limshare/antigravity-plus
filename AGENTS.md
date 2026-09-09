# Agent Workspace Guidelines & Methods

This document defines execution rules, command formatting methods, and architectural guidelines for all AI agents operating in this workspace.

---

## 1. PowerShell Quoting & Command Execution Rules

### Avoid Parser Errors (`TerminatorExpectedAtEndOfString`)
The error `The string is missing the terminator: "` occurs when Windows CLI argument parsing strips nested double quotes (`\"`) before PowerShell interprets them.

To avoid this error across all agents:

1. **Use Single Quotes for `-Command` script blocks**:
   ```powershell
   # CORRECT
   powershell -NoProfile -ExecutionPolicy Bypass -Command '& { Get-Process | Where-Object { $_.ProcessName -like "*antigravity*" } }'
   ```

2. **Use Backticks (`` ` ``) for PowerShell Escaping, Never Backslashes (`\`)**:
   - Variables inside double quotes: `` `$myVar `` (not `\$myVar`)
   - Nested double quotes: `` `"quoted`" `` (not `\"quoted\"`)
   - Pipeline filter: `` `$_.Name `` (not `\$_.Name` or unescaped `$_`)

3. **Prefer `-File` Invocations over Complex Inline `-Command`**:
   ```powershell
   # CORRECT
   powershell -NoProfile -ExecutionPolicy Bypass -File .\patch.ps1 -Install
   ```

4. **Set Appropriate `WaitMsBeforeAsync` in `run_command`**:
   - Default to `5000` (5000ms) for commands expected to finish quickly, preventing them from being pushed to unnecessary background tasks.

---

## 2. Process Management & Background Tasks

1. **Internal Tool Preference**:
   - Always prefer `grep_search` and `view_file` over shell commands (`rg`, `grep`, `dir`) for codebase exploration.
2. **Terminal Search Restraints**:
   - When running search commands in terminal, always restrict the search path (e.g. `src/`, `tools/`), exclude build folders (`-g "!node_modules" -g "!dist"`), and pass `--no-pager`.
3. **Immediate Cleanup of Superseded Tasks**:
   - If a background task is spawned and is no longer needed or failed, immediately terminate it using `manage_task(Action: 'kill')`.

---

## 3. Antigravity Plus Lifecycle & Process Health

1. **Electron `runInBackground` Setting**:
   - `runInBackground` in `app_storage.json` must always be `"false"`.
   - Setting it to `"true"` causes Electron's helper processes (GPU, network, audio, video) to remain as headless background zombies after window close.

2. **Port Monitor Failure Counter**:
   - In `Start-AntigravityPortMonitor`, `$consecutiveFailures` must **only** be reset to `0` when valid active page targets (`$pageTargets.Count -gt 0`) are returned.
   - Never reset `$consecutiveFailures = 0` unconditionally inside `try` blocks, as `Get-AntigravityDevToolsTargets` returns `@()` upon window close without throwing an unhandled exception.

3. **Orphan Pruning**:
   - Use `Clear-AntigravityOrphanedProcesses` during installation, restoration, and launch workflows to ensure no zombie processes linger on the system.
