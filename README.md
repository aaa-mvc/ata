# ATA — Atlas Time Archive

> **承载 · 秩序 · 守护** | 放心关机，一键回到昨天

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Phase](https://img.shields.io/badge/phase-1%20(design)-orange.svg)](PROJECT_STATEMENT.md)

ATA 是一个 Windows 桌面会话时间胶囊。关机时一键保存完整工作现场，开机时一键恢复到昨天——不只是窗口摆在哪，更是你在做什么、在想什么。

---

## 姐妹项目

| ATA（本仓库） | ANA |
|---|---|
| Windows 桌面状态保存/恢复 | Obsidian 每日定时回顾 |
| JSON 快照 + DeepSeek AI 洞察 | WeeklyManifesto 思维路径 |
| `ata save` / `ata restore` | `obsidian://open?vault=...` |

> ANA 守护思维状态，ATA 守护数字状态。两者结合 = 完整的"昨日恢复"系统。

---

## 快速开始（Phase 1 - 即将推出）

```powershell
# 保存当前桌面状态
ata save

# 恢复到最新快照
ata restore

# 恢复到指定日期
ata restore 20260605

# 生成 AI 洞察
ata insight

# 查看日志
ata log
```

---

## 项目结构

```
ata/
├── README.md                    ← 你在这里
├── PROJECT_STATEMENT.md         ← 项目愿景与完整架构
├── ANA_BRIDGE.md                ← ANA ↔ ATA 桥接设计
├── DEEPSEEK_INSIGHT.md          ← DeepSeek AI 洞察引擎
├── LOG_ROLLBACK.md              ← 日志与回滚系统
├── schema/
│   └── snapshot-v1.0.json       ← 快照 JSON Schema
├── src/                         ← 源代码（Phase 1 开发中）
│   ├── Save-ATA.ps1
│   ├── Restore-ATA.ps1
│   ├── Log-ATA.ps1
│   ├── Insight-ATA.ps1
│   └── ANA-Bridge.ps1
├── bridge/
│   ├── ana-daily-template.md
│   └── weekly-manifesto-link.md
├── deepseek/
│   ├── prompt-templates.md
│   └── analysis-schemas.json
└── examples/
    └── example-snapshot.json
```

---

## 路线图

| Phase | 目标 | 状态 |
|---|---|---|
| Phase 1 | `ata save` + `ata restore` | 🟡 设计中 |
| Phase 2 | DeepSeek 洞察 + 回滚 | ⬜ 规划中 |
| Phase 3 | ANA 桥接 + 自动化 | ⬜ 规划中 |
| v1.0 | C# / .NET 原生应用 | ⬜ 待决策 |

---

## 许可证

MIT © 2026

---

*ATA = Atlas Time Archive = 承载时间的档案。关机时天不塌，开机时一切归位。*
