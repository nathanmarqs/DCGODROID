@echo off
title DCGO Android Converter & Builder
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DCGO-Converter.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Ocorreu um erro durante a execucao. Codigo: %ERRORLEVEL%
    pause
)
