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
- **Enhanced Composer Top Bar:**
  - Project workspace switcher button.
  - Active background agent / subagent process badge.
  - Quick new chat routing and native commit/push actions.
- **Smart Prompt Composer:**
  - ContentEditable prompt input dynamically shifts text alignment and direction as you type in Hebrew or English.
- **Non-Invasive Architecture:**
  - Google's original installation in `%LOCALAPPDATA%\Programs\Antigravity` remains untouched.
  - Operates via Chrome DevTools Protocol (CDP) loopback injection and managed shortcuts.
- **Instant Live Injection:**
  - Inject enhancements directly into an already-running Antigravity window with zero restarts.
- **Single-EXE Standalone Installer:**
  - 1-click standalone `AntigravityPlus-Setup.exe` deployment.

---

## Requirements

- **Windows 10 / 11** (64-bit)
- **Google Antigravity Desktop** installed (`%LOCALAPPDATA%\Programs\Antigravity\Antigravity.exe`)
- **Windows PowerShell 5.1** (`powershell.exe`) or **PowerShell 7** (`pwsh`)
- **Administrator privileges**: **Not required** (installs per-user to `%LOCALAPPDATA%\Antigravity Plus`)

---

## Installation

### Option 1: 1-Click Standalone Installer (Recommended)

1. Download **[`AntigravityPlus-Setup.exe`](https://github.com/limshare/antigravity-plus/raw/main/dist/AntigravityPlus-Setup.exe)**.
2. Double-click **`AntigravityPlus-Setup.exe`** to run it.
3. ✨ **Done!**
   - A new **Antigravity Plus** shortcut will appear on your **Desktop** and **Start Menu**.
   - If Antigravity is already open, the RTL and composer enhancements will activate immediately.

---

### Option 2: Download ZIP (No Git Required)

1. Go to the repository: **[github.com/limshare/antigravity-plus](https://github.com/limshare/antigravity-plus)**
2. Click the green **`Code`** button &rarr; click **`Download ZIP`**.
3. Extract (unzip) the downloaded folder.
4. Open the folder and double-click:
   ```text
   Antigravity Plus Install Local.bat
   ```
5. ✨ **Done!**

---

### Option 3: For Developers (Git & PowerShell)

Clone the repository and run the install script:

```powershell
git clone https://github.com/limshare/antigravity-plus.git
cd antigravity-plus
powershell.exe -ExecutionPolicy Bypass -File .\patch.ps1 -Install
```

---

## Usage & Commands

### Live Injection (No Restart Needed)

If Antigravity is already running and you want to re-inject or refresh enhancements:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\patch.ps1 -LiveInject
```

### Restore / Uninstall

To remove Antigravity Plus shortcuts and restore original defaults:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\patch.ps1 -Restore
```
*(Your original Google Antigravity installation is never modified or harmed).*

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
