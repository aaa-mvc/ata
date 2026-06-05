@echo off
title ATA - Save Workspace
cd /d D:\Hi\Projects\ata
echo.
echo ========================================
echo   ATA - Saving your workspace...
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -File ".\ata.ps1" save
echo.
echo ========================================
echo   Done. Press any key to close.
echo ========================================
pause >nul
