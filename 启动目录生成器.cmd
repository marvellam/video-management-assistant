@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Generate-VideoProject.ps1"
if errorlevel 1 pause
endlocal
