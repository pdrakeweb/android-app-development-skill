# start-emulator.ps1 -- start one Android emulator with its window on screen.
#
# Use this instead of calling emulator.exe yourself on Windows. An emulator launched from a shell
# opens off the right edge and above the top of the display, every time (see
# fit-emulator-windows.ps1). This starts it detached, places its window as soon as it exists,
# waits for Android to boot, places it again, and fails if it is not fully on screen.
#
# Usage:  powershell -ExecutionPolicy Bypass -File start-emulator.ps1 -Avd Pixel10Test -Port 5554
#             [-Extra "-no-audio -no-snapshot-load"] [-TimeoutSec 300]
#
# Only the window on -Port is moved; other sessions' emulators are left alone. If an emulator is
# already running on -Port, nothing is started and its window is placed.
# Exit code: 0 booted and on screen, 1 not on screen, 2 no window or not booted in time, 3 setup.
# Windows only. For an unattended run with no window, call emulator.exe -no-window instead.
# Keep this file ASCII-only (Windows PowerShell 5.1).

param(
    [Parameter(Mandatory = $true)][string]$Avd,
    [Parameter(Mandatory = $true)][int]$Port,
    [string]$Extra = "",
    [int]$TimeoutSec = 300
)

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$emulator = Join-Path $sdk "emulator\emulator.exe"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$fit = Join-Path $PSScriptRoot "fit-emulator-windows.ps1"
foreach ($f in $emulator, $adb, $fit) { if (-not (Test-Path $f)) { "Missing: $f"; exit 3 } }
if (-not (& $emulator -list-avds | Where-Object { $_.Trim() -eq $Avd })) { "No AVD named '$Avd'."; exit 3 }

# An emulator launched while the adb daemon is down never registers with it.
& $adb start-server | Out-Null

$running = Get-Process | Where-Object { $_.ProcessName -like "qemu-system*" -and $_.MainWindowTitle -match ":$Port\s*$" }
if ($running) {
    if ($running.MainWindowTitle -notmatch "\b$([regex]::Escape($Avd)):$Port") { "Port $Port is in use by '$($running.MainWindowTitle)'."; exit 3 }
    "Already running: $($running.MainWindowTitle)"
} else {
    $arguments = "-avd $Avd -port $Port -no-boot-anim $Extra".Trim()
    "Starting: emulator $arguments"
    Start-Process -FilePath $emulator -ArgumentList $arguments -WindowStyle Minimized | Out-Null
}

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$placed = $false
$booted = $false
while ((Get-Date) -lt $deadline) {
    if (-not $placed) {
        & $fit -Port $Port | Out-Null
        $placed = ($LASTEXITCODE -ne 2)
    }
    $state = & $adb -s "emulator-$Port" shell getprop sys.boot_completed 2>$null
    if ("$state".Trim() -eq "1") { $booted = $true }
    if ($placed -and $booted) { break }
    Start-Sleep -Seconds 2
}

# The window can be resized while Android starts, so place it once more and report.
& $fit -Port $Port
$result = $LASTEXITCODE
if ($result -ne 0) { exit $result }
if (-not $booted) { "Android had not finished booting after $TimeoutSec s."; exit 2 }
"emulator-$Port is booted."
exit 0
