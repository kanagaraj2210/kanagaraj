@echo off
rem Double-click me: shows ONLY the trading terminal (MT5) on the TV, not a mirror of the whole PC screen.
rem Options go after the .ps1 name below, for example:  -Match "Kalpana"   or   -Monitor 2
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0TerminalToTV.ps1" %*
if errorlevel 1 pause
