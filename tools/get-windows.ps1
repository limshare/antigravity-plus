Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinEnumerator {
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public static List<string> ListWindows(int[] pids) {
        var set = new HashSet<int>(pids);
        var list = new List<string>();
        EnumWindows((hWnd, lParam) => {
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            var sbText = new StringBuilder(256);
            GetWindowText(hWnd, sbText, 256);
            string title = sbText.ToString();
            var sbClass = new StringBuilder(256);
            GetClassName(hWnd, sbClass, 256);
            bool visible = IsWindowVisible(hWnd);
            if (set.Contains((int)pid) || title.ToLower().Contains("antigravity") || title.ToLower().Contains("curriculum") || title.ToLower().Contains("potential")) {
                list.Add(string.Format("PID:{0} | HWND:0x{1:X} | Vis:{2} | Class:{3} | Title:{4}", pid, hWnd.ToInt64(), visible, sbClass.ToString(), title));
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }

    public static bool ActivateFirstVisible(int[] pids) {
        var set = new HashSet<int>(pids);
        bool activated = false;
        EnumWindows((hWnd, lParam) => {
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            if (set.Contains((int)pid) && IsWindowVisible(hWnd)) {
                var sbClass = new StringBuilder(256);
                GetClassName(hWnd, sbClass, 256);
                if (sbClass.ToString() == "Chrome_WidgetWin_1") {
                    ShowWindow(hWnd, 9); // SW_RESTORE
                    SetForegroundWindow(hWnd);
                    activated = true;
                    return false; // stop
                }
            }
            return true;
        }, IntPtr.Zero);
        return activated;
    }
}
"@ -IgnoreWarnings

$pids = @(Get-Process | Where-Object { $_.ProcessName -like '*antigravity*' } | ForEach-Object { $_.Id })
Write-Host "Found $($pids.Count) Antigravity processes: $($pids -join ', ')"
[WinEnumerator]::ListWindows($pids) | ForEach-Object { Write-Host $_ }
