# AnaBridge.ps1 鈥?ANA 鈫?ATA 妗ユ帴
# 闀滃ご 025锛氫繚瀛樻椂鍐?Obsidian 鏃ヨ 路 鎭㈠鏃舵墦寮€ Obsidian 瀵瑰簲鏃ヨ

. "$PSScriptRoot\Snapshot.ps1"

# ============================================================
# ANA 閰嶇疆璇诲彇
# ============================================================
function Get-ANAConfig {
    $configPath = "$env:APPDATA\ATA\config.json"
    if (-not (Test-Path $configPath)) { return $null }
    $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
    return $cfg.ana
}

# ============================================================
# 淇濆瓨鏃讹細ATA 鈫?Obsidian 鏃ヨ
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

    # 璇诲彇蹇収
    $data = Get-Content $SnapshotPath -Raw | ConvertFrom-Json
    $s = $data.snapshot
    $date = [DateTime]::Parse($s.created).ToString("yyyy-MM-dd")
    $noteDir = Join-Path $vaultPath $dailyFolder
    $notePath = Join-Path $noteDir "$date.md"

    # 纭繚鐩綍瀛樺湪
    if (-not (Test-Path $noteDir)) {
        New-Item -ItemType Directory -Path $noteDir -Force | Out-Null
    }

    # 鐢熸垚 Markdown
    $markdown = @"
---
date: $date
ata_snapshot: $($s.id)
type: $($s.type)
---

# $date 宸ヤ綔鐜板満蹇収

> ATA 鑷姩淇濆瓨 路 $($s.created) 路 $($s.windows.Count) apps 路 $($s.environment.monitors.Count) monitors

## 鎵撳紑鐨勫簲鐢?
| # | 搴旂敤 | 鐘舵€?|
|---|------|------|
"@

    foreach ($w in $s.windows) {
        $icon = if ($w.hadFocus) { "馃幆" } else { "" }
        $title = $w.title
        if ($title.Length -gt 40) { $title = $title.Substring(0, 40) + "..." }
        $markdown += "`n| $icon $($w.process.name) | $title | $($w.state) |"
    }

    $markdown += "`n`n## 宸ヤ綔涓婁笅鏂嘸n"

    # 宸ヤ綔鐩綍鎺ㄦ祴
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
        $markdown += "`n### 宸ヤ綔鐩綍`n"
        foreach ($dir in $workDirs.Keys) {
            $markdown += "- **$dir** 鈥?$($workDirs[$dir] -join ', ')`n"
        }
    }

    # DeepSeek 娲炲療
    if ($DeepSeekInsight) {
        $markdown += "`n## DeepSeek 娲炲療`n"
        $markdown += "`n> $DeepSeekInsight`n"
    }

    $markdown += "`n## 鎭㈠`n"
    $markdown += "`n``````powershell`nata restore $($s.id)`n```````n"

    $markdown += "`n---`n*姝ょ瑪璁扮敱 ATA 鑷姩鐢熸垚銆?`n"

    # 鍐欏叆
    if (Test-Path $notePath) {
        $existing = Get-Content $notePath -Raw
        # 杩藉姞鍒板凡鏈夋棩璁版湯灏?        $markdown = "`n`n---`n`n$markdown"
        Add-Content -Path $notePath -Value $markdown -Encoding UTF8
    } else {
        Set-Content -Path $notePath -Value $markdown -Encoding UTF8
    }

    Write-Host "ANA daily note updated: $notePath" -ForegroundColor Magenta
}

# ============================================================
# 鎭㈠鏃讹細ATA 鈫?鎵撳紑 Obsidian 鏃ヨ
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

    # 鐢?Obsidian URI 鎵撳紑
    $vaultName = Split-Path $vault -Leaf
    $obsidianUri = "obsidian://open?vault=" + [uri]::EscapeDataString($vaultName) + `
        "&file=" + [uri]::EscapeDataString("$dailyFolder/$Date.md")

    Write-Host "Opening ANA daily note: $Date" -ForegroundColor Magenta
    Start-Process $obsidianUri
}

# ============================================================
# 澧炲己鐗?Save-ATA锛氬甫 ANA 妗ユ帴 + DeepSeek 娲炲療
# ============================================================
function Save-ATA-Full {
    param(
        [ValidateSet('shutdown', 'auto', 'manual')]
        [string]$Type = 'manual'
    )

    # 1. 淇濆瓨蹇収
    $path = Save-ATA -Type $Type

    # 2. DeepSeek 鍗虫椂娲炲療
    $insight = $null
    $cfg = Get-Content "$env:APPDATA\ATA\config.json" -Raw | ConvertFrom-Json
    if ($cfg.deepseek.enabled) {
        $insight = Get-ATAInsight -Level instant -SnapshotPath $path
    }

    # 3. 鍐?ANA 鏃ヨ
    $anaCfg = Get-ANAConfig
    if ($anaCfg -and $anaCfg.enabled -and $anaCfg.autoWriteOnSave) {
        if ($Type -eq "shutdown" -or ($anaCfg.saveTriggers -contains "manual" -and $Type -eq "manual")) {
            Write-ANADailyNote -SnapshotPath $path -DeepSeekInsight $insight
        }
    }

    return $path
}

