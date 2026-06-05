# ATA — Atlas Time Archive
# CLI 入口 · 一键保存/恢复/洞察/清理
# Usage: .\ata.ps1 <command> [options]

param(
    [Parameter(Position = 0)]
    [ValidateSet('save', 'restore', 'log', 'insight', 'diff', 'clean', 'install', 'uninstall', 'help')]
    [string]$Command = 'help',

    [string]$Date,
    [string]$OutputPath,
    [string]$Level = 'instant',
    [switch]$DryRun,
    [switch]$SkipMissing,
    [switch]$Yes,
    [int]$OlderThan = 30
)

$srcDir = "$PSScriptRoot\src"

# 显示 Banner
function Show-Banner {
    Write-Host @"

  ╔══════════════════════════════════╗
  ║   A T A   Atlas Time Archive    ║
  ║   承载 · 秩序 · 守护             ║
  ╚══════════════════════════════════╝

"@ -ForegroundColor Magenta
}

# 帮助
function Show-ATAHelp {
    Show-Banner
    Write-Host "USAGE" -ForegroundColor Cyan
    Write-Host "  .\ata.ps1 <command> [options]`n"
    Write-Host "COMMANDS" -ForegroundColor Cyan
    Write-Host "  save       Snapshot current desktop state"
    Write-Host "  restore    Restore a previous snapshot"
    Write-Host "  log        List recent snapshots"
    Write-Host "  insight    Generate AI insight from snapshots"
    Write-Host "  diff       Compare two recent snapshots"
    Write-Host "  clean      Remove old snapshots"
    Write-Host "  install    Register startup + shutdown hooks"
    Write-Host "  uninstall  Remove scheduled tasks"
    Write-Host "  help       Show this help`n"
    Write-Host "OPTIONS" -ForegroundColor Cyan
    Write-Host "  -Date <yyyyMMdd>    Target date for restore/log"
    Write-Host "  -Level <level>      Insight level: instant|daily|weekly"
    Write-Host "  -DryRun             Preview without executing"
    Write-Host "  -SkipMissing        Skip apps that can't be launched"
    Write-Host "  -Yes                Skip confirmation prompts"
    Write-Host "  -OlderThan <days>   Age threshold for clean (default 30)`n"
    Write-Host "EXAMPLES" -ForegroundColor Cyan
    Write-Host "  .\ata.ps1 save"
    Write-Host "  .\ata.ps1 restore"
    Write-Host "  .\ata.ps1 restore -Date 20260605 -DryRun"
    Write-Host "  .\ata.ps1 log"
    Write-Host "  .\ata.ps1 insight -Level weekly"
    Write-Host "  .\ata.ps1 diff"
    Write-Host "  .\ata.ps1 clean -DryRun"
    Write-Host "  .\ata.ps1 install`n"
}

# ═══════════════════════════════════════
# 命令路由
# ═══════════════════════════════════════

switch ($Command) {
    'save' {
        . "$srcDir\Snapshot.ps1"
        . "$srcDir\AnaBridge.ps1"
        Save-ATA-Full -Type manual
    }

    'restore' {
        . "$srcDir\Restore.ps1"
        $params = @{ SkipMissing = $SkipMissing; Yes = $Yes; DryRun = $DryRun }
        if ($Date) { $params['Date'] = $Date }
        Restore-ATA @params
    }

    'log' {
        . "$srcDir\Restore.ps1"
        $snaps = Get-ATASnapshots -Date $Date -Last 20
        Show-Banner
        if ($snaps.Count -eq 0) {
            Write-Host "No snapshots found." -ForegroundColor Gray
        } else {
            Write-Host "Recent snapshots:" -ForegroundColor Cyan
            $snaps | ForEach-Object {
                $size = [math]::Round($_.Length / 1024, 1)
                Write-Host "  $($_.Name)  |  $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))  |  ${size}KB" -ForegroundColor Gray
            }
            Write-Host "`n$($snaps.Count) snapshot(s). Use '.\ata.ps1 restore -Date <date>' to restore." -ForegroundColor Gray
        }

        # 同时显示最近日志
        $logDir = Join-Path $([Environment]::GetFolderPath('ApplicationData')) "ATA\logs"
        $logFile = Join-Path $logDir "ata.log"
        if ((Test-Path $logFile)) {
            Write-Host "`nRecent activity:" -ForegroundColor Cyan
            Get-Content $logFile -Tail 5 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
    }

    'insight' {
        . "$srcDir\DeepSeek.ps1"
        Show-Banner
        $params = @{ Level = $Level }
        if ($Date) {
            $snap = Resolve-ATASnapshot -Date $Date
            if ($snap) { $params['SnapshotPath'] = $snap }
        }
        $result = Get-ATAInsight @params
        if (-not $result) {
            Write-Host "`nNo insight generated. Configure DeepSeek API key in config to enable." -ForegroundColor Gray
            Write-Host "  Config: $env:APPDATA\ATA\config.json" -ForegroundColor Gray
        }
    }

    'diff' {
        . "$srcDir\DeepSeek.ps1"
        Show-Banner
        $snaps = @(Get-ATASnapshots -Last 2)
        if ($snaps.Count -lt 2) {
            Write-Host "Need at least 2 snapshots to diff. Save more first." -ForegroundColor Yellow
        } else {
            Write-Host "Comparing last 2 snapshots:" -ForegroundColor Cyan
            $null = Compare-ATASnapshots -SnapshotPath1 $snaps[1].FullName -SnapshotPath2 $snaps[0].FullName
        }
    }

    'clean' {
        . "$srcDir\Restore.ps1"
        Show-Banner
        $params = @{ OlderThan = $OlderThan; DryRun = $DryRun }
        Invoke-ATAClean @params
        if (-not $DryRun) {
            Write-Host "`nUse '.\ata.ps1 clean -DryRun' to preview first." -ForegroundColor Gray
        }
    }

    'install' {
        . "$srcDir\Automation.ps1"
        Show-Banner
        Install-ATA
        Write-Host "`nRun '.\ata.ps1 save' to create your first snapshot." -ForegroundColor Cyan
    }

    'uninstall' {
        . "$srcDir\Automation.ps1"
        Uninstall-ATA
    }

    default {
        Show-ATAHelp
    }
}
