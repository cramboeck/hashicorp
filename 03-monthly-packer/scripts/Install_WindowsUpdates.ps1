# Enable debug mode
$DebugMode = $true

# === Setup logging ===
$logFolder = "C:\InstallLogs"
$logFile = Join-Path $logFolder ("windows-updates_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "MM-dd-yyyy HH:mm:ss.fff"
    $entry = "<$timestamp> [$Level] $Message"
    Write-Output $entry
    $entry | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-Log "Windows Update script started."

# Load Windows Update COM object
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    Write-Log "Searching for available updates..."
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
} catch {
    Write-Log "Error accessing Windows Update service: $_" "ERROR"
    exit 1
}

if ($searchResult.Updates.Count -eq 0) {
    Write-Log "No updates found. System is up to date."
} else {
    Write-Log "$($searchResult.Updates.Count) update(s) found."
    $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

    foreach ($update in $searchResult.Updates) {
        Write-Log "Adding update: $($update.Title)"
        $updatesToInstall.Add($update) | Out-Null
    }

    $downloader = $updateSession.CreateUpdateDownloader()
    $downloader.Updates = $updatesToInstall
    Write-Log "Downloading updates..."
    $downloadResult = $downloader.Download()

    if ($downloadResult.ResultCode -ne 2) {
        Write-Log "Download failed. Result code: $($downloadResult.ResultCode)" "ERROR"
        exit 1
    }

    Write-Log "Download complete. Installing updates..."
    $installer = $updateSession.CreateUpdateInstaller()
    $installer.Updates = $updatesToInstall
    $installationResult = $installer.Install()

    Write-Log "Installation result code: $($installationResult.ResultCode)"
    Write-Log "$($installationResult.Updates.Count) updates installed."

    if ($installationResult.RebootRequired) {
        Write-Log "[WARNING] Reboot is required to complete installation." "WARNING"
    } else {
        Write-Log "[SUCCESS] No reboot required."
    }
}

# === Optional: Debug wait
if ($DebugMode) {
    Write-Log "Waiting for marker file to continue: C:\packer-continue.txt"
    while (-not (Test-Path "C:\packer-continue.txt")) {
        Start-Sleep -Seconds 60
    }
    Write-Log "Marker file detected. Continuing..."
}

# === Cleanup if not in debug mode
if (-not $DebugMode) {
    Write-Log "Cleaning up logs..."
    Remove-Item -Path $logFolder -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Log "Debug mode active, logs retained."
}

Write-Log "Windows Update script completed."
