#!/bin/bash

###############################################################################
# AVD Image Update Script
# Vereinfacht den Prozess zum Aktualisieren von Azure Virtual Desktop Images
###############################################################################

set -e  # Exit on error

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     Azure Virtual Desktop - Image Update Tool                ║
║     Powered by Terraform & Packer                            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Funktion: Ausgabe mit Farbe
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Funktion: Prüfe ob Tool installiert ist
check_tool() {
    if command -v $1 &> /dev/null; then
        print_success "$1 ist installiert ($(command -v $1))"
        return 0
    else
        print_error "$1 ist NICHT installiert!"
        return 1
    fi
}

# Funktion: Prüfe Prerequisites
check_prerequisites() {
    print_info "Prüfe erforderliche Tools..."
    echo ""

    local all_ok=true

    check_tool "terraform" || all_ok=false
    check_tool "packer" || all_ok=false
    check_tool "az" || all_ok=false

    echo ""

    if [ "$all_ok" = false ]; then
        print_error "Nicht alle erforderlichen Tools sind installiert!"
        echo ""
        print_info "Installation:"
        echo "  - Terraform: https://www.terraform.io/downloads"
        echo "  - Packer:    https://www.packer.io/downloads"
        echo "  - Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi

    print_success "Alle erforderlichen Tools sind vorhanden!"
    echo ""
}

# Funktion: Zeige Menü
show_menu() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  Was möchten Sie tun?                                        ${BLUE}║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  1) ${GREEN}Monatliches Update${NC} (03-monthly-packer)                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     → Schnellstes Update: Windows Updates + Software Updates ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     → Nutzt vorhandenes Golden Image als Basis               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  2) ${YELLOW}Neues App-Layer Image${NC} (02-appscustom-packer)          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     → Software-Installation + Optimierungen                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     → Nutzt Base Image als Grundlage                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  3) ${RED}Vollständiger Rebuild${NC} (Base + Apps)                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     → Kompletter Neuaufbau von Grund auf                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     → Base Image (01) → App Layer (02)                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  4) ${BLUE}Infrastruktur aktualisieren${NC} (Terraform)               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     → AVD Host Pool, Workspace, SIG ändern                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  0) ${NC}Beenden                                                ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Funktion: Azure Login prüfen
check_azure_login() {
    print_info "Prüfe Azure Login Status..."

    if az account show &> /dev/null; then
        local account_name=$(az account show --query name -o tsv)
        print_success "Angemeldet als: $account_name"
        return 0
    else
        print_warning "Nicht bei Azure angemeldet!"
        print_info "Starte Azure Login..."
        az login
        return $?
    fi
}

# Funktion: Monatliches Update
run_monthly_update() {
    print_info "Starte monatliches Image-Update..."
    echo ""

    cd 03-monthly-packer

    print_info "Initialisiere Packer..."
    packer init .

    print_info "Validiere Packer Konfiguration..."
    packer validate .

    print_info "Starte Image-Build (dies kann 30-60 Minuten dauern)..."
    packer build avd-monthly-image.pkr.hcl

    if [ $? -eq 0 ]; then
        print_success "Monatliches Update erfolgreich abgeschlossen!"
        print_info "Neue Image-Version wurde in Shared Image Gallery gespeichert"
    else
        print_error "Build fehlgeschlagen! Prüfen Sie die Logs oben."
        exit 1
    fi

    cd ..
}

# Funktion: App Layer Build
run_app_layer_build() {
    print_info "Starte App-Layer Image-Build..."
    echo ""

    cd 02-appscustom-packer

    print_info "Initialisiere Packer..."
    packer init .

    print_info "Validiere Packer Konfiguration..."
    packer validate .

    print_info "Starte Image-Build (dies kann 60-90 Minuten dauern)..."
    packer build avd-image.pkr.hcl

    if [ $? -eq 0 ]; then
        print_success "App-Layer Build erfolgreich abgeschlossen!"
        print_info "Neue Image-Version wurde in Shared Image Gallery gespeichert"
    else
        print_error "Build fehlgeschlagen! Prüfen Sie die Logs oben."
        exit 1
    fi

    cd ..
}

# Funktion: Base Image Build
run_base_build() {
    print_info "Starte Base Image-Build..."
    echo ""

    cd 01-base-packer

    print_info "Initialisiere Packer..."
    packer init .

    print_info "Validiere Packer Konfiguration..."
    packer validate .

    print_info "Starte Base Image-Build (dies kann 45-75 Minuten dauern)..."
    packer build avd-base-image.pkr.hcl

    if [ $? -eq 0 ]; then
        print_success "Base Image Build erfolgreich abgeschlossen!"
    else
        print_error "Build fehlgeschlagen! Prüfen Sie die Logs oben."
        exit 1
    fi

    cd ..
}

# Funktion: Vollständiger Rebuild
run_full_rebuild() {
    print_warning "Vollständiger Rebuild wird gestartet..."
    print_info "Dies kann 2-3 Stunden dauern!"
    echo ""

    read -p "Möchten Sie fortfahren? (j/N): " confirm
    if [[ ! $confirm =~ ^[Jj]$ ]]; then
        print_info "Abgebrochen."
        return
    fi

    echo ""
    print_info "Phase 1/2: Base Image Build"
    run_base_build

    echo ""
    print_info "Phase 2/2: App Layer Build"
    run_app_layer_build

    print_success "Vollständiger Rebuild abgeschlossen!"
}

# Funktion: Terraform Update
run_terraform_update() {
    print_info "Terraform Infrastruktur-Update..."
    echo ""

    cd 00-avd-terraform

    if [ ! -f "terraform.tfvars" ]; then
        print_error "terraform.tfvars nicht gefunden!"
        print_info "Bitte erstellen Sie die Datei basierend auf terraform.tfvars.example"
        cd ..
        return 1
    fi

    print_info "Initialisiere Terraform..."
    terraform init

    print_info "Formatiere Terraform Dateien..."
    terraform fmt -recursive

    print_info "Validiere Terraform Konfiguration..."
    terraform validate

    print_info "Erstelle Terraform Plan..."
    terraform plan -out=tfplan

    echo ""
    read -p "Möchten Sie diese Änderungen anwenden? (j/N): " confirm
    if [[ $confirm =~ ^[Jj]$ ]]; then
        print_info "Wende Terraform Plan an..."
        terraform apply tfplan
        rm -f tfplan
        print_success "Infrastruktur erfolgreich aktualisiert!"
    else
        print_info "Terraform Apply abgebrochen."
        rm -f tfplan
    fi

    cd ..
}

# Hauptprogramm
main() {
    # Prüfe Prerequisites
    check_prerequisites

    # Prüfe Azure Login (nur Warnung, kein Exit)
    check_azure_login || print_warning "Azure Login fehlgeschlagen, aber fortfahren..."
    echo ""

    while true; do
        show_menu
        read -p "Ihre Wahl [0-4]: " choice
        echo ""

        case $choice in
            1)
                run_monthly_update
                echo ""
                read -p "Drücken Sie Enter um fortzufahren..."
                ;;
            2)
                run_app_layer_build
                echo ""
                read -p "Drücken Sie Enter um fortzufahren..."
                ;;
            3)
                run_full_rebuild
                echo ""
                read -p "Drücken Sie Enter um fortzufahren..."
                ;;
            4)
                run_terraform_update
                echo ""
                read -p "Drücken Sie Enter um fortzufahren..."
                ;;
            0)
                print_info "Auf Wiedersehen!"
                exit 0
                ;;
            *)
                print_error "Ungültige Auswahl! Bitte wählen Sie 0-4."
                sleep 2
                ;;
        esac
    done
}

# Starte Hauptprogramm
main
