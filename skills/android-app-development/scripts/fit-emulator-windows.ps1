# fit-emulator-windows.ps1 -- put Android emulator windows fully on screen, and prove it.
#
# Emulators started from a shell can open partly off screen, and taller than the usable area, so
# the bottom row of the phone screen (where sign-in pages keep their buttons) is behind the
# taskbar. The saved window.x / window.y in emulator-user.ini is not honoured, and the emulator
# has no position option. This moves windows inside the primary monitor's working area, keeps
# each window's aspect ratio, and prints where they ended up.
#
# Usage:  powershell -ExecutionPolicy Bypass -File fit-emulator-windows.ps1 [-Port 5560[,5562]] [-Check]
#
#   (no -Port)  arrange every emulator window side by side. Moves other sessions' windows too.
#   -Port       move only these; go to the right of the others if there is room, else overlap.
#   -Check      move nothing; only report.
#
# Exit code: 0 every window in scope is fully on screen, 1 at least one is not, 2 none found.
# Windows only. start-emulator.ps1 calls this for you. Emulators started with -no-window have no
# window and are skipped. Keep this file ASCII-only (Windows PowerShell 5.1).

# A string, split here: -File does not parse arrays, and [int] reads "5560,5562" as 55605562.
param([string]$Port = "", [switch]$Check)
$Ports = @($Port -split "[,s]+" | Where-Object { $_ } | ForEach-Object { [int]$_ })

Add-Type -AssemblyName System.Windows.Forms
if (-not ("EmuWin" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class EmuWin {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowPlacement(IntPtr h, ref PLACEMENT p);
    [DllImport("user32.dll")] public static extern bool SetWindowPlacement(IntPtr h, ref PLACEMENT p);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct PLACEMENT { public int Length, Flags, ShowCmd; public POINT Min, Max; public RECT Normal; }
}
"@
}

$Toolbar = 60    # the emulator's side toolbar is a separate window on the right of the main one
$Margin = 20
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

# A minimized window reports a parked position, so use where it will reopen. It stays minimized.
function Get-Placement($handle) {
    $p = New-Object EmuWin+PLACEMENT
    $p.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($p)
    [void][EmuWin]::GetWindowPlacement($handle, [ref]$p)
    $p
}
function Get-Rect($handle) {
    if ([EmuWin]::IsIconic($handle)) { return (Get-Placement $handle).Normal }
    $r = New-Object EmuWin+RECT
    [void][EmuWin]::GetWindowRect($handle, [ref]$r)
    $r
}
function Test-Inside($r) {
    $r.Left -ge $area.Left -and $r.Top -ge $area.Top -and $r.Right -le $area.Right -and $r.Bottom -le $area.Bottom
}
function Move-Window($w, [int]$x, [int]$width, [int]$height) {
    if ([EmuWin]::IsIconic($w.Handle)) {
        $p = Get-Placement $w.Handle
        $n = New-Object EmuWin+RECT
        $n.Left = $x; $n.Top = $area.Top + 5; $n.Right = $x + $width; $n.Bottom = $area.Top + 5 + $height
        $p.Normal = $n
        $p.ShowCmd = 7   # minimized, not activated
        [void][EmuWin]::SetWindowPlacement($w.Handle, [ref]$p)
        return
    }
    # 0x0014 = keep the z-order and do not take keyboard focus from the person
    [void][EmuWin]::SetWindowPos($w.Handle, [IntPtr]::Zero, $x, ($area.Top + 5), $width, $height, 0x0014)
    Start-Sleep -Milliseconds 500
    # The emulator rounds the size to its own aspect ratio; pull it back in if that pushed it out.
    $r = Get-Rect $w.Handle
    $dx = [Math]::Max(0, $r.Right - $area.Right)
    $dy = [Math]::Max(0, $r.Bottom - $area.Bottom)
    if ($dx -or $dy) {
        $left = [Math]::Max($area.Left, $r.Left - $dx)
        $top = [Math]::Max($area.Top, $r.Top - $dy)
        [void][EmuWin]::SetWindowPos($w.Handle, [IntPtr]::Zero, $left, $top, 0, 0, 0x0015)
        Start-Sleep -Milliseconds 200
    }
}

$all = @(Get-Process | Where-Object { $_.ProcessName -like "qemu-system*" -and $_.MainWindowHandle -ne 0 } |
    ForEach-Object {
        $r = Get-Rect $_.MainWindowHandle
        $p = 0
        if ($_.MainWindowTitle -match ':(\d+)\s*$') { $p = [int]$Matches[1] }
        $h = [Math]::Max(1, $r.Bottom - $r.Top)
        New-Object PSObject -Property @{
            Title = $_.MainWindowTitle; Port = $p; Handle = $_.MainWindowHandle
            Ratio = ($r.Right - $r.Left) / $h; Rect = $r
        }
    } | Sort-Object Port)
$mine = @($all | Where-Object { -not $Ports -or $Ports -contains $_.Port })

"Working area (screen minus taskbar): $($area.Width) x $($area.Height) at $($area.Left),$($area.Top)"
if ($mine.Count -eq 0) { "No emulator window found$(if ($Ports) { " on port $($Ports -join ', ')" })."; exit 2 }

if (-not $Check) {
    $fullHeight = $area.Height - 20
    $usable = $area.Width - 2 * $Margin
    if ($Ports) {
        foreach ($w in $mine) {
            $height = [int][Math]::Min($fullHeight, ($usable - $Toolbar) / $w.Ratio)
            $width = [int]($height * $w.Ratio)
            $x = $area.Left + $Margin
            foreach ($o in ($all | Where-Object { $_.Handle -ne $w.Handle })) {
                $or = Get-Rect $o.Handle
                if (Test-Inside $or) { $x = [Math]::Max($x, $or.Right + $Toolbar) }
            }
            $x = [Math]::Max($area.Left, [Math]::Min($x, $area.Right - $width - $Toolbar))
            Move-Window $w $x $width $height
        }
    } else {
        $ratios = ($mine | Measure-Object Ratio -Sum).Sum
        $height = [int][Math]::Min($fullHeight, ($usable - $Toolbar * $mine.Count) / $ratios)
        $x = $area.Left + $Margin
        foreach ($w in $mine) {
            $width = [int]($height * $w.Ratio)
            Move-Window $w $x $width $height
            $x += $width + $Toolbar
        }
    }
}

$bad = 0
foreach ($w in $mine) {
    $r = Get-Rect $w.Handle
    $ok = Test-Inside $r
    if (-not $ok) { $bad++ }
    "  {0,-10} '{1}' at {2},{3} size {4}x{5}{6}" -f $(if ($ok) { "on screen" } else { "OFF SCREEN" }), $w.Title, $r.Left, $r.Top, ($r.Right - $r.Left), ($r.Bottom - $r.Top), $(if ([EmuWin]::IsIconic($w.Handle)) { " when reopened (minimized now)" })
}
if ($bad) { exit 1 }
exit 0
