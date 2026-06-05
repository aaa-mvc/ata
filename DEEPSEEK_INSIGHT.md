# DeepSeek 洞察引擎设计

> ATA 不只是保存和恢复——它理解你的工作模式，并给你反馈。

---

## 一、为什么需要 AI 洞察

| 没有洞察 | 有洞察 |
|---|---|
| "上次关机前有 14 个窗口" | "这周你在 VS Code 上花了 72% 的时间，Chrome 上 23%。周五出现了新的数据库工具——新项目开始了？" |
| "恢复成功 12/14" | "Figma 连续 3 天未恢复成功，链接的文件可能已移动。建议更新路径或移除。" |
| 快照只是数据 | 快照变成了"关于你如何工作"的知识 |

**DeepSeek 的角色**：把每次保存的 JSON 快照从"死的存档"变成"活的洞察"。

---

## 二、分析层次

```
Level 1 · 即时分析（每次保存时触发）
  ├─ 输入：本次快照 vs 上次快照
  ├─ 分析：窗口增减、应用切换、桌面变化
  ├─ 输出：1-2 句话的状态变化总结
  └─ 延迟：< 2 秒

Level 2 · 每日分析（每天第一次恢复时触发）
  ├─ 输入：今日快照 + 昨日快照 + ANA 日记
  ├─ 分析：工作主题切换、效率模式、中断检测
  ├─ 输出：每日简报（写回 Obsidian 日记）
  └─ 延迟：< 5 秒

Level 3 · 每周分析（每周日晚触发）
  ├─ 输入：本周所有快照 + WeeklyManifesto
  ├─ 分析：高频应用 Top 5、工作时段分布、模式变迁
  ├─ 输出：每周工作模式报告 + 优化建议
  └─ 延迟：< 15 秒
```

---

## 三、API 集成架构

### 3.1 调用方式

```powershell
# 方式一：直接调 DeepSeek API（需要 API Key）
$DEEPSEEK_API_KEY = $env:DEEPSEEK_API_KEY
$DEEPSEEK_ENDPOINT = "https://api.deepseek.com/v1/chat/completions"

# 方式二：通过 Ollama 本地部署（零成本、离线）
$DEEPSEEK_ENDPOINT = "http://localhost:11434/v1/chat/completions"

# 方式三：通过 OpenAI 兼容接口（可替换为任何 LLM）
# 任何兼容 OpenAI Chat Completions 的端点都可以接入
```

### 3.2 配置

```json
// config.json
{
  "deepseek": {
    "enabled": true,
    "provider": "deepseek",
    "endpoint": "https://api.deepseek.com/v1/chat/completions",
    "apiKey": "${DEEPSEEK_API_KEY}",
    "model": "deepseek-chat",
    "maxTokens": 500,
    "temperature": 0.3,
    "analysisLevels": {
      "instant": true,
      "daily": true,
      "weekly": true
    },
    "cacheResults": true,
    "cacheTTL": 86400
  }
}
```

### 3.3 PowerShell 实现

```powershell
function Invoke-DeepSeekAnalysis {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,
        [string]$Level = "instant",
        [int]$MaxTokens = 500
    )

    $config = Get-ATAConfig
    $ds = $config.deepseek

    if (-not $ds.enabled) {
        Write-Verbose "DeepSeek analysis disabled in config."
        return $null
    }

    $body = @{
        model       = $ds.model
        messages    = @(
            @{ role = "system"; content = Get-SystemPrompt -Level $Level }
            @{ role = "user";   content = $Prompt }
        )
        max_tokens  = $MaxTokens
        temperature = $ds.temperature
    } | ConvertTo-Json -Depth 5

    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $($ds.apiKey)"
    }

    try {
        $response = Invoke-RestMethod `
            -Uri $ds.endpoint `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 30

        $result = $response.choices[0].message.content

        # 缓存结果
        if ($ds.cacheResults) {
            Save-InsightCache -Level $Level -Result $result
        }

        return $result
    }
    catch {
        Write-Warning "DeepSeek API call failed: $_"
        Write-Warning "Insight skipped. ATA core functions unaffected."
        return $null
    }
}
```

---

## 四、Prompt 模板

### 4.1 系统提示词（System Prompt）

```
你是 ATA 工作状态分析助手。你的角色是帮助用户理解自己的数字工作模式。

原则：
1. 简洁——即时分析不超过 2 句，每日简报不超过 5 句
2. 有用——提供可操作的观察，而不是空洞的总结
3. 诚实——不确定的就说"可能是"，不编造数据
4. 中文——始终用中文回复
5. 非侵入——你只是观察和建议，不是评判
```

### 4.2 即时分析 Prompt

```
以下是用户两次桌面快照之间的变化：

**上次快照** ({last_time})：{last_window_count} 个窗口
{last_windows_summary}

**本次快照** ({current_time})：{current_window_count} 个窗口
{current_windows_summary}

**变化**：
- 新增：{new_windows}
- 关闭：{closed_windows}
- 移动：{moved_windows}

请用 1-2 句中文总结变化。
```

### 4.3 每日分析 Prompt

```
今天是 {date}，用户刚才恢复了以下工作现场：

恢复快照：{snapshot_id}（{snapshot_time} 保存）
恢复结果：成功 {success_count}/{total_count}

今日快照应用列表：{today_apps}
昨日快照应用列表：{yesterday_apps}
今日新增应用：{new_today}
今日未恢复应用：{missing_apps}

对应的 Obsidian 日记：{daily_note_path}

请写一段 3-5 句的每日简报，包括：
1. 一个关于今天工作状态的观察
2. 和昨天的差异（如果有的话）
3. 一条轻量的建议（如果适用）
```

### 4.4 每周分析 Prompt

```
以下是用户本周（{week_start} 至 {week_end}）的工作数据：

**快照统计**：{snapshot_count} 次保存
**日均窗口**：{avg_windows_per_day} 个
**高频应用 Top 5**：{top_apps}
**工作时段分布**：{time_distribution}
**显示器配置**：使用过 {monitor_configs} 种配置
**首次恢复成功率**：{restore_success_rate}%

**与上周对比**：
{week_over_week_diff}

**WeeklyManifesto 链接**：obsidian://open?vault=Obsidian%20Vault&file=_Ana%2FWeeklyManifesto

请生成一份"本周工作模式简报"：
1. 本周工作节奏总结（1-2 句）
2. 最值得注意的变化（1 个）
3. 一条具体的优化建议
```

---

## 五、缓存与离线策略

```
缓存层级：
  ├─ Level 1（即时）：不缓存，每次都实时分析
  ├─ Level 2（每日）：缓存在 %APPDATA%\ATA\insights\daily-{date}.json，当天不重复请求
  └─ Level 3（每周）：缓存在 %APPDATA%\ATA\insights\weekly-{week}.json，本周不重复请求

离线降级：
  ├─ DeepSeek API 不可用 → 跳过 AI 分析，ATA 核心功能完全正常
  ├─ 离线时累积的快照 → 下次联网时批量分析
  └─ 本地 Ollama 作为备选（用户自行部署）
```

---

## 六、隐私设计

| 原则 | 实现 |
|---|---|
| **不上传快照全文** | 只传摘要（应用名、窗口数、时间），不传窗口标题、文件路径 |
| **本地优先** | 所有分析缓存存在本地，不依赖云端 |
| **可关闭** | `ata config set deepseek.enabled false` 一键关闭 |
| **可审计** | 每次 API 调用的请求体记录在 `ata.log`，用户可查 |
| **不传个人信息** | 主机名、用户名、文件路径不出现在 Prompt 中 |

**发送给 DeepSeek 的数据示例**（注意缺失了什么）：

```json
{
  "last_time": "2026-06-05T22:45:00",
  "last_window_count": 14,
  "last_windows_summary": "Code(2), Chrome(4), Terminal(1), Obsidian(1), Slack(1), Figma(1), WindowsTerminal(1), Explorer(2), Notion(1)",
  "current_time": "2026-06-06T23:15:00",
  "current_window_count": 14,
  "current_windows_summary": "Code(2), Chrome(4), Terminal(1), Obsidian(1), Slack(1), DataGrip(1), WindowsTerminal(1), Explorer(2), Notion(1)",
  "new_windows": ["DataGrip"],
  "closed_windows": ["Figma"],
  "moved_windows": []
}
```

**明确不发送**：
- ❌ 窗口标题（可能含项目名、文件名、网页标题）
- ❌ 命令行参数（可能含路径）
- ❌ 主机名
- ❌ 文件路径

---

## 七、CLI 命令

```powershell
# 查看洞察
ata insight                        # 最新一次洞察
ata insight --daily                # 今日简报
ata insight --weekly               # 本周报告
ata insight --diff 20260605        # 对比 6/5 和当前

# 配置 DeepSeek
ata config set deepseek.enabled true
ata config set deepseek.apiKey "sk-xxx"
ata config set deepseek.provider "ollama"     # 切换到本地 Ollama
ata config set deepseek.provider "openai"     # 切换到任何 OpenAI 兼容 API
```

---

*DeepSeek 洞察是 ATA 的"大脑皮层"——它让快照不只是存档，而是关于你工作方式的知识。*
