# ATA — Atlas Time Archive

> **承载 · 秩序 · 守护**
>
> 源自 Atlas（阿特拉斯），泰坦神因反叛宙斯失败，被罚永远托举苍天。
> ATA 替用户托举整个数字工作世界——关机时天不塌，开机时一切归位。
>
> `A → T → A`：回文结构，正读反读皆同。昨天的状态 = 今天的起点。

---

## 一、一句话定义

**ATA 是一个 Windows 桌面会话时间胶囊。关机时一键保存完整工作现场，开机时一键恢复到昨天——不只是窗口摆在哪，更是你在做什么、在想什么。**

---

## 二、ATA 与 ANA：姐妹项目

ATA 有一个姐妹项目 **ANA**（基于 Obsidian 的每日定时回顾系统）。

```
ANA 守护的是"思维状态"     → 你昨天在想什么？  → obsidian://open?vault=Obsidian%20Vault&file=_Ana%2FWeeklyManifesto
ATA 守护的是"数字状态"     → 你昨天在看什么？  → ana restore 20260605
                    ↓
            两者结合 = 完整的"昨日恢复"系统
```

| 维度 | ANA（思维层） | ATA（数字层） |
|---|---|---|
| **平台** | Obsidian | Windows OS |
| **保存对象** | 笔记、思考、决策、WeeklyManifesto | 窗口、应用、桌面布局 |
| **触发方式** | 每日定时提醒 | 关机自动 / 定时 / 手动 |
| **恢复方式** | 打开 Obsidian 回顾 | 一键重启所有窗口 |
| **时间粒度** | 天 / 周 | 分钟（每次关机 / 每 30 分钟） |
| **核心隐喻** | 日记本 | 时间胶囊 |

**ATA 恢复工作现场的同时，自动打开 ANA 对应的每日笔记——你的屏幕和你的思维一起回到昨天。**

---

## 三、问题空间

### 3.1 用户痛点

> "我不是舍不得关机，我是舍不得丢掉现在这个工作状态。"

重度知识工作者普遍：
- 长时间不关机，用睡眠/休眠保留状态
- 关机后第二天要花 15-30 分钟重建工作上下文
- 不记得昨天关机前究竟打开了哪些窗口、停在了哪个文件

### 3.2 市场空白

| 现有工具 | 能做什么 | 不能做什么 |
|---|---|---|
| PersistentWindows | 保存窗口位置 | 不启动应用，不保存内部状态 |
| PowerToys Workspaces | 手动定义布局 | 不自动触发，不深入应用状态 |
| WinLayout | 一键保存布局 | 不管应用启动 |
| KDE ksmserver | Linux 下完整会话管理 | 仅 Linux |
| macOS Reopen Windows | 恢复上次窗口 | 不精确、不跨应用、不可回滚 |

**空白**：没有一个 Windows 工具能实现"保存 → 关机 → 开机 → 恢复 → 洞察"的完整闭环。

---

## 四、ATA 五层架构

```
┌──────────────────────────────────────────────────────┐
│  感官层    CLI 命令  │  开机对话框  │  Tray 托盘       │
│           ata save   │  ata restore │  ata insight    │
├──────────────────────────────────────────────────────┤
│  调度层    关机钩子  │  30min 定时保存  │  手动触发    │
├──────────────────────────────────────────────────────┤
│  洞察层    DeepSeek 分析引擎                          │
│           快照 diff │ 工作模式识别 │ 优化建议         │
├──────────────────────────────────────────────────────┤
│  核心层    快照管理  │  回滚引擎  │  ANA 桥接器       │
├──────────────────────────────────────────────────────┤
│  数据层    JSON 快照  │  日志系统  │  本地存储        │
└──────────────────────────────────────────────────────┘
```

**ATA 独有的两层（vs 之前讨论的 ana 项目）**：

| 层 | 功能 | 说明 |
|---|---|---|
| **洞察层** | DeepSeek AI 分析 | 比对快照差异、识别工作模式、生成每日简报 |
| **ANA 桥接** | Obsidian 集成 | 快照保存时自动写 Obsidian 日记，恢复时打开对应日记 |

---

## 五、核心数据模型：快照 + 日志

### 5.1 快照 JSON（Snapshots）

```json
{
  "version": "1.0.0",
  "snapshot": {
    "id": "ata-20260606-231500",
    "created": "2026-06-06T23:15:00+08:00",
    "type": "shutdown",
    "anaDailyNote": "2026-06-06.md",
    "environment": {
      "os": "Windows 11 Pro",
      "hostname": "DEV-MACHINE",
      "monitors": [
        { "index": 0, "bounds": { "x": 0, "y": 0, "w": 2560, "h": 1440 }, "dpi": 125, "primary": true }
      ],
      "virtualDesktops": [
        { "index": 0, "name": "Dev" },
        { "index": 1, "name": "Web" }
      ]
    },
    "windows": [
      {
        "id": "w-001",
        "process": { "name": "Code", "pid": 12345, "commandLine": "C:\\Program Files\\Microsoft VS Code\\Code.exe C:\\projects\\ata" },
        "title": "PROJECT_STATEMENT.md — ata",
        "class": "Chrome_WidgetWin_1",
        "bounds": { "x": 0, "y": 0, "w": 1280, "h": 1400 },
        "state": "maximized",
        "monitor": 0,
        "virtualDesktop": 0,
        "zOrder": 3,
        "hadFocus": true,
        "adapter": "vscode",
        "appState": {
          "workspacePath": "C:\\projects\\ata\\ata.code-workspace",
          "openFiles": ["PROJECT_STATEMENT.md", "ANA_BRIDGE.md"],
          "activeFile": "PROJECT_STATEMENT.md",
          "cursorLine": 342
        }
      }
    ],
    "config": {
      "restoreOrder": "zOrder",
      "launchDelay": 1500,
      "skipMissing": true,
      "openAnaDailyNote": true
    }
  }
}
```

### 5.2 日志系统（Log）

```
%APPDATA%\ATA\
├── snapshots\
│   ├── ata-20260606-231500.json      ← 每次快照
│   ├── ata-20260606-180000.json      ← 定时自动保存
│   └── ata-20260605-224500.json
├── logs\
│   ├── ata.log                        ← 运行日志（append-only）
│   ├── diff-20260606-231500.md        ← DeepSeek 生成的快照差异分析
│   └── weekly-2026-W23.md            ← 每周工作模式报告
├── insights\
│   ├── pattern-cache.json             ← DeepSeek 分析缓存
│   └── recommendations.md             ← 优化建议累积
└── config.json                        ← 用户配置
```

**日志格式（ata.log）**：

```
[2026-06-06T23:15:00+08:00] SAVE   snapshot=ata-20260606-231500 type=shutdown windows=14 monitors=2
[2026-06-06T18:00:00+08:00] SAVE   snapshot=ata-20260606-180000 type=auto      windows=12 monitors=2
[2026-06-06T09:05:00+08:00] RESTORE snapshot=ata-20260605-224500 success=12/14 failed=2 note="Figma path changed; Notion re-auth required"
[2026-06-06T09:05:00+08:00] INSIGHT diff=ata-20260605→ata-20260606 changes="+2 windows, -1 monitor" pattern="daily-rhythm"
[2026-06-05T22:45:00+08:00] SAVE   snapshot=ata-20260605-224500 type=shutdown windows=14 monitors=2
```

---

## 六、DeepSeek 洞察引擎

### 6.1 三层分析

| 层 | 触发时机 | 分析内容 | 输出 |
|---|---|---|---|
| **即时** | 每次保存 | 本次快照 vs 上次快照的窗口变化 | 简短 diff 摘要 |
| **每日** | 每天第一次恢复时 | 今天的工作场景 vs 昨天 | 每日简报 + ANA 日记条目 |
| **每周** | 每周日晚 | 本周工作模式、高频应用、最佳恢复时间 | WeeklyManifesto 更新 |

### 6.2 API 集成设计

```powershell
# DeepSeek insight 命令
ata insight                    # 查看最新洞察
ata insight --diff             # 对比最近两次快照的差异
ata insight --weekly           # 生成本周工作模式报告
ata insight --recommend        # 获取优化建议
```

### 6.3 DeepSeek Prompt 模板

**即时分析 Prompt**：
```
你是 ATA 的工作状态分析助手。以下是用户两次桌面快照的差异：

上次快照时间：{last_timestamp}
本次快照时间：{current_timestamp}
变化的窗口：{changed_windows}
新增的窗口：{new_windows}
关闭的窗口：{closed_windows}

请用 2-3 句中文总结用户工作状态的变化，语气简洁自然。
```

**每周分析 Prompt**：
```
以下是用户本周（{week_start} 至 {week_end}）的桌面快照数据：

快照总数：{snapshot_count}
日均窗口数：{avg_windows}
高频应用 Top 5：{top_apps}
工作时段分布：{time_distribution}
最多同时使用的显示器数：{max_monitors}

请生成一份"本周工作模式简报"，包含：
1. 本周工作节奏总结
2. 最常使用的工具和应用
3. 一条优化建议（如何让下周的工作更高效）
```

### 6.4 回滚系统

```powershell
# 回滚到指定日期的快照
ata restore 20260605           # 恢复到 6 月 5 日最后一次快照
ata restore 20260605-180000    # 恢复到 6 月 5 日 18:00 的快照

# 查看可回滚的快照列表
ata log                        # 列出所有快照及时间
ata log --week 23              # 列出第 23 周所有快照
ata log --diff 20260605        # 显示 6 月 5 日快照 vs 当前的差异

# 回滚预览（不实际执行）
ata restore 20260605 --dry-run # 预览回滚会做什么
```

---

## 七、ANA 桥接：从思维到桌面，从桌面到思维

### 7.1 保存时：ATA → ANA

当 ATA 保存快照时，自动生成 Markdown 并写入 Obsidian：

```markdown
# 2026-06-06 工作现场快照

> 自动保存于 23:15 · ATA snapshot: ata-20260606-231500

## 打开的应用 (14)
- **VS Code** — PROJECT_STATEMENT.md (光标在 L342)
- **Chrome** — GitHub PR #342 review · 15 tabs
- **Terminal** — C:\projects\ata · 2 tabs
- **Obsidian** — Daily Note 2026-06-06

## 显示器布局
- 主屏 ASUS 2560×1440 (Dev 桌面)
- 副屏 LG 1920×1080 (Web 桌面)

## DeepSeek 洞察
> 今日新增 Figma 窗口（设计评审），关闭了昨天在用的 Excel。
> 工作重心从数据整理转向设计评审。

## 明日提醒
- [ ] 继续 PROJECT_STATEMENT.md 的编写
- [ ] 跟进 PR #342 的 review 意见
```

### 7.2 恢复时：ATA ← ANA

恢复桌面后，ATA 自动打开 Obsidian 对应的每日笔记：

```powershell
# ata restore 执行后，额外执行：
Start-Process "obsidian://open?vault=Obsidian%20Vault&file=daily%2F2026-06-06.md"
```

### 7.3 桥接配置

```json
// config.json
{
  "ana": {
    "enabled": true,
    "obsidianVault": "Obsidian Vault",
    "dailyNotePath": "daily/",
    "weeklyManifestoPath": "_Ana/WeeklyManifesto.md",
    "autoOpenOnRestore": true,
    "autoWriteOnSave": true
  }
}
```

---

## 八、执行计划（三阶段 + 两个决策门）

### Phase 1：ATA 核心（3 天）
- `ata save` — 枚举窗口 → 输出 JSON
- `ata restore` — 读取 JSON → 启动应用 → 窗口归位
- `ata log` — 查看快照列表

### Phase 2：DeepSeek 洞察 + 回滚（3 天）
- `ata insight` — DeepSeek 分析
- `ata restore <date>` — 回滚到指定日期
- `ata log --diff` — 快照差异对比

### Phase 3：ANA 桥接 + 自动化（2 天）
- 保存时自动写 Obsidian 日记
- 恢复时自动打开 Obsidian 对应日记
- 关机钩子 + 定时保存 + 开机对话框

### 🔴 决策门 A：发布验证（Phase 1+2 完成后）
### 🔴 决策门 B：v1.0 C# 开发（Phase 3 完成后）

---

## 九、项目结构

```
ata/
├── README.md
├── PROJECT_STATEMENT.md          ← 本文件（原点文件）
├── ANA_BRIDGE.md                 ← ANA 桥接设计
├── DEEPSEEK_INSIGHT.md           ← DeepSeek 洞察引擎设计
├── LOG_ROLLBACK.md               ← 日志与回滚系统设计
├── schema/
│   └── snapshot-v1.0.json        ← JSON Schema
├── src/
│   ├── Save-ATA.ps1              ← 保存命令
│   ├── Restore-ATA.ps1           ← 恢复命令
│   ├── Log-ATA.ps1               ← 日志命令
│   ├── Insight-ATA.ps1           ← DeepSeek 洞察命令
│   └── ANA-Bridge.ps1            ← Obsidian 桥接
├── bridge/
│   ├── ana-daily-template.md     ← ANA 日记模板
│   └── weekly-manifesto-link.md  ← WeeklyManifesto 连接
├── deepseek/
│   ├── prompt-templates.md       ← Prompt 模板
│   └── analysis-schemas.json     ← 分析输出 Schema
└── examples/
    └── example-snapshot.json
```

---

## 十、ATA 与 ana 的关系说明

> 本项目原名 `ana`（也曾短暂命名为 `Resume`），最终定名 **ATA**。
>
> `ana` 这个名字保留给姐妹项目——基于 Obsidian 的每日定时回顾系统。
>
> ATA = Atlas Time Archive = 承载时间的档案。
> ANA = Ana Daily Review  = 每日思维回顾。
>
> 一个守桌面，一个守心流。合在一起，完整回到昨天。

---

*本文件是 ATA 项目的原点。随项目演进持续更新。*
