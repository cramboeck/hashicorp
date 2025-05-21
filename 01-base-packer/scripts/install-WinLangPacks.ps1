<#
.SYNOPSIS
    Installs additional language packs during a Packer build using the built-in Install-Language cmdlet.

.DESCRIPTION
    This script installs a predefined set of Windows language packs and sets the preferred system language.
    All steps are logged to the console for real-time output during provisioning.

.PARAMETER DeployMode
    Optional. If set to "Silent", the script runs without user interaction.
#>

param (
    [ValidateSet("Silent", "Interactive")]
    [string]$DeployMode = "Silent"
)

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logline = "$timestamp [$Level] $Message"
    Write-Host $logline
}

Write-Log "Starting language pack installation process..."

# Define languages to be installed
$languages = @("de-DE","nl-nl")
$preferredLanguage = "de-de"

foreach ($lang in $languages) {
    try {
        Write-Log "Installing language: $lang"
        Install-Language -Language $lang -CopyToSettings -Force
        Write-Log "Language $lang installed successfully."
    } catch {
        Write-Log "Failed to install language $lang. Exception: $_" "ERROR"
    }
}

# Set system-wide preferred language
try {
    Write-Log "Applying $preferredLanguage as the default system language..."
    Set-WinUILanguageOverride -Language $preferredLanguage
    Set-WinUserLanguageList -LanguageList $preferredLanguage -Force
    Set-WinSystemLocale $preferredLanguage
    Set-Culture $preferredLanguage
    Set-WinHomeLocation -GeoId 94  # Germany
    Write-Log "System language configuration completed."
} catch {
    Write-Log "Failed to configure the system language. Exception: $_" "ERROR"
}

Write-Log "Language pack installation process completed."
