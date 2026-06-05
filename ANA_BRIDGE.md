# ANA ↔ ATA 桥接设计

> ANA 守护思维状态，ATA 守护数字状态。两者通过桥接层互通，构成完整的"昨日恢复"系统。

---

## 一、两个项目的关系

```
ANA (Obsidian)                          ATA (Windows OS)
─────────────                          ────────────────
每日定时回顾提醒                        关机 / 定时触发快照
WeeklyManifesto 回顾本周思维路径         每周工作模式分析报告
Obsidian 日记记录"在想什么"              JSON 快照记录"在看什么"
obsidian:// URI 触发                    PowerShell CLI 触发
```

**核心洞察**：一个重度用户的工作状态 = 思维状态 × 数字状态。单独恢复一个维度只是半成品。

---

## 二、桥接架构

```
┌─────────────────────────────────────────────────────────┐
│                    ATA 快照引擎                          │
│                                                         │
│  ata save ──→ JSON 快照 ──→ ANA Bridge ──→ Obsidian 日记│
│                    │                    │               │
│                    ↓                    ↓               │
│              DeepSeek 分析         WeeklyManifesto      │
│                    │                    │               │
│                    ↓                    ↓               │
│  ata restore ←── JSON 快照 ←── Obsidian 打开对应日记    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 三、保存流程：ATA → ANA

### 3.1 触发时机

| 场景 | ATA 动作 | ANA 桥接动作 |
|---|---|---|
| 关机保存 | `ata save --type shutdown` | 写 Obsidian 日记 + 更新 WeeklyManifesto 草稿 |
| 定时保存 | `ata save --type auto`（每 30 分钟） | 静默，不写日记 |
| 手动保存 | `ata save --type manual` | 写 Obsidian 日记（可选） |

### 3.2 生成的 Obsidian 日记模板

```markdown
---
date: {{date}}
ata_snapshot: {{snapshot_id}}
type: {{save_type}}
---

# {{date}} 工作现场快照

> 🔗 ATA 快照：`{{snapshot_id}}`
> 🕐 保存时间：{{timestamp}}
> 📊 打开应用：{{window_count}} 个 · 显示器：{{monitor_count}} 个

## 🖥️ 打开的应用

| 应用 | 窗口标题 | 桌面 |
|------|---------|------|
{{#windows}}
| {{process_name}} | {{title}} | VD{{virtual_desktop}} |
{{/windows}}

## 🗂️ 工作上下文

{{#adapters}}
### {{app_name}}
{{#app_state}}
- 工作区：{{workspace_path}}
- 活动文件：{{active_file}}
- 打开的标签页：{{tab_count}} 个
{{/app_state}}
{{/adapters}}

## 🧠 DeepSeek 洞察

> {{insight_summary}}

## 📝 今日笔记

（在此记录今天的思考、决策、待办）

---

## 🔄 明日恢复

要恢复到此刻的工作现场，在终端执行：
\`\`\`powershell
ata restore {{snapshot_id}}
\`\`\`
```

### 3.3 PowerShell 实现

```powershell
function Write-ANADailyNote {
    param(
        [string]$SnapshotPath,
        [string]$ObsidianVault = "Obsidian Vault",
        [string]$DailyNotePath = "daily/"
    )

    $snapshot = Get-Content $SnapshotPath | ConvertFrom-Json
    $date = [DateTime]::Parse($snapshot.snapshot.created).ToString("yyyy-MM-dd")
    $notePath = "$env:USERPROFILE\Documents\$ObsidianVault\$DailyNotePath$date.md"

    # 生成 Markdown
    $markdown = @"
---
date: $date
ata_snapshot: $($snapshot.snapshot.id)
type: $($snapshot.snapshot.type)
---

# $date 工作现场快照

> 🔗 ATA 快照：`$($snapshot.snapshot.id)`
> 🕐 保存时间：$($snapshot.snapshot.created)
> 📊 打开应用：$($snapshot.snapshot.windows.Count) 个

## 🖥️ 打开的应用

| 应用 | 窗口标题 |
|------|---------|
"@

    foreach ($window in $snapshot.snapshot.windows) {
        $markdown += "`n| $($window.process.name) | $($window.title) |"
    }

    $markdown += @"

## 📝 今日笔记

（在此记录今天的思考、决策、待办）
"@

    # 确保目录存在
    $noteDir = Split-Path $notePath -Parent
    if (-not (Test-Path $noteDir)) {
        New-Item -ItemType Directory -Force -Path $noteDir
    }

    # 如果日记已存在，追加 ATA 区块（不覆盖）
    if (Test-Path $notePath) {
        $existing = Get-Content $notePath -Raw
        if ($existing -notmatch "ATA 快照") {
            $markdown = $existing + "`n`n---`n`n" + $markdown
        }
    }

    Set-Content -Path $notePath -Value $markdown -Encoding UTF8
    Write-Host "📝 ANA daily note written: $notePath"
}
```

---

## 四、恢复流程：ATA ← ANA

### 4.1 恢复时自动打开 Obsidian

```powershell
function Open-ANADailyNote {
    param(
        [string]$Date = (Get-Date).ToString("yyyy-MM-dd"),
        [string]$ObsidianVault = "Obsidian Vault",
        [string]$DailyNotePath = "daily/"
    )

    $encodedVault = [uri]::EscapeDataString($ObsidianVault)
    $encodedFile = [uri]::EscapeDataString("$DailyNotePath$Date.md")
    $uri = "obsidian://open?vault=$encodedVault&file=$encodedFile"

    Start-Process $uri
    Write-Host "🧠 ANA daily note opened: $Date"
}
```

### 4.2 恢复后的完整流程

```
ata restore → 启动应用 → 窗口归位 → 打开 Obsidian 对应日记 → 显示恢复报告
                                                                    │
                                                    "成功恢复 12/14 个窗口。
                                                     已打开 2026-06-06 工作日记。
                                                     DeepSeek 发现你今天少开了 Figma。"
```

---

## 五、WeeklyManifesto 同步

### 5.1 ANA 的 WeeklyManifesto

ANA 的 WeeklyManifesto 是手动维护的，记录本周的思维路径和关键决策。路径：
```
obsidian://open?vault=Obsidian%20Vault&file=_Ana%2FWeeklyManifesto
```

### 5.2 ATA 的每周报告

ATA 每周日晚自动生成工作模式报告，可以作为 WeeklyManifesto 的"数据附录"：

```markdown
## 📊 ATA 本周数据（自动生成 · W23）

| 指标 | 数值 |
|------|------|
| 快照数 | 42 次 |
| 日均窗口 | 13.5 个 |
| 高频应用 | VS Code (98%), Chrome (95%), Terminal (88%) |
| 平均开机恢复时间 | 47 秒 |
| 最长工作时段 | 6月5日 09:00-23:15 (14h15m) |

### 🤖 DeepSeek 洞察
> 本周工作模式稳定，Dev 桌面工作日活跃，Web 桌面集中在下班后。
> 周五新增了 DataGrip，可能是新项目的数据分析需求。
> 建议：如果要保持 VS Code + Chrome 的 30+ 标签页习惯，考虑用 Workspace 分组管理。
```

### 5.3 同步机制

```powershell
function Update-WeeklyManifesto {
    param(
        [string]$WeekNumber = (Get-Date -UFormat "%V"),
        [string]$ObsidianVault = "Obsidian Vault"
    )

    $manifestoPath = "$env:USERPROFILE\Documents\$ObsidianVault\_Ana\WeeklyManifesto.md"
    $weeklyReport = Get-ATAWeeklyReport -Week $WeekNumber

    # 在 WeeklyManifesto 末尾追加 ATA 数据区块
    $appendix = Generate-WeeklyAppendix -Report $weeklyReport

    if (Test-Path $manifestoPath) {
        $existing = Get-Content $manifestoPath -Raw
        # 替换已有的 ATA 区块（如果有的话），否则追加
        if ($existing -match "## 📊 ATA 本周数据") {
            $existing = $existing -replace "(?s)## 📊 ATA 本周数据.*", $appendix
        } else {
            $existing += "`n`n$appendix"
        }
        Set-Content -Path $manifestoPath -Value $existing -Encoding UTF8
    }
}
```

---

## 六、用户故事：一天的生活

```
08:55  开机
09:00  ATA 对话框弹出："检测到昨晚 23:15 的快照 (14 apps)。恢复？"
09:00  → 点 [Restore]
09:01  窗口逐个恢复：VS Code → Chrome → Terminal → Obsidian...
09:02  恢复完成。Obsidian 自动打开 2026-06-06.md 日记
09:03  日记顶部写着："昨天光标停在 PROJECT_STATEMENT.md L342"
09:03  打开 VS Code → 确实停在那一行，继续写
09:05  ATA 通知："DeepSeek 发现你今天恢复了昨天 12/14 个窗口。
        Figma 未恢复（设计稿路径已变更），Notion 需要重新登录。"

12:30  午休。ATA 定时保存了上午的状态。

18:00  ATA 定时保存下午的状态。

23:15  关机。ATA 自动保存 + 写 Obsidian 日记 + 更新 WeeklyManifesto。
        终端显示：
        ✅ Snapshot saved: ata-20260606-231500 (14 windows, 2 monitors)
        📝 ANA daily note written
        🤖 DeepSeek 洞察已生成
        🔗 obsidian://open?vault=Obsidian%20Vault&file=daily%2F2026-06-06.md
```

---

## 七、配置文件

```json
// %APPDATA%\ATA\config.json
{
  "ana": {
    "enabled": true,
    "obsidianVaultPath": "C:\\Users\\Hi\\Documents\\Obsidian Vault",
    "dailyNoteFolder": "daily/",
    "weeklyManifestoPath": "_Ana/WeeklyManifesto.md",
    "autoWriteOnSave": true,
    "autoOpenOnRestore": true,
    "saveTriggers": ["shutdown", "manual"],
    "skipAutoTriggers": true
  }
}
```

---

*ANA 和 ATA 是同一个问题的两个解。一个向内，一个向外。*
