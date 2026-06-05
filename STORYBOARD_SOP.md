# ATA 故事脚本 · 分镜头 SOP

> 电影有分镜头剧本，软件有分镜头 SOP。
> 每一个镜头都有精确到秒的时间轴、输入、输出、检验标准。
> 拍完一个镜头，验完一条标准，才能喊"CUT"，进下一个镜头。

---

## 🎬 故事大纲（四幕剧）

```
第一幕 · 保存    "拍一张桌面照片"          Phase 1 · 3天
第二幕 · 恢复    "让昨天重新开机"          Phase 2 · 3天
第三幕 · 觉醒    "AI 理解你的工作"         Phase 3 · 2天
第四幕 · 联网    "五个项目一起呼吸"         Ecosystem · 2天
```

---

# 第一幕 · 保存 — "拍一张桌面照片"

> 时长：3 天 · 镜头数：18 个 · 总工时：~12h

---

## 场景 1-1：项目骨架就位

### 🎥 镜头 001 | 创建目录结构
| 项目 | 值 |
|---|---|
| **时长** | 120 秒 |
| **输入** | 无 |
| **输出** | 9 个目录 + 4 个 .gitkeep 文件 |
| **依赖** | 无 |

**操作**：
```powershell
# 在 D:\Hi\Projects\ata\ 下创建
mkdir src, schema, adapters, hooks, ecosystem, examples, tests, bridge, deepseek -Force
New-Item -ItemType File hooks/pre-save.d/.gitkeep, hooks/post-restore.d/.gitkeep, hooks/on-shutdown.d/.gitkeep, hooks/on-startup.d/.gitkeep -Force
```

**检验标准**：
- [ ] `Get-ChildItem -Directory D:\Hi\Projects\ata` 返回 ≥ 10 个目录
- [ ] 4 个 `.gitkeep` 文件存在于 `hooks/` 子目录下
- [ ] `D:\Hi\Projects\ata\src\` 目录存在且为空

---

### 🎥 镜头 002 | 创建配置模板
| 项目 | 值 |
|---|---|
| **时长** | 180 秒 |
| **输入** | 无 |
| **输出** | `%APPDATA%\ATA\config.json`（默认配置） |
| **依赖** | 镜头 001 |

**操作**：
```powershell
$configDir = "$env:APPDATA\ATA"
mkdir $configDir, "$configDir\snapshots", "$configDir\logs" -Force

$defaultConfig = @{
    version = "1.0.0"
    deepseek = @{
        enabled = $false
        provider = "deepseek"
        endpoint = "https://api.deepseek.com/v1/chat/completions"
        apiKey = '${DEEPSEEK_API_KEY}'
        model = "deepseek-chat"
        maxTokens = 500
        temperature = 0.3
    }
    ana = @{
        enabled = $false
        obsidianVaultPath = ""
        dailyNoteFolder = "01_Inbox/02_日常记录"
        autoWriteOnSave = $false
        autoOpenOnRestore = $false
    }
    retention = @{
        keepAllDays = 7
        keepDailyAfter = 30
        keepWeeklyAfter = 90
        deleteAfter = 365
        minimumSnapshots = 14
    }
    restore = @{
        launchDelay = 1500
        skipMissing = $true
        restoreOrder = "zOrder"
        timeout = 15
    }
    ecosystem = @{
        enabled = $false
        eventBusPath = "$env:APPDATA\Ecosystem\events"
        eventRetentionDays = 90
    }
} | ConvertTo-Json -Depth 5

# 只在不存在时创建（不覆盖已有配置）
if (-not (Test-Path "$configDir\config.json")) {
    Set-Content -Path "$configDir\config.json" -Value $defaultConfig -Encoding UTF8
}
```

**检验标准**：
- [ ] `Test-Path $env:APPDATA\ATA\config.json` 返回 `$true`
- [ ] `Get-Content $env:APPDATA\ATA\config.json | ConvertFrom-Json` 不报错
- [ ] 配置中包含 `deepseek`、`ana`、`retention`、`restore`、`ecosystem` 五个 section

---

## 场景 1-2：Windows API 封装

### 🎥 镜头 003 | Get-WindowRect — 窗口坐标获取
| 项目 | 值 |
|---|---|
| **时长** | 300 秒 |
| **输入** | 窗口句柄（HWND） |
| **输出** | `{ x, y, width, height }` |
| **依赖** | 镜头 002 |

**操作**：`src/Window.ps1` — 用 C# Add-Type 封装 `GetWindowRect`

```powershell
# Window.ps1
Add-Type @"
using System;
using System.Runtime.InteropServices;
public struct RECT {
    public int Left, Top, Right, Bottom;
}
public class Win32Window {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsZoomed(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowPlacement(IntPtr hWnd, out WINDOWPLACEMENT lpwndpl);
}

public struct WINDOWPLACEMENT {
    public int length;
    public int flags;
    public int showCmd;
    public POINT ptMinPosition;
    public POINT ptMaxPosition;
    public RECT rcNormalPosition;
}

public struct POINT {
    public int X, Y;
}
"@

function Get-WindowRect {
    param([IntPtr]$Handle)
    $rect = New-Object RECT
    [Win32Window]::GetWindowRect($Handle, [ref]$rect)
    return @{
        x      = $rect.Left
        y      = $rect.Top
        width  = $rect.Right - $rect.Left
        height = $rect.Bottom - $rect.Top
    }
}
```

**检验标准**：
- [ ] 在 PowerShell 中手动执行 `$hwnd = (Get-Process -Name notepad | Where-Object {$_.MainWindowHandle -ne 0}).MainWindowHandle; Get-WindowRect $hwnd` → 返回有效坐标
- [ ] 返回值包含 `x`, `y`, `width`, `height` 四个正整数
- [ ] 最小化窗口仍然能返回正确的还原坐标

---

### 🎥 镜头 004 | Get-WindowState — 窗口状态判断
| 项目 | 值 |
|---|---|
| **时长** | 180 秒 |
| **输入** | HWND |
| **输出** | `"normal" | "maximized" | "minimized"` |
| **依赖** | 镜头 003 |

```powershell
function Get-WindowState {
    param([IntPtr]$Handle)
    if ([Win32Window]::IsIconic($Handle))   { return "minimized" }
    if ([Win32Window]::IsZoomed($Handle))   { return "maximized" }
    return "normal"
}
```

**检验标准**：
- [ ] 最大化窗口 → 返回 `"maximized"`
- [ ] 最小化窗口 → 返回 `"minimized"`
- [ ] 正常窗口 → 返回 `"normal"`

---

### 🎥 镜头 005 | Get-WindowText + Get-WindowClass — 窗口标识
| 项目 | 值 |
|---|---|
| **时长** | 120 秒 |
| **输入** | HWND |
| **输出** | 标题字符串 + 窗口类名 |
| **依赖** | 镜头 003 |

```powershell
function Get-WindowTitle {
    param([IntPtr]$Handle)
    $sb = New-Object System.Text.StringBuilder 512
    [Win32Window]::GetWindowText($Handle, $sb, 512)
    return $sb.ToString()
}

function Get-WindowClass {
    param([IntPtr]$Handle)
    $sb = New-Object System.Text.StringBuilder 256
    [Win32Window]::GetClassName($Handle, $sb, 256)
    return $sb.ToString()
}
```

**检验标准**：
- [ ] 打开 Notepad 输入"hello"，`Get-WindowTitle` 返回 `"hello - Notepad"` 或包含 `"hello"` 的字符串
- [ ] `Get-WindowClass` 返回非空字符串

---

## 场景 1-3：显示器信息

### 🎥 镜头 006 | Get-MonitorInfo — 显示器布局
| 项目 | 值 |
|---|---|
| **时长** | 300 秒 |
| **输入** | 无 |
| **输出** | 显示器数组 `[{ index, name, bounds, dpi, primary }]` |
| **依赖** | 镜头 002 |

```powershell
# Monitor.ps1
function Get-MonitorInfo {
    $monitors = @()
    # 用 WMI 获取显示器信息
    $wmiMonitors = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue
    # 用 .NET 获取屏幕边界
    $screens = [System.Windows.Forms.Screen]::AllScreens

    for ($i = 0; $i -lt $screens.Count; $i++) {
        $screen = $screens[$i]
        # 尝试获取显示器名称（从注册表）
        $monitorName = "Monitor $($i+1)"
        # DPI 获取
        $dpi = 100  # 默认值，精确值需要通过 Win32 API 获取
        try {
            $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
            $dpiX = $g.DpiX
            $g.Dispose()
        } catch {
            $dpiX = 96  # 默认 96 DPI = 100%
        }

        $monitors += @{
            index   = $i
            name    = $monitorName
            bounds  = @{
                x = $screen.Bounds.X
                y = $screen.Bounds.Y
                w = $screen.Bounds.Width
                h = $screen.Bounds.Height
            }
            dpi     = [math]::Round($dpiX / 96 * 100)
            primary = $screen.Primary
        }
    }
    return $monitors
}
```

**检验标准**：
- [ ] 在单屏机器上返回 1 个显示器对象
- [ ] 在双屏机器上返回 2 个显示器对象，其中一个 `primary = $true`
- [ ] 每个显示器的 `bounds.w` 和 `bounds.h` 是正数

---

## 场景 1-4：主保存逻辑

### 🎥 镜头 007 | Get-ATAWindows — 枚举所有窗口
| 项目 | 值 |
|---|---|
| **时长** | 300 秒 |
| **输入** | 无 |
| **输出** | 窗口对象数组 |
| **依赖** | 镜头 003, 004, 005 |

```powershell
# Snapshot.ps1
function Get-ATAWindows {
    $windows = @()
    $windowId = 1

    $processes = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 }

    foreach ($proc in $processes) {
        $hwnd = $proc.MainWindowHandle

        # 跳过不可见窗口
        if (-not [Win32Window]::IsWindowVisible($hwnd)) { continue }

        $title = Get-WindowTitle -Handle $hwnd
        # 跳过无标题窗口（通常是后台工具）
        if ([string]::IsNullOrWhiteSpace($title)) { continue }

        $bounds = Get-WindowRect -Handle $hwnd
        $state = Get-WindowState -Handle $hwnd
        $class = Get-WindowClass -Handle $hwnd
        $cmdLine = Get-ProcessCommandLine -ProcessId $proc.Id

        # 判断平台类型
        $platform = "win32"
        if ($class -match "ApplicationFrameWindow") { $platform = "uwp" }
        if ($proc.ProcessName -match "^(Code|Discord|Slack|Notion)$") { $platform = "electron" }

        $windows += @{
            id             = "w-$($windowId.ToString('000'))"
            process        = @{
                name            = $proc.ProcessName
                pid             = $proc.Id
                commandLine     = $cmdLine
                executablePath  = $proc.Path
            }
            title          = $title
            class          = $class
            bounds         = $bounds
            state          = $state
            monitor        = $null  # 镜头 008 填入
            virtualDesktop = $null  # 镜头 009 填入
            zOrder         = $windowId
            hadFocus       = $false  # 镜头 010 填入
            restorable     = ($platform -ne "uwp")
            platform       = $platform
            adapter        = $null
            appState       = $null
        }
        $windowId++
    }
    return $windows
}
```

**检验标准**：
- [ ] 返回的数组长度 ≥ 当前打开的非系统窗口数
- [ ] 每个窗口对象包含 `id`（w-001 格式）、`process.name`、`title`、`bounds`、`state`
- [ ] 没有空标题的窗口
- [ ] 没有 `MainWindowHandle = 0` 的进程

---

### 🎥 镜头 008 | 窗口→显示器映射
| 项目 | 值 |
|---|---|
| **时长** | 180 秒 |
| **输入** | 窗口数组 + 显示器数组 |
| **输出** | 每个窗口的 `monitor` 字段被填入 |
| **依赖** | 镜头 006, 007 |

```powershell
function Resolve-WindowMonitors {
    param([array]$Windows, [array]$Monitors)

    foreach ($window in $Windows) {
        $cx = $window.bounds.x + $window.bounds.width / 2
        $cy = $window.bounds.y + $window.bounds.height / 2

        foreach ($monitor in $Monitors) {
            $mx = $monitor.bounds.x
            $my = $monitor.bounds.y
            $mw = $monitor.bounds.w
            $mh = $monitor.bounds.h

            if ($cx -ge $mx -and $cx -lt ($mx + $mw) -and
                $cy -ge $my -and $cy -lt ($my + $mh)) {
                $window.monitor = $monitor.index
                break
            }
        }
        # 兜底：默认显示器 0
        if ($null -eq $window.monitor) { $window.monitor = 0 }
    }
}
```

**检验标准**：
- [ ] 所有窗口的 `monitor` 字段都不是 `$null`
- [ ] 跨屏窗口被分配到中心点所在的显示器
- [ ] 单屏机器上所有窗口 `monitor = 0`

---

### 🎥 镜头 009 | 虚拟桌面检测（Win10+）
| 项目 | 值 |
|---|---|
| **时长** | 300 秒 |
| **输入** | 无 |
| **输出** | 虚拟桌面数组 + 每个窗口的 `virtualDesktop` |
| **依赖** | 镜头 007 |

```powershell
function Get-VirtualDesktops {
    # 需要 Win10+ 的 IVirtualDesktopManager COM 接口
    # 如果调用失败（Win7/Win8），返回单桌面
    try {
        Add-Type -Path "$env:SystemRoot\System32\VirtualDesktop.dll" -ErrorAction Stop 2>$null
        # 通过 COM 获取虚拟桌面列表（实现复杂，这里仅框架）
        # Win10+ 版本使用 IVirtualDesktopManagerInternal
        # 降级：返回默认单桌面
        return @(@{ index = 0; name = "Desktop 1" })
    } catch {
        return @(@{ index = 0; name = "Desktop 1" })
    }
}
```

**检验标准**：
- [ ] Win10+ 多桌面环境下返回 ≥ 1 个虚拟桌面
- [ ] Win7/Win8 下降级为单桌面，不报错
- [ ] Windows Server 上优雅降级

---

### 🎥 镜头 010 | 焦点窗口检测
| 项目 | 值 |
|---|---|
| **时长** | 60 秒 |
| **输入** | 窗口数组 |
| **输出** | 焦点窗口的 `hadFocus = $true` |
| **依赖** | 镜头 007 |

```powershell
function Mark-FocusedWindow {
    param([array]$Windows)
    $fgHwnd = [Win32Window]::GetForegroundWindow()
    $fgPid = 0
    [Win32Window]::GetWindowThreadProcessId($fgHwnd, [ref]$fgPid)

    foreach ($w in $Windows) {
        if ($w.process.pid -eq $fgPid) {
            $w.hadFocus = $true
            break
        }
    }
}
```

**检验标准**：
- [ ] 有且仅有一个窗口的 `hadFocus = $true`
- [ ] 焦点窗口与你当前点击的窗口一致

---

## 场景 1-5：快照组装与落盘

### 🎥 镜头 011 | Save-ATA — 主入口函数
| 项目 | 值 |
|---|---|
| **时长** | 300 秒 |
| **输入** | `-Type` (shutdown/auto/manual), `-OutputPath` (可选) |
| **输出** | 快照 JSON 文件路径 |
| **依赖** | 镜头 006-010 |

```powershell
# Save-ATA.ps1
function Save-ATA {
    param(
        [ValidateSet('shutdown','auto','manual')]
        [string]$Type = 'manual',
        [string]$OutputPath
    )

    # 1. 生成快照 ID 和路径
    $timestamp = Get-Date
    $snapshotId = "ata-$($timestamp.ToString('yyyyMMdd-HHmmss'))"
    if (-not $OutputPath) {
        $OutputPath = "$env:APPDATA\ATA\snapshots\$snapshotId.json"
    }

    # 2. 收集信息
    Write-Host "🔍 Enumerating windows..." -ForegroundColor Cyan
    $windows = Get-ATAWindows
    Write-Host "   Found $($windows.Count) windows."

    Write-Host "🖥️  Detecting monitors..." -ForegroundColor Cyan
    $monitors = Get-MonitorInfo
    Resolve-WindowMonitors -Windows $windows -Monitors $monitors
    Write-Host "   Found $($monitors.Count) monitor(s)."

    Write-Host "🖥️  Detecting virtual desktops..." -ForegroundColor Cyan
    $virtualDesktops = Get-VirtualDesktops
    Write-Host "   Found $($virtualDesktops.Count) virtual desktop(s)."

    Write-Host "🎯 Detecting focused window..." -ForegroundColor Cyan
    Mark-FocusedWindow -Windows $windows

    # 3. 组装快照
    $snapshot = @{
        version  = "1.0.0"
        snapshot = @{
            id              = $snapshotId
            created         = $timestamp.ToString("yyyy-MM-ddTHH:mm:sszzz")
            type            = $Type
            hostname        = $env:COMPUTERNAME
            anaDailyNote    = $null  # Phase 3 填入
            environment     = @{
                os               = (Get-CimInstance Win32_OperatingSystem).Caption
                monitors         = $monitors
                virtualDesktops  = $virtualDesktops
            }
            windows         = $windows
            config          = @{
                restoreOrder       = "zOrder"
                launchDelay        = 1500
                skipMissing        = $true
                openAnaDailyNote   = $false
            }
            event           = $null  # 预留
            ecosystem       = $null  # 预留
            deepseek        = $null  # 预留
        }
    }

    # 4. 写 JSON
    $snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

    # 5. 预留：写事件
    # Write-ATAEvent -Type 'snapshot.created' -Data @{ snapshotId = $snapshotId }

    Write-Host "✅ Snapshot saved: $snapshotId" -ForegroundColor Green
    Write-Host "   Path: $OutputPath" -ForegroundColor Gray
    Write-Host "   Windows: $($windows.Count) | Monitors: $($monitors.Count) | Type: $Type" -ForegroundColor Gray

    return $OutputPath
}
```

**检验标准**：
- [ ] `Save-ATA -Type manual` 执行后在 `$env:APPDATA\ATA\snapshots\` 下生成 JSON 文件
- [ ] JSON 文件可以被 `Get-Content | ConvertFrom-Json` 正确解析
- [ ] 快照中的 `windows.Count` 等于实际打开的窗口数
- [ ] 终端输出"绿色的 ✅ Snapshot saved"

---

### 🎥 镜头 012 | 快照完整性自检
| 项目 | 值 |
|---|---|
| **时长** | 120 秒 |
| **输入** | 快照 JSON 文件路径 |
| **输出** | 校验报告 |
| **依赖** | 镜头 011 |

```powershell
function Test-ATASnapshot {
    param([string]$SnapshotPath)
    $errors = @()
    $warnings = @()

    $s = Get-Content $SnapshotPath | ConvertFrom-Json

    # 必填字段检查
    if (-not $s.version) { $errors += "Missing: version" }
    if (-not $s.snapshot.id) { $errors += "Missing: snapshot.id" }
    if (-not $s.snapshot.created) { $errors += "Missing: snapshot.created" }
    if (-not $s.snapshot.environment.monitors) { $errors += "Missing: environment.monitors" }
    if (-not $s.snapshot.windows) { $errors += "Missing: windows" }
    if ($s.snapshot.windows.Count -eq 0) { $warnings += "No windows captured" }

    # 窗口字段完整性
    foreach ($w in $s.snapshot.windows) {
        if (-not $w.process.name) { $errors += "Window $($w.id): missing process.name" }
        if ($null -eq $w.monitor) { $warnings += "Window $($w.id): monitor not resolved" }
    }

    # 显示器完整性
    $primaryCount = ($s.snapshot.environment.monitors | Where-Object { $_.primary }).Count
    if ($primaryCount -ne 1) { $errors += "Expected 1 primary monitor, got $primaryCount" }

    return @{
        isValid   = ($errors.Count -eq 0)
        errors    = $errors
        warnings  = $warnings
    }
}
```

**检验标准**：
- [ ] 合法快照 → `isValid = $true`
- [ ] 缺字段快照 → `errors` 数组包含具体缺失字段名

---

## 场景 1-6：第一幕验收

### 🎥 镜头 013 | 第一幕集成测试
| 项目 | 值 |
|---|---|
| **时长** | 180 秒 |
| **输入** | 真实的桌面环境 |
| **输出** | 测试报告 |
| **依赖** | 镜头 001-012 |

**测试清单**（手动执行）：

```
场景 A · 单屏 · 5个窗口
  1. 打开 Notepad, Calculator, 2个Explorer窗口, 1个PowerShell
  2. Save-ATA -Type manual
  ✓ JSON 包含 5 个窗口
  ✓ 所有窗口 bounds 不重叠（各自在各自位置）
  ✓ 显示器数量 = 1

场景 B · 有最小化窗口
  1. 最小化 Notepad
  2. Save-ATA
  ✓ Notepad 的 state = "minimized"
  ✓ Notepad 的 bounds 是还原后的坐标（不是 0,0 或 -32000）

场景 C · 双显示器（如果有）
  1. 把一个窗口拖到副屏
  2. Save-ATA
  ✓ 该窗口的 monitor = 1
  ✓ 该窗口的 bounds.x > 主屏宽度

场景 D · 标题含特殊字符
  1. 打开一个标题含 emoji 的窗口
  2. Save-ATA
  ✓ JSON 文件是合法 UTF-8
  ✓ emoji 正确保存和显示
```

**第一幕出口标准（全部通过才进第二幕）**：
- [ ] 场景 A 全部 ✓
- [ ] 场景 B 全部 ✓
- [ ] 场景 C（如有多屏）全部 ✓
- [ ] 场景 D 全部 ✓
- [ ] 自己连续使用 `ata save` ≥ 3 天
- [ ] 生成的 JSON 能被人手工读懂

---

> 🎬 第一幕结束。喊"CUT"后先不要急着拍。确认 7 个检验标准全绿，再进第二幕。

---

# 第二幕 · 恢复 — "让昨天重新开机"

> 时长：3 天 · 镜头数：10 个 · 总工时：~10h

---

## 场景 2-1：应用启动引擎

### 🎥 镜头 014 | Get-ProcessCommandLine — 命令行获取
| 项目 | 值 |
|---|---|
| **时长** | 180 秒 |
| **输入** | PID |
| **输出** | 命令行字符串 |
| **依赖** | 第一幕完成 |

```powershell
function Get-ProcessCommandLine {
    param([int]$ProcessId)
    try {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId"
        return $process.CommandLine
    } catch {
        return $null
    }
}
```

**检验标准**：
- [ ] 对正在运行的进程返回非空命令行
- [ ] 对已退出的进程返回 `$null`（不崩溃）

---

### 🎥 镜头 015 | Start-ATAApp — 应用启动器
| 项目 | 值 |
|---|---|
| **时长** | 300 秒 |
| **输入** | 窗口对象 |
| **输出** | 启动的进程对象（或 `$null`） |
| **依赖** | 镜头 014 |

```powershell
function Start-ATAApp {
    param([hashtable]$Window, [int]$Timeout = 15)

    $name = $Window.process.name
    $cmdLine = $Window.process.commandLine

    # 检查进程是否已经在运行
    $existing = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($existing -and $existing.MainWindowHandle -ne 0) {
        Write-Host "   ⏭️  $name already running, skipping launch." -ForegroundColor Gray
        return $existing
    }

    try {
        if ($cmdLine) {
            # 用命令行启动
            $process = Start-Process -FilePath $cmdLine -PassThru -WindowStyle Normal
        } else {
            # 只用进程名启动
            $process = Start-Process -FilePath "$name.exe" -PassThru -WindowStyle Normal
        }

        # 等待窗口出现
        $waited = 0
        while ($waited -lt $Timeout) {
            Start-Sleep -Milliseconds 500
            $waited += 0.5
            $proc = Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($proc -and $proc.MainWindowHandle -ne 0) { break }
        }

        return (Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1)
    } catch {
        Write-Warning "   ❌ Failed to start $name : $_"
        return $null
    }
}
```

**检验标准**：
- [ ] 启动尚未运行的 exe → 进程启动成功
- [ ] 已运行的进程 → 跳过，返回已有进程
- [ ] 不存在的应用 → 返回 `$null` + 输出 Warning（不崩溃）
- [ ] 启动后 15 秒内窗口出现

---

## 场景 2-2：窗口归位引擎

### 🎥 镜头 016 | Set-WindowPosition — 窗口定位
| 项目 | 值 |
|---|---|
| **时长** | 180 秒 |
| **输入** | HWND + 目标 bounds + 目标 state |
| **输出** | 成功/失败 |
| **依赖** | 镜头 003 |

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32WindowEx {
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public static readonly IntPtr HWND_TOP = IntPtr.Zero;
    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const int SW_RESTORE = 9;
    public const int SW_MAXIMIZE = 3;
    public const int SW_MINIMIZE = 6;
}
"@

function Set-WindowPosition {
    param(
        [IntPtr]$Handle,
        [int]$X, [int]$Y, [int]$Width, [int]$Height,
        [string]$State = "normal"
    )

    # 先恢复窗口（如果最小化）
    if ($State -eq "maximized") {
        [Win32WindowEx]::ShowWindow($Handle, [Win32WindowEx]::SW_MAXIMIZE)
    } elseif ($State -eq "minimized") {
        [Win32WindowEx]::ShowWindow($Handle, [Win32WindowEx]::SW_MINIMIZE)
    } else {
        [Win32WindowEx]::ShowWindow($Handle, [Win32WindowEx]::SW_RESTORE)
        Start-Sleep -Milliseconds 200
        [Win32WindowEx]::SetWindowPos(
            $Handle,
            [Win32WindowEx]::HWND_TOP,
            $X, $Y, $Width, $Height,
            [Win32WindowEx]::SWP_NOZORDER -bor [Win32WindowEx]::SWP_NOACTIVATE
        )
    }
    return $true
}
```

**检验标准**：
- [ ] Notepad 窗口从 (100,100) 移动到 (500,500)，GetWindowRect 验证
- [ ] 最大化设置后 `IsZoomed` 返回 `$true`
- [ ] 最小化设置后 `IsIconic` 返回 `$true`

---

## 场景 2-3：主恢复逻辑

### 🎥 镜头 017 | Get-CoordinateMapping — 显示器适配
| 项目 | 值 |
|---|---|
| **时长** | 240 秒 |
| **输入** | 快照显示器配置 + 当前显示器配置 |
| **输出** | 坐标映射函数 |
| **依赖** | 镜头 006 |

```powershell
function Get-CoordinateMapping {
    param([array]$SavedMonitors, [array]$CurrentMonitors)

    # 如果显示器配置相同，不做映射
    if ($SavedMonitors.Count -eq $CurrentMonitors.Count) {
        $same = $true
        for ($i = 0; $i -lt $SavedMonitors.Count; $i++) {
            if ($SavedMonitors[$i].bounds.w -ne $CurrentMonitors[$i].bounds.w -or
                $SavedMonitors[$i].bounds.h -ne $CurrentMonitors[$i].bounds.h) {
                $same = $false; break
            }
        }
        if ($same) { return $null }  # null = 无需映射
    }

    # 需要映射：按比例缩放坐标
    return {
        param($x, $y, $w, $h, $monitorIndex)
        if ($monitorIndex -ge $CurrentMonitors.Count) { $monitorIndex = 0 }
        $cur = $CurrentMonitors[$monitorIndex]
        # Clamp 到当前屏幕范围内
        $newX = [math]::Max($cur.bounds.x, [math]::Min($x, $cur.bounds.x + $cur.bounds.w - $w))
        $newY = [math]::Max($cur.bounds.y, [math]::Min($y, $cur.bounds.y + $cur.bounds.h - $h))
        return @{ x = $newX; y = $newY }
    }.GetNewClosure()
}
```

**检验标准**：
- [ ] 双屏→单屏：窗口被 clamp 到可见区域内
- [ ] 相同显示器：返回 `$null`（无需映射）
- [ ] 4K→1080p：窗口坐标不会超出 1920×1080

---

### 🎥 镜头 018 | Restore-ATA — 主入口函数
| 项目 | 值 |
|---|---|
| **时长** | 600 秒 |
| **输入** | `-SnapshotPath` 或 `-Date` |
| **输出** | 恢复报告 |
| **依赖** | 镜头 014-017 |

```powershell
# Restore-ATA.ps1
function Restore-ATA {
    param(
        [string]$SnapshotPath,
        [string]$Date,
        [switch]$DryRun,
        [switch]$SkipMissing,
        [int]$Timeout = 15
    )

    # 1. 解析快照
    if ($Date) {
        $SnapshotPath = Resolve-ATASnapshot -Date $Date
        if (-not $SnapshotPath) {
            Write-Error "No snapshot found for date: $Date"
            return
        }
    }
    if (-not $SnapshotPath) {
        # 默认取最近快照
        $SnapshotPath = Get-LatestSnapshot
    }

    Write-Host "📂 Loading snapshot: $SnapshotPath" -ForegroundColor Cyan
    $data = Get-Content $SnapshotPath | ConvertFrom-Json

    # 2. 显示器检测
    $currentMonitors = Get-MonitorInfo
    $savedMonitors = $data.snapshot.environment.monitors
    $mapper = Get-CoordinateMapping -SavedMonitors $savedMonitors -CurrentMonitors $currentMonitors

    if ($mapper) {
        Write-Host "⚠️  Monitor configuration changed. Coordinates will be adapted." -ForegroundColor Yellow
    }

    if ($DryRun) {
        Write-DryRunReport -Snapshot $data -Mapper $mapper
        return
    }

    # 3. 按 zOrder 排序后逐个恢复
    $windows = $data.snapshot.windows | Sort-Object { $_.zOrder }
    $results = @{ total = $windows.Count; success = 0; failed = 0; skipped = 0; details = @() }

    Write-Host "🔄 Restoring $($windows.Count) windows..." -ForegroundColor Cyan

    foreach ($window in $windows) {
        if (-not $window.restorable) {
            Write-Host "   ⏭️  $($window.process.name) (UWP, not restorable)" -ForegroundColor Gray
            $results.skipped++
            continue
        }

        # 启动应用
        Write-Host "   🚀 Starting $($window.process.name)..." -ForegroundColor Gray
        $proc = Start-ATAApp -Window $window -Timeout $Timeout

        if (-not $proc) {
            if ($SkipMissing) {
                Write-Host "   ⚠️  $($window.process.name) not found, skipped." -ForegroundColor Yellow
                $results.skipped++
            } else {
                Write-Host "   ❌ $($window.process.name) failed to start." -ForegroundColor Red
                $results.failed++
            }
            $results.details += @{ window = $window.id; app = $window.process.name; status = "failed" }
            continue
        }

        # 窗口归位
        Start-Sleep -Milliseconds $data.snapshot.config.launchDelay
        $hwnd = $proc.MainWindowHandle
        if ($hwnd -ne 0) {
            if ($mapper) {
                $mapped = & $mapper $window.bounds.x $window.bounds.y $window.bounds.w $window.bounds.h $window.monitor
                $x = $mapped.x; $y = $mapped.y
            } else {
                $x = $window.bounds.x; $y = $window.bounds.y
            }
            Set-WindowPosition -Handle $hwnd -X $x -Y $y -Width $window.bounds.w -Height $window.bounds.h -State $window.state
        }

        $results.success++
        $results.details += @{ window = $window.id; app = $window.process.name; status = "success" }
    }

    # 4. 恢复焦点窗口
    $focusWindow = $windows | Where-Object { $_.hadFocus } | Select-Object -First 1
    if ($focusWindow) {
        $proc = Get-Process -Name $focusWindow.process.name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc) {
            [Win32WindowEx]::SetForegroundWindow($proc.MainWindowHandle)
        }
    }

    # 5. 输出报告
    Write-Host "`n✅ Restore complete: $($results.success)/$($results.total) succeeded" -ForegroundColor Green
    if ($results.skipped -gt 0) {
        Write-Host "   ⏭️  Skipped: $($results.skipped)" -ForegroundColor Yellow
    }
    if ($results.failed -gt 0) {
        Write-Host "   ❌ Failed: $($results.failed)" -ForegroundColor Red
        foreach ($d in ($results.details | Where-Object { $_.status -eq 'failed' })) {
            Write-Host "      - $($d.app)" -ForegroundColor Red
        }
    }

    # 6. 预留：写事件 + 打开 ANA 日记
    # Write-ATAEvent -Type 'snapshot.restored' -Data @{ ... }
    # Open-ANADailyNote

    return $results
}
```

**检验标准**：
- [ ] 从 Phase 1 生成的快照恢复 → 成功 ≥ 80% 的窗口
- [ ] `-DryRun` 输出"将要恢复哪些窗口"的清单元数据
- [ ] 大多数应用的窗口位置偏差 ≤ 50px
- [ ] 终端输出"绿色的 ✅ Restore complete"

---

## 场景 2-4：辅助命令

### 🎥 镜头 019 | ata log + ata clean
| 项目 | 值 |
|---|---|
| **时长** | 360 秒 |
| **输入** | 用户参数 |
| **输出** | 日志列表 / 清理结果 |
| **依赖** | 镜头 011, 018 |

```powershell
# Log-ATA.ps1
function Get-ATASnapshots {
    param([string]$Date, [int]$Last = 10)
    $dir = "$env:APPDATA\ATA\snapshots"
    if (-not (Test-Path $dir)) { return @() }

    $files = Get-ChildItem $dir -Filter "ata-*.json" | Sort-Object LastWriteTime -Descending
    if ($Date) {
        $files = $files | Where-Object { $_.Name -match "ata-$Date" }
    }
    return $files | Select-Object -First $Last
}

function Invoke-ATAClean {
    param([int]$OlderThan = 30, [switch]$DryRun)
    $cutoff = (Get-Date).AddDays(-$OlderThan)
    $dir = "$env:APPDATA\ATA\snapshots"
    $toDelete = Get-ChildItem $dir -Filter "ata-*.json" | Where-Object { $_.LastWriteTime -lt $cutoff }

    if ($DryRun) {
        Write-Host "Would delete $($toDelete.Count) snapshots older than $OlderThan days:"
        $toDelete | ForEach-Object { Write-Host "  $_" }
        return
    }

    $toDelete | Remove-Item -Force
    Write-Host "✅ Deleted $($toDelete.Count) snapshots."
}
```

**检验标准**：
- [ ] `ata log` 返回最近 10 个快照（按时间倒序）
- [ ] `ata log --date 20260605` 只返回那天的快照
- [ ] `ata clean --dry-run` 列出将要删除的文件但不实际删除

---

### 🎥 镜头 020 | 第二幕集成测试
| 项目 | 值 |
|---|---|
| **时长** | 300 秒 |
| **输入** | Phase 1 生成的快照 |
| **输出** | 恢复测试报告 |
| **依赖** | 镜头 013-019 |

**测试清单**：

```
场景 E · 正常恢复（同显示器）
  1. 用昨天的快照执行 ata restore
  ✓ 所有可恢复窗口启动
  ✓ 窗口位置偏差 < 50px
  ✓ 恢复报告显示成功数/总数

场景 F · DryRun
  1. ata restore --dry-run
  ✓ 不实际启动任何窗口
  ✓ 输出清晰列出"将要启动"的应用清单

场景 G · 显示器变化（如果有条件）
  1. 拔掉副屏（或改变 DPI）
  2. ata restore
  ✓ 检测到显示器变化 + 显示 Warning
  ✓ 所有窗口都在可见区域内（没有 64000,64000 这种坐标）

场景 H · 应用不存在
  1. 快照中包含一个已卸载的应用
  2. ata restore --skip-missing
  ✓ 该应用被跳过
  ✓ 其他窗口正常恢复
  ✓ 恢复报告中它被标记为 "skipped"

场景 I · 恢复焦点
  1. ata restore
  ✓ 恢复完成后，焦点落在快照中 hadFocus 的窗口上
```

**第二幕出口标准（全部通过才进第三幕）**：
- [ ] 场景 E-H 全部通过
- [ ] 自己连续使用 `ata save` + `ata restore` ≥ 3 个工作日
- [ ] 不再需要手动打开任何一个被快照记录的窗口

---

> 🎬 第二幕结束。第一幕的"拍照片"+ 第二幕的"冲印照片"= 核心闭环完成。

---

# 第三幕 · 觉醒 — "AI 理解你的工作"

> 时长：2 天 · 镜头数：6 个 · 总工时：~8h

---

### 🎥 镜头 021 | DeepSeek API 连接器（120s）
### 🎥 镜头 022 | 即时洞察（300s）
### 🎥 镜头 023 | 关机钩子注册（300s）
### 🎥 镜头 024 | 开机对话框（600s）
### 🎥 镜头 025 | ANA 桥接写日记（420s）
### 🎥 镜头 026 | 第三幕集成测试（300s）

*(第三幕细节在第二幕验收通过后展开——基于真实快照数据调整 Prompt 和触发时机)*

---

# 第四幕 · 联网 — "五个项目一起呼吸"

> 时长：2 天 · 镜头数：4 个 · 总工时：~6h

---

### 🎥 镜头 027 | Ecosystem 目录初始化（180s）
### 🎥 镜头 028 | 事件写入 JSONL（300s）
### 🎥 镜头 029 | 跨项目配置合并（300s）
### 🎥 镜头 030 | 第四幕集成测试（180s）

---

## 📊 总计

| 幕 | 镜头数 | 工时 | 累计工时 |
|---|---|---|---|
| 第一幕 · 保存 | 13 | 12h | 12h |
| 第二幕 · 恢复 | 7 | 10h | 22h |
| 第三幕 · 觉醒 | 6 | 8h | 30h |
| 第四幕 · 联网 | 4 | 6h | 36h |
| **合计** | **30** | **36h** | |

---

## 🎯 每一幕的"不可跳过的自检"

**第一幕自检**：你能在终端里敲 `ata save`，然后去 `%APPDATA%\ATA\snapshots\` 里看到一份你能读懂的 JSON 吗？

**第二幕自检**：你能敲 `ata restore`，去倒杯咖啡，回来发现桌面回到了昨天的样子吗？成功恢复率 ≥ 80%？

**第三幕自检**：你关机时 DeepSeek 自动生成了洞察，开机时对话框问你要不要恢复，点在"Restore"上不是一个负担，而是一个期待？

**第四幕自检**：你能在 Obsidian 的 `_Ana/ATA.md` 里看到今天的工作简报，锚点文本里有来自 show 的朋友圈文案链接？

---

*30 个镜头，36 小时，4 次"喊 CUT"验收。不跳过任何一个检验标准。*
