@echo off
cd /d "%~dp0"
echo Installing Smart Model Router...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1"
echo.
pause