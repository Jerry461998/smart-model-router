@echo off
cd /d "%~dp0"
echo Disabling Smart Model Router...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\disable.ps1"
echo.
pause