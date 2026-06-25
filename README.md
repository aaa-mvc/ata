# ATA — Atlas Time Archive

> **承载 · 秩序 · 守护** | 放心关机，一键回到昨天

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-archived-lightgrey.svg)](#)
> ⚠️ **项目已归档**（2026-06-25）。评估结论：Windows 桌面时间胶囊的价值有限——真正的工作现场是上下文（IDE 未保存编辑、终端状态、思路片断）而非窗口坐标，不关机比费力重建更可靠。代码和快照保留供参考，自动化已停止。详见 [CHANGELOG](CHANGELOG.md)。

ATA 是一个 Windows 桌面会话时间胶囊。关机时一键保存完整工作现场（窗口、文件夹、应用状态），开机时一键恢复到昨天。内置 **DeepSeek / OpenAI 双 AI 洞察引擎**，自动分析你的工作模式。

---

## 五项目生态系统

| 项目 | 定位 | AI 后端 |
|---|---|---|
| **ata**（本仓库） | Windows 桌面时间胶囊 | DeepSeek / OpenAI 双 provider |
| ana | Obsidian 每日思维回顾 | Athena |
| anchor | AI 评论区互动 | DeepSeek |
| show | AI 朋友圈文案 | DeepSeek / OpenAI |
| tax-calculator | 个税计算器 | — |

> 五个项目共享统一的 AI 架构，API Key 通过环境变量一次配置、全局生效。

---

## 快速开始

```powershell
# 克隆
git clone https://github.com/keatemorishita-svg/ata.git
cd ata

# 一键保存
.\ata.ps1 save

# 一键恢复
.\ata.ps1 restore

# AI 洞察（需配置 API Key）
$env:DEEPSEEK_API_KEY = "your-key"
.\ata.ps1 insight

# 其他命令
.\ata.ps1 log           # 快照历史
.\ata.ps1 diff          # 对比变化
.\ata.ps1 install       # 开机自启 + 定时保存
```

---

## AI 洞察引擎

内置三层分析，provider 可切换：

| 层 | 触发 | 内容 |
|---|---|---|
| 即时 | 每次保存 | 1-2 句工作总结 |
| 每日 | 每天首次恢复 | 3-5 句今日简报 + vs 昨天对比 |
| 每周 | 每周日晚 | 工作模式报告 + 优化建议 |

**Provider 切换**：编辑 `%APPDATA%\ATA\config.json`

```json
{
  "deepseek": {
    "enabled": true,
    "provider": "deepseek",
    "apiKey": ""
  }
}
```

将 `provider` 改为 `"openai"` 即切换至 OpenAI，其余代码不动。

---

## 项目结构

```
ata/
├── README.md                     ← 你在这里
├── PROJECT_STATEMENT.md          ← 项目愿景与完整架构
├── ANA_BRIDGE.md                 ← ANA ↔ ATA 桥接设计
├── DEEPSEEK_INSIGHT.md           ← AI 洞察引擎设计
├── ECOSYSTEM_ARCHITECTURE.md     ← 五项目生态全景
├── LOG_ROLLBACK.md               ← 日志与回滚系统
├── ATA_INTERFACES.md             ← 预留接口与预见性设计
├── STORYBOARD_SOP.md             ← 30 镜头分镜 SOP
├── ata.ps1                       ← CLI 入口
├── ATA.bat                       ← 桌面一键脚本
├── ata-logo.ico                  ← Logo
├── schema/
│   └── snapshot-v1.0.json        ← 快照 JSON Schema
├── src/
│   ├── Window.ps1                ← Win32 API 封装
│   ├── Monitor.ps1               ← 显示器检测
│   ├── Snapshot.ps1              ← 快照引擎（save）
│   ├── Restore.ps1               ← 恢复引擎（restore）
│   ├── DeepSeek.ps1              ← AI 洞察引擎
│   ├── Automation.ps1            ← 定时/开机/关机自动化
│   ├── AnaBridge.ps1             ← Obsidian 桥接
│   ├── Explorer.ps1              ← File Explorer 适配器
│   └── adapters/                 ← 应用适配器目录
│       └── Explorer.ps1
├── hooks/                        ← 钩子脚本目录
└── examples/
```

---

## 路线图

| Phase | 目标 | 状态 |
|---|---|---|
| Phase 1 | 保存引擎（窗口枚举 · JSON 快照） | ✅ 完成 |
| Phase 2 | 恢复引擎（应用启动 · 窗口归位 · 回滚） | ✅ 完成 |
| Phase 3 | AI 洞察 + 自动化 + Explorer 适配器 | 🟡 进行中 |
| Phase 4 | 五项目事件总线 + ANA 桥接 | ⬜ 规划中 |
| Phase 5 | C# / .NET 原生应用 + 托盘图标 + WPF | ⬜ 规划中 |
| Phase 6 | macOS / Linux + 云同步 | ⬜ 远期 |

---

## 许可证

MIT © 2026

---

*ATA = Atlas Time Archive = 承载时间的档案。关机时天不塌，开机时一切归位。*
