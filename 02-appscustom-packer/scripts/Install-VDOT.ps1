# Debug mode parameter - kann beim Aufruf überschrieben werden
param(
    [bool]$DebugMode = $false
)

New-Item -ItemType Directory -Path "C:\InstallLogs" -Force | Out-Null
$log = "C:\InstallLogs\install-vdot.log"
$vdotTemp = "$env:TEMP\VDOT"
$vdotZip = "$vdotTemp\vdot.zip"
$vdotUrl = "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip"

Write-Output "[INFO] Lade aktuelles VDOT von GitHub..." | Tee-Object -Append $log

New-Item -ItemType Directory -Force -Path $vdotTemp | Out-Null

# Robustere Download-Logik
try {
    Invoke-WebRequest -Uri $vdotUrl -OutFile $vdotZip -UseBasicParsing -TimeoutSec 60
    Write-Output "[INFO] VDOT ZIP erfolgreich heruntergeladen." | Tee-Object -Append $log
} catch {
    Write-Output "[ERROR] Fehler beim Herunterladen von $vdotUrl : $_" | Tee-Object -Append $log
    throw "Download von VDOT fehlgeschlagen."
}

# ZIP entpacken
try {
    Expand-Archive -Path $vdotZip -DestinationPath $vdotTemp -Force
    Write-Output "[INFO] VDOT ZIP entpackt." | Tee-Object -Append $log
} catch {
    Write-Output "[ERROR] Fehler beim Entpacken: $_" | Tee-Object -Append $log
    throw "Entpacken der VDOT-ZIP fehlgeschlagen."
}

# Pfad zur entpackten Datei (GitHub packt in Unterordner)
$vdotScript = Get-ChildItem -Recurse -Path $vdotTemp -Filter Windows_VDOT.ps1 | Select-Object -First 1

if ($vdotScript) {
    Write-Output "[INFO] VDOT-Skript gefunden: $($vdotScript.FullName)" | Tee-Object -Append $log
    try {
        & $vdotScript.FullName -AcceptEula -Optimizations All | Tee-Object -Append $log
    } catch {
        Write-Output "[ERROR] Fehler bei der Ausführung von VDOT: $_" | Tee-Object -Append $log
        throw "VDOT-Skript konnte nicht ausgeführt werden."
    }
} else {
    Write-Output "[ERROR] Windows_VDOT.ps1 nicht gefunden!" | Tee-Object -Append $log
    throw "VDOT-Skript nicht gefunden"
}

# Debug-Wartephase für Packer Debugging (kann über RunCommand beendet werden)
if ($DebugMode) {
    Write-Output "[INFO] Warte auf manuelles Fortsetzen..." | Tee-Object -Append $log
    $waitMarker = "C:\packer-continue.txt"
    while (-not (Test-Path $waitMarker)) {
        Start-Sleep -Seconds 60
    }
    Write-Output "[INFO] Fortsetzung erkannt: $waitMarker vorhanden." | Tee-Object -Append $log
}

# Optional: Temp-Verzeichnis löschen
if (-not $DebugMode) {
    Remove-Item -Path $vdotTemp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "[INFO] Temporäre Dateien entfernt." | Tee-Object -Append $log
}
