@echo off
cd /d "%~dp0"
echo Uninstalling Smart Model Router...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1"
echo.
pause