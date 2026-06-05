@echo off
title ATA — Atlas Time Archive
cd /d D:\Hi\Projects\ata

:: Get today's date
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set td=%%I
set td=%td:~0,8%

:: Check for today's snapshot
dir /b "%APPDATA%\ATA\snapshots\ata-%td%*.json" >nul 2>&1

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo   Today's snapshot FOUND.
    echo   Picking the best one (most windows)...
    echo ========================================
    echo.
    powershell -ExecutionPolicy Bypass -Command "$snaps=@(Get-ChildItem \"$env:APPDATA\ATA\snapshots\ata-%td%*.json\");$best=$snaps[0];$max=0;foreach($s in $snaps){$d=Get-Content $s.FullName -Raw|ConvertFrom-Json;$c=$d.snapshot.windows.Count;if($c -gt $max){$max=$c;$best=$s}};Write-Host ('Restoring: '+$best.Name+' ('+$max+' windows)');cd D:\Hi\Projects\ata;.\ata.ps1 restore -SnapshotPath $best.FullName -SkipMissing -Yes
) else (
    echo.
    echo ========================================
    echo   No snapshot for today yet.
    echo   SAVING your workspace now...
    echo ========================================
    echo.
    powershell -ExecutionPolicy Bypass -File ".\ata.ps1" save
)

echo.
echo ========================================
echo   Done! Press any key to close...
echo ========================================
pause >nul
