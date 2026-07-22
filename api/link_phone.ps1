# Telefon (USB) -> PC API :8000 tüneli. Flutter hot restart / Yeniden Baglan sonrasi calisir.
$Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $Adb)) {
    Write-Error "adb bulunamadi: $Adb"
    exit 1
}
& $Adb reverse tcp:8000 tcp:8000
& $Adb reverse --list
Write-Host "Tamam. Telefonda Ayarlar > Yeniden Baglan veya uygulamayi hot restart et."
