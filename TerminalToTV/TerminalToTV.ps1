<#
.SYNOPSIS
    Shows ONLY your trading terminal (MT5 / MT4) on the TV - not a mirror of the whole PC screen.

.DESCRIPTION
    Windows Cast (Win+K) starts in "Duplicate" mode, so the TV mirrors everything on the PC.
    This script does the manual steps for you:
      1. If the TV is not connected yet, it opens the Windows Cast panel and waits while you pick the TV.
      2. It switches the TV from Duplicate (mirror) to Extend, so the TV becomes a separate second screen.
      3. It moves the terminal window onto the TV and maximizes it there.
    Everything else stays on the PC screen. When you disconnect the TV, Windows moves the
    terminal back to the PC screen by itself.

    Works on Windows 10 and 11 with Windows Cast (Miracast) or an HDMI cable. Nothing to install.

.PARAMETER Match
    Only needed when more than one terminal is open: part of the terminal's folder path
    (e.g. Kalpana) or of its window title (e.g. the account number).
    If no MT5/MT4 terminal matches, any open window whose title contains this text is used.

.PARAMETER Monitor
    Only needed if the wrong screen is picked: the TV's number in the "Displays" list
    this script prints, or part of the TV's name.

.PARAMETER WaitSeconds
    How long to wait for the TV to connect after the Cast panel opens.

.EXAMPLE
    .\TerminalToTV.ps1

.EXAMPLE
    .\TerminalToTV.ps1 -Match Kalpana

.EXAMPLE
    .\TerminalToTV.ps1 -Match 51234567 -Monitor 2
#>
[CmdletBinding()]
param(
    # Your terminal: part of its folder name or window title, e.g. 'Kalpana' or the account number.
    # Can stay empty when only one MT5 terminal is open.
    [string]$Match = '',

    # Which screen is the TV: its number in the "Displays" list, or part of its name. Empty = automatic.
    [string]$Monitor = '',

    # Seconds to wait for the TV to connect after the Cast panel opens.
    [int]$WaitSeconds = 90
)

$ErrorActionPreference = 'Stop'

# Unexpected errors: show a short message instead of a wall of red text.
trap {
    Write-Host "`nPROBLEM: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Process names of MetaTrader terminals: MT5, MT4.
$TerminalProcessNames = @('terminal64', 'terminal')

if (-not ('TerminalToTV.Native' -as [type])) {
    Add-Type -IgnoreWarnings -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace TerminalToTV
{
    public class WindowInfo
    {
        public IntPtr Handle;
        public int ProcessId;
        public string ProcessName = "";   // e.g. "terminal64" (lower case, no .exe)
        public string ProcessPath = "";   // e.g. "C:\Program Files\MetaTrader 5\terminal64.exe"
        public string Title = "";
        public string ClassName = "";
    }

    public class DisplayInfo
    {
        public string DeviceName = "";    // e.g. "\\.\DISPLAY2"
        public string Name = "";          // monitor / TV name, can be empty
        public int Technology = -1;       // DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY
        public int Screens;               // screens showing this desktop area; 2 or more = mirrored
        public bool IsPrimary;
        public int Left, Top, Width, Height;

        public bool IsWireless { get { return Technology == Native.TECHNOLOGY_MIRACAST; } }

        public string Connection
        {
            get
            {
                switch (Technology)
                {
                    case 15: return "wireless (Cast)";
                    case 5: return "HDMI";
                    case 10: return "DisplayPort";
                    case 4: return "DVI";
                    case 0: return "VGA";
                    case 16: return "USB";
                    case 6: case 11: case int.MinValue: return "built-in";
                    default: return "";
                }
            }
        }
    }

    public static class Native
    {
        public const int TECHNOLOGY_MIRACAST = 15;

        // Windows handles screens that show different pictures as separate "monitors" (\\.\DISPLAY1,
        // \\.\DISPLAY2, ...). A mirrored TV shares the PC screen's monitor, an extended TV gets its own.

        public static List<WindowInfo> GetWindows()
        {
            List<WindowInfo> windows = new List<WindowInfo>();
            Dictionary<uint, string> processPaths = new Dictionary<uint, string>();
            IntPtr console = GetConsoleWindow();
            EnumWindowsProc callback = delegate(IntPtr hWnd, IntPtr lParam)
            {
                try
                {
                    // Only normal app windows: visible, not owned by another window, with a title.
                    if (hWnd == console || !IsWindowVisible(hWnd) || GetWindow(hWnd, GW_OWNER) != IntPtr.Zero) return true;
                    StringBuilder title = new StringBuilder(512);
                    if (GetWindowText(hWnd, title, title.Capacity) == 0) return true;
                    StringBuilder className = new StringBuilder(256);
                    GetClassName(hWnd, className, className.Capacity);
                    uint pid;
                    GetWindowThreadProcessId(hWnd, out pid);
                    string path;
                    if (!processPaths.TryGetValue(pid, out path))
                    {
                        path = GetProcessPath(pid);
                        processPaths[pid] = path;
                    }

                    WindowInfo window = new WindowInfo();
                    window.Handle = hWnd;
                    window.ProcessId = (int)pid;
                    window.ProcessPath = path;
                    window.ProcessName = Path.GetFileNameWithoutExtension(path).ToLowerInvariant();
                    window.Title = title.ToString();
                    window.ClassName = className.ToString();
                    windows.Add(window);
                }
                catch (Exception) { }
                return true;
            };
            EnumWindows(callback, IntPtr.Zero);
            GC.KeepAlive(callback);
            return windows;
        }

        // Screens that are connected (plugged in or cast), whether they show a picture or not.
        public static int CountConnectedScreens()
        {
            return CountScreens(GetDisplayPaths(QDC_ALL_PATHS), true);
        }

        // Screens that show a picture right now; mirrored screens count one by one.
        public static int CountActiveScreens()
        {
            return CountScreens(GetDisplayPaths(QDC_ONLY_ACTIVE_PATHS), false);
        }

        public static List<DisplayInfo> GetDisplays()
        {
            IntPtr dpi = EnterPhysicalPixels();
            try
            {
                List<DisplayInfo> displays = new List<DisplayInfo>();
                foreach (MonitorEntry monitor in GetMonitors())
                {
                    DisplayInfo display = new DisplayInfo();
                    display.DeviceName = monitor.DeviceName;
                    display.IsPrimary = monitor.IsPrimary;
                    display.Left = monitor.Bounds.Left;
                    display.Top = monitor.Bounds.Top;
                    display.Width = monitor.Bounds.Right - monitor.Bounds.Left;
                    display.Height = monitor.Bounds.Bottom - monitor.Bounds.Top;
                    displays.Add(display);
                }
                foreach (DisplayPath path in GetDisplayPaths(QDC_ONLY_ACTIVE_PATHS))
                {
                    string deviceName = GetSourceName(path.SourceAdapter, path.SourceId);
                    foreach (DisplayInfo display in displays)
                    {
                        if (!string.Equals(display.DeviceName, deviceName, StringComparison.OrdinalIgnoreCase)) continue;
                        display.Screens++;
                        // A mirrored monitor has several screens: describe it by the wireless one (the TV).
                        if (display.Screens == 1 || path.Technology == TECHNOLOGY_MIRACAST)
                        {
                            display.Technology = path.Technology;
                            display.Name = GetTargetName(path.TargetAdapter, path.TargetId);
                        }
                    }
                }
                return displays;
            }
            finally { LeavePhysicalPixels(dpi); }
        }

        // Same as Win+P -> "Extend": every connected screen gets its own desktop area. 0 = success.
        public static int ExtendDesktop()
        {
            return SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, SDC_TOPOLOGY_EXTEND | SDC_APPLY);
        }

        // Moves the window onto the given monitor and maximizes it there. Returns "" or the problem.
        public static string MoveToDisplay(IntPtr hWnd, string deviceName)
        {
            IntPtr dpi = EnterPhysicalPixels();
            try
            {
                MonitorEntry target = FindMonitor(deviceName);
                if (target == null) return "the screen " + deviceName + " is not available any more.";

                // A maximized or minimized window cannot be moved, so bring it back to normal size first
                // (a minimized window that was maximized needs two restores).
                for (int i = 0; i < 3 && (IsIconic(hWnd) || IsZoomed(hWnd)); i++)
                {
                    ShowWindow(hWnd, SW_RESTORE);
                    Thread.Sleep(250);
                }

                RECT work = target.Work;
                int width = (work.Right - work.Left) * 3 / 4;
                int height = (work.Bottom - work.Top) * 3 / 4;
                int x = work.Left + (work.Right - work.Left - width) / 2;
                int y = work.Top + (work.Bottom - work.Top - height) / 2;
                if (!SetWindowPos(hWnd, IntPtr.Zero, x, y, width, height, SWP_NOACTIVATE | SWP_SHOWWINDOW))
                    return "Windows refused to move the window (error " + Marshal.GetLastWin32Error() + ").";
                ShowWindow(hWnd, SW_MAXIMIZE);
                Thread.Sleep(200);

                if (MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST) != target.Handle)
                    return "the window did not stay on " + deviceName + ".";
                return "";
            }
            finally { LeavePhysicalPixels(dpi); }
        }

        public static bool IsOnDisplay(IntPtr hWnd, string deviceName)
        {
            IntPtr dpi = EnterPhysicalPixels();
            try
            {
                MonitorEntry monitor = FindMonitor(deviceName);
                return monitor != null && MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST) == monitor.Handle;
            }
            finally { LeavePhysicalPixels(dpi); }
        }

        // ---- helpers --------------------------------------------------------------------

        class MonitorEntry
        {
            public IntPtr Handle;
            public string DeviceName;
            public RECT Bounds;
            public RECT Work;
            public bool IsPrimary;
        }

        struct DisplayPath
        {
            public LUID SourceAdapter;
            public uint SourceId;
            public LUID TargetAdapter;
            public uint TargetId;
            public int Technology;
            public bool TargetAvailable;
        }

        // Use real pixels, so positions are right even when the PC screen and the TV use
        // different Windows scaling (e.g. 125% on the monitor, 300% on a 4K TV).
        static IntPtr EnterPhysicalPixels()
        {
            try
            {
                IntPtr previous = SetThreadDpiAwarenessContext(new IntPtr(-4));                // per monitor v2
                if (previous == IntPtr.Zero) previous = SetThreadDpiAwarenessContext(new IntPtr(-3)); // per monitor
                return previous;
            }
            catch (EntryPointNotFoundException) { return IntPtr.Zero; }                         // before Windows 10 1607
        }

        static void LeavePhysicalPixels(IntPtr previous)
        {
            if (previous != IntPtr.Zero) SetThreadDpiAwarenessContext(previous);
        }

        static List<MonitorEntry> GetMonitors()
        {
            List<MonitorEntry> monitors = new List<MonitorEntry>();
            MonitorEnumProc callback = delegate(IntPtr hMonitor, IntPtr hdc, ref RECT rect, IntPtr data)
            {
                MONITORINFOEX info = new MONITORINFOEX();
                info.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));
                if (GetMonitorInfo(hMonitor, ref info))
                {
                    MonitorEntry monitor = new MonitorEntry();
                    monitor.Handle = hMonitor;
                    monitor.DeviceName = info.szDevice;
                    monitor.Bounds = info.rcMonitor;
                    monitor.Work = info.rcWork;
                    monitor.IsPrimary = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
                    monitors.Add(monitor);
                }
                return true;
            };
            EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
            GC.KeepAlive(callback);
            return monitors;
        }

        static MonitorEntry FindMonitor(string deviceName)
        {
            foreach (MonitorEntry monitor in GetMonitors())
                if (string.Equals(monitor.DeviceName, deviceName, StringComparison.OrdinalIgnoreCase)) return monitor;
            return null;
        }

        static int CountScreens(List<DisplayPath> paths, bool availableOnly)
        {
            List<string> seen = new List<string>();
            foreach (DisplayPath path in paths)
            {
                if (availableOnly && !path.TargetAvailable) continue;
                string key = path.TargetAdapter.HighPart + "/" + path.TargetAdapter.LowPart + "/" + path.TargetId;
                if (!seen.Contains(key)) seen.Add(key);
            }
            return seen.Count;
        }

        static List<DisplayPath> GetDisplayPaths(uint flags)
        {
            for (int attempt = 0; attempt < 5; attempt++)
            {
                uint pathCount, modeCount;
                int error = GetDisplayConfigBufferSizes(flags, out pathCount, out modeCount);
                if (error != 0) throw new Win32Exception(error);
                IntPtr paths = Marshal.AllocHGlobal((int)Math.Max(pathCount, 1) * PATH_INFO_SIZE);
                IntPtr modes = Marshal.AllocHGlobal((int)Math.Max(modeCount, 1) * MODE_INFO_SIZE);
                try
                {
                    error = QueryDisplayConfig(flags, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
                    if (error == ERROR_INSUFFICIENT_BUFFER) continue;   // a screen came or went meanwhile
                    if (error != 0) throw new Win32Exception(error);

                    // Read the fields we need straight from each DISPLAYCONFIG_PATH_INFO (72 bytes).
                    List<DisplayPath> list = new List<DisplayPath>();
                    for (int i = 0; i < pathCount; i++)
                    {
                        IntPtr p = new IntPtr(paths.ToInt64() + (long)i * PATH_INFO_SIZE);
                        DisplayPath path = new DisplayPath();
                        path.SourceAdapter.LowPart = (uint)Marshal.ReadInt32(p, 0);
                        path.SourceAdapter.HighPart = Marshal.ReadInt32(p, 4);
                        path.SourceId = (uint)Marshal.ReadInt32(p, 8);
                        path.TargetAdapter.LowPart = (uint)Marshal.ReadInt32(p, 20);
                        path.TargetAdapter.HighPart = Marshal.ReadInt32(p, 24);
                        path.TargetId = (uint)Marshal.ReadInt32(p, 28);
                        path.Technology = Marshal.ReadInt32(p, 36);
                        path.TargetAvailable = Marshal.ReadInt32(p, 60) != 0;
                        list.Add(path);
                    }
                    return list;
                }
                finally
                {
                    Marshal.FreeHGlobal(paths);
                    Marshal.FreeHGlobal(modes);
                }
            }
            throw new InvalidOperationException("The screen setup kept changing. Please run the script again.");
        }

        static string GetSourceName(LUID adapter, uint sourceId)
        {
            DISPLAYCONFIG_SOURCE_DEVICE_NAME request = new DISPLAYCONFIG_SOURCE_DEVICE_NAME();
            request.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
            request.header.size = Marshal.SizeOf(typeof(DISPLAYCONFIG_SOURCE_DEVICE_NAME));
            request.header.adapterId = adapter;
            request.header.id = sourceId;
            return DisplayConfigGetDeviceInfo(ref request) == 0 ? request.viewGdiDeviceName : "";
        }

        static string GetTargetName(LUID adapter, uint targetId)
        {
            DISPLAYCONFIG_TARGET_DEVICE_NAME request = new DISPLAYCONFIG_TARGET_DEVICE_NAME();
            request.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
            request.header.size = Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_DEVICE_NAME));
            request.header.adapterId = adapter;
            request.header.id = targetId;
            return DisplayConfigGetDeviceInfo(ref request) == 0 ? (request.monitorFriendlyDeviceName ?? "") : "";
        }

        static string GetProcessPath(uint processId)
        {
            IntPtr process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, processId);
            if (process == IntPtr.Zero) return "";
            try
            {
                StringBuilder path = new StringBuilder(1024);
                uint size = (uint)path.Capacity;
                return QueryFullProcessImageName(process, 0, path, ref size) ? path.ToString() : "";
            }
            finally { CloseHandle(process); }
        }

        // ---- Win32 ------------------------------------------------------------------------

        const uint GW_OWNER = 4;
        const int SW_MAXIMIZE = 3;
        const int SW_RESTORE = 9;
        const uint SWP_NOACTIVATE = 0x0010;
        const uint SWP_SHOWWINDOW = 0x0040;
        const uint MONITOR_DEFAULTTONEAREST = 2;
        const uint MONITORINFOF_PRIMARY = 1;
        const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
        const uint QDC_ALL_PATHS = 0x1;
        const uint QDC_ONLY_ACTIVE_PATHS = 0x2;
        const uint SDC_TOPOLOGY_EXTEND = 0x4;
        const uint SDC_APPLY = 0x80;
        const int DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME = 1;
        const int DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME = 2;
        const int ERROR_INSUFFICIENT_BUFFER = 122;
        const int PATH_INFO_SIZE = 72;   // sizeof(DISPLAYCONFIG_PATH_INFO)
        const int MODE_INFO_SIZE = 64;   // sizeof(DISPLAYCONFIG_MODE_INFO)

        [StructLayout(LayoutKind.Sequential)]
        struct RECT { public int Left, Top, Right, Bottom; }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct MONITORINFOEX
        {
            public int cbSize;
            public RECT rcMonitor;
            public RECT rcWork;
            public uint dwFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szDevice;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct LUID { public uint LowPart; public int HighPart; }

        [StructLayout(LayoutKind.Sequential)]
        struct DISPLAYCONFIG_DEVICE_INFO_HEADER
        {
            public int type;
            public int size;
            public LUID adapterId;
            public uint id;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct DISPLAYCONFIG_SOURCE_DEVICE_NAME
        {
            public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string viewGdiDeviceName;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct DISPLAYCONFIG_TARGET_DEVICE_NAME
        {
            public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
            public uint flags;
            public int outputTechnology;
            public ushort edidManufactureId;
            public ushort edidProductCodeId;
            public uint connectorInstance;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string monitorFriendlyDeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string monitorDevicePath;
        }

        delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, ref RECT rect, IntPtr data);

        [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hWnd, uint command);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder name, int maxCount);
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hWnd);
        [DllImport("user32.dll")] static extern bool IsZoomed(IntPtr hWnd);
        [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int command);
        [DllImport("user32.dll", SetLastError = true)] static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int width, int height, uint flags);
        [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr hWnd, uint flags);
        [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc callback, IntPtr data);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX info);
        [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
        [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags, out uint pathCount, out uint modeCount);
        [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint pathCount, IntPtr paths, ref uint modeCount, IntPtr modes, IntPtr topologyId);
        [DllImport("user32.dll")] static extern int SetDisplayConfig(uint pathCount, IntPtr paths, uint modeCount, IntPtr modes, uint flags);
        [DllImport("user32.dll")] static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_SOURCE_DEVICE_NAME request);
        [DllImport("user32.dll")] static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_TARGET_DEVICE_NAME request);
        [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
        [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inheritHandle, uint processId);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool QueryFullProcessImageName(IntPtr process, uint flags, StringBuilder path, ref uint size);
        [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    }
}
'@
}

function Write-Step([string]$Text) { Write-Host "`n>> $Text" -ForegroundColor Cyan }

function Write-Info([string]$Text) { Write-Host "   $Text" }

function Stop-WithError([string]$Text) {
    Write-Host "`nPROBLEM: $Text" -ForegroundColor Red
    exit 1
}

function Test-Contains([string]$Text, [string]$Part) {
    return [bool]$Text -and $Text.IndexOf($Part, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Read-Choice([string]$Question, [int]$Count) {
    $answer = Read-Host "   $Question"
    $number = 0
    if (-not [int]::TryParse($answer, [ref]$number) -or $number -lt 1 -or $number -gt $Count) {
        Stop-WithError "'$answer' is not a number from the list."
    }
    return $number - 1
}

# Finds the terminal window to show on the TV.
function Find-Terminal {
    $windows = @([TerminalToTV.Native]::GetWindows() | Where-Object {
        $_.ProcessId -ne $PID -and -not (Test-Contains $_.Title 'TerminalToTV')
    })

    # One main window per running MetaTrader terminal.
    $terminals = @()
    foreach ($group in @($windows | Where-Object { $TerminalProcessNames -contains $_.ProcessName } | Group-Object ProcessId)) {
        $main = @($group.Group | Where-Object { $_.ClassName -like 'MetaQuotes::MetaTrader*' })
        if ($main.Count -gt 0) { $terminals += $main[0] } else { $terminals += $group.Group[0] }
    }

    if ($Match) {
        $found = @($terminals | Where-Object { (Test-Contains $_.Title $Match) -or (Test-Contains $_.ProcessPath $Match) })
        if ($found.Count -eq 0) {
            # Not a MetaTrader terminal? Then any window with that text in its title (e.g. a web terminal).
            $found = @($windows | Where-Object { Test-Contains $_.Title $Match })
        }
        if ($found.Count -eq 0) {
            Stop-WithError "No open window matches '$Match'. Open the terminal first, or check the name / account number."
        }
    }
    else {
        $found = $terminals
        if ($found.Count -eq 0) { Stop-WithError 'No MT5 / MT4 terminal is open. Open it first, then run this again.' }
    }
    if ($found.Count -eq 1) { return $found[0] }

    Write-Step 'More than one terminal is open. Which one should go to the TV?'
    for ($i = 0; $i -lt $found.Count; $i++) {
        Write-Info ('[{0}] {1}' -f ($i + 1), $found[$i].Title)
        if ($found[$i].ProcessPath) { Write-Host ('       {0}' -f $found[$i].ProcessPath) -ForegroundColor DarkGray }
    }
    $terminal = $found[(Read-Choice 'Type the number and press Enter' $found.Count)]
    Write-Info "Tip: to skip this question next time, put a part of the name or the account number in `$Match at the top of TerminalToTV.ps1."
    return $terminal
}

function Test-Extended($Displays) {
    return @($Displays).Count -ge 2 -and @($Displays | Where-Object { $_.Screens -gt 1 }).Count -eq 0
}

# Makes sure the TV is connected and in Extend mode. Returns the list of displays.
function Connect-TV {
    if ([TerminalToTV.Native]::CountConnectedScreens() -lt 2) {
        Write-Step 'The TV is not connected yet. Opening the Windows Cast panel - click your TV there.'
        Write-Info '(If no panel opens, press Win+K.)'
        Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList 'ms-settings-connectabledevices:devicediscovery'

        $deadline = (Get-Date).AddSeconds($WaitSeconds)
        while ([TerminalToTV.Native]::CountConnectedScreens() -lt 2) {
            if ((Get-Date) -gt $deadline) {
                Stop-WithError ("The TV did not connect within $WaitSeconds seconds.`n" +
                    "         Connect it with Windows Cast (Win+K) or an HDMI cable, then run this again.`n" +
                    "         (Casting from the Chrome browser / Chromecast can only mirror the screen.)")
            }
            Start-Sleep -Seconds 1
        }
        # Give Windows a moment to finish switching the TV on.
        $deadline = (Get-Date).AddSeconds(10)
        while ([TerminalToTV.Native]::CountActiveScreens() -lt 2 -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
        Start-Sleep -Seconds 2
        Write-Info 'TV connected.'
    }

    $displays = @([TerminalToTV.Native]::GetDisplays())
    if (Test-Extended $displays) { return $displays }

    Write-Step 'Switching the TV from Mirror (Duplicate) to Extend, so it becomes a separate screen...'
    $result = [TerminalToTV.Native]::ExtendDesktop()
    if ($result -ne 0) {
        Write-Info "Windows did not switch by itself (code $result). In the menu that opens, click 'Extend'."
        Start-Process -FilePath 'DisplaySwitch.exe'
    }
    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 500
        $displays = @([TerminalToTV.Native]::GetDisplays())
    } while (-not (Test-Extended $displays) -and (Get-Date) -lt $deadline)
    if ($displays.Count -lt 2) {
        Stop-WithError "The TV is still mirroring. Press Win+P, choose 'Extend', then run this again."
    }
    Start-Sleep -Seconds 1
    return @([TerminalToTV.Native]::GetDisplays())
}

# Picks the display that is the TV.
function Select-TV($Displays) {
    $list = @($Displays | Sort-Object @{ Expression = { $_.IsPrimary }; Descending = $true }, @{ Expression = { $_.Left }; Ascending = $true })

    Write-Step 'Displays:'
    for ($i = 0; $i -lt $list.Count; $i++) {
        $display = $list[$i]
        $name = if ($display.Name) { $display.Name } else { '(no name)' }
        $role = if ($display.IsPrimary) { 'main PC screen' } else { '' }
        Write-Info ('[{0}] {1,-26} {2,5} x {3,-5} {4,-16} {5}' -f ($i + 1), $name, $display.Width, $display.Height, $display.Connection, $role)
    }

    if ($Monitor) {
        $number = 0
        if ([int]::TryParse($Monitor, [ref]$number)) {
            if ($number -lt 1 -or $number -gt $list.Count) { Stop-WithError "-Monitor $Monitor is not in the Displays list above." }
            return $list[$number - 1]
        }
        $named = @($list | Where-Object { (Test-Contains $_.Name $Monitor) -or (Test-Contains $_.DeviceName $Monitor) })
        if ($named.Count -eq 0) { Stop-WithError "No display in the list above has '$Monitor' in its name." }
        return $named[0]
    }

    $wireless = @($list | Where-Object { $_.IsWireless })
    if ($wireless.Count -gt 0) { return $wireless[0] }
    $others = @($list | Where-Object { -not $_.IsPrimary })
    if ($others.Count -eq 1) { return $others[0] }
    Write-Info '(If your TV is not in this list, connect it with Win+K first.)'
    return $list[(Read-Choice 'Which number is the TV? Type it and press Enter' $list.Count)]
}

# ---- main ----------------------------------------------------------------------------------

try { $Host.UI.RawUI.WindowTitle = 'TerminalToTV' } catch { }
Write-Host 'TerminalToTV - only the trading terminal on the TV' -ForegroundColor Green

$terminal = Find-Terminal
Write-Step "Terminal: $($terminal.Title)"

for ($attempt = 1; $attempt -le 2; $attempt++) {
    $tv = Select-TV (Connect-TV)
    $tvName = if ($tv.Name) { $tv.Name } else { $tv.DeviceName }
    Write-Step "Moving the terminal to the TV ($tvName)..."

    $problem = [TerminalToTV.Native]::MoveToDisplay($terminal.Handle, $tv.DeviceName)
    if ($problem) {
        if ($problem -like '*(error 5)*') {
            $problem += "`n         MT5 runs 'as administrator', so this must too: right-click TerminalToTV.bat, 'Run as administrator'."
        }
        Stop-WithError "Could not move the terminal: $problem"
    }

    Start-Sleep -Seconds 2
    if ([TerminalToTV.Native]::IsOnDisplay($terminal.Handle, $tv.DeviceName)) {
        Write-Host "`nDone! The terminal is on the TV - the PC screen is free for your other work." -ForegroundColor Green
        Write-Info 'Tip: press F11 in MT5 for a full-screen chart. Disconnect the TV (Win+K) to bring the terminal back.'
        Start-Sleep -Seconds 5
        exit 0
    }
    Write-Info 'Windows changed the screen setup meanwhile - trying once more...'
}
Stop-WithError "The terminal did not stay on the TV. Press Win+P, choose 'Extend', then run this again."
