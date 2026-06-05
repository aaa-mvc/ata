# Restore.ps1 鈥?鎭㈠寮曟搸
# 闀滃ご 015-019锛氬簲鐢ㄥ惎鍔?路 绐楀彛褰掍綅 路 鍧愭爣鏄犲皠 路 涓绘仮澶?路 鏃ュ織娓呯悊

. "$PSScriptRoot\Window.ps1"
. "$PSScriptRoot\Monitor.ps1"
. "$PSScriptRoot\Snapshot.ps1"

# ============================================================
# 015锛歋tart-ATAApp 鈥?搴旂敤鍚姩鍣?# ============================================================
function Start-ATAApp {
    param($Window, [int]$Timeout = 15)
    $name = $Window.process.name
    $existing = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($existing) {
        $main = $existing | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($main) { Write-Host "   ... $name already running" -ForegroundColor Gray; return $main }
    }
    $proc = $null
    $exePath = $Window.process.executablePath
    if ($exePath -and (Test-Path $exePath)) {
        $proc = Start-Process -FilePath $exePath -PassThru -WindowStyle Normal
    } else {
        $proc = Start-Process -FilePath "$name.exe" -PassThru -WindowStyle Normal
    }
    $waited = 0
    while ($waited -lt $Timeout -and $proc) {
        Start-Sleep -Milliseconds 500
        $waited += 0.5
        $fresh = Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($fresh) { return $fresh }
    }
    if ($proc) { Write-Warning "   $name started but window not detected in ${Timeout}s."; return $proc }
    return $null
}

# ============================================================
# 016锛歋et-WindowPosition 鈥?绐楀彛褰掍綅
# ============================================================
function Set-WindowPosition {
    param(
        [IntPtr]$Handle,
        [int]$X, [int]$Y, [int]$Width, [int]$Height,
        [string]$State = "normal"
    )

    if ($Handle -eq [IntPtr]::Zero) { return $false }

    if ($State -eq "maximized") {
        [Win32]::ShowWindow($Handle, [Win32]::SW_MAXIMIZE) | Out-Null
    }
    elseif ($State -eq "minimized") {
        [Win32]::ShowWindow($Handle, [Win32]::SW_MINIMIZE) | Out-Null
    }
    else {
        [Win32]::ShowWindow($Handle, [Win32]::SW_RESTORE) | Out-Null
        Start-Sleep -Milliseconds 200
        [Win32]::SetWindowPos(
            $Handle,
            [Win32]::HWND_TOP,
            $X, $Y, $Width, $Height,
            [Win32]::SWP_NOZORDER
        ) | Out-Null
    }

    return $true
}

# ============================================================
# 017锛欸et-CoordinateMapping 鈥?鏄剧ず鍣ㄩ€傞厤
# ============================================================
function Get-CoordinateMapping {
    param([array]$SavedMonitors, [array]$CurrentMonitors)

    # 鐩稿悓閰嶇疆 鈫?鏃犻渶鏄犲皠
    if ($SavedMonitors.Count -eq $CurrentMonitors.Count) {
        $same = $true
        for ($i = 0; $i -lt $SavedMonitors.Count; $i++) {
            if ($SavedMonitors[$i].bounds.w -ne $CurrentMonitors[$i].bounds.w) {
                $same = $false
                break
            }
            if ($SavedMonitors[$i].bounds.h -ne $CurrentMonitors[$i].bounds.h) {
                $same = $false
                break
            }
        }
        if ($same) { return $null }
    }

    Write-Host "   Monitor config changed." -ForegroundColor Yellow

    # 杩斿洖褰撳墠鏄剧ず鍣ㄦ暟缁勶紝Restore-ATA 鐢ㄥ畠鍋?clamp
    return @{ changed = $true; monitors = $CurrentMonitors }
}

# ============================================================
# 杈呭姪锛氬揩鐓цВ鏋?# ============================================================
function Resolve-ATASnapshot {
    param([string]$Date)
    $dir = "$env:APPDATA\ATA\snapshots"
    if (-not (Test-Path $dir)) { return $null }
    $files = Get-ChildItem $dir -Filter "ata-$Date*.json" |
        Sort-Object LastWriteTime -Descending
    if ($files.Count -eq 0) { return $null }
    return $files[0].FullName
}

function Get-LatestSnapshot {
    $dir = "$env:APPDATA\ATA\snapshots"
    if (-not (Test-Path $dir)) { return $null }
    $latest = Get-ChildItem $dir -Filter "ata-*.json" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { return $null }
    return $latest.FullName
}

# ============================================================
# Write-ATALogEntry 鈥?鏃ュ織杩藉姞
# ============================================================
function Write-ATALogEntry {
    param([string]$Action, [string]$SnapshotId, $Results)

    $logDir = "$env:APPDATA\ATA\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    $detail = ""
    if ($Results) {
        $detail = "success=$($Results.success)/$($Results.total) skipped=$($Results.skipped) failed=$($Results.failed)"
    }
    $entry = "[$ts] INFO $Action snapshot=$SnapshotId $detail"
    Add-Content -Path "$logDir\ata.log" -Value $entry -Encoding UTF8
}

# ============================================================
# 019锛欸et-ATASnapshots + Invoke-ATAClean
# ============================================================
function Get-ATASnapshots {
    param([string]$Date, [int]$Last = 10)
    $dir = "$env:APPDATA\ATA\snapshots"
    if (-not (Test-Path $dir)) { return @() }
    $files = Get-ChildItem $dir -Filter "ata-*.json" |
        Sort-Object LastWriteTime -Descending
    if ($Date) {
        $files = $files | Where-Object { $_.Name -match "ata-$Date" }
    }
    return $files | Select-Object -First $Last
}

function Invoke-ATAClean {
    param([int]$OlderThan = 30, [switch]$DryRun)

    $cutoff = (Get-Date).AddDays(-$OlderThan)
    $dir = "$env:APPDATA\ATA\snapshots"

    if (-not (Test-Path $dir)) {
        Write-Host "No snapshots directory." -ForegroundColor Gray
        return
    }

    $toDelete = Get-ChildItem $dir -Filter "ata-*.json" |
        Where-Object { $_.LastWriteTime -lt $cutoff }

    if ($DryRun) {
        Write-Host "Would delete $($toDelete.Count) snapshots > $OlderThan days:" -ForegroundColor Yellow
        $toDelete | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
        return
    }

    if ($toDelete.Count -eq 0) {
        Write-Host "No snapshots older than $OlderThan days." -ForegroundColor Gray
        return
    }

    Write-Host "Deleting $($toDelete.Count) snapshots..." -ForegroundColor Cyan
    $toDelete | Remove-Item -Force
    Write-Host "Done." -ForegroundColor Green
}

# ============================================================
# 018锛歊estore-ATA 鈥?涓绘仮澶嶅嚱鏁?# ============================================================
function Restore-ATA {
    param(
        [string]$SnapshotPath,
        [string]$Date,
        [switch]$DryRun,
        [switch]$SkipMissing,
        [switch]$Yes,
        [int]$Timeout = 15
    )

    # 1. 瑙ｆ瀽蹇収
    if ($Date) {
        $SnapshotPath = Resolve-ATASnapshot -Date $Date
        if (-not $SnapshotPath) {
            Write-Error "No snapshot found for date: $Date"
            return
        }
    }
    if (-not $SnapshotPath) {
        $SnapshotPath = Get-LatestSnapshot
        if (-not $SnapshotPath) {
            Write-Error "No snapshots found. Run ata save first."
            return
        }
    }

    Write-Host "`nLoading snapshot: $SnapshotPath" -ForegroundColor Cyan
    $data = Get-Content $SnapshotPath -Raw | ConvertFrom-Json
    $s = $data.snapshot
    Write-Host "Snapshot: $($s.id) | $($s.created) | $($s.windows.Count) windows" -ForegroundColor Gray

    # 2. 鏄剧ず鍣ㄥ姣?    $currentMonitors = Get-MonitorInfo
    $savedMonitors = $s.environment.monitors
    $mapper = Get-CoordinateMapping -SavedMonitors $savedMonitors -CurrentMonitors $currentMonitors

    # 3. Dry-run
    if ($DryRun) {
        Write-Host "`n--- DRY RUN ---" -ForegroundColor Yellow
        Write-Host "Would restore $($s.windows.Count) windows:" -ForegroundColor Gray
        $ordered = $s.windows | Sort-Object { $_.zOrder }
        foreach ($w in $ordered) {
            $tag = if ($w.restorable) { "" } else { " [NOT RESTORABLE]" }
            $t = $w.title
            if ($t.Length -gt 60) { $t = $t.Substring(0, 60) + "..." }
            Write-Host "  $($w.process.name) 鈥?$t$tag"
        }
        if ($mapper -and $mapper.changed) {
            Write-Host "Monitor config changed: coordinates will adapt." -ForegroundColor Yellow
        }
        return
    }

    # 4. 纭
    if (-not $Yes) {
        Write-Host "About to restore $($s.windows.Count) windows."
        $null = Read-Host "  [Enter] to proceed, Ctrl+C to cancel"
    }

    # 5. 閫愪釜鎭㈠
    $orderedWindows = $s.windows | Sort-Object {
        if ($_.process.name -eq "clash-verge" -or $_.process.name -eq "Clash Verge") { -999 } else { $_.zOrder }
    }
    $results = @{
        total = $orderedWindows.Count
        success = 0
        failed = 0
        skipped = 0
        details = @()
    }
    $launchDelay = if ($s.config.launchDelay) { $s.config.launchDelay } else { 1500 }

    Write-Host "`nRestoring $($orderedWindows.Count) windows..." -ForegroundColor Cyan

    foreach ($window in $orderedWindows) {
        if (-not $window.restorable) {
            Write-Host "  SKIP $($window.process.name) 鈥?not restorable" -ForegroundColor Gray
            $results.skipped++
            $results.details += @{
                window = $window.id
                app = $window.process.name
                status = "skipped"
                reason = $window.platform
            }
            continue
        }

        
        # Explorer 文件夹窗口特殊处理
        if ($window.adapter -eq "explorer" -and $window.appState.folderPath) {
            Write-Host "  OPEN $($window.appState.folderPath)" -ForegroundColor Gray
            $result = Open-ExplorerWindow -Path $window.appState.folderPath
            if ($result) {
                $results.success++
                $results.details += @{ window = $window.id; app = "explorer"; status = "success" }
                Write-Host "    OK" -ForegroundColor Green
            } else {
                $results.skipped++
                $results.details += @{ window = $window.id; app = "explorer"; status = "skipped"; reason = "path_not_found" }
                Write-Host "    WARN — path not found" -ForegroundColor Yellow
            }
            continue
        }Write-Host "  LAUNCH $($window.process.name)..." -ForegroundColor Gray
        $proc = Start-ATAApp -Window $window -Timeout $Timeout

        if (-not $proc) {
            if ($SkipMissing) {
                Write-Host "    WARN 鈥?skipped" -ForegroundColor Yellow
                $results.skipped++
                $results.details += @{
                    window = $window.id
                    app = $window.process.name
                    status = "skipped"
                    reason = "startup_failed"
                }
            }
            else {
                Write-Host "    FAIL 鈥?failed" -ForegroundColor Red
                $results.failed++
                $results.details += @{
                    window = $window.id
                    app = $window.process.name
                    status = "failed"
                    reason = "startup_failed"
                }
            }
            continue
        }

        $delay = if ($window.process.name -eq "clash-verge" -or $window.process.name -eq "Clash Verge") { 3000 } else { $launchDelay }
        Start-Sleep -Milliseconds $delay
        $hwnd = $proc.MainWindowHandle

        if ($hwnd -ne [IntPtr]::Zero) {
            $x = $window.bounds.x
            $y = $window.bounds.y
            if ($mapper -and $mapper.monitors) {
                $mi = $window.monitor
                if ($mi -lt 0) { $mi = 0 }
                $monList = @($mapper.monitors)
                if ($mi -ge $monList.Count) { $mi = $monList.Count - 1 }
                if ($mi -ge 0 -and $mi -lt $monList.Count) {
                    $cur = $monList[$mi]
                    if ($x -lt $cur.bounds.x) { $x = $cur.bounds.x }
                    if ($y -lt $cur.bounds.y) { $y = $cur.bounds.y }
                    if (($x + $window.bounds.w) -gt ($cur.bounds.x + $cur.bounds.w)) { $x = $cur.bounds.x + $cur.bounds.w - $window.bounds.w }
                    if (($y + $window.bounds.h) -gt ($cur.bounds.y + $cur.bounds.h)) { $y = $cur.bounds.y + $cur.bounds.h - $window.bounds.h }
                }
                if ($x -lt 0) { $x = 0 }
                if ($y -lt 0) { $y = 0 }
            }
            $null = Set-WindowPosition -Handle $hwnd -X $x -Y $y -Width $window.bounds.w -Height $window.bounds.h -State $window.state
        }

        $results.success++
        $results.details += @{ window = $window.id; app = $window.process.name; status = "success" }
        Write-Host "    OK" -ForegroundColor Green
    }

    # 6. 鎭㈠鐒︾偣
    $focusWindow = $s.windows | Where-Object { $_.hadFocus } | Select-Object -First 1
    if ($focusWindow) {
        $fproc = Get-Process -Name $focusWindow.process.name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($fproc -and $fproc.MainWindowHandle -ne [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 500
            [Win32]::SetForegroundWindow($fproc.MainWindowHandle) | Out-Null
            Write-Host "`nFocus restored: $($focusWindow.process.name)" -ForegroundColor Gray
        }
    }

    # 7. 鎶ュ憡
    Write-Host "`n====================================" -ForegroundColor Cyan
    Write-Host "Restore complete: $($results.success)/$($results.total) succeeded" -ForegroundColor Green
    if ($results.skipped -gt 0) {
        Write-Host "Skipped: $($results.skipped)" -ForegroundColor Yellow
        foreach ($d in @($results.details | Where-Object { $_.status -eq 'skipped' })) {
            Write-Host "  - $($d.app): $($d.reason)" -ForegroundColor Yellow
        }
    }
    if ($results.failed -gt 0) {
        Write-Host "Failed: $($results.failed)" -ForegroundColor Red
        foreach ($d in @($results.details | Where-Object { $_.status -eq 'failed' })) {
            Write-Host "  - $($d.app): $($d.reason)" -ForegroundColor Red
        }
    }
    Write-Host "====================================" -ForegroundColor Cyan

    # 8. 鏃ュ織
    Write-ATALogEntry -Action "RESTORE" -SnapshotId $s.id -Results $results

    return $results
}

