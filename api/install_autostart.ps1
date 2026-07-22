# EEG API — Windows oturum açılışında otomatik başlatmayı kurar / kaldırır.
#
# Kurulum:   powershell -ExecutionPolicy Bypass -File install_autostart.ps1
# Kaldırma:  powershell -ExecutionPolicy Bypass -File install_autostart.ps1 -Uninstall
#
# Startup watchdog her 2 dk API + USB adb reverse kontrol eder (yönetici gerekmez).

param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$ApiDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnsureScript = Join-Path $ApiDir 'ensure_running.ps1'
$WatchdogScript = Join-Path $ApiDir 'watchdog.ps1'
$StartupDir = [Environment]::GetFolderPath('Startup')
$ShortcutPath = Join-Path $StartupDir 'EEG_API.lnk'
$TaskName = 'EEG_API_EnsureRunning'

function Stop-EegWatchdog {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like '*watchdog.ps1*' } |
        ForEach-Object {
            try {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            } catch {
                # ignore
            }
        }
}

function Remove-Autostart {
    Stop-EegWatchdog

    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host "Startup kısayolu silindi: $ShortcutPath"
    }

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Zamanlanmış görev silindi: $TaskName"
    }
}

if ($Uninstall) {
    Remove-Autostart
    Write-Host "EEG API otomatik başlatma kaldırıldı."
    exit 0
}

if (-not (Test-Path $EnsureScript)) {
    throw "ensure_running.ps1 bulunamadı: $EnsureScript"
}
if (-not (Test-Path $WatchdogScript)) {
    throw "watchdog.ps1 bulunamadı: $WatchdogScript"
}

# 1) Startup kısayolu — watchdog (oturum boyunca her 2 dk)
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = 'powershell.exe'
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$WatchdogScript`""
$shortcut.WorkingDirectory = $ApiDir
$shortcut.WindowStyle = 7
$shortcut.Description = 'EEG API + adb reverse watchdog'
$shortcut.Save()
Write-Host "Startup kısayolu oluşturuldu: $ShortcutPath (watchdog)"

# 2) Zamanlanmış görev (opsiyonel; bazı PC'lerde erişim engeli olabilir)
try {
    $action = New-ScheduledTaskAction `
        -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$EnsureScript`"" `
        -WorkingDirectory $ApiDir

    $triggers = @(
        (New-ScheduledTaskTrigger -AtLogOn),
        (New-ScheduledTaskTrigger -Once -At ((Get-Date).Date.AddMinutes(1)) `
            -RepetitionInterval (New-TimeSpan -Minutes 2) `
            -RepetitionDuration (New-TimeSpan -Days 3650))
    )

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $triggers `
        -Settings $settings `
        -Principal $principal `
        -Description 'EEG API + USB adb reverse (Emotiv Cortex köprüsü)' | Out-Null

    Write-Host "Zamanlanmış görev kuruldu: $TaskName"
} catch {
    Write-Host "Zamanlanmış görev atlandı (watchdog yeterli): $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Şimdi bir kez başlatılıyor..."
& $EnsureScript

Stop-EegWatchdog
Start-Process -FilePath 'powershell.exe' `
    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$WatchdogScript`"" `
    -WorkingDirectory $ApiDir `
    -WindowStyle Hidden

Write-Host "Watchdog arka planda calisiyor (her 2 dk API + adb reverse)."
Write-Host "Flutter: .\run_device.ps1  veya  EEG_Mobil icinde flutter run"
Write-Host "Kaldırmak için: .\install_autostart.ps1 -Uninstall"
