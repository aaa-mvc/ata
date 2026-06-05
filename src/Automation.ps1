# Automation.ps1 — 自动化调度
# 镜头 023-024：关机钩子 · 开机对话框 · 定时保存 · 一键安装/卸载

. "$PSScriptRoot\Snapshot.ps1"
. "$PSScriptRoot\DeepSeek.ps1"
. "$PSScriptRoot\AnaBridge.ps1"

function Register-ATAStartupTask {
    $taskName = "ATA-StartupDialog"
    $scriptPath = "$PSScriptRoot\Show-StartupDialog.ps1"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Force -ErrorAction Stop
        Write-Host "Registered: $taskName" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to register startup task: $_"
    }
}

function Register-ATAShutdownHook {
    $taskName = "ATA-ShutdownSave"
    try {
        $trigger = New-ScheduledTaskTrigger -AtLogoff
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -Command `". '$PSScriptRoot\Snapshot.ps1'; Save-ATA -Type shutdown`""
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -Compatibility Win8 -ExecutionTimeLimit (New-TimeSpan -Seconds 30)
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Force -ErrorAction Stop
        Write-Host "Registered: $taskName (shutdown hook)" -ForegroundColor Green
        return
    } catch {
        Write-Warning "Shutdown hook failed ($_). Falling back to periodic auto-save."
    }
    $taskName2 = "ATA-AutoSave"
    try {
        $trigger = New-ScheduledTaskTrigger -Once (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30) `
            -RepetitionDuration ([TimeSpan]::MaxValue)
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -Command `". '$PSScriptRoot\Snapshot.ps1'; Save-ATA -Type auto`""
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $taskName2 -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Force -ErrorAction Stop
        Write-Host "Registered: $taskName2 (30min auto-save fallback)" -ForegroundColor Green
    } catch {
        Write-Warning "Auto-save also failed: $_"
        Write-Host "Manual save (ata save) is always available." -ForegroundColor Gray
    }
}

function Show-StartupDialog {
    $snapshots = @(Get-ATASnapshots -Last 5)
    if ($snapshots.Count -eq 0) { return }

    $lines = @()
    $idx = 1
    foreach ($s in $snapshots) {
        try {
            $d = Get-Content $s.FullName -Raw | ConvertFrom-Json
            $ts = $d.snapshot.created
            $wc = $d.snapshot.windows.Count
            $lines += "[$idx] $ts | $wc apps | $($d.snapshot.type)"
            $idx++
        } catch { }
    }

    Write-Host "`n============================================" -ForegroundColor Magenta
    Write-Host "  ATA — Restore Your Workspace?" -ForegroundColor White
    Write-Host "============================================" -ForegroundColor Magenta
    foreach ($line in $lines) { Write-Host "  $line" -ForegroundColor Gray }
    Write-Host "  [0] Skip — Start fresh" -ForegroundColor Gray
    Write-Host "  [Enter] = restore latest | Any other key = skip" -ForegroundColor DarkGray

    $key = Read-Host "`n  Choice"
    if ($key -eq "0") { Write-Host "  Skipped." -ForegroundColor Gray; return }
    $choice = 1
    try { $choice = [int]$key } catch { $choice = 1 }
    if ($choice -lt 1 -or $choice -gt $snapshots.Count) { $choice = 1 }

    $selected = $snapshots[$choice - 1]
    Write-Host "  Restoring: $($selected.Name)..." -ForegroundColor Cyan
    . "$PSScriptRoot\Restore.ps1"
    Restore-ATA -SnapshotPath $selected.FullName -Yes -SkipMissing
}

function Install-ATA {
    Write-Host "`nInstalling ATA..." -ForegroundColor Cyan
    $dirs = @("$env:APPDATA\ATA\snapshots", "$env:APPDATA\ATA\logs", "$env:APPDATA\ATA\insights")
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    $ecoDir = "$env:APPDATA\Ecosystem\events"
    if (-not (Test-Path $ecoDir)) { New-Item -ItemType Directory -Path $ecoDir -Force | Out-Null }
    Register-ATAStartupTask
    Register-ATAShutdownHook

    # 桌面一键恢复快捷方式
    $desktopBat = [Environment]::GetFolderPath('Desktop') + '\ATA 恢复.bat'
    $batLines = @(
        '@echo off',
        'title ATA - Restore Your Workspace',
        'cd /d D:\Hi\Projects\ata',
        'powershell -ExecutionPolicy Bypass -File ".\ata.ps1" restore -SkipMissing -Yes',
        'echo.',
        'echo Press any key to close...',
        'pause >nul'
    )
    $batLines | Set-Content -Path $desktopBat -Encoding ASCII -Force
    Write-Host "  Desktop: ATA 恢复.bat (double-click to restore)" -ForegroundColor Gray

    Write-Host "`nATA installed." -ForegroundColor Green
    Write-Host "  Startup dialog: on | Shutdown save: on (30min fallback)" -ForegroundColor Gray
}

function Uninstall-ATA {
    Write-Host "`nUninstalling ATA..." -ForegroundColor Cyan
    $tasks = @("ATA-StartupDialog", "ATA-ShutdownSave", "ATA-AutoSave")
    foreach ($t in $tasks) {
        try { Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction Stop; Write-Host "  Removed: $t" }
        catch { Write-Host "  Not found: $t" -ForegroundColor DarkGray }
    }
    Write-Host "`nSnapshots and config preserved at: $env:APPDATA\ATA\" -ForegroundColor Green
}
