###############################################################################
# AVD Image Update Script (PowerShell)
# Vereinfacht den Prozess zum Aktualisieren von Azure Virtual Desktop Images
###############################################################################

#Requires -Version 5.1

# Error handling
$ErrorActionPreference = "Stop"

# Banner
function Show-Banner {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║                                                               ║" -ForegroundColor Blue
    Write-Host "║     Azure Virtual Desktop - Image Update Tool                ║" -ForegroundColor Blue
    Write-Host "║     Powered by Terraform & Packer                            ║" -ForegroundColor Blue
    Write-Host "║                                                               ║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
}

# Ausgabe-Funktionen
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[✓] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[✗] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# Prüfe ob Tool installiert ist
function Test-Tool {
    param([string]$ToolName)

    $tool = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($tool) {
        Write-Success "$ToolName ist installiert ($($tool.Source))"
        return $true
    }
    else {
        Write-ErrorMsg "$ToolName ist NICHT installiert!"
        return $false
    }
}

# Prüfe Prerequisites
function Test-Prerequisites {
    Write-Info "Prüfe erforderliche Tools..."
    Write-Host ""

    $allOk = $true

    if (-not (Test-Tool "terraform")) { $allOk = $false }
    if (-not (Test-Tool "packer")) { $allOk = $false }
    if (-not (Test-Tool "az")) { $allOk = $false }

    Write-Host ""

    if (-not $allOk) {
        Write-ErrorMsg "Nicht alle erforderlichen Tools sind installiert!"
        Write-Host ""
        Write-Info "Installation:"
        Write-Host "  - Terraform: https://www.terraform.io/downloads"
        Write-Host "  - Packer:    https://www.packer.io/downloads"
        Write-Host "  - Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    }

    Write-Success "Alle erforderlichen Tools sind vorhanden!"
    Write-Host ""
}

# Zeige Menü
function Show-Menu {
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║  Was möchten Sie tun?                                        ║" -ForegroundColor Blue
    Write-Host "╠═══════════════════════════════════════════════════════════════╣" -ForegroundColor Blue
    Write-Host "║  1) " -ForegroundColor Blue -NoNewline
    Write-Host "Monatliches Update" -ForegroundColor Green -NoNewline
    Write-Host " (03-monthly-packer)                  ║" -ForegroundColor Blue
    Write-Host "║     → Schnellstes Update: Windows Updates + Software Updates ║" -ForegroundColor Blue
    Write-Host "║     → Nutzt vorhandenes Golden Image als Basis               ║" -ForegroundColor Blue
    Write-Host "║                                                               ║" -ForegroundColor Blue
    Write-Host "║  2) " -ForegroundColor Blue -NoNewline
    Write-Host "Neues App-Layer Image" -ForegroundColor Yellow -NoNewline
    Write-Host " (02-appscustom-packer)          ║" -ForegroundColor Blue
    Write-Host "║     → Software-Installation + Optimierungen                   ║" -ForegroundColor Blue
    Write-Host "║     → Nutzt Base Image als Grundlage                          ║" -ForegroundColor Blue
    Write-Host "║                                                               ║" -ForegroundColor Blue
    Write-Host "║  3) " -ForegroundColor Blue -NoNewline
    Write-Host "Vollständiger Rebuild" -ForegroundColor Red -NoNewline
    Write-Host " (Base + Apps)                     ║" -ForegroundColor Blue
    Write-Host "║     → Kompletter Neuaufbau von Grund auf                      ║" -ForegroundColor Blue
    Write-Host "║     → Base Image (01) → App Layer (02)                        ║" -ForegroundColor Blue
    Write-Host "║                                                               ║" -ForegroundColor Blue
    Write-Host "║  4) " -ForegroundColor Blue -NoNewline
    Write-Host "Infrastruktur aktualisieren" -ForegroundColor Cyan -NoNewline
    Write-Host " (Terraform)               ║" -ForegroundColor Blue
    Write-Host "║     → AVD Host Pool, Workspace, SIG ändern                    ║" -ForegroundColor Blue
    Write-Host "║                                                               ║" -ForegroundColor Blue
    Write-Host "║  0) Beenden                                                   ║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
}

# Prüfe Azure Login
function Test-AzureLogin {
    Write-Info "Prüfe Azure Login Status..."

    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Success "Angemeldet als: $($account.name)"
            return $true
        }
    }
    catch {
        Write-Warning "Nicht bei Azure angemeldet!"
        Write-Info "Starte Azure Login..."
        az login
        return $?
    }
}

# Monatliches Update
function Start-MonthlyUpdate {
    Write-Info "Starte monatliches Image-Update..."
    Write-Host ""

    Push-Location 03-monthly-packer

    try {
        Write-Info "Initialisiere Packer..."
        packer init .

        Write-Info "Validiere Packer Konfiguration..."
        packer validate .

        Write-Info "Starte Image-Build (dies kann 30-60 Minuten dauern)..."
        packer build avd-monthly-image.pkr.hcl

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Monatliches Update erfolgreich abgeschlossen!"
            Write-Info "Neue Image-Version wurde in Shared Image Gallery gespeichert"
        }
        else {
            throw "Packer Build fehlgeschlagen!"
        }
    }
    catch {
        Write-ErrorMsg "Build fehlgeschlagen: $_"
        Write-ErrorMsg "Prüfen Sie die Logs oben."
    }
    finally {
        Pop-Location
    }
}

# App Layer Build
function Start-AppLayerBuild {
    Write-Info "Starte App-Layer Image-Build..."
    Write-Host ""

    Push-Location 02-appscustom-packer

    try {
        Write-Info "Initialisiere Packer..."
        packer init .

        Write-Info "Validiere Packer Konfiguration..."
        packer validate .

        Write-Info "Starte Image-Build (dies kann 60-90 Minuten dauern)..."
        packer build avd-image.pkr.hcl

        if ($LASTEXITCODE -eq 0) {
            Write-Success "App-Layer Build erfolgreich abgeschlossen!"
            Write-Info "Neue Image-Version wurde in Shared Image Gallery gespeichert"
        }
        else {
            throw "Packer Build fehlgeschlagen!"
        }
    }
    catch {
        Write-ErrorMsg "Build fehlgeschlagen: $_"
        Write-ErrorMsg "Prüfen Sie die Logs oben."
    }
    finally {
        Pop-Location
    }
}

# Base Image Build
function Start-BaseBuild {
    Write-Info "Starte Base Image-Build..."
    Write-Host ""

    Push-Location 01-base-packer

    try {
        Write-Info "Initialisiere Packer..."
        packer init .

        Write-Info "Validiere Packer Konfiguration..."
        packer validate .

        Write-Info "Starte Base Image-Build (dies kann 45-75 Minuten dauern)..."
        packer build avd-base-image.pkr.hcl

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Base Image Build erfolgreich abgeschlossen!"
        }
        else {
            throw "Packer Build fehlgeschlagen!"
        }
    }
    catch {
        Write-ErrorMsg "Build fehlgeschlagen: $_"
        Write-ErrorMsg "Prüfen Sie die Logs oben."
    }
    finally {
        Pop-Location
    }
}

# Vollständiger Rebuild
function Start-FullRebuild {
    Write-Warning "Vollständiger Rebuild wird gestartet..."
    Write-Info "Dies kann 2-3 Stunden dauern!"
    Write-Host ""

    $confirm = Read-Host "Möchten Sie fortfahren? (j/N)"
    if ($confirm -ne "j" -and $confirm -ne "J") {
        Write-Info "Abgebrochen."
        return
    }

    Write-Host ""
    Write-Info "Phase 1/2: Base Image Build"
    Start-BaseBuild

    Write-Host ""
    Write-Info "Phase 2/2: App Layer Build"
    Start-AppLayerBuild

    Write-Success "Vollständiger Rebuild abgeschlossen!"
}

# Terraform Update
function Start-TerraformUpdate {
    Write-Info "Terraform Infrastruktur-Update..."
    Write-Host ""

    Push-Location 00-avd-terraform

    try {
        if (-not (Test-Path "terraform.tfvars")) {
            Write-ErrorMsg "terraform.tfvars nicht gefunden!"
            Write-Info "Bitte erstellen Sie die Datei basierend auf terraform.tfvars.example"
            return
        }

        Write-Info "Initialisiere Terraform..."
        terraform init

        Write-Info "Formatiere Terraform Dateien..."
        terraform fmt -recursive

        Write-Info "Validiere Terraform Konfiguration..."
        terraform validate

        Write-Info "Erstelle Terraform Plan..."
        terraform plan -out=tfplan

        Write-Host ""
        $confirm = Read-Host "Möchten Sie diese Änderungen anwenden? (j/N)"
        if ($confirm -eq "j" -or $confirm -eq "J") {
            Write-Info "Wende Terraform Plan an..."
            terraform apply tfplan
            Remove-Item tfplan -ErrorAction SilentlyContinue
            Write-Success "Infrastruktur erfolgreich aktualisiert!"
        }
        else {
            Write-Info "Terraform Apply abgebrochen."
            Remove-Item tfplan -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-ErrorMsg "Terraform Fehler: $_"
    }
    finally {
        Pop-Location
    }
}

# Hauptprogramm
function Main {
    Show-Banner

    # Prüfe Prerequisites
    Test-Prerequisites

    # Prüfe Azure Login (nur Warnung, kein Exit)
    try {
        Test-AzureLogin | Out-Null
    }
    catch {
        Write-Warning "Azure Login fehlgeschlagen, aber fortfahren..."
    }
    Write-Host ""

    while ($true) {
        Show-Menu
        $choice = Read-Host "Ihre Wahl [0-4]"
        Write-Host ""

        switch ($choice) {
            "1" {
                Start-MonthlyUpdate
                Write-Host ""
                Read-Host "Drücken Sie Enter um fortzufahren" | Out-Null
            }
            "2" {
                Start-AppLayerBuild
                Write-Host ""
                Read-Host "Drücken Sie Enter um fortzufahren" | Out-Null
            }
            "3" {
                Start-FullRebuild
                Write-Host ""
                Read-Host "Drücken Sie Enter um fortzufahren" | Out-Null
            }
            "4" {
                Start-TerraformUpdate
                Write-Host ""
                Read-Host "Drücken Sie Enter um fortzufahren" | Out-Null
            }
            "0" {
                Write-Info "Auf Wiedersehen!"
                exit 0
            }
            default {
                Write-ErrorMsg "Ungültige Auswahl! Bitte wählen Sie 0-4."
                Start-Sleep -Seconds 2
            }
        }
    }
}

# Starte Hauptprogramm
Main
