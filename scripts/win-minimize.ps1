# win-minimize.ps1 - close / minimize / restore / inspect an Edge or Chrome window.
# (for CLIs such as Codex that have no computer_* tools)
#
# Usage (PowerShell 5.1 / 7):
#   powershell -NoProfile -File win-minimize.ps1 -Hwnd 12345 -Action close      # close by exact hwnd (no focus needed)
#   powershell -NoProfile -File win-minimize.ps1 -Hwnd 12345 -Action status
#   powershell -NoProfile -File win-minimize.ps1 -Title "<document.title>" -Action status
#   powershell -NoProfile -File win-minimize.ps1 -Title "<document.title>" -Action minimize
#   powershell -NoProfile -File win-minimize.ps1 -Title "<document.title>" -Action restore
#   powershell -NoProfile -File win-minimize.ps1 -Action list                  # list windows only
#
# -Hwnd targets one exact window and skips title matching entirely: prefer it whenever
#   you already recorded the hwnd (e.g. the cold-start "normal" window that has to go).
# -Title is a substring match and refuses to guess when several windows match.
#
# Output is one JSON line so an agent can parse it:
#   {"found":true,"hwnd":123,"title":"...","action":"close","closed":true}
#   {"found":true,"hwnd":123,"title":"...","action":"status","iconic":false}
#   {"found":false,"error":"ambiguous","count":2,"hits":[...],"hint":"..."}   <- refuses to guess
#
# Exit codes: 0=ok  1=missing -Title/-Hwnd  2=no such window (or wrong process)
#             3=ambiguous title match (nothing was touched)  4=close failed (window still alive)
#
# Design notes:
#   * Closing posts WM_CLOSE to the exact hwnd instead of synthesizing Alt+F4: no focus
#     change is needed, so a stray keystroke can never land on the Agent Window (which
#     would kill the browser and disconnect bsk).
#   * -Hwnd is validated against -ProcessName, so a typo cannot close an unrelated app.
#   * Comments and literals in this file are intentionally ASCII-only. PowerShell 5.1
#     decodes a BOM-less .ps1 with the ANSI code page, and CJK comments can swallow the
#     next line and produce bogus parser errors. Keep it ASCII, or re-save as UTF-8 with BOM.
param(
    [string]$Title = "",
    [int64]$Hwnd = 0,
    [ValidateSet('minimize', 'restore', 'status', 'close', 'list')]
    [string]$Action = 'minimize',
    [string[]]$ProcessName = @('msedge', 'chrome')
)

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
} catch {
    # Older hosts / constrained language mode may refuse this; keep the default encoding.
}

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WinMin {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
}
"@

function Out-Json($obj) {
    Write-Output ($obj | ConvertTo-Json -Compress -Depth 5)
}

function Get-TitleOf([IntPtr]$h) {
    $sb = New-Object System.Text.StringBuilder 512
    [void][WinMin]::GetWindowText($h, $sb, 512)
    return $sb.ToString()
}

function Get-ProcNameOf([IntPtr]$h) {
    $procId = [uint32]0
    [void][WinMin]::GetWindowThreadProcessId($h, [ref]$procId)
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if ($p) { return $p.ProcessName }
    return ''
}

# ---- list: enumerate every visible window of the watched processes ---------
if ($Action -eq 'list') {
    $pids = @()
    foreach ($n in $ProcessName) {
        $pids += (Get-Process -Name $n -ErrorAction SilentlyContinue).Id
    }
    $pids = $pids | Sort-Object -Unique

    $all = New-Object System.Collections.ArrayList
    $cb = [WinMin+EnumProc]{
        param($h, $l)
        if ([WinMin]::IsWindowVisible($h)) {
            $procId = [uint32]0
            [void][WinMin]::GetWindowThreadProcessId($h, [ref]$procId)
            if ($pids -contains $procId) {
                $t = Get-TitleOf $h
                if ($t) { [void]$all.Add([pscustomobject]@{ Hwnd = $h; Title = $t }) }
            }
        }
        return $true
    }
    [void][WinMin]::EnumWindows($cb, [IntPtr]::Zero)

    $all | ForEach-Object {
        "{0}`t{1}`ticonic={2}" -f $_.Hwnd, $_.Title, [WinMin]::IsIconic($_.Hwnd)
    }
    exit 0
}

# ---- resolve the target window --------------------------------------------
$hit = $null

if ($Hwnd -ne 0) {
    $h = [IntPtr]$Hwnd
    if (-not [WinMin]::IsWindow($h)) {
        Out-Json @{ found = $false; error = "no window with hwnd $Hwnd"; action = $Action }
        exit 2
    }
    $procName = Get-ProcNameOf $h
    if ($ProcessName -notcontains $procName) {
        Out-Json @{
            found  = $false
            error  = "hwnd $Hwnd belongs to process '$procName', expected one of: $($ProcessName -join ', ')"
            action = $Action
        }
        exit 2
    }
    $hit = [pscustomobject]@{ Hwnd = $h; Title = (Get-TitleOf $h) }
}
else {
    if (-not $Title) {
        Out-Json @{ found = $false; error = 'missing -Title or -Hwnd' }
        exit 1
    }

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
                $t = Get-TitleOf $h
                if ($t) { [void]$found.Add([pscustomobject]@{ Hwnd = $h; Title = $t }) }
            }
        }
        return $true
    }
    [void][WinMin]::EnumWindows($cb, [IntPtr]::Zero)

    $hits = @($found | Where-Object { $_.Title -like "*$Title*" })

    if ($hits.Count -eq 0) {
        Out-Json @{
            found      = $false
            error      = "no window title contains: $Title"
            candidates = @($found | ForEach-Object { $_.Title })
            action     = $Action
        }
        exit 2
    }

    if ($hits.Count -gt 1) {
        Out-Json @{
            found  = $false
            error  = 'ambiguous'
            count  = $hits.Count
            hits   = @($hits | ForEach-Object { [pscustomobject]@{ hwnd = $_.Hwnd; title = $_.Title; iconic = [WinMin]::IsIconic($_.Hwnd) } })
            hint   = 'multiple windows match -Title; nothing was changed. Narrow -Title, or pass -Hwnd.'
            action = $Action
        }
        exit 3
    }

    $hit = $hits[0]
}

# ---- act -------------------------------------------------------------------
if ($Action -eq 'status') {
    Out-Json @{
        found  = $true
        hwnd   = [int64]$hit.Hwnd
        action = 'status'
        iconic = [WinMin]::IsIconic($hit.Hwnd)
        title  = $hit.Title
    }
    exit 0
}

if ($Action -eq 'close') {
    # A minimized window still accepts WM_CLOSE; no need to restore it first.
    [void][WinMin]::PostMessage($hit.Hwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)   # WM_CLOSE

    $closed = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 100
        if (-not [WinMin]::IsWindow($hit.Hwnd)) { $closed = $true; break }
    }

    Out-Json @{
        found  = $true
        hwnd   = [int64]$hit.Hwnd
        action = 'close'
        closed = $closed
        title  = $hit.Title
    }
    if ($closed) { exit 0 } else { exit 4 }
}

$cmd = if ($Action -eq 'minimize') { 6 } else { 9 }   # SW_MINIMIZE / SW_RESTORE
[void][WinMin]::ShowWindow($hit.Hwnd, $cmd)
Start-Sleep -Milliseconds 300
$iconic = [WinMin]::IsIconic($hit.Hwnd)

Out-Json @{
    found  = $true
    hwnd   = [int64]$hit.Hwnd
    action = $Action
    iconic = $iconic
    title  = $hit.Title
}
exit 0
