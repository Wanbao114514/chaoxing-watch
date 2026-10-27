# win-minimize.ps1 — 按窗口标题最小化/还原 Edge 或 Chrome 窗口（给 Codex 等无 computer_* 工具的 CLI 用）
#
# 用法（PowerShell 5.1 / 7 均可）：
#   powershell -NoProfile -File win-minimize.ps1 -Title "个人空间" -Action minimize
#   powershell -NoProfile -File win-minimize.ps1 -Title "个人空间" -Action restore
#   powershell -NoProfile -File win-minimize.ps1 -Action list           # 只列窗口，不动
#
# -Title 是“包含匹配”，用 bsk evaluate 读到的 document.title 即可（不要带 " - Microsoft Edge" 后缀也行）。
# 输出一行 JSON，方便 agent 解析：{"found":true,"hwnd":123,"title":"...","action":"minimize","iconic":true}
param(
    [string]$Title = "",
    [ValidateSet('minimize', 'restore', 'list')]
    [string]$Action = 'minimize',
    [string[]]$ProcessName = @('msedge', 'chrome')
)

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WinMin {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
}
"@

$pids = @()
foreach ($n in $ProcessName) {
    $pids += (Get-Process -Name $n -ErrorAction SilentlyContinue).Id
}
$pids = $pids | Sort-Object -Unique

$found = New-Object System.Collections.ArrayList
$cb = [WinMin+EnumProc]{
    param($h, $l)
    if ([WinMin]::IsWindowVisible($h)) {
        $procId = [uint32]0
        [void][WinMin]::GetWindowThreadProcessId($h, [ref]$procId)
        if ($pids -contains $procId) {
            $sb = New-Object System.Text.StringBuilder 512
            [void][WinMin]::GetWindowText($h, $sb, 512)
            $t = $sb.ToString()
            if ($t) { [void]$found.Add([pscustomobject]@{ Hwnd = $h; Title = $t }) }
        }
    }
    return $true
}
[void][WinMin]::EnumWindows($cb, [IntPtr]::Zero)

if ($Action -eq 'list') {
    $found | ForEach-Object {
        "{0}`t{1}`ticonic={2}" -f $_.Hwnd, $_.Title, [WinMin]::IsIconic($_.Hwnd)
    }
    exit 0
}

if (-not $Title) {
    Write-Output '{"found":false,"error":"missing -Title"}'
    exit 1
}

$hit = $found | Where-Object { $_.Title -like "*$Title*" } | Select-Object -First 1
if (-not $hit) {
    Write-Output ('{"found":false,"error":"no window title contains: ' + $Title.Replace('"', "'") + '"}')
    exit 2
}

$cmd = if ($Action -eq 'minimize') { 6 } else { 9 }   # SW_MINIMIZE / SW_RESTORE
[void][WinMin]::ShowWindow($hit.Hwnd, $cmd)
Start-Sleep -Milliseconds 300
$iconic = [WinMin]::IsIconic($hit.Hwnd)

$out = '{"found":true,"hwnd":' + [int64]$hit.Hwnd + ',"action":"' + $Action + '","iconic":' + $iconic.ToString().ToLower() + ',"title":"' + $hit.Title.Replace('"', "'") + '"}'
Write-Output $out
