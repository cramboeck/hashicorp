#!/bin/bash
# AVD Image Builder - Interactive Setup Script
# Führt Sie durch den kompletten Build-Prozess

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_command() {
    if command -v $1 &> /dev/null; then
        log_success "$1 ist installiert: $(command -v $1)"
        return 0
    else
        log_error "$1 ist NICHT installiert"
        return 1
    fi
}

# Banner
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     AVD Image Builder - Interactive Setup                 ║"
echo "║     Windows 11 25H2 Multisession AVD Image                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Prerequisites Check
log_info "Schritt 1/10: Überprüfe Voraussetzungen..."
echo ""

MISSING_TOOLS=0

if ! check_command az; then
    log_warning "Installieren Sie Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
    MISSING_TOOLS=1
fi

if ! check_command terraform; then
    log_warning "Installieren Sie Terraform: https://www.terraform.io/downloads"
    MISSING_TOOLS=1
fi

if ! check_command packer; then
    log_warning "Installieren Sie Packer: https://www.packer.io/downloads"
    MISSING_TOOLS=1
fi

if [ $MISSING_TOOLS -eq 1 ]; then
    log_error "Fehlende Tools müssen installiert werden. Bitte installieren Sie diese und führen Sie das Script erneut aus."
    exit 1
fi

echo ""
log_success "Alle benötigten Tools sind installiert!"
echo ""

# Step 2: Azure Login
log_info "Schritt 2/10: Azure Login..."
echo ""

if ! az account show &> /dev/null; then
    log_warning "Sie sind nicht in Azure eingeloggt."
    read -p "Möchten Sie jetzt einloggen? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        az login
    else
        log_error "Azure Login erforderlich. Führen Sie 'az login' aus und starten Sie das Script neu."
        exit 1
    fi
fi

# Get current subscription
CURRENT_SUB=$(az account show --query name -o tsv)
CURRENT_SUB_ID=$(az account show --query id -o tsv)
log_success "Eingeloggt in Azure"
log_info "Aktuelle Subscription: $CURRENT_SUB"
log_info "Subscription ID: $CURRENT_SUB_ID"
echo ""

read -p "Möchten Sie diese Subscription verwenden? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Verfügbare Subscriptions:"
    az account list --output table
    echo ""
    read -p "Geben Sie die gewünschte Subscription ID ein: " SUB_ID
    az account set --subscription "$SUB_ID"
    CURRENT_SUB=$(az account show --query name -o tsv)
    CURRENT_SUB_ID=$(az account show --query id -o tsv)
    log_success "Subscription gewechselt zu: $CURRENT_SUB"
fi

echo ""

# Step 3: Service Principal Check
log_info "Schritt 3/10: Service Principal..."
echo ""

if [ -f "00-avd-terraform/terraform.tfvars" ]; then
    log_warning "terraform.tfvars existiert bereits."
    read -p "Möchten Sie diese Datei überschreiben? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Verwende existierende terraform.tfvars"
        SKIP_TFVARS=1
    fi
fi

if [ -z "$SKIP_TFVARS" ]; then
    read -p "Haben Sie bereits einen Service Principal? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Use existing SP
        log_info "Bitte geben Sie Ihre Service Principal Daten ein:"
        read -p "Client ID (App ID): " CLIENT_ID
        read -sp "Client Secret (Password): " CLIENT_SECRET
        echo
        TENANT_ID=$(az account show --query tenantId -o tsv)
        log_success "Service Principal Daten erfasst"
    else
        # Create new SP
        log_info "Erstelle neuen Service Principal..."
        SP_NAME="avd-image-builder-sp-$(date +%s)"

        SP_OUTPUT=$(az ad sp create-for-rbac \
            --name "$SP_NAME" \
            --role Contributor \
            --scopes /subscriptions/$CURRENT_SUB_ID \
            --output json)

        CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.appId')
        CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r '.password')
        TENANT_ID=$(echo $SP_OUTPUT | jq -r '.tenant')

        log_success "Service Principal erstellt: $SP_NAME"
        log_warning "WICHTIG: Speichern Sie diese Daten sicher!"
        echo "Client ID: $CLIENT_ID"
        echo "Client Secret: ********** (gespeichert in terraform.tfvars)"
    fi

    # Step 4: Terraform Configuration
    log_info "Schritt 4/10: Terraform Konfiguration erstellen..."
    echo ""

    read -p "Kundenname/Kürzel (z.B. 'ramboeck'): " CUSTOMER
    read -p "Environment (dev/test/prod) [dev]: " ENVIRONMENT
    ENVIRONMENT=${ENVIRONMENT:-dev}
    read -p "Azure Region [West Europe]: " LOCATION
    LOCATION=${LOCATION:-"West Europe"}

    # Create terraform.tfvars
    cat > 00-avd-terraform/terraform.tfvars <<EOF
# Azure Authentication
client_id       = "$CLIENT_ID"
client_secret   = "$CLIENT_SECRET"
subscription_id = "$CURRENT_SUB_ID"
tenant_id       = "$TENANT_ID"

# Environment Configuration
customer    = "$CUSTOMER"
environment = "$ENVIRONMENT"
location    = "$LOCATION"
EOF

    log_success "terraform.tfvars erstellt"
    echo ""
fi

# Step 5: Terraform Init & Apply
log_info "Schritt 5/10: Terraform - Infrastruktur bereitstellen..."
echo ""

cd 00-avd-terraform

if [ ! -d ".terraform" ]; then
    log_info "Initialisiere Terraform..."
    terraform init
    log_success "Terraform initialisiert"
fi

log_info "Erstelle Terraform Plan..."
terraform plan -out=tfplan

echo ""
read -p "Möchten Sie die Infrastruktur jetzt erstellen? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Erstelle Infrastruktur (dauert ~5 Minuten)..."
    terraform apply tfplan
    log_success "Infrastruktur erfolgreich erstellt!"
else
    log_warning "Infrastruktur-Erstellung übersprungen."
    log_info "Führen Sie später manuell aus: cd 00-avd-terraform && terraform apply"
    exit 0
fi

cd ..

# Step 6: Verify Packer Variables
log_info "Schritt 6/10: Prüfe Packer Variablen..."
echo ""

if [ -f "packer/terraform.auto.pkrvars.json" ]; then
    log_success "Packer Variablen wurden von Terraform generiert"
    log_info "Inhalt:"
    cat packer/terraform.auto.pkrvars.json | jq '.'
else
    log_error "Packer Variablen Datei nicht gefunden!"
    log_info "Erwarte: packer/terraform.auto.pkrvars.json"
    exit 1
fi

echo ""

# Step 7: Build Type Selection
log_info "Schritt 7/10: Build-Typ auswählen..."
echo ""
echo "Welches Image möchten Sie bauen?"
echo "  1) Base Image nur (Windows 11 25H2 + Language Packs) - ~45-60 Min"
echo "  2) Base + Apps Image (inkl. Software-Installation) - ~2-3 Stunden"
echo "  3) Nur Apps Image (Base muss existieren) - ~60-90 Min"
echo ""
read -p "Ihre Wahl (1/2/3): " -n 1 -r BUILD_CHOICE
echo ""

# Step 8: SAS Token Warning
if [[ $BUILD_CHOICE =~ ^[23]$ ]]; then
    log_warning "Apps Image erfordert SAS Token URLs für Software-Pakete!"
    log_info "Prüfen Sie 02-appscustom-packer/avd-image.pkr.hcl"
    echo ""
    read -p "Haben Sie gültige SAS Token URLs konfiguriert? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "OHNE gültige SAS URLs wird die App-Installation fehlschlagen."
        read -p "Trotzdem fortfahren? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Build abgebrochen. Konfigurieren Sie SAS URLs und starten Sie neu."
            exit 0
        fi
    fi
fi

# Step 9: Packer Build - Base Image
if [[ $BUILD_CHOICE =~ ^[12]$ ]]; then
    log_info "Schritt 8/10: Base Image bauen..."
    echo ""
    log_warning "Dies dauert ca. 45-60 Minuten. Bitte warten Sie..."
    echo ""

    cd 01-base-packer

    log_info "Initialisiere Packer..."
    packer init .

    log_info "Validiere Packer Konfiguration..."
    packer validate \
        -var-file=../packer/terraform.auto.pkrvars.json \
        avd-base-image.pkr.hcl

    log_info "Starte Base Image Build..."
    log_info "Start: $(date)"

    packer build \
        -var-file=../packer/terraform.auto.pkrvars.json \
        avd-base-image.pkr.hcl

    if [ $? -eq 0 ]; then
        log_success "Base Image erfolgreich gebaut!"
        log_info "Ende: $(date)"
    else
        log_error "Base Image Build fehlgeschlagen!"
        exit 1
    fi

    cd ..
    echo ""
fi

# Step 10: Packer Build - Apps Image
if [[ $BUILD_CHOICE =~ ^[23]$ ]]; then
    log_info "Schritt 9/10: Apps Image bauen..."
    echo ""
    log_warning "Dies dauert ca. 60-90 Minuten. Bitte warten Sie..."
    echo ""

    cd 02-appscustom-packer

    log_info "Initialisiere Packer..."
    packer init .

    log_info "Validiere Packer Konfiguration..."
    packer validate \
        -var-file=../packer/terraform.auto.pkrvars.json \
        avd-image.pkr.hcl

    log_info "Starte Apps Image Build..."
    log_info "Start: $(date)"

    packer build \
        -var-file=../packer/terraform.auto.pkrvars.json \
        avd-image.pkr.hcl

    if [ $? -eq 0 ]; then
        log_success "Apps Image erfolgreich gebaut!"
        log_info "Ende: $(date)"
    else
        log_error "Apps Image Build fehlgeschlagen!"
        exit 1
    fi

    cd ..
    echo ""
fi

# Final Step: Verify Image in SIG
log_info "Schritt 10/10: Verifiziere Image in Shared Image Gallery..."
echo ""

RG_NAME=$(cd 00-avd-terraform && terraform output -raw resource_group_name)

log_info "Resource Group: $RG_NAME"
log_info "Verfügbare Image Versionen:"
echo ""

az sig image-version list \
    --resource-group "$RG_NAME" \
    --gallery-name avd_sig \
    --gallery-image-definition avd-goldenimage \
    --output table

echo ""
log_success "✨ Build-Prozess abgeschlossen! ✨"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Nächste Schritte:"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "1. Test-VM deployen:"
echo "   az vm create \\"
echo "     --resource-group $RG_NAME \\"
echo "     --name test-vm-avd \\"
echo "     --image /subscriptions/$CURRENT_SUB_ID/resourceGroups/$RG_NAME/providers/Microsoft.Compute/galleries/avd_sig/images/avd-goldenimage/versions/$(date +%Y.%m.%d)"
echo ""
echo "2. Session Hosts aktualisieren (falls vorhanden):"
echo "   ./Update-AVDSessionHosts.ps1 -ResourceGroupName '$RG_NAME' -HostPoolName 'Ihr-Pool' -ImageVersion '$(date +%Y.%m.%d)'"
echo ""
echo "3. Image-Details anzeigen:"
echo "   az sig image-version show \\"
echo "     --resource-group $RG_NAME \\"
echo "     --gallery-name avd_sig \\"
echo "     --gallery-image-definition avd-goldenimage \\"
echo "     --gallery-image-version $(date +%Y.%m.%d)"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
log_success "Viel Erfolg mit Ihrem neuen AVD Image! 🚀"
echo ""
