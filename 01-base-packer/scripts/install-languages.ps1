<#
.Author: Christoph Ramböck
.Description: Installs Windows language packs based on JSON list in C:\Install\languages.json.
.Date: 2025-05-22
#>

[CmdletBinding()]
param ()

function Write-Log {
    param (
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO"
    )
    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Write-Output "[$timestamp][$Level] $Message"
}

# Load JSON
$jsonPath = "C:\Install\languages.json"
if (-not (Test-Path $jsonPath)) {
    Write-Log "Language definition file not found: $jsonPath" "ERROR"
    exit 1
}

try {
    $languageData = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
    $Global:LanguageCodes = $languageData.languages
} catch {
    Write-Log "Failed to parse JSON: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Validate language codes
foreach ($code in $Global:LanguageCodes) {
    if ($code -notmatch "^[a-z]{2}-[A-Z]{2}$") {
        Write-Log "Invalid language code in JSON: '$code'" "ERROR"
        exit 1
    }
}

function Install-LanguagePack {
    BEGIN {
        $workingDirectory = "C:\Install"
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Log "Language installation started." "INFO"

        # Disable scheduled tasks that could interfere
        Write-Log "Disabling interfering scheduled tasks..." "INFO"
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\MUI\" -TaskName "LPRemove" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "Uninstallation" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "Installation" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "ReconcileLanguageResources" -ErrorAction SilentlyContinue

        # Registry fix
        try {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Control Panel\International" -Force | Out-Null
            New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Control Panel\International" `
                             -Name "BlockCleanupOfUnusedPreinstalledLangPacks" `
                             -Value 1 -PropertyType DWORD -Force | Out-Null
            Write-Log "Registry key set to block cleanup of unused language packs." "INFO"
        } catch {
            Write-Log "Failed to set registry key: $($_.Exception.Message)" "WARN"
        }
    }

    PROCESS {
        foreach ($lang in $Global:LanguageCodes) {
            $success = $false
            for ($attempt = 1; $attempt -le 5; $attempt++) {
                try {
                    Write-Log "Installing language pack: '$lang' (Attempt $attempt)..." "INFO"
                    Install-Language -Language $lang -Force -ErrorAction Stop
                    Write-Log "Language pack '$lang' installed successfully." "INFO"
                    $success = $true
                    break
                } catch {
                    Write-Log "Attempt $attempt failed for '$lang': $($_.Exception.Message)" "WARN"
                    Start-Sleep -Seconds 3
                }
            }

            if (-not $success) {
                Write-Log "Failed to install language pack '$lang' after 5 attempts." "ERROR"
                exit 1
            }
        }
    }

    END {
        Write-Log "Re-enabling scheduled tasks..." "INFO"
        Enable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "Installation" -ErrorAction SilentlyContinue
        Enable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "ReconcileLanguageResources" -ErrorAction SilentlyContinue

        $timer.Stop()
        Write-Log "Language pack installation completed in $($timer.Elapsed.TotalMinutes.ToString("0.00")) minutes." "INFO"
        Write-Log "Script finished with Exit Code: $LASTEXITCODE" "INFO"
        exit 0
    }
}

# Start installation
Install-LanguagePack
