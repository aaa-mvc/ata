# AnaBridge.ps1 — ANA ↔ ATA 桥接
# 镜头 025：保存时写 Obsidian 日记 · 恢复时打开 Obsidian 对应日记

. "$PSScriptRoot\Snapshot.ps1"

# ============================================================
# ANA 配置读取
# ============================================================
function Get-ANAConfig {
    $configPath = "$env:APPDATA\ATA\config.json"
    if (-not (Test-Path $configPath)) { return $null }
    $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
    return $cfg.ana
}

# ============================================================
# 保存时：ATA → Obsidian 日记
# ============================================================
function Write-ANADailyNote {
    param(
        [string]$SnapshotPath,
        [string]$DeepSeekInsight
    )

    $anaCfg = Get-ANAConfig
    if (-not $anaCfg -or -not $anaCfg.enabled) {
        Write-Verbose "ANA bridge not enabled."
        return
    }

    $vaultPath = $anaCfg.obsidianVaultPath
    if ([string]::IsNullOrWhiteSpace($vaultPath)) {
        Write-Verbose "ANA vault path not configured."
        return
    }

    $dailyFolder = $anaCfg.dailyNoteFolder
    if ([string]::IsNullOrWhiteSpace($dailyFolder)) {
        $dailyFolder = "daily"
    }

    # 读取快照
    $data = Get-Content $SnapshotPath -Raw | ConvertFrom-Json
    $s = $data.snapshot
    $date = [DateTime]::Parse($s.created).ToString("yyyy-MM-dd")
    $noteDir = Join-Path $vaultPath $dailyFolder
    $notePath = Join-Path $noteDir "$date.md"

    # 确保目录存在
    if (-not (Test-Path $noteDir)) {
        New-Item -ItemType Directory -Path $noteDir -Force | Out-Null
    }

    # 生成 Markdown
    $markdown = @"
---
date: $date
ata_snapshot: $($s.id)
type: $($s.type)
---

# $date 工作现场快照

> ATA 自动保存 · $($s.created) · $($s.windows.Count) apps · $($s.environment.monitors.Count) monitors

## 打开的应用

| # | 应用 | 状态 |
|---|------|------|
"@

    foreach ($w in $s.windows) {
        $icon = if ($w.hadFocus) { "🎯" } else { "" }
        $title = $w.title
        if ($title.Length -gt 40) { $title = $title.Substring(0, 40) + "..." }
        $markdown += "`n| $icon $($w.process.name) | $title | $($w.state) |"
    }

    $markdown += "`n`n## 工作上下文`n"

    # 工作目录推测
    $workDirs = @{}
    foreach ($w in $s.windows) {
        $cl = $w.process.commandLine
        if ($cl -and $cl -match '([A-Z]:\\[^ ";]+)\\') {
            $dir = $matches[1]
            if (-not $workDirs.ContainsKey($dir)) { $workDirs[$dir] = @() }
            $workDirs[$dir] += $w.process.name
        }
    }
    if ($workDirs.Count -gt 0) {
        $markdown += "`n### 工作目录`n"
        foreach ($dir in $workDirs.Keys) {
            $markdown += "- **$dir** — $($workDirs[$dir] -join ', ')`n"
        }
    }

    # DeepSeek 洞察
    if ($DeepSeekInsight) {
        $markdown += "`n## DeepSeek 洞察`n"
        $markdown += "`n> $DeepSeekInsight`n"
    }

    $markdown += "`n## 恢复`n"
    $markdown += "`n``````powershell`nata restore $($s.id)`n```````n"

    $markdown += "`n---`n*此笔记由 ATA 自动生成。*`n"

    # 写入
    if (Test-Path $notePath) {
        $existing = Get-Content $notePath -Raw
        # 追加到已有日记末尾
        $markdown = "`n`n---`n`n$markdown"
        Add-Content -Path $notePath -Value $markdown -Encoding UTF8
    } else {
        Set-Content -Path $notePath -Value $markdown -Encoding UTF8
    }

    Write-Host "ANA daily note updated: $notePath" -ForegroundColor Magenta
}

# ============================================================
# 恢复时：ATA → 打开 Obsidian 日记
# ============================================================
function Open-ANADailyNote {
    param(
        [string]$Date = (Get-Date).ToString("yyyy-MM-dd")
    )

    $anaCfg = Get-ANAConfig
    if (-not $anaCfg -or -not $anaCfg.enabled -or -not $anaCfg.autoOpenOnRestore) {
        return
    }

    $vault = $anaCfg.obsidianVaultPath
    if ([string]::IsNullOrWhiteSpace($vault)) { return }

    $dailyFolder = $anaCfg.dailyNoteFolder
    if ([string]::IsNullOrWhiteSpace($dailyFolder)) { $dailyFolder = "daily" }

    $notePath = Join-Path $vault $dailyFolder "$Date.md"

    # 用 Obsidian URI 打开
    $vaultName = Split-Path $vault -Leaf
    $obsidianUri = "obsidian://open?vault=" + [uri]::EscapeDataString($vaultName) + `
        "&file=" + [uri]::EscapeDataString("$dailyFolder/$Date.md")

    Write-Host "Opening ANA daily note: $Date" -ForegroundColor Magenta
    Start-Process $obsidianUri
}

# ============================================================
# 增强版 Save-ATA：带 ANA 桥接 + DeepSeek 洞察
# ============================================================
function Save-ATA-Full {
    param(
        [ValidateSet('shutdown', 'auto', 'manual')]
        [string]$Type = 'manual'
    )

    # 1. 保存快照
    $path = Save-ATA -Type $Type

    # 2. DeepSeek 即时洞察
    $insight = $null
    $cfg = Get-Content "$env:APPDATA\ATA\config.json" -Raw | ConvertFrom-Json
    if ($cfg.deepseek.enabled) {
        $insight = Get-ATAInsight -Level instant -SnapshotPath $path
    }

    # 3. 写 ANA 日记
    $anaCfg = Get-ANAConfig
    if ($anaCfg -and $anaCfg.enabled -and $anaCfg.autoWriteOnSave) {
        if ($Type -eq "shutdown" -or ($anaCfg.saveTriggers -contains "manual" -and $Type -eq "manual")) {
            Write-ANADailyNote -SnapshotPath $path -DeepSeekInsight $insight
        }
    }

    return $path
}
