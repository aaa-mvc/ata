@echo off
title ATA - Save Workspace
cd /d D:\Hi\Projects\ata
echo Saving your workspace...
powershell -ExecutionPolicy Bypass -File ".\ata.ps1" save
echo.
echo Done. Press any key to close.
pause >nul
