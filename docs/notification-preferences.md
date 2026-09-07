# Antigravity Notification Preferences Prompt Suppression

## Summary
Antigravity displays an onboarding prompt card toast in the bottom-right corner of the window:
- **Title**: Notification Preferences
- **Message**: "Choose whether to be notified when the agent needs your attention or completes a task."
- **Buttons**: `[Open Preferences]` (primary) and `[Dismiss]` (secondary)

---

## Root Cause & Architecture

### 1. Component Implementation
The prompt is rendered by Antigravity's webview UI (served by `language_server.exe` using Radix UI Toast primitives):
- **DOM Container**: `div.toast-viewport[role="region"][aria-label="Notifications"]`
- **Card**: `div.toast-root[role="dialog"]`
- **Internal ID**: `permission:notifications`

### 2. Trigger Logic (`main.js`)
The notification service checks whether this permission prompt was previously asked:
```javascript
async sendNotification(a) {
  if (this.stateStore?.getEnableNotificationsForSpecialEvents() ?? true) {
    if (this.bridge) {
      return !this.storageService.get("didAskForNotificationPermission") &&
        this.permissionRequestManager &&
        (
          this.storageService.store("didAskForNotificationPermission", "true"),
          bl(this.permissionRequestManager, {
            id: "notifications",
            title: "Notification Preferences",
            message: "Choose whether to be notified when the agent needs your attention or completes a task.",
            actions: [
              {
                label: "Dismiss",
                style: "outline",
                onClick: () => {
                  this.permissionRequestManager?.dismissPermission("notifications");
                }
              },
              {
                label: "Open Preferences",
                style: "primary",
                onClick: () => {
                  this.openPreferences();
                  this.permissionRequestManager?.dismissPermission("notifications");
                }
              }
            ]
          })
        );
    }
  }
}
```

---

## Permanent Solution (No Loop / No Monitoring)

The flag is persisted in Antigravity's native storage file on disk:
- **File**: `C:\Users\Noam\AppData\Roaming\Antigravity\app_storage.json`
- **Key**: `"didAskForNotificationPermission": "true"`

### How to Ensure It Stays Disabled:
Verify or set `"didAskForNotificationPermission": "true"` in `app_storage.json`:
```powershell
$path = "$env:APPDATA\Antigravity\app_storage.json"
$json = Get-Content $path -Raw | ConvertFrom-Json
$json | Add-Member -NotePropertyName "didAskForNotificationPermission" -NotePropertyValue "true" -Force
$json | ConvertTo-Json -Depth 20 | Set-Content $path
```

When this flag is `"true"`, `!this.storageService.get("didAskForNotificationPermission")` evaluates to `false` and Antigravity will never trigger or render the prompt card.

---

## Pure CSS Fallback Selector
If CSS hiding is ever needed:
```css
.toast-viewport .toast-root:not(:has(svg)):has(p):has(button.bg-primary + button.bg-secondary) {
  display: none !important;
}
```
*Note: Do NOT use broad selectors like `:is([role="dialog"]):has(button + button)` because standard modal confirmation dialogs (Delete Thread, Discard Changes) in apps also use `[role="dialog"]` with two buttons.*
