# fit-emulator-windows.ps1 -- put every Android emulator window where a person can use it.
#
# Emulators started from a shell can open partly off screen, and taller than the usable area, so
# the bottom row of the phone screen (where sign-in pages keep their buttons) is behind the
# taskbar. This moves every emulator window inside the primary monitor's working area, side by
# side, at full usable height, keeping each window's aspect ratio, and prints where they ended up.
#
# Usage:  powershell -ExecutionPolicy Bypass -File fit-emulator-windows.ps1
# Windows only. Run it after the emulators have booted. Emulators started with -no-window have
# no window and are skipped. Keep this file ASCII-only (Windows PowerShell 5.1).

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win2 {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
"Working area (screen minus taskbar): $area"
$height = $area.Height - 20
$x = $area.Left + 20
foreach ($p in (Get-Process | Where-Object { $_.ProcessName -like "qemu-system*" -and $_.MainWindowHandle -ne 0 } | Sort-Object MainWindowTitle)) {
    $r = New-Object Win2+RECT
    [void][Win2]::GetWindowRect($p.MainWindowHandle, [ref]$r)
    $ratio = ($r.Right - $r.Left) / ($r.Bottom - $r.Top)
    $width = [int]($height * $ratio)
    [void][Win2]::SetWindowPos($p.MainWindowHandle, [IntPtr]::Zero, $x, $area.Top + 5, $width, $height, 0x0004)
    Start-Sleep -Milliseconds 500
    [void][Win2]::GetWindowRect($p.MainWindowHandle, [ref]$r)
    "  '{0}' now at {1},{2} size {3}x{4} (bottom edge {5})" -f $p.MainWindowTitle, $r.Left, $r.Top, ($r.Right - $r.Left), ($r.Bottom - $r.Top), $r.Bottom
    $x += $width + 30
}
