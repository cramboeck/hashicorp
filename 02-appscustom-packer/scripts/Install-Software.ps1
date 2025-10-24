# Debug mode parameter - kann beim Aufruf überschrieben werden
param(
    [bool]$DebugMode = $false
)

# === Setup logging ===
$logFolder = "C:\InstallLogs"
$logFile = Join-Path $logFolder ("install-software_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log")
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

Write-Log "Software installation started."

# === Ensure Chocolatey is installed ===
$chocoExe = "C:\ProgramData\chocolatey\bin\choco.exe"
if (-not (Test-Path $chocoExe)) {
    Write-Log "Chocolatey not found. Installing..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        $script = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $script
        Write-Log "Chocolatey installed."
        Start-Sleep -Seconds 10
    } catch {
        Write-Log "Chocolatey install failed: $_" "ERROR"
        exit 1
    }
} else {
    Write-Log "Chocolatey is already installed."
}

# === Software packages to install ===
$packages = @(
    "7zip",
  #  "greenshot",
    "adobereader",
    "foxitreader",
    "splashtop-business",
    "citrix-workspace",
    "pdf24"
)

foreach ($pkg in $packages) {
    Write-Log "Installing $pkg..."

    try {
        if ($pkg -eq "greenshot") {
         $cmd = $chocoExe + ' install greenshot --params "/NoStartup" --install-arguments "/VERYSILENT" -y --no-progress'
        } else {
            $cmd = "$chocoExe install $pkg -y --no-progress"
        }

        Write-Log "Running command: $cmd"
        $output = Invoke-Expression $cmd 2>&1
        Write-Log "$pkg output:`n$output"

        if ($pkg -eq "greenshot") {
            Write-Log "Terminating Greenshot process (if running)..."
            Stop-Process -Name "Greenshot" -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Log "Error during $pkg install: $_" "ERROR"
    }

    Start-Sleep -Seconds 5
}

Write-Log "All installations completed."

# === Optional: Packer debug wait ===
if ($DebugMode) {
    Write-Log "Waiting for marker file to continue: C:\packer-continue.txt"
    while (-not (Test-Path "C:\packer-continue.txt")) {
        Start-Sleep -Seconds 60
    }
    Write-Log "Marker detected. Continuing."
}

# === Optional: Cleanup ===
if (-not $DebugMode) {
    Write-Log "Cleaning up logs..."
    Remove-Item $logFolder -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Log "Debug mode: logs preserved."
}

Write-Log "Script finished."
