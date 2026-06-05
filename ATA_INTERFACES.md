# ATA 预留接口与预见性设计

> 今天不实现的接口，明天就是债务。
> 今天预留的接口，明天就是护城河。

---

## 一、设计原则

### 1.1 "先留口，后填肉"

```
❌ 错误做法：
   Phase 3 发现需要事件总线 → 重构 Phase 1-2 所有代码 → 破坏 JSON Schema

✅ 正确做法：
   Phase 1 在 JSON Schema 里预留 event 字段（值为 null）
   Phase 1 在代码里留一个空函数 Write-ATAEvent（什么都不做，但签名对）
   Phase 3 填上实现 → 不需要改 Schema，不需要改其他代码
```

### 1.2 三个预留层级

| 层级 | 含义 | 例子 |
|---|---|---|
| **Schema 层** | JSON 字段预留 | `event`, `ecosystemConfig`, `crossProjectContext` |
| **函数签名层** | PowerShell 函数占位 | `Write-ATAEvent`, `Get-CrossProjectConfig` |
| **文件系统层** | 目录和文件路径预留 | `%APPDATA%\Ecosystem\`, `adapters/`, `events/` |

---

## 二、JSON Schema 预留字段

### 2.1 快照 Schema 扩展

在 `snapshot-v1.0.json` 中**已预留**的字段基础上，增加以下字段：

```json
{
  "version": "1.0.0",
  "snapshot": {
    "id": "ata-20260606-231500",
    "created": "2026-06-06T23:15:00+08:00",
    "type": "shutdown",

    "━━━━━ 以下为预留字段，Phase 1 值为 null ━━━━━": null,

    "event": {
      "description": "关联的统一事件 ID。Phase 3 前为 null。",
      "type": "string | null",
      "example": "evt-20260606-231500-a1b2c3",
      "value": null
    },

    "ecosystem": {
      "description": "跨项目上下文。Phase 4 前为 null。",
      "type": "object | null",
      "properties": {
        "activeProject": "string | null",
        "crossProjectContext": "string | null",
        "relatedEvents": ["string"],
        "linkedTools": {
          "show": { "lastPost": "string | null" },
          "anchor": { "lastComment": "string | null" },
          "taxCalc": { "lastCalculation": "string | null" }
        }
      },
      "value": null
    },

    "deepseek": {
      "description": "DeepSeek 分析结果缓存。Phase 2 填入。",
      "type": "object | null",
      "properties": {
        "insightHash": "string",
        "dailySummary": "string",
        "patternTags": ["string"],
        "optimizationTip": "string"
      },
      "value": null
    },

    "windows": [
      {
        "━━━━━ 窗口级预留字段 ━━━━━": null,

        "eventContext": {
          "description": "此窗口关联的外部事件。",
          "type": "object | null",
          "properties": {
            "obsidianNote": "string | null",
            "showPost": "string | null",
            "anchorComment": "string | null",
            "taxCalculation": "string | null"
          },
          "value": null
        },

        "restoreHooks": {
          "description": "恢复时额外执行的钩子。Phase 3 填入。",
          "type": "object | null",
          "properties": {
            "preLaunch": "string | null",
            "postLaunch": "string | null",
            "onFailure": "string | null"
          },
          "value": null
        }
      }
    ]
  }
}
```

### 2.2 为什么 Phase 1 就要留这些 null 字段

```
原因 1：Schema 版本号不变
  → Phase 1 的快照和 Phase 4 的快照用同一个 Schema 版本
  → 向后兼容，旧快照永远可读

原因 2：代码不需要改分支
  → if ($snapshot.ecosystem -ne $null) { ... }
  → 不存在时优雅跳过，存在时无缝接入

原因 3：给社区清晰的信号
  → "这个字段现在为空，但未来会填什么"一目了然
  → 降低贡献者的理解成本
```

---

## 三、函数签名预留（PowerShell 阶段）

### 3.1 事件总线接口

```powershell
# Phase 1：空函数，只定义签名
# Phase 3：实现事件写入逻辑

function Write-ATAEvent {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet(
            'snapshot.created',
            'snapshot.restored',
            'rollback.executed',
            'config.changed',
            'adapter.registered'
        )]
        [string]$Type,

        [Parameter(Mandatory=$true)]
        [hashtable]$Data,

        [hashtable]$Context = @{}
    )

    # Phase 1-2: 留空，只写日志
    Write-Verbose "[Event] $Type | data=$($Data | ConvertTo-Json -Compress)"

    # Phase 3: 实现
    # $event = New-ATAEvent -Type $Type -Data $Data -Context $Context
    # $event | Write-EventToJsonl -Path "$env:APPDATA\Ecosystem\events\$(Get-Date -Format 'yyyy-MM-dd').jsonl"
}
```

### 3.2 跨项目配置接口

```powershell
# Phase 1：读取 ATA 自己的配置
# Phase 4：读取 Ecosystem 共享配置

function Get-CrossProjectConfig {
    param(
        [string]$Project = 'ata'
    )

    $ecosystemConfig = "$env:APPDATA\Ecosystem\config.json"

    # Phase 1: Ecosystem 配置不存在是正常的
    if (-not (Test-Path $ecosystemConfig)) {
        Write-Verbose "Ecosystem config not found. Using ATA-only config."
        return Get-ATAConfig
    }

    # Phase 4: 合并 Ecosystem 配置和项目配置
    $shared = Get-Content $ecosystemConfig | ConvertFrom-Json
    return $shared.projects.$Project
}
```

### 3.3 适配器注册接口

```powershell
# Phase 1：adapters/ 目录存在但为空
# Phase 2：第一个 adapter（vscode）入驻
# Phase 3+：社区贡献更多 adapter

function Register-ATAAdapter {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AdapterName,

        [Parameter(Mandatory=$true)]
        [string]$AdapterPath
    )

    # Phase 1: 只验证目录存在
    $adapterDir = "D:\Hi\Projects\ata\adapters"
    if (-not (Test-Path $adapterDir)) {
        New-Item -ItemType Directory -Path $adapterDir -Force
    }

    Write-Verbose "Adapter registered: $AdapterName (not yet functional in Phase 1)"

    # Phase 2+: 加载适配器脚本
    # . "$AdapterPath\$AdapterName.ps1"
    # Invoke-AdapterSave -AdapterName $AdapterName
}
```

### 3.4 DeepSeek 洞察接口

```powershell
# Phase 1：空壳
# Phase 2：实现即时分析
# Phase 3+：实现每日 + 每周分析

function Invoke-ATAInsight {
    param(
        [ValidateSet('instant', 'daily', 'weekly')]
        [string]$Level = 'instant',

        [string]$SnapshotPath
    )

    # Phase 1: 返回 null，不报错
    if (-not (Get-ATAConfig).deepseek.enabled) {
        Write-Verbose "DeepSeek insight skipped (not configured)."
        return $null
    }

    # Phase 2+: 调 DeepSeek API
    # $prompt = Build-InsightPrompt -Level $Level -SnapshotPath $SnapshotPath
    # return Invoke-DeepSeekAnalysis -Prompt $prompt -Level $Level
}
```

---

## 四、目录结构预留

```
D:\Hi\Projects\ata\
│
├── adapters/              ← 🆕 Phase 1 创建空目录，Phase 2+ 填充
│   ├── README.md          ← "如何写一个 ATA 适配器"
│   ├── template.ps1       ← 适配器模板
│   ├── vscode.ps1         ← Phase 2 实现
│   ├── chrome.ps1         ← Phase 2 实现
│   └── terminal.ps1       ← Phase 2 实现
│
├── hooks/                 ← 🆕 Phase 1 创建空目录，Phase 3+ 填充
│   ├── pre-save.d/        ← 保存前执行的钩子脚本
│   ├── post-restore.d/    ← 恢复后执行的钩子脚本
│   ├── on-shutdown.d/     ← 关机前执行的钩子脚本
│   └── on-startup.d/      ← 开机后执行的钩子脚本
│
├── ecosystem/             ← 🆕 Phase 1 创建空目录，Phase 4+ 填充
│   ├── event-bus.ps1      ← 事件总线实现
│   ├── cross-config.ps1   ← 跨项目配置管理
│   └── link-ana.ps1       ← ANA 桥接核心逻辑
│
├── src/                   ← Phase 1 实现
│   ├── Save-ATA.ps1       ← 核心保存
│   ├── Restore-ATA.ps1    ← 核心恢复
│   ├── Log-ATA.ps1        ← 日志系统
│   ├── Insight-ATA.ps1    ← DeepSeek 洞察（空壳→实现）
│   └── ANA-Bridge.ps1     ← ANA 桥接（空壳→实现）
│
└── schema/
    └── snapshot-v1.0.json ← 快照 Schema（含预留字段）
```

---

## 五、预见性设计决策

### 5.1 决策一：事件总线用 JSONL 而不是 SQLite

```
JSONL 优势（Phase 1-3 阶段）：
  ✅ 零依赖——PowerShell 原生读写
  ✅ 人可读——记事本打开就能看
  ✅ append-only——不会损坏
  ✅ 每天一个文件——方便清理和归档
  ✅ 未来可以导入 SQLite——数据格式不变

SQLite 优势（v1.0 C# 阶段）：
  ✅ 查询快——SELECT WHERE timestamp > ...
  ✅ 跨进程安全——多项目同时写
  ✅ 事务支持

→ 决策：Phase 1-3 用 JSONL。v1.0 加 SQLite 但不移除 JSONL 支持。
```

### 5.2 决策二：适配器用独立脚本而不是 DLL 插件

```
独立脚本 (.ps1) 优势：
  ✅ 零编译——用户可以直接改
  ✅ 热加载——放进去立刻生效
  ✅ 低门槛——20 行 PowerShell 就是一个适配器
  ✅ 可审计——纯文本，用户知道它做什么

DLL 插件优势：
  ✅ 性能好
  ✅ 类型安全

→ 决策：Phase 1-3 用 .ps1 脚本适配器。
   v1.0 C# 版支持 .ps1 + .dll 两种适配器格式。
```

### 5.3 决策三：配置分三层

```
Layer 1 · 用户配置     %APPDATA%\ATA\config.json
  → 用户手动编辑，ATA 读取
  → 例如：排除哪些应用、恢复策略

Layer 2 · 快照内配置   每个快照 JSON 里的 config 字段
  → 保存在快照里，跟随快照
  → 例如：这个快照恢复时要不要打开 ANA 日记

Layer 3 · 生态配置     %APPDATA%\Ecosystem\config.json
  → 跨项目共享
  → 例如：DeepSeek API Key、Obsidian Vault 路径、事件存储位置

三层互不覆盖。
Layer 1 是"我的偏好"，Layer 2 是"这个快照的特性"，Layer 3 是"所有项目的共同知识"。
```

### 5.4 决策四：DeepSeek API Key 只存在一个地方

```
所有 5 个项目的 DeepSeek API Key 统一从以下位置读取（优先级）：

1. 环境变量 $env:DEEPSEEK_API_KEY          ← 最高优先级
2. Ecosystem 配置 %APPDATA%\Ecosystem\config.json
3. 项目本地配置 %APPDATA%\ATA\config.json   ← 最低优先级（不推荐）

→ 用户只需要在一个地方设置 API Key，所有项目自动共享。
→ ATA 的 Phase 1 代码里，读 Key 的逻辑已经包含三层回退。
```

### 5.5 决策五：ATA 不应该直接修改其他项目的数据

```
✅ 可以：
  - 写入 Ecosystem 共享目录（%APPDATA%\Ecosystem\）
  - 写入 Obsidian Vault（通过 ANA Bridge）
  - 发射事件到 JSONL

❌ 不可以：
  - 修改 show/server.py
  - 修改 anchor 的 config
  - 修改 tax-calculator 的 localStorage

→ 每个项目保持独立。事件总线是"通知"，不是"控制"。
```

---

## 六、向后兼容承诺

```
ATA v0.1（Phase 1-3, PowerShell）
  ├─ 快照 Schema v1.0.0
  ├─ 新增字段 → 小版本号递增（1.0.0 → 1.1.0）
  ├─ 破坏性变更 → 大版本号递增（1.x.x → 2.0.0）
  └─ v1.x 的快照永远能被 v1.x 读取

ATA v1.0（C# / .NET）
  ├─ 继续支持 Schema v1.x 的快照
  ├─ 引入 Schema v2.0.0（增加 SQLite 索引、压缩等）
  └─ 内置 v1→v2 迁移工具
```

---

## 七、现在就能做的事（Phase 1 启动前）

- [ ] 创建 `adapters/` 空目录 + README + 模板文件
- [ ] 创建 `hooks/` 空目录（4 个子目录 + .gitkeep）
- [ ] 创建 `ecosystem/` 空目录 + 接口定义注释
- [ ] 在 `Save-ATA.ps1` 中写入 `Write-ATAEvent` 空函数
- [ ] 在 `Restore-ATA.ps1` 中写入 `Get-CrossProjectConfig` 空函数
- [ ] 在 `snapshot-v1.0.json` 中加入 `event`、`ecosystem`、`deepseek` 预留字段
- [ ] 创建 `%APPDATA%\Ecosystem\` 目录结构（即使现在为空）

---

*预留不是拖延。预留是给未来的自己写一封信，告诉他"这条路我留好了，你直接走"。*
