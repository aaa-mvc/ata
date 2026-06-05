# Window.ps1 — Windows API 封装
# ATA 项目技术根基 · 所有窗口枚举、定位、状态判断都从这里来
# 镜头 003：Get-WindowRect · 镜头 004：Get-WindowState · 镜头 005：Get-WindowTitle + Get-WindowClass

# ============================================================
# C# Add-Type：一次性注入所有 Win32 API
# ============================================================
$csharpCode = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

[StructLayout(LayoutKind.Sequential)]
public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

[StructLayout(LayoutKind.Sequential)]
public struct POINT {
    public int X;
    public int Y;
}

[StructLayout(LayoutKind.Sequential)]
public struct WINDOWPLACEMENT {
    public int length;
    public int flags;
    public int showCmd;
    public POINT ptMinPosition;
    public POINT ptMaxPosition;
    public RECT rcNormalPosition;
}

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsZoomed(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowPlacement(IntPtr hWnd, out WINDOWPLACEMENT lpwndpl);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr hWnd);

    // 常量
    public static readonly IntPtr HWND_TOP       = IntPtr.Zero;
    public static readonly IntPtr HWND_TOPMOST   = new IntPtr(-1);

    public const uint SWP_NOSIZE         = 0x0001;
    public const uint SWP_NOMOVE         = 0x0002;
    public const uint SWP_NOZORDER       = 0x0004;
    public const uint SWP_NOACTIVATE     = 0x0010;
    public const uint SWP_SHOWWINDOW     = 0x0040;

    public const int SW_HIDE             = 0;
    public const int SW_SHOWNORMAL       = 1;
    public const int SW_SHOWMINIMIZED    = 2;
    public const int SW_SHOWMAXIMIZED    = 3;
    public const int SW_RESTORE          = 9;

    public const int GWL_EXSTYLE         = -20;
    public const uint WS_EX_TOOLWINDOW   = 0x00000080;
    public const uint WS_EX_APPWINDOW    = 0x00040000;
}
'@

Add-Type -TypeDefinition $csharpCode -ErrorAction Stop

# ============================================================
# 镜头 003：Get-WindowRect
# ============================================================
function Get-WindowRect {
    param([Parameter(Mandatory=$true)][IntPtr]$Handle)
    $rect = New-Object RECT
    [Win32]::GetWindowRect($Handle, [ref]$rect) | Out-Null
    return @{
        x      = $rect.Left
        y      = $rect.Top
        width  = $rect.Right - $rect.Left
        height = $rect.Bottom - $rect.Top
    }
}

function Get-WindowRestoreRect {
    param([Parameter(Mandatory=$true)][IntPtr]$Handle)
    $placement = New-Object WINDOWPLACEMENT
    $placement.length = [System.Runtime.InteropServices.Marshal]::SizeOf($placement)
    [Win32]::GetWindowPlacement($Handle, [ref]$placement) | Out-Null
    return @{
        x      = $placement.rcNormalPosition.Left
        y      = $placement.rcNormalPosition.Top
        width  = $placement.rcNormalPosition.Right - $placement.rcNormalPosition.Left
        height = $placement.rcNormalPosition.Bottom - $placement.rcNormalPosition.Top
    }
}

# ============================================================
# 镜头 004：Get-WindowState
# ============================================================
function Get-WindowState {
    param([Parameter(Mandatory=$true)][IntPtr]$Handle)
    if ([Win32]::IsIconic($Handle))  { return "minimized" }
    if ([Win32]::IsZoomed($Handle))  { return "maximized" }
    return "normal"
}

# ============================================================
# 镜头 005：Get-WindowTitle + Get-WindowClass
# ============================================================
function Get-WindowTitle {
    param([Parameter(Mandatory=$true)][IntPtr]$Handle)
    $len = [Win32]::GetWindowTextLength($Handle)
    if ($len -eq 0) { return "" }
    $sb = New-Object System.Text.StringBuilder ($len + 1)
    [Win32]::GetWindowText($Handle, $sb, $sb.Capacity) | Out-Null
    return $sb.ToString()
}

function Get-WindowClass {
    param([Parameter(Mandatory=$true)][IntPtr]$Handle)
    $sb = New-Object System.Text.StringBuilder 256
    [Win32]::GetClassName($Handle, $sb, $sb.Capacity) | Out-Null
    return $sb.ToString()
}

# ============================================================
# 辅助函数
# ============================================================
function Get-WindowProcessId {
    param([IntPtr]$Handle)
    $procId = [uint32]0
    [Win32]::GetWindowThreadProcessId($Handle, [ref]$procId) | Out-Null
    return $procId
}

function Get-ForegroundWindowHandle {
    return [Win32]::GetForegroundWindow()
}

function Test-IsAltTabWindow {
    param([IntPtr]$Handle)
    if (-not [Win32]::IsWindowVisible($Handle)) { return $false }
    if (-not [Win32]::IsWindowEnabled($Handle)) { return $false }
    $exStyle = [Win32]::GetWindowLong($Handle, [Win32]::GWL_EXSTYLE)
    $isTool = ($exStyle -band [Win32]::WS_EX_TOOLWINDOW) -ne 0
    $isApp  = ($exStyle -band [Win32]::WS_EX_APPWINDOW) -ne 0
    if ($isTool -and (-not $isApp)) { return $false }
    return $true
}

function Test-IsValidAppWindow {
    param([IntPtr]$Handle)
    if (-not (Test-IsAltTabWindow $Handle)) { return $false }
    $title = Get-WindowTitle -Handle $Handle
    if ([string]::IsNullOrWhiteSpace($title)) { return $false }
    $rect = Get-WindowRect -Handle $Handle
    if ($rect.width -le 0 -or $rect.height -le 0) { return $false }
    if ($rect.width -lt 50 -and $rect.height -lt 50) { return $false }
    return $true
}
