# ATA Roadmap

> Atlas Time Archive — Desktop Session Time Capsule
> Last updated: 2026-06-05

---

## Phase 1 · Foundation — "Take the Photo"

**Status: ✅ Complete**

Core snapshot engine. Enumerate every visible window, capture position/size/state/title, record monitor layout, export to JSON.

| Deliverable | Description |
|---|---|
| `Window.ps1` | Win32 API wrapper — `GetWindowRect`, `GetWindowState`, `GetWindowTitle`, `GetWindowClass`, `Test-IsValidAppWindow` (9 functions) |
| `Monitor.ps1` | Display detection — WMI + .NET Screen API, `Get-MonitorInfo`, `Get-MonitorSummary` |
| `Snapshot.ps1` | Snapshot engine — `Get-ATAWindows`, `Resolve-WindowMonitors`, `Mark-FocusedWindow`, `Save-ATA`, `Test-ATASnapshot` (6 functions) |
| `snapshot-v1.0.json` | JSON Schema — reserved fields for `appState`, `adapter`, `event`, `ecosystem`, `deepseek` |
| `config.json` | Runtime config — `%APPDATA%\ATA\config.json` with 6 sections |

**Self-check**: `.\ata.ps1 save` produces a valid JSON snapshot with all open windows.

---

## Phase 2 · Resurrection — "Develop the Photo"

**Status: ✅ Complete**

One-click restore engine. Read JSON snapshot, detect current monitor config, launch applications in dependency order, position windows to saved coordinates.

| Deliverable | Description |
|---|---|
| `Restore.ps1` | Restore engine — `Start-ATAApp`, `Set-WindowPosition`, `Get-CoordinateMapping`, `Restore-ATA`, `ata log`, `ata clean` (8 functions) |
| `Explorer.ps1` | File Explorer adapter — COM `Shell.Application` enumeration, folder path capture/restore |
| Priority launch | Infrastructure apps (Clash Verge, VPN) launch first with 3s extra delay |
| Rollback | `ata restore 20260605` — restore any historical snapshot by date |
| Dry-run | `ata restore --dry-run` — preview without executing |

**Self-check**: `.\ata.ps1 restore` brings back 70%+ of windows to correct positions.

---

## Phase 3 · Awakening — "AI Understands Your Work"

**Status: 🟡 In Progress (70%)**

AI insight engine, startup/shutdown automation, Obsidian bridge.

| Deliverable | Status |
|---|---|
| `DeepSeek.ps1` — dual-provider AI (DeepSeek/OpenAI, config-switchable) | ✅ Code complete |
| Instant insight — 1-2 line summary on each save | ✅ Code complete |
| Daily insight — 3-5 line brief, today vs yesterday diff | ✅ Code complete |
| Weekly insight — work-pattern report with optimization tips | ✅ Code complete |
| `Automation.ps1` — `Install-ATA` registers startup dialog + 30min auto-save via `schtasks.exe` | ✅ Working |
| Desktop shortcut — `ATA.bat` with logo icon, one-click save | ✅ Working |
| `AnaBridge.ps1` — save writes Obsidian daily note, restore opens it | ⬜ Code ready, needs config |
| AI credit application | ⬜ Pending OpenAI approval |

**Self-check**: `.\ata.ps1 insight` returns AI-generated work summary (requires API key).

---

## Phase 4 · Network — "Five Projects Breathe Together"

**Status: ⬜ Planned (1-2 weeks)**

Unified event bus connecting all 5 projects. Cross-project awareness.

| Deliverable | Description |
|---|---|
| Event bus JSONL | `%APPDATA%\Ecosystem\events\YYYY-MM-DD.jsonl` — append-only, one JSON line per event |
| Cross-project config | One `DEEPSEEK_API_KEY`, all 5 projects read from shared config |
| Snapshot → Obsidian diary | Shutdown snapshot auto-writes daily note with workspace summary |
| Restore → Obsidian diary | Restore auto-opens the corresponding day's ANA note |
| Adapter marketplace scaffold | `adapters/` directory with template, README, contribution guide |
| Save-ATA-Full | Integrated save: snapshot + AI insight + Obsidian diary + event emission |

**Self-check**: After shutdown and restore, Obsidian shows today's workspace diary entry with AI insight.

---

## Phase 5 · Evolution — "Native Windows Application"

**Status: ⬜ Planned (1-3 months)**

Rewrite from PowerShell scripts to C# / .NET native application.

| Deliverable | Description |
|---|---|
| C# rewrite | Same JSON schema, native performance, proper multi-threading |
| System tray icon | Right-click → Save / Restore / Insights / Settings |
| WPF restore dialog | Logo + snapshot selector + "Restore" / "Skip" buttons |
| SQLite snapshot DB | Fast query, tags, search — "What was I working on last Wednesday?" |
| MSI installer + winget | `winget install ata` — zero-terminal setup for non-programmers |
| Auto-update | Background update check via GitHub Releases |
| Adapter marketplace | Community-submitted adapters with versioning and compatibility tags |
| Restore success rate ≥ 90% | Cover Explorer, Chrome tabs, VS Code workspace, Terminal CWD |

**Self-check**: Non-technical user installs via `winget`, clicks tray icon, restores workspace in one click.

---

## Phase 6 · Boundary Break — "Cross-Platform Workspace Infrastructure"

**Status: ⬜ Vision (6-12 months)**

Same JSON schema, different OS backends. Workspace portability.

| Deliverable | Description |
|---|---|
| macOS backend | Accessibility API + AppleScript for window enumeration and positioning |
| Linux backend | X11/Wayland compositor integration per desktop environment |
| Cloud sync (optional, encrypted) | Save on office PC → restore on home PC via end-to-end encrypted sync |
| Team shared workspaces | "New hire onboarding: one-click restore team's standard dev environment" |
| Obsidian plugin | Manage snapshots, view work journals, trigger restore — all from within Obsidian |
| REST API | `POST /snapshots` / `GET /snapshots/latest` — integrate with any tool |

**Self-check**: Snap a workspace on Windows, restore it on macOS, with monitor layout adaptation.

---

## Visual Timeline

```
Phase 1 ──── Phase 2 ──── Phase 3 ──── Phase 4 ──── Phase 5 ──── Phase 6
  ✅           ✅           🟡            ⬜            ⬜            ⬜
 Save        Restore    AI+Auto        Event       Native      Cross-Plat
 Engine      Engine     Insight         Bus         App        form

Day 1        Day 1      Day 1-3       Week 2-3    Month 1-3   Month 6-12
(Complete)  (Complete)  (In Progress)  (Planned)   (Planned)   (Vision)
```

---

## Key Metrics

| Metric | Current | Target (Phase 5) |
|---|---|---|
| Restore success rate | ~50-60% | ≥ 90% |
| Apps with adapters | 1 (Explorer) | 10+ (Chrome, VS Code, Terminal, Figma, Obsidian, Slack...) |
| Lines of code | ~1,200 | ~5,000 (C# rewrite) |
| GitHub stars | — | 200+ |
| External contributors | 0 | 5+ |

---

*ATA = Atlas Time Archive. Carry your digital world across reboots.*

---

---

# ATA 路线图

> 阿特拉斯时间档案 — 桌面会话时间胶囊
> 最后更新：2026-06-05

---

## Phase 1 · 地基 — "拍一张照片"

**状态：✅ 完成**

核心快照引擎。枚举所有可见窗口，捕获位置/大小/状态/标题，记录显示器布局，导出为 JSON。

| 交付物 | 描述 |
|---|---|
| `Window.ps1` | Win32 API 封装 — `GetWindowRect`、`GetWindowState`、`GetWindowTitle`、`GetWindowClass`、`Test-IsValidAppWindow`（9 个函数） |
| `Monitor.ps1` | 显示器检测 — WMI + .NET Screen API，`Get-MonitorInfo`、`Get-MonitorSummary` |
| `Snapshot.ps1` | 快照引擎 — `Get-ATAWindows`、`Resolve-WindowMonitors`、`Mark-FocusedWindow`、`Save-ATA`、`Test-ATASnapshot`（6 个函数） |
| `snapshot-v1.0.json` | JSON Schema — 预留 `appState`、`adapter`、`event`、`ecosystem`、`deepseek` 字段 |
| `config.json` | 运行时配置 — `%APPDATA%\ATA\config.json`，6 个配置区 |

**自检标准**：`.\ata.ps1 save` 生成包含所有打开窗口的有效 JSON 快照。

---

## Phase 2 · 复活 — "冲洗这张照片"

**状态：✅ 完成**

一键恢复引擎。读取 JSON 快照，检测当前显示器配置，按依赖顺序启动应用，将窗口归位到保存的坐标。

| 交付物 | 描述 |
|---|---|
| `Restore.ps1` | 恢复引擎 — `Start-ATAApp`、`Set-WindowPosition`、`Get-CoordinateMapping`、`Restore-ATA`、`ata log`、`ata clean`（8 个函数） |
| `Explorer.ps1` | 文件资源管理器适配器 — COM `Shell.Application` 枚举，文件夹路径捕获/恢复 |
| 优先启动 | 基础设施应用（Clash Verge、VPN）优先启动，额外等待 3 秒 |
| 回滚 | `ata restore 20260605` — 按日期恢复到任意历史快照 |
| Dry-run | `ata restore --dry-run` — 预览恢复内容，不实际执行 |

**自检标准**：`.\ata.ps1 restore` 将 70% 以上的窗口恢复到正确位置。

---

## Phase 3 · 觉醒 — "AI 理解你的工作"

**状态：🟡 进行中（70%）**

AI 洞察引擎、开关机自动化、Obsidian 桥接。

| 交付物 | 状态 |
|---|---|
| `DeepSeek.ps1` — 双 provider AI（DeepSeek/OpenAI，配置可切换） | ✅ 代码完成 |
| 即时洞察 — 每次保存时 1-2 句工作总结 | ✅ 代码完成 |
| 每日洞察 — 3-5 句今日简报 + 与昨日对比 | ✅ 代码完成 |
| 每周洞察 — 工作模式报告 + 优化建议 | ✅ 代码完成 |
| `Automation.ps1` — `Install-ATA` 注册开机对话框 + 30 分钟定时保存（通过 `schtasks.exe`） | ✅ 已可用 |
| 桌面快捷方式 — `ATA.bat` 带 Logo 图标，一键保存 | ✅ 已可用 |
| `AnaBridge.ps1` — 保存时写入 Obsidian 日记，恢复时打开对应日记 | ⬜ 代码就绪，待启用 |
| AI 额度申请 | ⬜ 等待 OpenAI 审批 |

**自检标准**：`.\ata.ps1 insight` 返回 AI 生成的工作总结（需配置 API Key）。

---

## Phase 4 · 联网 — "五个项目一起呼吸"

**状态：⬜ 规划中（1-2 周）**

统一事件总线，连接全部 5 个项目。跨项目感知。

| 交付物 | 描述 |
|---|---|
| 事件总线 JSONL | `%APPDATA%\Ecosystem\events\YYYY-MM-DD.jsonl` — 追加写入，每条事件一行 JSON |
| 跨项目配置 | 一个 `DEEPSEEK_API_KEY`，5 个项目从共享配置读取 |
| 快照 → Obsidian 日记 | 关机快照自动写入当日 Obsidian 笔记，附带工作区摘要 |
| 恢复 → Obsidian 日记 | 恢复时自动打开对应的 ANA 思维日记 |
| 适配器市场框架 | `adapters/` 目录 + 模板 + README + 贡献指南 |
| Save-ATA-Full | 一体化保存：快照 + AI 洞察 + Obsidian 日记 + 事件发射 |

**自检标准**：关机再恢复后，Obsidian 中出现当天的工作区日记条目，附带 AI 洞察。

---

## Phase 5 · 进化 — "原生 Windows 应用"

**状态：⬜ 规划中（1-3 个月）**

从 PowerShell 脚本重写为 C# / .NET 原生应用。

| 交付物 | 描述 |
|---|---|
| C# 重写 | 同一 JSON Schema，原生性能，真正的多线程 |
| 系统托盘图标 | 右键 → 保存 / 恢复 / 洞察 / 设置 |
| WPF 恢复对话框 | Logo + 快照选择器 + "恢复" / "跳过"按钮 |
| SQLite 快照数据库 | 快速查询、标签、搜索——"上周三下午我在做什么？" |
| MSI 安装包 + winget | `winget install ata` — 零终端安装，非程序员友好 |
| 自动更新 | 通过 GitHub Releases 后台检查更新 |
| 适配器市场 | 社区提交的适配器，带版本号和兼容性标签 |
| 恢复成功率 ≥ 90% | 覆盖资源管理器、Chrome 标签、VS Code 工作区、终端目录 |

**自检标准**：非技术用户通过 `winget` 安装，点击托盘图标，一键恢复工作区。

---

## Phase 6 · 破界 — "跨平台工作区基础设施"

**状态：⬜ 愿景（6-12 个月）**

同一 JSON Schema，不同操作系统后端。工作区可移植。

| 交付物 | 描述 |
|---|---|
| macOS 后端 | Accessibility API + AppleScript 窗口枚举和定位 |
| Linux 后端 | X11/Wayland 合成器集成，各桌面环境适配 |
| 云端同步（可选加密） | 办公室关机 → 家里开机 → 同一份快照跨机器恢复 |
| 团队共享工作区 | "新员工入职：一键恢复团队标准开发环境" |
| Obsidian 插件 | 从 Obsidian 内管理快照、查看工作日报、触发恢复 |
| REST API | `POST /snapshots` / `GET /snapshots/latest` — 与任意工具集成 |

**自检标准**：在 Windows 上拍快照，在 macOS 上恢复，显示器布局自动适配。

---

## 时间线

```
Phase 1 ──── Phase 2 ──── Phase 3 ──── Phase 4 ──── Phase 5 ──── Phase 6
  ✅           ✅           🟡            ⬜            ⬜            ⬜
 保存引擎     恢复引擎    AI+自动化     事件总线     原生应用      跨平台

第 1 天       第 1 天     第 1-3 天     第 2-3 周    第 1-3 月    第 6-12 月
（已完成）   （已完成）   （进行中）    （规划中）   （规划中）   （愿景）
```

---

## 关键指标

| 指标 | 当前 | 目标（Phase 5） |
|---|---|---|
| 恢复成功率 | ~50-60% | ≥ 90% |
| 已适配应用 | 1（Explorer） | 10+（Chrome、VS Code、Terminal、Figma、Obsidian、Slack...） |
| 代码行数 | ~1,200 | ~5,000（C# 重写） |
| GitHub Stars | — | 200+ |
| 外部贡献者 | 0 | 5+ |

---

*ATA = Atlas Time Archive = 承载时间的档案。关机时天不塌，开机时一切归位。*

