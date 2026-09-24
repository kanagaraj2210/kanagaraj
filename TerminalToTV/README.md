# TerminalToTV: TV-la Trading Terminal mattum

PC-la irukkura **TV Cast icon** click panna, PC screen muzhusum TV-la **mirror** aagudhu
(Windows-la idhukku *Duplicate* mode nu peru). Idhu TV-ai oru **thani second screen**
(*Extend* mode) aakki, **MT5 terminal window-ai mattum** TV-ku move panni maximize pannum.
PC screen-la neenga vera vela paakalam (Chrome, MetaEditor, etc.). TV-la trading terminal mattum dhaan theriyum.

> **English:** Windows Cast mirrors the whole PC screen by default. This switches the TV to *Extend*
> mode (a separate second screen) and moves only the MT5 terminal window onto it, maximized.
> Works on Windows 10 / 11 with Windows Cast (Miracast) or an HDMI cable.

Rendu vazhi irukku:

| | Enna | Eppo use pannanum |
|---|---|---|
| **Vazhi 1 (best)** | `TerminalToTV.mq5`: MT5 script | Eppovume. Download / ZIP / PowerShell theva illa, antivirus block pannaadhu. Endha terminal-la run panreengalo, **adhu mattum** TV-ku pogum. |
| Vazhi 2 | `TerminalToTV.bat` + `.ps1`: PowerShell | MT5 illadha vera app-ai TV-ku anuppanum-na. Sila PC-la Windows Defender idhai (and repo ZIP-ai) "virus"-nu thappa block pannum. |

## Vazhi 1: MT5 script (`TerminalToTV.mq5`)

### One-time setup (Kalpana terminal-la)

1. GitHub-la [`TerminalToTV/TerminalToTV.mq5`](TerminalToTV.mq5) file-ai open pannunga →
   mela right side-la **Copy raw file** button click pannunga (code ellam copy aagum).
2. **Kalpana MT5 terminal**-la `F4` press pannunga → **MetaEditor** open aagum.
   (Andha terminal-la irundhe open pannanum. Ovvoru terminal-kum thani data folder irukku.)
3. MetaEditor-la **File → New** (`Ctrl+N`) → **Script** → **Next** → Name: `TerminalToTV` → **Finish**.
4. Ulla irukkura code ellathaiyum delete panni (`Ctrl+A`, `Delete`), copy panna code-ai paste pannunga (`Ctrl+V`).
5. **Compile** (`F7`) press pannunga. Keezha `0 errors, 0 warnings` varanum.
6. *(Optional)* MT5 **Navigator → Scripts → TerminalToTV** → right-click → **Set hotkey** (e.g. `Ctrl+T`).
   Appuram oru key press-la TV-ku pogum.

### Daily use

1. TV-ai Cast pannunga (`Win + K` → TV). Pannalai-na script-e Cast panel open pannum.
2. Kalpana terminal-la **Navigator → Scripts → TerminalToTV**-ai edhavadhu oru chart mela drag pannunga
   (illa hotkey press pannunga).
3. Varra dialog-la **Allow DLL imports** tick pannunga (Common / Dependencies tab-la irukkum) → **OK**.
   (Windows-oda sondha `user32.dll` / `shell32.dll` mattum dhaan use aagum: screen setup + window move.
   Trade edhuvum pannaadhu. Chart-la irukkura EA-vai touch pannaadhu.)
4. Script:
   - Mirror (Duplicate) → **Extend** maathum
   - Indha terminal-ai TV-ku move panni **maximize** pannum
5. Mudinjadhu! TV-la Kalpana terminal mattum, PC-la unga desktop.

- **Terminal-ai PC screen-ku thirumba kondu vara:** script run pannum bodhu **Inputs** tab-la `Screen` = `1`.
  Illa TV-ai disconnect pannunga (`Win + K` → **Disconnect**). Windows thaana PC-ku kondu varum.
- **Messages:** chart-la (left top) and **Toolbox → Experts** tab-la varum. Problem vandha Alert window varum.
- **Allow DLL imports tick panna mudiyala-na:** Tools → Options → Expert Advisors → **Allow DLL imports** tick pannunga.

## Vazhi 2: PowerShell (`TerminalToTV.bat`)

> Windows Defender sila PC-la idhai "Virus detected"-nu block pannum (false positive: PowerShell launcher
> pattern). Appadi vandha **Vazhi 1** use pannunga.

| File | Enna panradhu |
|---|---|
| `TerminalToTV.bat` | Idhai double-click pannunga. Idhu dhaan start button. |
| `TerminalToTV-choose.bat` | Vera terminal-ai TV-ku anuppanum-na idhai double-click pannunga (list-la irundhu thirumba choose panna). |
| `TerminalToTV.ps1` | Main script (PowerShell). Windows-la already irukku, edhuvum install panna theva illa. Idhai double-click panna vendaam. |

### Setup

1. Moonu files-aiyum PC-la oru folder-la vainga, e.g. `C:\TerminalToTV\`.
2. Rendu `.bat` files-kum: right-click → **Properties** → keezha **Unblock** tick irundha tick pannunga → **OK**.
3. `TerminalToTV.bat` → right-click → **Send to → Desktop (create shortcut)**.
   Desktop shortcut-ku **MT5 to TV** nu per vainga.

### Endha terminal TV-ku pogum?

- **Oru MT5 mattum open-ah irundha:** adhu automatic-ah TV-ku pogum.
- **Neraiya MT5 terminals open-ah irundha:** first time script oru list kaattum:

  ```
  >> Endha terminal TV-ku poganum?
     [1] 51234567: ICMarketsSC-Live07 - Hedge - ... - [XAUUSD,M5]
     [2] 7001234: Exness-MT5Real - Hedge - ... - [EURUSD,H1]
     Number type panni Enter press pannunga : 2
  ```

  Kalpana terminal-oda number-ai (title bar-la irukkura account number-ai vechu kandupidikkalaam)
  type panni Enter press pannunga. Script adhai **nyabagam vechukkum**, adutha thadava kekkaadhu.
- **Vera terminal-ku maathanum-na:** `TerminalToTV-choose.bat` double-click pannunga.
- **List-la unga terminal illa-na:** `0` type pannunga. PC-la open-ah irukkura ella windows-um varum,
  adhula unga terminal-oda number-ai kudunga.

### Options

`TerminalToTV.bat`-ai Notepad-la open panni, `TerminalToTV.ps1"`-ku appuram add pannalaam:

| Option | Enna | Example |
|---|---|---|
| `-Match` | Endha terminal (account number / folder name / window title-la irukkura text). Match aagala-na script list kaattum. | `-Match "51234567"` |
| `-Monitor` | Endha screen TV (script print panra **Screens** list-la irukkura number, illa TV name) | `-Monitor 2` |
| `-WaitSeconds` | TV connect aaga evvalavu seconds wait pannanum (default 90) | `-WaitSeconds 120` |
| `-Choose` | Terminal list-ai thirumba kaattum (`TerminalToTV-choose.bat` idhai dhaan pannudhu) | `-Choose` |

## Script illama, manual-ah pannanum-na

1. `Win + K` → unga TV-ai select pannunga.
2. `Win + P` → **Extend** select pannunga.
3. MT5 window-ai click panni `Win + Shift + →` (illa `←`) press pannunga. Window TV screen-ku pogum.
4. `Win + ↑` → maximize.

**Tip:** MT5-la `F11` press panna toolbars ellam hide aagi, chart mattum full-screen-ah TV-la theriyum.

## Problems?

| Problem | Solution |
|---|---|
| ZIP / `.bat` download-la "Virus detected" | Windows Defender false positive (PowerShell launcher pattern; latest Defender signatures-la scan panna clean dhaan). **Vazhi 1** (MT5 script) use pannunga: code-ai copy panni MetaEditor-la paste pannalaam, download theva illa. |
| MT5 script: "DLL imports is not allowed" / script run aagala | Dialog-la **Allow DLL imports** tick pannunga. Illa Tools → Options → Expert Advisors → **Allow DLL imports**. |
| Cast panel-la TV varala | TV-la *Screen Mirroring / Screen Share / Miracast* on pannunga. PC-um TV-um same Wi-Fi-la irukkanum. |
| "TV connect aagala" | Chrome browser-la irundhu Chromecast / Google TV-ku cast panreengana, adhu Windows-ku oru screen-ah theriyaadhu, mirror mattum dhaan mudiyum. Windows Cast (`Win + K`, Miracast) illa HDMI cable use pannunga. |
| Terminal thappana screen-ku pogudhu | MT5 script: Experts tab-la **Screen 1, 2, ...** list irukkum, `Screen` input-la TV number kudunga. PowerShell: `-Monitor <number>`. |
| TV-la taskbar theriyudhu | Settings → Personalization → Taskbar → Taskbar behaviors → **Show my taskbar on all displays** off pannunga. Illa MT5-la `F11`. |

## How it works (technical)

- **MT5 script:** takes its own terminal's top-level window (`GetAncestor(CHART_WINDOW_HANDLE, GA_ROOT)`).
  If the TV is mirrored it calls `SetDisplayConfig(SDC_TOPOLOGY_EXTEND | SDC_APPLY)` (the same as
  `Win + P` → **Extend**); if no second screen is active it opens the Cast panel
  (`ms-settings-connectabledevices:devicediscovery`, same as `Win + K`) and waits. It finds the screens by
  probing the virtual desktop with `MonitorFromPoint` + `GetMonitorInfoW` (MQL5 cannot pass the
  `EnumDisplayMonitors` callback), picks the screen that is not the PC main screen, then restores, moves
  (`SetWindowPos`) and maximizes the terminal there and checks it stayed. Since it runs inside the
  terminal process, window moves work even when MT5 runs as administrator.
- **PowerShell script:** same display steps via `QueryDisplayConfig` / `SetDisplayConfig`. It finds the terminal
  window (process `terminal64.exe` / `terminal.exe`, or window class `MetaQuotes::MetaTrader::*`), asks
  when there are several, and remembers the pick in `%LOCALAPPDATA%\TerminalToTV\terminal.txt`.
  It prefers the wireless (Miracast) screen as the TV.
