//+------------------------------------------------------------------+
//|                                                 TerminalToTV.mq5 |
//|  Indha MT5 terminal-ai mattum TV-la kaattum - PC screen mirror    |
//|  illama. Shows ONLY this terminal on the TV (Windows Cast / HDMI).|
//|                                                                  |
//|  Run it on any chart of the terminal that should go to the TV    |
//|  (e.g. the Kalpana live terminal). In the script dialog tick     |
//|  "Allow DLL imports": it only calls Windows' own user32.dll and  |
//|  shell32.dll (screen setup + window position). It never trades.  |
//+------------------------------------------------------------------+
#property copyright   "kanagaraj"
#property version     "1.00"
#property description "Indha terminal-ai mattum TV-la kaattum (PC screen mirror illama)."
#property description "'Allow DLL imports' tick pannunga - Windows user32/shell32 mattum use aagum, trade edhuvum pannaadhu."
#property script_show_inputs

input int InpScreen      = 0;   // Screen: 0 = TV (automatic), 1 = PC main screen, 2+ = number from Experts log
input int InpWaitSeconds = 90;  // TV connect aaga wait panna vendiya seconds

//--- Windows API (user32 and shell32 are part of Windows)
struct MONITORINFO
  {
   int               cbSize;
   int               monLeft, monTop, monRight, monBottom;
   int               workLeft, workTop, workRight, workBottom;
   uint              flags;
  };

#import "user32.dll"
int  GetSystemMetrics(int index);
long GetAncestor(long hwnd, uint flags);
int  IsIconic(long hwnd);
int  IsZoomed(long hwnd);
int  ShowWindow(long hwnd, int command);
int  SetWindowPos(long hwnd, long insertAfter, int x, int y, int width, int height, uint flags);
long MonitorFromPoint(long point, uint flags);
long MonitorFromWindow(long hwnd, uint flags);
int  GetMonitorInfoW(long monitor, MONITORINFO &info);
int  GetDisplayConfigBufferSizes(uint flags, uint &pathCount, uint &modeCount);
int  SetDisplayConfig(uint pathCount, long paths, uint modeCount, long modes, uint flags);
#import
#import "shell32.dll"
long ShellExecuteW(long hwnd, string operation, string file, string parameters, string directory, int showCommand);
#import

#define SM_XVIRTUALSCREEN        76
#define SM_YVIRTUALSCREEN        77
#define SM_CXVIRTUALSCREEN       78
#define SM_CYVIRTUALSCREEN       79
#define SM_CMONITORS             80
#define GA_ROOT                  2
#define SW_SHOWNORMAL            1
#define SW_MAXIMIZE              3
#define SW_RESTORE               9
#define SWP_NOACTIVATE           0x0010
#define SWP_SHOWWINDOW           0x0040
#define MONITOR_DEFAULTTONULL    0
#define MONITOR_DEFAULTTONEAREST 2
#define MONITORINFOF_PRIMARY     1
#define QDC_ONLY_ACTIVE_PATHS    2
#define SDC_TOPOLOGY_EXTEND      0x4
#define SDC_APPLY                0x80

//--- one screen (Windows "monitor"); coordinates in pixels
struct Screen
  {
   long              handle;
   int               left, top, right, bottom;
   int               workLeft, workTop, workRight, workBottom;   // without the taskbar
   bool              primary;
  };

//+------------------------------------------------------------------+
void OnStart()
  {
   long window = GetAncestor(ChartGetInteger(0, CHART_WINDOW_HANDLE), GA_ROOT);
   if(window == 0)
     {
      Alert("TerminalToTV: terminal window kidaikkala.");
      return;
     }

   if(InpScreen != 1 && !MakeTVSeparateScreen())
     {
      Comment("");
      Alert("TerminalToTV: TV connect aagala / innum mirror-la irukku. Win+K -> TV connect pannunga, Win+P -> Extend, appuram script-ai thirumba run pannunga.");
      return;
     }

   Screen screens[];
   int count = GetScreens(screens);
   for(int i = 0; i < count; i++)
      PrintFormat("Screen %d: %d x %d at (%d, %d)%s", i + 1,
                  screens[i].right - screens[i].left, screens[i].bottom - screens[i].top,
                  screens[i].left, screens[i].top, screens[i].primary ? "  <- PC main screen" : "");

   int target = PickScreen(screens);
   if(target < 0)
     {
      Comment("");
      Alert("TerminalToTV: screen " + IntegerToString(InpScreen) + " illa. TV Win+K-la connect aagi irukkaa nu paarunga (Experts log-la Screens list irukku).");
      return;
     }

   Say("Terminal-ai screen " + IntegerToString(target + 1) + "-ku move panren...");
   string problem = MoveTo(window, screens[target]);
   Comment("");
   if(problem != "")
     {
      Alert("TerminalToTV: terminal-ai move panna mudiyala: " + problem);
      return;
     }
   Print(screens[target].primary ? "Terminal PC screen-ku vandhaachu."
                                 : "Mudinjadhu! Terminal ippo TV-la irukku. PC screen-la vera vela paakalam. (MT5-la F11 = full-screen chart)");
  }

//+------------------------------------------------------------------+
//| Makes the TV a separate screen (Extend). Opens the Windows Cast  |
//| panel if no TV is connected yet.                                 |
//+------------------------------------------------------------------+
bool MakeTVSeparateScreen()
  {
   if(DesktopScreens() >= 2)
      return true;                                      // already extended
   if(ActiveScreens() >= 2)
      return SwitchToExtend();                          // TV connected but mirroring the PC screen

   // A TV on HDMI that is switched to "PC screen only" comes back with Extend.
   if(SetDisplayConfig(0, 0, 0, 0, SDC_TOPOLOGY_EXTEND | SDC_APPLY) == 0 && WaitForDesktopScreens(5))
      return true;

   Say("TV innum connect aagala. Windows Cast panel-la unga TV-ai click pannunga... (" + IntegerToString(InpWaitSeconds) + " seconds wait panren)");
   ShellExecuteW(0, "open", "explorer.exe", "ms-settings-connectabledevices:devicediscovery", "", SW_SHOWNORMAL);
   ulong deadline = GetTickCount64() + (ulong)InpWaitSeconds * 1000;
   while(ActiveScreens() < 2 && DesktopScreens() < 2)
     {
      if(IsStopped() || GetTickCount64() > deadline)
         return false;
      Sleep(1000);
     }
   Sleep(3000);                                         // let Windows finish switching the TV on
   return DesktopScreens() >= 2 || SwitchToExtend();
  }

//--- same as Win+P -> Extend; if Windows refuses, opens the Win+P menu for the user
bool SwitchToExtend()
  {
   Say("TV-ai Mirror (Duplicate)-la irundhu Extend-ku maathuren...");
   int result = SetDisplayConfig(0, 0, 0, 0, SDC_TOPOLOGY_EXTEND | SDC_APPLY);
   if(result == 0 && WaitForDesktopScreens(15))
      return true;
   PrintFormat("SetDisplayConfig(EXTEND) returned %d", result);
   Say("Windows thaana maathala. Open aagura menu-la 'Extend' click pannunga...");
   ShellExecuteW(0, "open", "DisplaySwitch.exe", "", "", SW_SHOWNORMAL);
   return WaitForDesktopScreens(30);
  }

//--- separate desktop screens (a mirrored TV does not count)
int DesktopScreens()
  {
   return GetSystemMetrics(SM_CMONITORS);
  }

//--- screens showing a picture right now (a mirrored TV counts too)
int ActiveScreens()
  {
   uint paths = 0, modes = 0;
   if(GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, paths, modes) != 0)
      return DesktopScreens();
   return (int)paths;
  }

bool WaitForDesktopScreens(int seconds)
  {
   ulong deadline = GetTickCount64() + (ulong)seconds * 1000;
   while(DesktopScreens() < 2)
     {
      if(IsStopped() || GetTickCount64() > deadline)
         return false;
      Sleep(500);
     }
   Sleep(1000);                                         // let the new layout settle
   return true;
  }

//+------------------------------------------------------------------+
//| All screens, PC main screen first, then left to right. Found by  |
//| probing points of the whole desktop (MQL5 cannot take the        |
//| EnumDisplayMonitors callback).                                   |
//+------------------------------------------------------------------+
int GetScreens(Screen &screens[])
  {
   ArrayResize(screens, 0);
   int vx = GetSystemMetrics(SM_XVIRTUALSCREEN), vy = GetSystemMetrics(SM_YVIRTUALSCREEN);
   int vw = GetSystemMetrics(SM_CXVIRTUALSCREEN), vh = GetSystemMetrics(SM_CYVIRTUALSCREEN);
   for(int x = vx + 40; x < vx + vw; x += 80)
      for(int y = vy + 40; y < vy + vh; y += 80)
        {
         long monitor = MonitorFromPoint(PackPoint(x, y), MONITOR_DEFAULTTONULL);
         if(monitor == 0 || FindScreen(screens, monitor) >= 0)
            continue;
         MONITORINFO info;
         ZeroMemory(info);
         info.cbSize = sizeof(MONITORINFO);
         if(GetMonitorInfoW(monitor, info) == 0)
            continue;
         int n = ArraySize(screens);
         ArrayResize(screens, n + 1);
         screens[n].handle     = monitor;
         screens[n].left       = info.monLeft;
         screens[n].top        = info.monTop;
         screens[n].right      = info.monRight;
         screens[n].bottom     = info.monBottom;
         screens[n].workLeft   = info.workLeft;
         screens[n].workTop    = info.workTop;
         screens[n].workRight  = info.workRight;
         screens[n].workBottom = info.workBottom;
         screens[n].primary    = (info.flags & MONITORINFOF_PRIMARY) != 0;
        }
   int count = ArraySize(screens);
   for(int i = 1; i < count; i++)                       // insertion sort: main screen first, then by left edge
      for(int j = i; j > 0 && ComesBefore(screens[j], screens[j - 1]); j--)
        {
         Screen swap   = screens[j];
         screens[j]     = screens[j - 1];
         screens[j - 1] = swap;
        }
   return count;
  }

bool ComesBefore(const Screen &a, const Screen &b)
  {
   if(a.primary != b.primary)
      return a.primary;
   return a.left < b.left;
  }

int FindScreen(const Screen &screens[], long monitor)
  {
   for(int i = 0; i < ArraySize(screens); i++)
      if(screens[i].handle == monitor)
         return i;
   return -1;
  }

//--- POINT {x, y} passed by value = one 64-bit register: x in the low half, y in the high half
long PackPoint(int x, int y)
  {
   return ((long)y << 32) | (long)(uint)x;
  }

//--- InpScreen 1..N picks that screen; 0 = the TV, i.e. the screen that is not the PC main screen
int PickScreen(const Screen &screens[])
  {
   int count = ArraySize(screens);
   if(InpScreen >= 1)
      return InpScreen <= count ? InpScreen - 1 : -1;
   int best = -1;
   for(int i = 0; i < count; i++)
      if(!screens[i].primary && (best < 0 || screens[i].left > screens[best].left))
         best = i;
   return best;
  }

//+------------------------------------------------------------------+
//| Moves the window onto the screen and maximizes it there.         |
//| Returns "" or the problem.                                       |
//+------------------------------------------------------------------+
string MoveTo(long window, const Screen &screen)
  {
   // A maximized or minimized window cannot be moved (minimized-after-maximized needs two restores).
   for(int i = 0; i < 3 && (IsIconic(window) != 0 || IsZoomed(window) != 0); i++)
     {
      ShowWindow(window, SW_RESTORE);
      Sleep(250);
     }
   int width  = (screen.workRight - screen.workLeft) * 3 / 4;
   int height = (screen.workBottom - screen.workTop) * 3 / 4;
   int x      = screen.workLeft + (screen.workRight - screen.workLeft - width) / 2;
   int y      = screen.workTop + (screen.workBottom - screen.workTop - height) / 2;
   if(SetWindowPos(window, 0, x, y, width, height, SWP_NOACTIVATE | SWP_SHOWWINDOW) == 0)
      return "Windows window-ai move panna vidala.";
   ShowWindow(window, SW_MAXIMIZE);
   Sleep(300);
   if(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST) != screen.handle)
      return "window andha screen-la nikkala.";
   return "";
  }

//--- progress message on the chart and in the Experts log
void Say(string text)
  {
   Comment("TerminalToTV: ", text);
   Print(text);
  }
//+------------------------------------------------------------------+
