@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "launcher\TerrixaLauncher.ps1"
if %errorlevel% neq 0 pause
endlocal
