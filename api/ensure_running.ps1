# EEG API — already running? leave it; otherwise start in background.
# Also refreshes USB adb reverse (tcp:8000) when a phone is connected.
# Emotiv Launcher + Cortex must be open; this only starts the Python bridge.

$ErrorActionPreference = 'Stop'
$ApiDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Port = 8000
$LogDir = Join-Path $ApiDir 'logs'
$LogFile = Join-Path $LogDir 'api_autostart.log'

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    } catch {
        # ignore log failures
    }
}

function Test-ApiListening {
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -ne $conn) { return $true }
        return $false
    } catch {
        return $false
    }
}

function Test-ApiHealthy {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -UseBasicParsing
        if ($r.StatusCode -eq 200) { return $true }
        return $false
    } catch {
        return $false
    }
}

function Ensure-AdbReverse {
    $Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (-not (Test-Path $Adb)) {
        Write-Log 'adb: SDK platform-tools bulunamadi, reverse atlandi.'
        return
    }

    $deviceLines = & $Adb devices 2>$null |
        Where-Object { $_ -match '\tdevice$' }
    if (-not $deviceLines) {
        Write-Log 'adb: bagli cihaz yok, reverse atlandi.'
        return
    }

    try {
        & $Adb reverse "tcp:$Port" "tcp:$Port" 2>$null | Out-Null
        Write-Log "adb reverse tcp:$Port ok ($($deviceLines.Count) cihaz)."
    } catch {
        Write-Log "adb reverse basarisiz: $($_.Exception.Message)"
    }
}

$apiAlreadyOk = $false

if (Test-ApiHealthy) {
    Write-Log 'API already running (health OK).'
    $apiAlreadyOk = $true
} elseif (Test-ApiListening) {
    Write-Log "Port $Port is listening but /health failed; leaving process alone."
    $apiAlreadyOk = $true
} else {
    $venvPython = Join-Path $ApiDir '.venv\Scripts\python.exe'
    if (Test-Path $venvPython) {
        $Python = $venvPython
    } else {
        $cmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $cmd) {
            $cmd = Get-Command py -ErrorAction SilentlyContinue
        }
        if ($cmd) {
            $Python = $cmd.Source
        } else {
            $Python = $null
        }
    }

    if (-not $Python) {
        Write-Log 'ERROR: python not found.'
        Ensure-AdbReverse
        exit 1
    }

    $server = Join-Path $ApiDir 'api_server.py'
    if (-not (Test-Path $server)) {
        Write-Log "ERROR: api_server.py missing: $server"
        Ensure-AdbReverse
        exit 1
    }

    Write-Log "Starting API: $Python $server"
    $proc = Start-Process -FilePath $Python `
        -ArgumentList "`"$server`"" `
        -WorkingDirectory $ApiDir `
        -WindowStyle Minimized `
        -PassThru

    $ok = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-ApiHealthy) {
            $ok = $true
            break
        }
    }

    if ($ok) {
        Write-Log "API ready (PID $($proc.Id))."
    } else {
        Write-Log "WARN: API started (PID $($proc.Id)) but /health not OK yet."
    }
}

# USB tüneli her kontrolde yenilenir (cihaz yeniden takılınca / adb reset sonrası).
Ensure-AdbReverse

if (-not $apiAlreadyOk -and -not (Test-ApiHealthy)) {
    exit 0
}
exit 0
