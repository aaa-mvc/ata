# Snapshot.ps1 — 快照核心逻辑
# 镜头 007-012：窗口枚举 · 显示器映射 · 焦点检测 · 快照组装 · 保存 · 校验

. "$PSScriptRoot\Window.ps1"
. "$PSScriptRoot\Monitor.ps1"
. "$PSScriptRoot\Explorer.ps1"

function Get-ProcessCommandLine {
    param([int]$ProcessId)
    try {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction Stop
        return $p.CommandLine
    } catch {
        return $null
    }
}

function Get-ATAWindows {
    $windows = @()
    $windowId = 1
    $processes = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 }

    foreach ($proc in $processes) {
        $hwnd = $proc.MainWindowHandle
        if (-not (Test-IsValidAppWindow -Handle $hwnd)) { continue }

        $title = Get-WindowTitle -Handle $hwnd
        $bounds = Get-WindowRect -Handle $hwnd
        $state = Get-WindowState -Handle $hwnd
        $class = Get-WindowClass -Handle $hwnd

        if ($state -eq "minimized") {
            $bounds = Get-WindowRestoreRect -Handle $hwnd
        }

        $cmdLine = Get-ProcessCommandLine -ProcessId $proc.Id

        $platform = "win32"
        if ($class -match "ApplicationFrameWindow") { $platform = "uwp" }
        elseif ($proc.ProcessName -match "^(Code|Discord|Slack|Notion|Figma|Obsidian)$") { $platform = "electron" }

        $window = @{}
        $window.id = "w-" + $windowId.ToString("000")
        $window.process = @{
            name           = $proc.ProcessName
            pid            = $proc.Id
            commandLine    = $cmdLine
            executablePath = $proc.Path
        }
        $window.title = $title
        $window.class = $class
        $window.bounds = $bounds
        $window.state = $state
        $window.monitor = $null
        $window.virtualDesktop = $null
        $window.zOrder = $windowId
        $window.hadFocus = $false
        $window.restorable = ($platform -ne "uwp")
        $window.platform = $platform
        $window.adapter = $null
        $window.appState = $null
        $window.eventContext = $null
        $window.restoreHooks = $null

        $windows += $window
        $windowId++
    }
    return $windows
}

function Resolve-WindowMonitors {
    param([array]$Windows, [array]$Monitors)
    foreach ($window in $Windows) {
        $cx = $window.bounds.x + $window.bounds.width / 2
        $cy = $window.bounds.y + $window.bounds.height / 2
        $window.monitor = 0
        foreach ($monitor in $Monitors) {
            $mx = $monitor.bounds.x; $my = $monitor.bounds.y
            $mw = $monitor.bounds.w; $mh = $monitor.bounds.h
            if (($cx -ge $mx) -and ($cx -lt ($mx + $mw)) -and ($cy -ge $my) -and ($cy -lt ($my + $mh))) {
                $window.monitor = $monitor.index
                break
            }
        }
    }
}

function Mark-FocusedWindow {
    param([array]$Windows)
    # 注意：直接使用 API 调用而非 helper 函数，避免作用域问题
    $fgHwnd = [Win32]::GetForegroundWindow()
    if ($fgHwnd -eq [IntPtr]::Zero) { return }
    $fgProcId = [uint32]0
    [Win32]::GetWindowThreadProcessId($fgHwnd, [ref]$fgProcId) | Out-Null
    if ($fgProcId -eq 0) { return }
    # 关键修复：使用 [int] 显式转换 + 通过索引直接赋值
    for ($i = 0; $i -lt $Windows.Count; $i++) {
        if ([int]$Windows[$i].process.pid -eq [int]$fgProcId) {
            $Windows[$i].hadFocus = $true
            return
        }
    }
}

function Test-ATASnapshot {
    param([string]$SnapshotPath)
    if (-not (Test-Path $SnapshotPath)) {
        return @{ isValid = $false; errors = @("File not found"); warnings = @() }
    }
    $errors = @(); $warnings = @()
    try { $s = Get-Content $SnapshotPath -Raw | ConvertFrom-Json }
    catch { return @{ isValid = $false; errors = @("JSON parse error"); warnings = @() } }
    if (-not $s.version) { $errors += "Missing: version" }
    if (-not $s.snapshot) { $errors += "Missing: snapshot" }
    if (-not $s.snapshot.id) { $errors += "Missing: id" }
    if (-not $s.snapshot.created) { $errors += "Missing: created" }
    if (-not $s.snapshot.windows) { $errors += "Missing: windows" }
    if ($s.snapshot.windows.Count -eq 0) { $warnings += "No windows captured" }
    foreach ($w in $s.snapshot.windows) {
        if (-not $w.process.name) { $errors += "Window $($w.id): missing name" }
        if ($null -eq $w.monitor) { $warnings += "Window $($w.id): monitor null" }
    }
    return @{ isValid = ($errors.Count -eq 0); errors = $errors; warnings = $warnings }
}

function Save-ATA {
    param(
        [ValidateSet('shutdown','auto','manual')]
        [string]$Type = 'manual',
        [string]$OutputPath
    )
    $timestamp = Get-Date
    $snapshotId = "ata-" + $timestamp.ToString("yyyyMMdd-HHmmss")
    if (-not $OutputPath) {
        $snapshotDir = "$env:APPDATA\ATA\snapshots"
        if (-not (Test-Path $snapshotDir)) { New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null }
        $OutputPath = "$snapshotDir\$snapshotId.json"
    }
    Write-Host "`nEnumerating windows..." -ForegroundColor Cyan
    $windows = Get-ATAWindows
    Write-Host "   Found $($windows.Count) visible app windows."
    Write-Host "Detecting monitors..." -ForegroundColor Cyan
    $monitors = Get-MonitorInfo
    Resolve-WindowMonitors -Windows $windows -Monitors $monitors
    Write-Host "   $($monitors.Count) monitor(s)."
    Write-Host "Detecting focused window..." -ForegroundColor Cyan
    Mark-FocusedWindow -Windows $windows
    # File Explorer 文件夹窗口
    Write-Host "📁 Detecting Explorer windows..." -ForegroundColor Cyan
    $explorerWindows = Get-ExplorerWindows
    Write-Host "   Found $($explorerWindows.Count) folder window(s)."
    foreach ($ew in $explorerWindows) {
        $windowId++
        $windows += @{
            id = "w-$($windowId.ToString('000'))"
            process = @{ name = "explorer"; pid = 0; commandLine = $null; executablePath = "C:\Windows\explorer.exe" }
            title = $ew.title
            class = "CabinetWClass"
            bounds = @{ x = 0; y = 0; width = 800; height = 600 }
            state = "normal"; monitor = 0; virtualDesktop = $null; zOrder = $windowId
            hadFocus = $false; restorable = $true; platform = "win32"
            adapter = "explorer"; appState = @{ folderPath = $ew.path }
            eventContext = $null; restoreHooks = $null
        }
    }
    $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
    $snapData = @{
        id = $snapshotId
        created = $timestamp.ToString("yyyy-MM-ddTHH:mm:sszzz")
        type = $Type
        hostname = $env:COMPUTERNAME
        anaDailyNote = $null
        environment = @{
            os = $osInfo
            monitors = $monitors
            virtualDesktops = @(@{ index = 0; name = "Desktop 1" })
        }
        windows = $windows
        config = @{
            restoreOrder = "zOrder"
            launchDelay = 1500
            skipMissing = $true
            openAnaDailyNote = $false
        }
        event = $null
        ecosystem = $null
        deepseek = $null
    }
    $snapshot = @{ version = "1.0.0"; snapshot = $snapData }
    $json = $snapshot | ConvertTo-Json -Depth 10
    Set-Content -Path $OutputPath -Value $json -Encoding UTF8
    Write-Host "`nSnapshot saved: $snapshotId" -ForegroundColor Green
    Write-Host "   Path: $OutputPath" -ForegroundColor Gray
    Write-Host "   Windows: $($windows.Count) | Type: $Type" -ForegroundColor Gray
    $check = Test-ATASnapshot -SnapshotPath $OutputPath
    if ($check.isValid) { Write-Host "   Integrity: PASS" -ForegroundColor Green }
    else { Write-Host "   Integrity: FAIL" -ForegroundColor Red }
    return $OutputPath
}



