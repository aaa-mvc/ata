@echo off
title ATA — Restore Your Workspace
cd /d D:\Hi\Projects\ata
powershell -ExecutionPolicy Bypass -File ".\ata.ps1" restore -SkipMissing -Yes
echo.
echo Press any key to close...
pause >nul
