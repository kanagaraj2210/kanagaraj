@echo off
rem Double-click me to choose (again) which terminal goes to the TV. The choice is remembered.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0TerminalToTV.ps1" -Choose %*
if errorlevel 1 pause
