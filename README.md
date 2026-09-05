# Antigravity Plus

**A local enhancement and bidirectional (RTL) layout layer for Google Antigravity Desktop on Windows.**

Antigravity Plus brings seamless Hebrew, Arabic, and bidirectional text rendering, prompt composer alignment, and runtime enhancement injection to Google Antigravity Desktop without modifying the original Google installation.

---

## Features

- **Full Bidirectional (RTL) Support:**
  - Automatic language detection for Hebrew & Arabic.
  - Aligns user prompt bubbles, assistant answers, bulleted lists, and blockquotes to `rtl`.
  - Fixes punctuation inversion (periods, exclamation marks, question marks render at the true end of the line).
  - Preserves strict `ltr` on code blocks (`pre`, `code`), inline snippets, file paths, and terminal commands.
- **Smart Prompt Composer:**
  - ContentEditable prompt input dynamically shifts text alignment and direction as you type in Hebrew or English.
- **Non-Invasive Architecture:**
  - Google's original installation in `%LOCALAPPDATA%\Programs\Antigravity` remains untouched.
  - Operates via Chrome DevTools Protocol (CDP) loopback injection and managed shortcuts.
- **Instant Live Injection:**
  - Inject enhancements directly into an already-running Antigravity window with zero restarts.
- **Single-EXE Installer:**
  - Build standalone `AntigravityPlus-Setup.exe` for 1-click deployment.

---

## Requirements

- Windows 10 / 11
- Google Antigravity Desktop installed (`%LOCALAPPDATA%\Programs\Antigravity\Antigravity.exe`)
- Windows PowerShell 5.1 (`powershell.exe`) or PowerShell 7 (`pwsh`)
- Administrator privileges: **Not required**

---

## Quick Start

### 1. Install / Patch Antigravity Plus

From a cloned checkout or downloaded folder, open PowerShell and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\patch.ps1 -Install
```

Or double-click:
```text
Antigravity Plus Install Local.bat
```

This sets up `%LOCALAPPDATA%\Antigravity Plus`, creates `Desktop\Antigravity Plus.lnk` and Start Menu shortcuts, and immediately injects enhancements if Antigravity is open.

### 2. Live Injection (No Restart Needed)

If Antigravity is already running, run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\patch.ps1 -LiveInject
```

### 3. Interactive Menu

Run `patch.ps1` without arguments to access the interactive menu:

```text
==========================================================
                ANTIGRAVITY PLUS                          
     Enhanced Runtime & RTL Layer for Antigravity         
==========================================================

Antigravity Desktop: Found (v2.12.2)
Active Session:      Running (Port 52467)

  1. Patch / Install Antigravity Plus *
  2. Live Inject into Running Antigravity
  3. Launch Antigravity Plus
  4. Restore Antigravity Plus
  5. Exit
```

### 4. Restore Original State

To uninstall Antigravity Plus shortcuts and runtime:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\patch.ps1 -Restore
```

---

## Developer & Inspection Tools

### Query Live Antigravity DevTools

Use `tools\invoke-antigravity-devtools.ps1` to run JavaScript expressions inside the running Antigravity window:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\tools\invoke-antigravity-devtools.ps1 -Expression "document.title"
```

### Run Compatibility & Regression Tests

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\tools\test-antigravity-version-compatibility.ps1
```

---

## Build Standalone EXE

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\build-exe-installer.ps1
```

Creates `dist\AntigravityPlus-Setup.exe`.

---

## License

MIT License
