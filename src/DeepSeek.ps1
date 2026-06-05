# DeepSeek.ps1 — AI 洞察引擎
# 镜头 021-022：DeepSeek API 连接 · 即时/每日/每周三层分析
# 隐私设计：只发送应用名和计数，绝不发送窗口标题、文件路径

. "$PSScriptRoot\Snapshot.ps1"
. "$PSScriptRoot\Restore.ps1"

$script:ATA_SYSTEM_PROMPT = "你是 ATA 工作状态分析助手。你的角色是帮助用户理解自己的数字工作模式。原则：1. 简洁——即时分析不超过2句，每日简报不超过5句。2. 有用——提供可操作的观察。3. 诚实——不确定的就说可能是。4. 中文——始终用中文回复。5. 非侵入——你只是观察和建议，不是评判。"

function Invoke-DeepSeekAPI {
    param([string]$SystemPrompt, [string]$UserPrompt, [int]$MaxTokens = 500, [double]$Temperature = 0.3)

    $configPath = "$env:APPDATA\ATA\config.json"
    if (-not (Test-Path $configPath)) { return $null }

    $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
    $ds = $cfg.deepseek
    if (-not $ds.enabled) { return $null }

    $apiKey = $ds.apiKey
    if ($apiKey -eq '${DEEPSEEK_API_KEY}' -or [string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = $env:DEEPSEEK_API_KEY
    }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $ecoConfig = "$env:APPDATA\Ecosystem\config.json"
        if (Test-Path $ecoConfig) {
            try { $eco = Get-Content $ecoConfig -Raw | ConvertFrom-Json; $apiKey = $eco.deepseek.apiKey } catch { }
        }
    }
    if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -match '\$\{') { return $null }

    $body = @{
        model = $ds.model
        messages = @(@{role="system";content=$SystemPrompt}, @{role="user";content=$UserPrompt})
        max_tokens = $MaxTokens
        temperature = $Temperature
    } | ConvertTo-Json -Depth 4 -Compress

    try {
        $response = Invoke-RestMethod -Uri $ds.endpoint -Method Post `
            -Headers @{"Content-Type"="application/json"; "Authorization"="Bearer $apiKey"} `
            -Body $body -TimeoutSec 30
        return $response.choices[0].message.content
    } catch {
        Write-Verbose "DeepSeek API: $_"
        return $null
    }
}

function Get-ATAInsight {
    param([ValidateSet('instant','daily','weekly')][string]$Level='instant', [string]$SnapshotPath)

    if (-not $SnapshotPath) { $SnapshotPath = Get-LatestSnapshot }
    if (-not $SnapshotPath) { return $null }

    $data = Get-Content $SnapshotPath -Raw | ConvertFrom-Json
    $s = $data.snapshot
    $apps = $s.windows | ForEach-Object { $_.process.name } | Sort-Object -Unique
    $appSummary = ($apps -join ", ")
    $wc = $s.windows.Count
    $mc = $s.environment.monitors.Count

    if ($Level -eq 'instant') {
        $prompt = "当前快照：$wc 个窗口，$mc 个显示器。应用：$appSummary。快照类型：$($s.type)。请用1-2句中文总结用户当前的工作状态。"
        $result = Invoke-DeepSeekAPI -SystemPrompt $script:ATA_SYSTEM_PROMPT -UserPrompt $prompt -MaxTokens 200 -Temperature 0.2
        if ($result) { Write-Host "`n🤖 DeepSeek: $result" -ForegroundColor Cyan }
        return $result
    }

    if ($Level -eq 'daily') {
        $yesterday = (Get-Date).AddDays(-1).ToString("yyyyMMdd")
        $ySnap = Resolve-ATASnapshot -Date $yesterday
        $diffInfo = ""
        if ($ySnap) {
            $yd = Get-Content $ySnap -Raw | ConvertFrom-Json
            $yApps = $yd.snapshot.windows | ForEach-Object { $_.process.name } | Sort-Object -Unique
            $newA = $apps | Where-Object { $_ -notin $yApps }
            $oldA = $yApps | Where-Object { $_ -notin $apps }
            if (@($newA).Count -gt 0) { $diffInfo = "新增：$($newA -join ', ')。" }
            if (@($oldA).Count -gt 0) { $diffInfo += "关闭：$($oldA -join ', ')。" }
        }
        $prompt = "今日快照：$wc 个窗口，$mc 个显示器。应用：$appSummary。$diffInfo 请提供3-5句中文每日简报：今天的工作状态观察、与昨天相比的变化、一条轻量的优化建议。"
        $result = Invoke-DeepSeekAPI -SystemPrompt $script:ATA_SYSTEM_PROMPT -UserPrompt $prompt -MaxTokens 400 -Temperature 0.3
        if ($result) { Write-Host "`n🤖 DeepSeek 每日简报: $result" -ForegroundColor Cyan }
        return $result
    }

    if ($Level -eq 'weekly') {
        $weekSnaps = @(Get-ATASnapshots -Last 50)
        if ($weekSnaps.Count -eq 0) { return $null }
        $dailyCounts = @(); $allApps = @{}
        foreach ($sf in $weekSnaps) {
            try {
                $sd = Get-Content $sf.FullName -Raw | ConvertFrom-Json
                $dailyCounts += $sd.snapshot.windows.Count
                foreach ($w in $sd.snapshot.windows) {
                    $n = $w.process.name
                    if (-not $allApps.ContainsKey($n)) { $allApps[$n] = 0 }
                    $allApps[$n]++
                }
            } catch { }
        }
        $avgW = if ($dailyCounts.Count -gt 0) { [math]::Round(($dailyCounts | Measure-Object -Average).Average, 0) } else { 0 }
        $top = ($allApps.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object { "$($_.Key)($($_.Value)次)" }) -join ", "
        $prompt = "本周快照统计：$($weekSnaps.Count)次保存。日均窗口：$avgW个。高频应用Top5：$top。请生成本周工作模式简报（中文，3-5句）：本周工作节奏总结、最值得注意的趋势、一条下周可操作的优化建议。"
        $result = Invoke-DeepSeekAPI -SystemPrompt $script:ATA_SYSTEM_PROMPT -UserPrompt $prompt -MaxTokens 500 -Temperature 0.3
        if ($result) { Write-Host "`n🤖 DeepSeek 每周: $result" -ForegroundColor Cyan }
        return $result
    }
    return $null
}

function Compare-ATASnapshots {
    param([string]$SnapshotPath1, [string]$SnapshotPath2)
    if (-not $SnapshotPath1 -or -not (Test-Path $SnapshotPath1)) { Write-Error "Snapshot 1 not found."; return }
    if (-not $SnapshotPath2 -or -not (Test-Path $SnapshotPath2)) { Write-Error "Snapshot 2 not found."; return }
    $s1 = (Get-Content $SnapshotPath1 -Raw | ConvertFrom-Json).snapshot
    $s2 = (Get-Content $SnapshotPath2 -Raw | ConvertFrom-Json).snapshot
    $apps1 = $s1.windows | ForEach-Object { $_.process.name } | Sort-Object -Unique
    $apps2 = $s2.windows | ForEach-Object { $_.process.name } | Sort-Object -Unique
    $added = @($apps2 | Where-Object { $_ -notin $apps1 })
    $removed = @($apps1 | Where-Object { $_ -notin $apps2 })
    $same = @($apps1 | Where-Object { $_ -in $apps2 })
    Write-Host "`n📊 Diff: $($s1.id) → $($s2.id)" -ForegroundColor Cyan
    Write-Host "   Windows: $($s1.windows.Count) → $($s2.windows.Count)"
    if ($added.Count -gt 0) { Write-Host "   + Added: $($added -join ', ')" -ForegroundColor Green }
    if ($removed.Count -gt 0) { Write-Host "   - Removed: $($removed -join ', ')" -ForegroundColor Red }
    Write-Host "   = Common: $($same.Count) apps" -ForegroundColor Gray
    return @{from=$s1.id; to=$s2.id; added=$added; removed=$removed; same=$same}
}

