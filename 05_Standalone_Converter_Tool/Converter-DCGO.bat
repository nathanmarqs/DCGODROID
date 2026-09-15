@echo off
title DCGO Android Converter & Builder
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DCGO-Converter.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo An error occurred during execution. Exit code: %ERRORLEVEL%
    pause
)
