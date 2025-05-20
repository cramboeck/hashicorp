# Debug-Modus aktivieren
$DebugMode = $false

$logFolder = "C:\InstallLogs"
$logFile = Join-Path $logFolder ("optimize-" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

function Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$level] $message"
    Write-Output $entry
    Add-Content -Path $logFile -Value $entry
}

Log "Starte AVD-Optimierung..."

# Beispielaufgabe: Aufgabenplanungseinträge deaktivieren
$tasksToDisable = @( "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                     "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
                     "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" )

foreach ($task in $tasksToDisable) {
    try {
        Log "Deaktiviere geplante Aufgabe: $task"
        Disable-ScheduledTask -TaskPath ($task -replace '[^\\]+$', '\\') -TaskName ($task -split '\\')[-1] -ErrorAction Stop
    } catch {
        Log "Fehler beim Deaktivieren von $task : $_" "ERROR"
    }
}

# Beispiel: Dienste bereinigen
try {
    Log "Bereinige temporäre Dateien..."
    Get-ChildItem -Path $env:TEMP -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Log "Temporäre Dateien und Papierkorb geleert."
} catch {
    Log "Fehler beim Bereinigen temporärer Dateien: $_" "ERROR"
}

Log "AVD-Optimierung abgeschlossen."

# Optional: Debug-Wartephase
if ($DebugMode) {
    Log "Warte auf Fortsetzung durch Datei: C:\packer-continue.txt"
    while (-not (Test-Path "C:\packer-continue.txt")) {
        Start-Sleep -Seconds 60
    }
    Log "Fortsetzungsmarker erkannt, fahre fort."
}

if (-not $DebugMode) {
    Log "Entferne temporäre Logverzeichnisse..."
    Remove-Item -Path $logFolder -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Log "Debug-Modus aktiv, Logs bleiben erhalten."
}
