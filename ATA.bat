@echo off
title ATA - Atlas Time Archive
cd /d D:\Hi\Projects\ata

:: Check for today's snapshot
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set td=%%I
set td=%td:~0,8%

dir /b "%APPDATA%\ATA\snapshots\ata-%td%*.json" >nul 2>&1

if %errorlevel% equ 0 (
    :: Today has snapshot = already saved today. RESTORE yesterday.
    echo.
    echo ========================================
    echo   RESTORING your workspace...
    echo   Press Ctrl+C within 5s to cancel
    echo ========================================
    echo.
    timeout /t 5 /nobreak >nul
    powershell -ExecutionPolicy Bypass -File ".\ata.ps1" restore -SkipMissing -Yes
) else (
    :: No snapshot today = first boot. RESTORE yesterday.
    echo.
    echo ========================================
    echo   RESTORING yesterday's workspace...
    echo   Press Ctrl+C within 5s to cancel
    echo ========================================
    echo.
    timeout /t 5 /nobreak >nul
    powershell -ExecutionPolicy Bypass -Command "$snaps=@(Get-ChildItem \"$env:APPDATA\ATA\snapshots\ata-*.json\"|Sort-Object LastWriteTime -Descending);if($snaps.Count -gt 0){cd D:\Hi\Projects\ata;.\ata.ps1 restore -SkipMissing -Yes}else{cd D:\Hi\Projects\ata;.\ata.ps1 save}"
)

echo.
echo ========================================
echo   Done. Press any key to close.
echo ========================================
pause >nul
