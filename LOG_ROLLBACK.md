# 日志与回滚系统设计

> 日志是"记得发生过什么"，回滚是"回到那个时刻"。
> 两者加起来，让 ATA 从"一键恢复最近"升级到"在时间轴上自由穿梭"。

---

## 一、日志系统架构

### 1.1 三类日志

```
%APPDATA%\ATA\logs\
├── ata.log                    ← 运行日志（append-only，结构化文本）
├── diff-{date}.md             ← DeepSeek 生成的快照差异分析
├── weekly-{week}.md           ← 每周工作报告
└── insights\
    ├── daily-{date}.json      ← 每日洞察缓存
    └── weekly-{week}.json     ← 每周洞察缓存
```

### 1.2 运行日志格式

```
[TIMESTAMP] [LEVEL] [ACTION] [DETAILS]

[TIMESTAMP]   ISO 8601，精确到秒，带时区
[LEVEL]       INFO | WARN | ERROR | INSIGHT
[ACTION]      SAVE | RESTORE | ROLLBACK | CLEAN | INSIGHT | CONFIG
[DETAILS]     key=value 键值对，空格分隔
```

**示例**：

```
[2026-06-06T23:15:00+08:00] INFO    SAVE     snapshot=ata-20260606-231500 type=shutdown windows=14 monitors=2 adapters=3
[2026-06-06T23:15:01+08:00] INFO    INSIGHT  level=instant prev=ata-20260606-180000 curr=ata-20260606-231500 changes=+1/-1
[2026-06-06T18:00:00+08:00] INFO    SAVE     snapshot=ata-20260606-180000 type=auto windows=12 monitors=2 adapters=2
[2026-06-06T09:05:00+08:00] INFO    RESTORE  snapshot=ata-20260605-224500 success=12/14 failed=2
[2026-06-06T09:05:01+08:00] WARN    RESTORE  window=Figma error="file_path_not_found" action=skipped
[2026-06-06T09:05:01+08:00] WARN    RESTORE  window=Notion error="reauth_required" action=skipped
[2026-06-06T09:05:02+08:00] INFO    INSIGHT  level=daily date=2026-06-06
[2026-06-05T22:45:00+08:00] INFO    SAVE     snapshot=ata-20260605-224500 type=shutdown windows=14 monitors=2 adapters=3
```

### 1.3 日志轮转

```powershell
# 自动清理策略
ata clean --logs --older-than 30d       # 删除 30 天前的日志
ata clean --snapshots --keep-last 14    # 只保留最近 14 个快照
ata clean --all --older-than 90d        # 清理所有 90 天前的数据
```

---

## 二、回滚系统设计

### 2.1 回滚的概念

回滚 = 从当前状态，跳转到某个历史快照。

```
当前状态                    目标快照
────────                    ────────
2026-06-06 23:15       ←   2026-06-05 22:45
(14 个窗口)                 (14 个不同的窗口)
```

与"恢复最近快照"不同，回滚是**跨越多个快照的跳转**。中间可能隔了几天、几十次保存。

### 2.2 回滚命令

```powershell
# 基本回滚
ata restore 20260605                  # 回滚到 6月5日最后一次快照
ata restore 20260605-180000           # 回滚到 6月5日 18:00 的快照
ata restore --date 20260605           # 同上，显式指定日期

# 回滚前预览
ata restore 20260605 --dry-run        # 不实际执行，只打印"会做什么"
ata restore 20260605 --preview        # 显示快照内容摘要

# 回滚确认（跳过交互）
ata restore 20260605 --yes            # 跳过确认，直接执行

# 选择性回滚
ata restore 20260605 --only Code      # 只恢复 VS Code 的状态
ata restore 20260605 --exclude Chrome # 恢复除了 Chrome 以外的所有窗口
```

### 2.3 回滚执行流程

```
1. 用户执行：ata restore 20260605

2. 查找快照
   ├─ 扫描 %APPDATA%\ATA\snapshots\
   ├─ 找到匹配的快照文件
   └─ 如果同一天有多个快照 → 取最后一个（最近关机时的那份）

3. 差异分析
   ├─ 对比当前显示器配置 vs 快照中的显示器配置
   ├─ 对比当前运行的应用 vs 快照中的应用列表
   └─ 生成"回滚预览"

4. 显示预览
   ┌─────────────────────────────────────────────┐
   │  Restore to June 5, 22:45?                  │
   │                                             │
   │  Changes from current state:                │
   │    + DataGrip (new since snapshot)           │
   │    - Figma (was open then, not now)         │
   │  Monitors: 2 → 2 (same config)              │
   │  14 windows will be repositioned            │
   │                                             │
   │  [ Restore ]  [ Cancel ]                    │
   └─────────────────────────────────────────────┘

5. 执行回滚
   ├─ 关闭快照中不存在的当前窗口（可选，默认不关）
   ├─ 启动快照中记录的应用
   ├─ 窗口归位
   └─ 输出恢复报告

6. 记录日志
   [2026-06-07T10:00:00+08:00] INFO ROLLBACK target=ata-20260605-224500 success=13/14
```

### 2.4 回滚实现

```powershell
function Invoke-ATARollback {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,                  # 日期或快照 ID
        [switch]$DryRun,
        [switch]$Yes,
        [string[]]$Only,                  # 只恢复指定应用
        [string[]]$Exclude                # 排除指定应用
    )

    # 1. 解析目标快照
    $snapshot = Resolve-Snapshot -Target $Target
    if (-not $snapshot) {
        Write-Error "No snapshot found for target: $Target"
        return
    }

    # 2. 加载快照
    $data = Get-Content $snapshot.Path | ConvertFrom-Json

    # 3. 环境检测
    $currentMonitors = Get-MonitorInfo
    $monitorChanged = Compare-MonitorConfig `
        -Saved $data.snapshot.environment.monitors `
        -Current $currentMonitors

    # 4. 生成预览
    $preview = New-RollbackPreview `
        -Snapshot $data `
        -MonitorChanged $monitorChanged `
        -Only $Only `
        -Exclude $Exclude

    if ($DryRun) {
        Write-RollbackPreview $preview
        return
    }

    # 5. 确认
    if (-not $Yes) {
        Write-RollbackPreview $preview
        $confirm = Read-Host "Proceed with rollback? (y/N)"
        if ($confirm -ne 'y') {
            Write-Host "Rollback cancelled."
            return
        }
    }

    # 6. 执行
    $result = Start-Rollback `
        -Snapshot $data `
        -MonitorChanged $monitorChanged `
        -Only $Only `
        -Exclude $Exclude

    # 7. 记录日志
    Write-ATALog -Level INFO -Action ROLLBACK -Details @{
        target = $snapshot.Id
        success = "$($result.SuccessCount)/$($result.TotalCount)"
    }

    # 8. 输出报告
    Write-RestoreReport $result
}
```

---

## 三、日志查询

### 3.1 命令

```powershell
# 查看日志
ata log                              # 最近 20 条日志
ata log --tail 50                    # 最近 50 条
ata log --level WARN                 # 只看警告
ata log --action RESTORE             # 只看恢复操作
ata log --date 20260605              # 只看某一天的日志
ata log --date 20260601..20260607    # 看一个日期范围

# 查看快照列表
ata log --snapshots                  # 所有快照
ata log --snapshots --week 23        # 第 23 周的快照
ata log --snapshots --last 7         # 最近 7 天的快照

# 查看差异
ata log --diff 20260605              # 6月5日快照 vs 当前状态
ata log --diff 20260605 20260606     # 两个快照之间的差异
```

### 3.2 日志查询实现

```powershell
function Get-ATALog {
    param(
        [int]$Tail = 20,
        [string]$Level,
        [string]$Action,
        [string]$Date
    )

    $logPath = "$env:APPDATA\ATA\logs\ata.log"
    if (-not (Test-Path $logPath)) {
        Write-Host "No log file found."
        return
    }

    $lines = Get-Content $logPath

    # 按日期过滤
    if ($Date) {
        if ($Date -match "\.\.") {
            $range = $Date -split "\.\."
            $start = [DateTime]::ParseExact($range[0], "yyyyMMdd", $null)
            $end   = [DateTime]::ParseExact($range[1], "yyyyMMdd", $null)
            $lines = $lines | Where-Object {
                if ($_ -match '^\[(\d{4}-\d{2}-\d{2})') {
                    $lineDate = [DateTime]$matches[1]
                    $lineDate -ge $start -and $lineDate -le $end
                }
            }
        } else {
            $target = [DateTime]::ParseExact($Date, "yyyyMMdd", $null).ToString("yyyy-MM-dd")
            $lines = $lines | Where-Object { $_ -match "^\[$target" }
        }
    }

    # 按级别过滤
    if ($Level) {
        $lines = $lines | Where-Object { $_ -match "\[$Level\]" }
    }

    # 按动作过滤
    if ($Action) {
        $lines = $lines | Where-Object { $_ -match "\b$Action\b" }
    }

    # 取尾部
    $lines | Select-Object -Last $Tail
}
```

---

## 四、快照生命周期管理

### 4.1 自动清理策略

```json
// config.json
{
  "retention": {
    "keepAllDays": 7,           // 最近 7 天保留所有快照
    "keepDailyAfter": 30,       // 7-30 天，每天只保留最后一个
    "keepWeeklyAfter": 90,      // 30-90 天，每周只保留一个
    "deleteAfter": 365,         // 超过 365 天自动删除
    "minimumSnapshots": 14      // 无论如何至少保留 14 个快照
  }
}
```

### 4.2 清理命令

```powershell
ata clean                           # 按默认策略清理
ata clean --dry-run                 # 预览会删除什么
ata clean --older-than 30d          # 删除 30 天前的
ata clean --keep-last 14            # 只保留最近 14 个
ata clean --all                     # 删除所有（会二次确认）
```

### 4.3 快照大小估算

```
单个快照 ≈ 2-5 KB（JSON）
每天 10 次保存 × 365 天 = 3650 个快照 ≈ 15 MB
加日志 ≈ 20 MB / 年

结论：对磁盘的影响可以忽略不计。
```

---

## 五、回滚场景示例

### 场景 1：周一想恢复周五的状态

```
周一早上开机：
  1. ATA 弹出："检测到最近快照：周五 22:45。恢复？"
  2. 用户点 [Restore]
  3. ATA 检查：当前显示器 = 周五的显示器（同一工位）
  4. 14 个窗口恢复 → 开始工作
```

### 场景 2：出差带着笔记本，想恢复办公室的状态

```
笔记本开机（单屏 1920×1080）：
  1. ATA 弹出："检测到最近快照：昨天 23:15（2 屏 2560+1920）。恢复？"
  2. 用户点 [Restore]
  3. ATA 检测到显示器配置不匹配 → 自动坐标映射
  4. 窗口适配到单屏布局 → 开始工作
```

### 场景 3：三天前有个窗口打开了重要文件，不记得是哪个

```
  1. ata log --date 20260604 --snapshots
     → ata-20260604-224500 (14 windows)
  2. ata restore 20260604-224500 --dry-run
     → 预览显示所有窗口标题
  3. 找到了那个文件！但不恢复整个快照
  4. 手动打开那个文件
```

---

## 六、日志的"不可篡改"设计

对于关键操作（保存、恢复、回滚），日志采用 **append-only 模式**：

```
- 只追加，不修改，不删除（除自动清理外）
- 每次 SAVE/RESTORE/ROLLBACK 操作都留一条不可变记录
- 用于排查"为什么这次恢复失败了"的历史追溯
- 格式简单到可以用记事本 grep
```

**这不是区块链，不需要防篡改。append-only 就够了。**

---

*日志让你记得，回滚让你回去。ATA 是时间的编辑者。*
