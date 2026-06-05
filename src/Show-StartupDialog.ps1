# Show-StartupDialog.ps1 — 开机恢复对话框（独立脚本，被 Task Scheduler 调用）
# 镜头 024 产物

$scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
. "$scriptRoot\Automation.ps1"

# 检查是否在今天已经恢复过（防止重复弹窗）
$todayMarker = "$env:APPDATA\ATA\logs\.restored-today"
if (Test-Path $todayMarker) {
    $lastRestore = Get-Content $todayMarker -Raw
    $today = (Get-Date).ToString("yyyy-MM-dd")
    if ($lastRestore -eq $today) {
        # 今天已经恢复过，静默退出
        exit 0
    }
}

# 弹窗
Show-StartupDialog

# 标记今天已恢复
(Get-Date).ToString("yyyy-MM-dd") | Set-Content $todayMarker -Force
