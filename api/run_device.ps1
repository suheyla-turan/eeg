# API'yi garantiye al + USB tüneli kur + Flutter'i cihazda baslat.
# Kullanim:  powershell -ExecutionPolicy Bypass -File .\run_device.ps1
# Opsiyonel: .\run_device.ps1 -DeviceId 2312FPCA6G

param(
    [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'
$ApiDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ApiDir
$FlutterDir = Join-Path $RootDir 'EEG_Mobil'
$EnsureScript = Join-Path $ApiDir 'ensure_running.ps1'

Write-Host '=== EEG API + adb reverse ==='
& $EnsureScript

if (-not (Test-Path $FlutterDir)) {
    throw "Flutter klasoru bulunamadi: $FlutterDir"
}

Set-Location $FlutterDir
Write-Host '=== flutter run ==='
if ($DeviceId) {
    flutter run -d $DeviceId
} else {
    flutter run
}
