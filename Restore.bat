@echo off
rem Restores the original files saved by the FS95/FS98 Win64 Patch. Asks for administrator rights, which are needed
rem when the game is installed under Program Files.
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FS-Win64-Patch.ps1" -Restore %*
echo.
pause
