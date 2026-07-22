# EEG API watchdog — oturum boyunca her 2 dk ensure_running (API + adb reverse).
# Arka planda calisir; pencere gizli baslatilir.

$ErrorActionPreference = 'Continue'
$ApiDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnsureScript = Join-Path $ApiDir 'ensure_running.ps1'
$IntervalSec = 120

while ($true) {
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $EnsureScript
    } catch {
        # ensure_running kendi loguna yazar
    }
    Start-Sleep -Seconds $IntervalSec
}
