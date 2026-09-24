# TerminalToTV: TV-la Trading Terminal mattum

PC-la irukkura **TV Cast icon** click panna, PC screen muzhusum TV-la **mirror** aagudhu
(Windows-la idhukku *Duplicate* mode nu peru). Indha script TV-ai oru **thani second screen**
(*Extend* mode) aakki, **MT5 terminal window-ai mattum** TV-ku move panni maximize pannum.
PC screen-la neenga vera vela paakalam (Chrome, MetaEditor, etc.). TV-la trading terminal mattum dhaan theriyum.

> **English:** Windows Cast mirrors the whole PC screen by default. This script switches the TV to
> *Extend* mode (a separate second screen) and moves only the MT5 terminal window onto it, maximized.
> Works on Windows 10 / 11 with Windows Cast (Miracast) or an HDMI cable. Nothing to install.

## Files

| File | Enna panradhu |
|---|---|
| `TerminalToTV.bat` | Idhai double-click pannunga. Idhu dhaan start button. |
| `TerminalToTV-choose.bat` | Vera terminal-ai TV-ku anuppanum-na idhai double-click pannunga (list-la irundhu thirumba choose panna). |
| `TerminalToTV.ps1` | Main script (PowerShell). Windows-la already irukku, edhuvum install panna theva illa. Idhai double-click panna vendaam. |

## One-time setup

1. GitHub repo page → green **Code** button → **Download ZIP** → extract pannunga.
   `TerminalToTV` folder-ai PC-la oru idathula vainga, e.g. `C:\TerminalToTV\`.
2. Rendu `.bat` files-kum: right-click → **Properties** → keezha **Unblock** tick irundha tick pannunga → **OK**.
3. `TerminalToTV.bat` → right-click → **Send to → Desktop (create shortcut)**.
   Desktop shortcut-ku **MT5 to TV** nu per vainga.
4. Script-la edhuvum edit panna theva illa.

## Endha terminal TV-ku pogum?

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

## Daily use

1. MT5 terminal open pannunga.
2. Desktop-la **MT5 to TV** double-click pannunga.
3. TV innum connect aagala-na, Windows **Cast** panel open aagum. Angae unga TV-ai click pannunga.
4. Script automatic-ah:
   - Mirror (Duplicate) → **Extend** mode-ku maathum
   - MT5 terminal-ai TV-ku move panni **maximize** pannum
5. Mudinjadhu! TV-la terminal mattum, PC-la unga desktop.

TV-ai disconnect pannina (`Win + K` → **Disconnect**), MT5 automatic-ah PC screen-ku thirumbi varum.

**Tip:** MT5-la `F11` press panna toolbars ellam hide aagi, chart mattum full-screen-ah TV-la theriyum.

## Script illama, manual-ah pannanum-na

1. `Win + K` → unga TV-ai select pannunga.
2. `Win + P` → **Extend** select pannunga.
3. MT5 window-ai click panni `Win + Shift + →` (illa `←`) press pannunga. Window TV screen-ku pogum.
4. `Win + ↑` → maximize.

Script indha 4 steps-aiyum one click-la pannudhu.

## Options

`TerminalToTV.bat`-ai Notepad-la open panni, `TerminalToTV.ps1"`-ku appuram add pannalaam:

| Option | Enna | Example |
|---|---|---|
| `-Match` | Endha terminal (account number / folder name / window title-la irukkura text). Match aagala-na script list kaattum. | `-Match "51234567"` |
| `-Monitor` | Endha screen TV (script print panra **Screens** list-la irukkura number, illa TV name) | `-Monitor 2` |
| `-WaitSeconds` | TV connect aaga evvalavu seconds wait pannanum (default 90) | `-WaitSeconds 120` |
| `-Choose` | Terminal list-ai thirumba kaattum (`TerminalToTV-choose.bat` idhai dhaan pannudhu) | `-Choose` |

Rendu terminals-ku rendu shortcuts venum-na: `.bat` file-ai copy panni (e.g. `Kalpana-to-TV.bat`),
ovvonnulayum vera `-Match` kudunga (account number best, adhu title bar-la irukkum).

## Problems?

| Problem | Solution |
|---|---|
| Black window varala / Notepad open aagudhu | `.ps1` illa, **`TerminalToTV.bat`**-ai dhaan double-click pannanum. Blue "Windows protected your PC" vandha: **More info → Run anyway**. |
| List-la unga terminal illa | `0` type panni ella windows-um paarunga. MT5 open-ah irukkaa nu check pannunga. |
| `Terminal-ai move panna mudiyala ... error 5` | MT5-ai **Run as administrator**-la open panni irundha, `TerminalToTV.bat`-aiyum right-click → **Run as administrator**. |
| Cast panel-la TV varala | TV-la *Screen Mirroring / Screen Share / Miracast* on pannunga. PC-um TV-um same Wi-Fi-la irukkanum. |
| `90 seconds-la TV connect aagala` | Chrome browser-la irundhu Chromecast / Google TV-ku cast panreengana, adhu Windows-ku oru screen-ah theriyaadhu, mirror mattum dhaan mudiyum. Windows Cast (`Win + K`, Miracast) illa HDMI cable use pannunga. |
| Terminal thappana screen-ku pogudhu | Script print panra **Screens** list-la TV-oda number paarunga, `-Monitor <number>` kudunga. |
| TV-la taskbar theriyudhu | Settings → Personalization → Taskbar → Taskbar behaviors → **Show my taskbar on all displays** off pannunga. Illa MT5-la `F11`. |

## How it works (technical)

1. Finds the terminal: MetaTrader windows (process `terminal64.exe` / `terminal.exe`, or window class
   `MetaQuotes::MetaTrader::*`), narrowed by `-Match` when it matches. With several terminals, or none
   recognised, it shows a numbered list; the pick is remembered in `%LOCALAPPDATA%\TerminalToTV\terminal.txt`
   (by program path, so it survives title changes).
2. Counts connected screens with `QueryDisplayConfig`. If only the PC screen is connected, it opens the
   Cast panel (`ms-settings-connectabledevices:devicediscovery`, same as `Win + K`) and waits.
3. If the TV is mirrored, it calls `SetDisplayConfig(SDC_TOPOLOGY_EXTEND | SDC_APPLY)`, the same thing
   `Win + P` → **Extend** does. If that fails, it opens the `Win + P` menu for you.
4. Picks the TV: the wireless (Miracast) screen, otherwise the only non-main screen, otherwise asks.
5. Restores the terminal window, moves it onto the TV with `SetWindowPos` (in physical pixels, so
   different Windows scaling on the PC and the TV doesn't matter), maximizes it, and checks that it stayed there.
