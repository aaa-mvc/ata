@echo off
title ATA - Restore Workspace
cd /d D:\Hi\Projects\ata
echo Restoring your workspace...
echo Press Ctrl+C within 5s to cancel.
timeout /t 5 /nobreak >nul
powershell -ExecutionPolicy Bypass -File ".\ata.ps1" restore -SkipMissing -Yes
echo.
echo Done. Press any key to close.
pause >nul
