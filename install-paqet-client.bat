@echo off
setlocal EnableDelayedExpansion
title Paqet Client Installer Launcher
cd /d "%~dp0"

:: ============================================================================
:: STEP 1: ADMINISTRATOR CHECK & ELEVATION
:: ============================================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo   ========================================================
    echo                 ADMINISTRATOR REQUIRED
    echo   ========================================================
    echo.
    echo   This installer requires Administrator privileges.
    echo   Requesting elevation...
    echo.

    :: Create a temporary VBS script to elevate
    echo Set UAC = CreateObject^("Shell.Application"^) > "%TEMP%\elevate.vbs"
    echo UAC.ShellExecute "%~f0", "", "%~dp0", "runas", 1 >> "%TEMP%\elevate.vbs"
    cscript //nologo "%TEMP%\elevate.vbs"
    del "%TEMP%\elevate.vbs"
    exit /B
)

:: ============================================================================
:: STEP 2: LAUNCH POWERSHELL INSTALLER
:: ============================================================================
echo.
echo   Launching PowerShell Installer...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-paqet-client.ps1"

if %errorLevel% neq 0 (
    echo.
    echo   PowerShell script exited with error code %errorLevel%
    pause
)

exit /B %errorLevel%
