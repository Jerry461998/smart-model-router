@echo off
cd /d "%~dp0"
echo Enabling Smart Model Router...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\enable.ps1"
echo.
pause