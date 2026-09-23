@echo off
cd /d "%~dp0"
echo Checking Smart Model Router status...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\status.ps1"
echo.
pause