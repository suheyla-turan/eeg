@echo off
REM EEG API'yi (gerekirse) baslat — cift tik yeterli.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure_running.ps1"
