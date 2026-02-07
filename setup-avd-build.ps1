#Requires -Version 7.0
<#
.SYNOPSIS
    AVD Image Builder - Interactive Setup Script (PowerShell)

.DESCRIPTION
    Führt Sie interaktiv durch den kompletten AVD Image Build-Prozess
    - Voraussetzungen prüfen
    - Azure Login
    - Service Principal erstellen/verwenden
    - Terraform Infrastructure deployen
    - Packer Image builds

.EXAMPLE
    .\setup-avd-build.ps1

.NOTES
    Author: AVD Image Builder Team
    Version: 1.0
#>

[CmdletBinding()]
param()

# Helper Functions
function Write-ColoredMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    $prefix = switch ($Type) {
        "Info"    { "ℹ️" }
        "Success" { "✅" }
        "Warning" { "⚠️" }
        "Error"   { "❌" }
    }

    $color = switch ($Type) {
        "Info"    { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }

    Write-Host "$prefix  $Message" -ForegroundColor $color
}

function Test-CommandExists {
    param([string]$Command)

    try {
        if (Get-Command $Command -ErrorAction Stop) {
            Write-ColoredMessage "$Command ist installiert: $(( Get-Command $Command).Source)" -Type Success
            return $true
        }
    } catch {
        Write-ColoredMessage "$Command ist NICHT installiert" -Type Error
        return $false
    }
}

# Banner
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     AVD Image Builder - Interactive Setup                 ║" -ForegroundColor Cyan
Write-Host "║     Windows 11 25H2 Multisession AVD Image                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Prerequisites Check
Write-ColoredMessage "Schritt 1/10: Überprüfe Voraussetzungen..." -Type Info
Write-Host ""

$missingTools = 0

if (-not (Test-CommandExists "az")) {
    Write-ColoredMessage "Installieren Sie Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli" -Type Warning
    $missingTools++
}

if (-not (Test-CommandExists "terraform")) {
    Write-ColoredMessage "Installieren Sie Terraform: https://www.terraform.io/downloads" -Type Warning
    $missingTools++
}

if (-not (Test-CommandExists "packer")) {
    Write-ColoredMessage "Installieren Sie Packer: https://www.packer.io/downloads" -Type Warning
    $missingTools++
}

if ($missingTools -gt 0) {
    Write-ColoredMessage "Fehlende Tools müssen installiert werden. Bitte installieren Sie diese und führen Sie das Script erneut aus." -Type Error
    exit 1
}

Write-Host ""
Write-ColoredMessage "Alle benötigten Tools sind installiert!" -Type Success
Write-Host ""

# Step 2: Azure Login
Write-ColoredMessage "Schritt 2/10: Azure Login..." -Type Info
Write-Host ""

try {
    $account = az account show 2>$null | ConvertFrom-Json
} catch {
    $account = $null
}

if (-not $account) {
    Write-ColoredMessage "Sie sind nicht in Azure eingeloggt." -Type Warning
    $login = Read-Host "Möchten Sie jetzt einloggen? (y/n)"
    if ($login -eq "y") {
        az login
        $account = az account show | ConvertFrom-Json
    } else {
        Write-ColoredMessage "Azure Login erforderlich. Führen Sie 'az login' aus und starten Sie das Script neu." -Type Error
        exit 1
    }
}

Write-ColoredMessage "Eingeloggt in Azure" -Type Success
Write-ColoredMessage "Aktuelle Subscription: $($account.name)" -Type Info
Write-ColoredMessage "Subscription ID: $($account.id)" -Type Info
Write-Host ""

$useCurrentSub = Read-Host "Möchten Sie diese Subscription verwenden? (y/n)"
if ($useCurrentSub -ne "y") {
    Write-ColoredMessage "Verfügbare Subscriptions:" -Type Info
    az account list --output table
    Write-Host ""
    $subId = Read-Host "Geben Sie die gewünschte Subscription ID ein"
    az account set --subscription $subId
    $account = az account show | ConvertFrom-Json
    Write-ColoredMessage "Subscription gewechselt zu: $($account.name)" -Type Success
}

$subscriptionId = $account.id
$tenantId = $account.tenantId

Write-Host ""

# Step 3: Service Principal
Write-ColoredMessage "Schritt 3/10: Service Principal..." -Type Info
Write-Host ""

$skipTfVars = $false
if (Test-Path "00-avd-terraform/terraform.tfvars") {
    Write-ColoredMessage "terraform.tfvars existiert bereits." -Type Warning
    $overwrite = Read-Host "Möchten Sie diese Datei überschreiben? (y/n)"
    if ($overwrite -ne "y") {
        Write-ColoredMessage "Verwende existierende terraform.tfvars" -Type Info
        $skipTfVars = $true
    }
}

if (-not $skipTfVars) {
    $hasServicePrincipal = Read-Host "Haben Sie bereits einen Service Principal? (y/n)"

    if ($hasServicePrincipal -eq "y") {
        # Use existing SP
        Write-ColoredMessage "Bitte geben Sie Ihre Service Principal Daten ein:" -Type Info
        $clientId = Read-Host "Client ID (App ID)"
        $clientSecret = Read-Host "Client Secret (Password)" -AsSecureString
        $clientSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret))
        Write-ColoredMessage "Service Principal Daten erfasst" -Type Success
    } else {
        # Create new SP
        Write-ColoredMessage "Erstelle neuen Service Principal..." -Type Info
        $spName = "avd-image-builder-sp-$(Get-Date -Format 'yyyyMMddHHmmss')"

        $spOutput = az ad sp create-for-rbac `
            --name $spName `
            --role Contributor `
            --scopes "/subscriptions/$subscriptionId" `
            --output json | ConvertFrom-Json

        $clientId = $spOutput.appId
        $clientSecretPlain = $spOutput.password

        Write-ColoredMessage "Service Principal erstellt: $spName" -Type Success
        Write-ColoredMessage "WICHTIG: Speichern Sie diese Daten sicher!" -Type Warning
        Write-Host "Client ID: $clientId"
        Write-Host "Client Secret: ********** (gespeichert in terraform.tfvars)"
    }

    # Step 4: Terraform Configuration
    Write-ColoredMessage "Schritt 4/10: Terraform Konfiguration erstellen..." -Type Info
    Write-Host ""

    $customer = Read-Host "Kundenname/Kürzel (z.B. 'ramboeck')"
    $environment = Read-Host "Environment (dev/test/prod) [dev]"
    if ([string]::IsNullOrWhiteSpace($environment)) { $environment = "dev" }
    $location = Read-Host "Azure Region [West Europe]"
    if ([string]::IsNullOrWhiteSpace($location)) { $location = "West Europe" }

    # Create terraform.tfvars
    $tfvarsContent = @"
# Azure Authentication
client_id       = "$clientId"
client_secret   = "$clientSecretPlain"
subscription_id = "$subscriptionId"
tenant_id       = "$tenantId"

# Environment Configuration
customer    = "$customer"
environment = "$environment"
location    = "$location"
"@

    $tfvarsContent | Out-File -FilePath "00-avd-terraform/terraform.tfvars" -Encoding UTF8

    Write-ColoredMessage "terraform.tfvars erstellt" -Type Success
    Write-Host ""
}

# Step 5: Terraform Init & Apply
Write-ColoredMessage "Schritt 5/10: Terraform - Infrastruktur bereitstellen..." -Type Info
Write-Host ""

Push-Location 00-avd-terraform

if (-not (Test-Path ".terraform")) {
    Write-ColoredMessage "Initialisiere Terraform..." -Type Info
    terraform init
    Write-ColoredMessage "Terraform initialisiert" -Type Success
}

Write-ColoredMessage "Erstelle Terraform Plan..." -Type Info
terraform plan -out=tfplan

Write-Host ""
$applyTerraform = Read-Host "Möchten Sie die Infrastruktur jetzt erstellen? (y/n)"
if ($applyTerraform -eq "y") {
    Write-ColoredMessage "Erstelle Infrastruktur (dauert ~5 Minuten)..." -Type Info
    terraform apply tfplan
    Write-ColoredMessage "Infrastruktur erfolgreich erstellt!" -Type Success
} else {
    Write-ColoredMessage "Infrastruktur-Erstellung übersprungen." -Type Warning
    Write-ColoredMessage "Führen Sie später manuell aus: cd 00-avd-terraform; terraform apply" -Type Info
    Pop-Location
    exit 0
}

Pop-Location

# Step 6: Verify Packer Variables
Write-ColoredMessage "Schritt 6/10: Prüfe Packer Variablen..." -Type Info
Write-Host ""

if (Test-Path "packer/terraform.auto.pkrvars.json") {
    Write-ColoredMessage "Packer Variablen wurden von Terraform generiert" -Type Success
    Write-ColoredMessage "Inhalt:" -Type Info
    Get-Content "packer/terraform.auto.pkrvars.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10
} else {
    Write-ColoredMessage "Packer Variablen Datei nicht gefunden!" -Type Error
    Write-ColoredMessage "Erwarte: packer/terraform.auto.pkrvars.json" -Type Info
    exit 1
}

Write-Host ""

# Step 7: Build Type Selection
Write-ColoredMessage "Schritt 7/10: Build-Typ auswählen..." -Type Info
Write-Host ""
Write-Host "Welches Image möchten Sie bauen?"
Write-Host "  1) Base Image nur (Windows 11 25H2 + Language Packs) - ~45-60 Min"
Write-Host "  2) Base + Apps Image (inkl. Software-Installation) - ~2-3 Stunden"
Write-Host "  3) Nur Apps Image (Base muss existieren) - ~60-90 Min"
Write-Host ""
$buildChoice = Read-Host "Ihre Wahl (1/2/3)"

# Step 8: SAS Token Warning
if ($buildChoice -in @("2", "3")) {
    Write-ColoredMessage "Apps Image erfordert SAS Token URLs für Software-Pakete!" -Type Warning
    Write-ColoredMessage "Prüfen Sie 02-appscustom-packer/avd-image.pkr.hcl" -Type Info
    Write-Host ""
    $hasSasTokens = Read-Host "Haben Sie gültige SAS Token URLs konfiguriert? (y/n)"
    if ($hasSasTokens -ne "y") {
        Write-ColoredMessage "OHNE gültige SAS URLs wird die App-Installation fehlschlagen." -Type Warning
        $continueAnyway = Read-Host "Trotzdem fortfahren? (y/n)"
        if ($continueAnyway -ne "y") {
            Write-ColoredMessage "Build abgebrochen. Konfigurieren Sie SAS URLs und starten Sie neu." -Type Info
            exit 0
        }
    }
}

# Step 9: Packer Build - Base Image
if ($buildChoice -in @("1", "2")) {
    Write-ColoredMessage "Schritt 8/10: Base Image bauen..." -Type Info
    Write-Host ""
    Write-ColoredMessage "Dies dauert ca. 45-60 Minuten. Bitte warten Sie..." -Type Warning
    Write-Host ""

    Push-Location 01-base-packer

    Write-ColoredMessage "Initialisiere Packer..." -Type Info
    packer init .

    Write-ColoredMessage "Validiere Packer Konfiguration..." -Type Info
    packer validate `
        -var-file=../packer/terraform.auto.pkrvars.json `
        avd-base-image.pkr.hcl

    Write-ColoredMessage "Starte Base Image Build..." -Type Info
    Write-ColoredMessage "Start: $(Get-Date)" -Type Info

    packer build `
        -var-file=../packer/terraform.auto.pkrvars.json `
        avd-base-image.pkr.hcl

    if ($LASTEXITCODE -eq 0) {
        Write-ColoredMessage "Base Image erfolgreich gebaut!" -Type Success
        Write-ColoredMessage "Ende: $(Get-Date)" -Type Info
    } else {
        Write-ColoredMessage "Base Image Build fehlgeschlagen!" -Type Error
        Pop-Location
        exit 1
    }

    Pop-Location
    Write-Host ""
}

# Step 10: Packer Build - Apps Image
if ($buildChoice -in @("2", "3")) {
    Write-ColoredMessage "Schritt 9/10: Apps Image bauen..." -Type Info
    Write-Host ""
    Write-ColoredMessage "Dies dauert ca. 60-90 Minuten. Bitte warten Sie..." -Type Warning
    Write-Host ""

    Push-Location 02-appscustom-packer

    Write-ColoredMessage "Initialisiere Packer..." -Type Info
    packer init .

    Write-ColoredMessage "Validiere Packer Konfiguration..." -Type Info
    packer validate `
        -var-file=../packer/terraform.auto.pkrvars.json `
        avd-image.pkr.hcl

    Write-ColoredMessage "Starte Apps Image Build..." -Type Info
    Write-ColoredMessage "Start: $(Get-Date)" -Type Info

    packer build `
        -var-file=../packer/terraform.auto.pkrvars.json `
        avd-image.pkr.hcl

    if ($LASTEXITCODE -eq 0) {
        Write-ColoredMessage "Apps Image erfolgreich gebaut!" -Type Success
        Write-ColoredMessage "Ende: $(Get-Date)" -Type Info
    } else {
        Write-ColoredMessage "Apps Image Build fehlgeschlagen!" -Type Error
        Pop-Location
        exit 1
    }

    Pop-Location
    Write-Host ""
}

# Final Step: Verify Image in SIG
Write-ColoredMessage "Schritt 10/10: Verifiziere Image in Shared Image Gallery..." -Type Info
Write-Host ""

Push-Location 00-avd-terraform
$rgName = terraform output -raw resource_group_name
Pop-Location

Write-ColoredMessage "Resource Group: $rgName" -Type Info
Write-ColoredMessage "Verfügbare Image Versionen:" -Type Info
Write-Host ""

az sig image-version list `
    --resource-group $rgName `
    --gallery-name avd_sig `
    --gallery-image-definition avd-goldenimage `
    --output table

Write-Host ""
Write-ColoredMessage "✨ Build-Prozess abgeschlossen! ✨" -Type Success
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Nächste Schritte:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Test-VM deployen:"
Write-Host "   az vm create \"
Write-Host "     --resource-group $rgName \"
Write-Host "     --name test-vm-avd \"
Write-Host "     --image /subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.Compute/galleries/avd_sig/images/avd-goldenimage/versions/$(Get-Date -Format 'yyyy.MM.dd')"
Write-Host ""
Write-Host "2. Session Hosts aktualisieren (falls vorhanden):"
Write-Host "   .\Update-AVDSessionHosts.ps1 -ResourceGroupName '$rgName' -HostPoolName 'Ihr-Pool' -ImageVersion '$(Get-Date -Format 'yyyy.MM.dd')'"
Write-Host ""
Write-Host "3. Image-Details anzeigen:"
Write-Host "   az sig image-version show \"
Write-Host "     --resource-group $rgName \"
Write-Host "     --gallery-name avd_sig \"
Write-Host "     --gallery-image-definition avd-goldenimage \"
Write-Host "     --gallery-image-version $(Get-Date -Format 'yyyy.MM.dd')"
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-ColoredMessage "Viel Erfolg mit Ihrem neuen AVD Image! 🚀" -Type Success
Write-Host ""
