<#
.SYNOPSIS
    Installs additional language packs during a Packer build using the built-in Install-Language cmdlet.

.DESCRIPTION
    This script installs a predefined set of Windows language packs.
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
$languages = @("de-DE", "nl-NL")

foreach ($lang in $languages) {
    try {
        if (-not (Get-WinUserLanguageList | Where-Object LanguageTag -eq $lang)) {
            Write-Log "Installing language: $lang"
            Install-Language -Language $lang -CopyToSettings
            Write-Log "Language $lang installed successfully."
        } else {
            Write-Log "Language $lang is already installed. Skipping..."
        }
    } catch {
        Write-Log "Failed to install language $lang. Exception: $_" "ERROR"
    }
}

Write-Log "Language pack installation process completed."
