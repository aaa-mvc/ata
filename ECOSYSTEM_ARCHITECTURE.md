# ATA × 四项目生态系统架构

> 5 个开源项目，1 条感知驱动的事件总线。不是各自为战，是一个生态系统。

---

## 一、五项目全景

```
┌─────────────────────────────────────────────────────────────┐
│                      知识工作者每日闭环                        │
│                                                             │
│   🧠 ANA          📺 SHOW         🎯 ANCHOR                 │
│   (Obsidian)      (Flask+AI)      (Flask+AI)                │
│   想什么           表达什么         连接谁                     │
│   WeeklyManifesto  朋友圈文案       评论区互动                 │
│       │               │               │                     │
│       └───────────────┼───────────────┘                     │
│                       │                                     │
│                  🤖 DeepSeek AI                             │
│                  (共享 AI 后端)                               │
│                       │                                     │
│       ┌───────────────┼───────────────┐                     │
│       │               │               │                     │
│   💻 ATA          🔢 Tax-Calculator                         │
│   (PowerShell)     (Vanilla JS)                             │
│   在哪做           算清楚                                     │
│   桌面时间胶囊      个税计算器                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

| # | 项目 | 平台 | 语言 | 核心价值 | 输出物 |
|---|---|---|---|---|---|
| 1 | **ana** | Obsidian 插件 | TypeScript | 思维聚类 · 认知洞察 | `WeeklyManifesto.md` |
| 2 | **ATA** | Windows CLI | PowerShell → C# | 桌面时间胶囊 · 一键恢复 | `ata-*.json` 快照 |
| 3 | **anchor** | Flask Web | Python | AI 评论区互动 | 评论文本 |
| 4 | **show** | Flask Web | Python | AI 朋友圈文案 | 文案文本 |
| 5 | **tax-calculator** | 静态 Web | Vanilla JS | 个税精准计算 | `localStorage` 数据 |

---

## 二、统一的感知驱动模型

### 2.1 五个项目的共同基因

| 基因 | ana | ATA | anchor | show | tax-calc |
|---|---|---|---|---|---|
| **本地优先** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **MIT 开源** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **AI 驱动** | Athena | DeepSeek | DeepSeek | DeepSeek/OpenAI | — |
| **输出到文件** | Markdown | JSON | 文本 | 文本 | localStorage |
| **零配置启动** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **中文优先** | ✅ | ✅ | ✅ | ✅ | ✅ |

### 2.2 感知驱动五层

```
Layer 5 · 表达层    show (朋友圈) · anchor (评论区)
         ↑ 你对外说什么、怎么连接
Layer 4 · 洞察层    ana (WeeklyManifesto)
         ↑ 理解你在想什么、知识库的趋势
Layer 3 · 状态层    ATA (桌面时间胶囊)
         ↑ 保存你在看什么、在做什么
Layer 2 · 工具层    tax-calculator
         ↑ 解决具体计算问题
Layer 1 · 事件总线  统一的 JSON 事件格式（本文定义）
         ↑ 所有项目通过事件互通
```

---

## 三、事件总线设计

### 3.1 为什么需要事件总线

现在 5 个项目各自独立运行。但真实的工作流是连续的：

```
你在 Obsidian 写了一篇笔记 (ana 扫描到)
  → 你在 VS Code 里改 ATA 的代码 (ATA 快照记录)
    → 你打开 show 生成了一条朋友圈文案
      → 你用 anchor 在别人视频下留了言
        → 晚上关机，ATA 自动保存桌面 + 写 Obsidian 日记
```

**事件总线让这个连续的工作流可追溯、可洞察、可回放。**

### 3.2 统一事件格式

```json
{
  "event": {
    "id": "evt-20260605-231500-a1b2c3",
    "timestamp": "2026-06-05T23:15:00+08:00",
    "source": "ata",
    "type": "snapshot.created",
    "data": {
      "snapshotId": "ata-20260605-231500",
      "windowCount": 14,
      "monitorCount": 2
    },
    "context": {
      "anaDailyNote": "2026-06-05.md",
      "activeProject": "ata",
      "tags": ["shutdown", "end-of-day"]
    }
  }
}
```

**事件类型枚举**：

| source | type | 触发时机 |
|---|---|---|
| `ata` | `snapshot.created` | 保存快照 |
| `ata` | `snapshot.restored` | 恢复快照 |
| `ata` | `rollback.executed` | 回滚到历史快照 |
| `ana` | `review.completed` | WeeklyManifesto 生成 |
| `ana` | `dream.completed` | 每日快速扫描 |
| `show` | `post.generated` | 生成朋友圈文案 |
| `anchor` | `comment.generated` | 生成评论区互动 |
| `tax-calc` | `calculation.completed` | 完成个税计算 |
| `system` | `session.start` | 开机 / 恢复 |
| `system` | `session.end` | 关机 / 保存 |

### 3.3 事件存储

```
%APPDATA%\Ecosystem\
├── events\
│   ├── 2026-06-05.jsonl     ← 每天一个 JSONL 文件
│   ├── 2026-06-06.jsonl
│   └── ...
├── config.json               ← 跨项目共享配置
└── insights\
    └── cross-project.md      ← DeepSeek 跨项目洞察
```

每条事件一行 JSON，append-only：

```jsonl
{"event":{"id":"evt-...","timestamp":"...","source":"ata","type":"snapshot.created","data":{...}}}
{"event":{"id":"evt-...","timestamp":"...","source":"show","type":"post.generated","data":{...}}}
{"event":{"id":"evt-...","timestamp":"...","source":"ata","type":"snapshot.restored","data":{...}}}
```

---

## 四、项目间的具体联动

### 4.1 ATA ↔ ana（核心闭环）

```
ATA 保存快照 → 写事件 → ana 读取事件 → 关联到 WeeklyManifesto
                                    ↓
                     "你在 23:15 关机，当时开着 14 个窗口，
                      VS Code 是主力，Figma 刚关掉。
                      今天的 WeeklyManifesto 已更新。"
```

### 4.2 ATA → show / anchor（上下文注入）

```
show 生成文案时：
  → 查询 ATA 快照："用户当前在写 PROJECT_STATEMENT.md"
  → 注入到 show 的 Prompt："用户正在设计开源项目架构"
  → 生成的文案更贴合当前状态

anchor 生成评论时：
  → 查询 ATA 快照："用户今天打开了设计工具"
  → 生成的评论更自然、更"像本人"
```

### 4.3 tax-calculator → ATA（状态持久化）

```
tax-calculator 计算结果 → 写事件 → ATA 快照中记录
  → 下次恢复桌面时，税计算器的状态也被记住
  → 用户不需要重新输入社保基数、专项扣除
```

### 4.4 ana → 所有项目（认知层）

```
ana 的 WeeklyManifesto 是所有项目的"思维上下文"：
  "本周你在 ATA 上投入了最多时间，
   其次是 show 的朋友圈文案。
   建议下周把 anchor 的评论策略提上日程。"
```

---

## 五、共享配置

```json
// %APPDATA%\Ecosystem\config.json
{
  "ecosystem": {
    "version": "1.0.0",
    "projects": {
      "ata":    { "path": "D:\\Hi\\Projects\\ata",    "enabled": true },
      "ana":    { "path": "C:\\...\\Obsidian Vault\\.obsidian\\plugins\\ana", "enabled": true },
      "anchor": { "path": "D:\\Hi\\Projects\\anchor", "enabled": true, "port": 5001 },
      "show":   { "path": "D:\\Hi\\Projects\\show",   "enabled": true, "port": 5002 },
      "tax":    { "path": "D:\\Hi\\Projects\\tax-calculator", "enabled": true }
    },
    "deepseek": {
      "apiKey": "${DEEPSEEK_API_KEY}",
      "model": "deepseek-chat",
      "shared": true
    },
    "obsidian": {
      "vaultPath": "C:\\Users\\Hi\\Documents\\Obsidian Vault",
      "dailyNoteFolder": "01_Inbox(收纳灵感，不留隔夜）/02_日常记录"
    },
    "eventBus": {
      "enabled": true,
      "storagePath": "%APPDATA%\\Ecosystem\\events",
      "retentionDays": 90
    }
  }
}
```

---

## 六、项目之间的"给予"与"获取"

```
        ana ──── 给予：思维上下文、认知洞察 ────→ 所有项目
         ↑                                        ↓
         │ 获取：工作数据、                   获取：思维上下文、
         │       事件时间线                    │       项目关联
         │                                   ↓
        ATA ←── 给予：桌面状态、事件时间线 ──→ show / anchor
         ↑                                        ↓
         │ 获取：思维上下文、                 获取：用户当前上下文、
         │       表达内容                      │       工作状态
         │                                   ↓
         └── tax-calculator ── 给予：实用工具、财务数据 ──→ ATA
              ↑
              获取：桌面状态持久化
```

---

## 七、生态路线图

| Phase | 内容 | 涉及项目 |
|---|---|---|
| **Phase 1**（当前） | 各项目独立运行 | 全部 |
| **Phase 2**（ATA Phase 3 后） | 统一事件格式 + 事件日志 | ATA + ana |
| **Phase 3** | DeepSeek 跨项目洞察 | ATA + ana + show + anchor |
| **Phase 4** | 共享配置 + 一键启动全部 | 全部 |
| **Phase 5** | 社区适配器生态 | 全部 + 外部 |

---

*5 个项目，1 个生态。每加一个项目，不是堆代码，是加一个感知器官。*
