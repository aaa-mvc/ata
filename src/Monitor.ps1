# Monitor.ps1 — 显示器信息获取
# 镜头 006：Get-MonitorInfo — 枚举所有显示器、分辨率、DPI、主屏标记

Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
Add-Type -AssemblyName System.Drawing -ErrorAction Stop

function Get-MonitorInfo {
    $monitors = @()
    $screens = [System.Windows.Forms.Screen]::AllScreens

    # 尝试通过 WMI 获取显示器友好名称
    $wmiNames = @{}
    try {
        $wmiIds = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorID -ErrorAction Stop
        if ($wmiIds) {
            $idx = 0
            foreach ($wm in $wmiIds) {
                $name = "Monitor $($idx + 1)"
                try {
                    $bytes = $wm.UserFriendlyName
                    if ($bytes -and $bytes.Count -gt 0) {
                        $decoded = [System.Text.Encoding]::ASCII.GetString($bytes).Trim([char]0)
                        if (-not [string]::IsNullOrWhiteSpace($decoded)) {
                            $name = $decoded
                        }
                    }
                }
                catch { }
                $wmiNames[$idx] = $name
                $idx++
            }
        }
    }
    catch {
        # WMI 不可用 → 静默降级，使用默认名称 "Monitor N"
    }

    # 获取 DPI
    $dpiX = 96
    try {
        $graphics = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
        if ($graphics) {
            $dpiX = $graphics.DpiX
            $graphics.Dispose()
        }
    }
    catch {
        $dpiX = 96
    }
    $dpiPercent = [math]::Round($dpiX / 96 * 100)

    for ($i = 0; $i -lt $screens.Count; $i++) {
        $screen = $screens[$i]
        $name = "Monitor $($i + 1)"
        if ($wmiNames -and $wmiNames.ContainsKey($i)) {
            $name = $wmiNames[$i]
        }

        $monitors += @{
            index    = $i
            name     = $name
            bounds   = @{
                x = $screen.Bounds.X
                y = $screen.Bounds.Y
                w = $screen.Bounds.Width
                h = $screen.Bounds.Height
            }
            dpi      = $dpiPercent
            primary  = $screen.Primary
            workArea = @{
                x = $screen.WorkingArea.X
                y = $screen.WorkingArea.Y
                w = $screen.WorkingArea.Width
                h = $screen.WorkingArea.Height
            }
        }
    }

    return $monitors
}

function Get-MonitorSummary {
    $monitors = Get-MonitorInfo
    $parts = @()
    foreach ($m in $monitors) {
        $tag = ""
        if ($m.primary) { $tag = " (primary)" }
        $parts += "[$($m.index)] $($m.name) $($m.bounds.w)x$($m.bounds.h)@$($m.dpi)%$tag"
    }
    return "$($monitors.Count) monitor(s): " + ($parts -join ", ")
}
