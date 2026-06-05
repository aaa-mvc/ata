# Explorer.ps1 — File Explorer 适配器
# 用 Shell.Application COM 接口枚举所有打开的文件夹窗口

function Get-ExplorerWindows {
    $result = @()
    try {
        $shell = New-Object -ComObject Shell.Application
        $shellWindows = $shell.Windows()
    } catch {
        Write-Verbose "Shell.Application COM not available"
        return $result
    }

    # 用 for 循环替代 foreach（COM 集合的 foreach 可能丢元素）
    for ($i = 0; $i -lt $shellWindows.Count; $i++) {
        try {
            $win = $shellWindows.Item($i)
            $name = $win.FullName
            if ($name -notmatch "explorer\.exe$") { continue }

            $folderPath = $null
            try { $folderPath = $win.Document.Folder.Self.Path } catch { continue }
            if (-not $folderPath) { continue }

            $title = $win.LocationName
            if (-not $title) { $title = Split-Path $folderPath -Leaf }

            $hwnd = $win.HWND
            if ($hwnd -eq 0) { continue }

            $result += @{
                path  = $folderPath
                hwnd  = [IntPtr]$hwnd
                title = $title
            }
        } catch { }
    }

    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shellWindows) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    return $result
}

function Open-ExplorerWindow {
    param([string]$Path)
    if (Test-Path $Path) {
        Start-Process explorer.exe -ArgumentList "`"$Path`""
        return $true
    }
    Write-Warning "Explorer path not found: $Path"
    return $false
}
