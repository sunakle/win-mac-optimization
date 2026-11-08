@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore-All.ps1" -Apply
echo.
if errorlevel 1 echo Restoration stopped with an error. Read the message above.
pause

