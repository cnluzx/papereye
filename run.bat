@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell.exe -STA -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%SCRIPT_DIR%paper-eye.ps1"
