# 🚀 AVD Image Builder - Initial Setup Guide

Diese Anleitung führt Sie Schritt für Schritt durch die Ersteinrichtung des AVD Image Builder Frameworks.

---

## 📋 Voraussetzungen

### 1. Software-Installation

Installieren Sie folgende Tools:

- **Terraform** >= 1.9.0
  ```bash
  # macOS (Homebrew)
  brew install terraform

  # Windows (Chocolatey)
  choco install terraform

  # Linux
  wget https://releases.hashicorp.com/terraform/1.9.0/terraform_1.9.0_linux_amd64.zip
  unzip terraform_1.9.0_linux_amd64.zip
  sudo mv terraform /usr/local/bin/
  ```

- **Packer** >= 2.3.3
  ```bash
  # macOS (Homebrew)
  brew install packer

  # Windows (Chocolatey)
  choco install packer

  # Linux
  wget https://releases.hashicorp.com/packer/2.3.3/packer_2.3.3_linux_amd64.zip
  unzip packer_2.3.3_linux_amd64.zip
  sudo mv packer /usr/local/bin/
  ```

- **Azure CLI**
  ```bash
  # macOS (Homebrew)
  brew install azure-cli

  # Windows (MSI Installer)
  # Download: https://aka.ms/installazurecliwindows

  # Linux (Debian/Ubuntu)
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  ```

### 2. Versionen prüfen

```bash
terraform --version    # Sollte >= 1.9.0 sein
packer --version       # Sollte >= 2.3.3 sein
az --version           # Azure CLI installiert
```

---

## 🔐 Azure Setup

### 1. Azure Login

```bash
az login
```

### 2. Service Principal erstellen

Der Service Principal wird für die Automation benötigt:

```bash
# Subscription ID abrufen
az account show --query id -o tsv

# Service Principal erstellen
az ad sp create-for-rbac \
  --name "avd-image-builder-sp" \
  --role "Contributor" \
  --scopes /subscriptions/{YOUR-SUBSCRIPTION-ID}
```

**Wichtig:** Notieren Sie die Ausgabe:
```json
{
  "appId": "00000000-0000-0000-0000-000000000000",       // → client_id
  "displayName": "avd-image-builder-sp",
  "password": "xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",        // → client_secret
  "tenant": "00000000-0000-0000-0000-000000000000"       // → tenant_id
}
```

### 3. Zusätzliche Berechtigungen (Optional)

Für Shared Image Gallery Operationen:

```bash
az role assignment create \
  --assignee <appId> \
  --role "Contributor" \
  --scope /subscriptions/{YOUR-SUBSCRIPTION-ID}/resourceGroups/Storage-RG
```

---

## ⚙️ Terraform Konfiguration

### 1. Konfigurationsdatei erstellen

```bash
cd 00-avd-terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. `terraform.tfvars` bearbeiten

Öffnen Sie `terraform.tfvars` und tragen Sie Ihre Werte ein:

```hcl
# Azure Authentication (aus Service Principal)
client_id       = "00000000-0000-0000-0000-000000000000"
client_secret   = "ihr-client-secret-hier"
subscription_id = "00000000-0000-0000-0000-000000000000"
tenant_id       = "00000000-0000-0000-0000-000000000000"

# Environment Konfiguration
customer    = "meinefirma"      # Ihr Kundenname/Kürzel
environment = "dev"              # dev, test, oder prod
location    = "westeurope"       # Azure Region
```

### 3. Backend-Konfiguration (Optional)

Wenn Sie ein anderes Backend verwenden möchten, passen Sie `backend.tf` an:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "Ihre-Storage-RG"
    storage_account_name = "ihrstorage"
    container_name       = "tfstate"
    key                  = "avd/terraform.tfstate"
  }
}
```

Oder verwenden Sie lokales Backend:

```hcl
# backend.tf auskommentieren oder löschen
# Terraform nutzt dann lokales Backend
```

---

## 🏗️ Infrastruktur bereitstellen

### 1. Terraform initialisieren

```bash
cd 00-avd-terraform
terraform init
```

**Erwartete Ausgabe:**
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

### 2. Terraform Plan erstellen

```bash
terraform plan -out=tfplan
```

Prüfen Sie die geplanten Änderungen. Es sollten folgende Ressourcen erstellt werden:
- Azure Resource Group
- AVD Host Pool
- AVD Application Group
- AVD Workspace
- Shared Image Gallery
- Shared Image Definition

### 3. Infrastruktur erstellen

```bash
terraform apply tfplan
```

**Wichtig:** Terraform erstellt automatisch folgende Dateien:
- `../01-base-packer/terraform.auto.pkrvars.json`
- `../02-appscustom-packer/terraform.auto.pkrvars.json`
- `../03-monthly-packer/terraform.auto.pkrvars.json`

Diese enthalten alle notwendigen Variablen für Packer!

### 4. Outputs prüfen

```bash
terraform output
```

---

## 🖼️ Image Build - Workflow

### Option A: Automatisiertes Script (EMPFOHLEN)

**Windows (PowerShell):**
```powershell
cd ..  # Zurück zum Repository-Root
.\update-avd-image.ps1
```

**Linux/macOS (Bash):**
```bash
cd ..  # Zurück zum Repository-Root
./update-avd-image.sh
```

Das Script bietet ein interaktives Menü:
1. **Monatliches Update** - Schnellster Weg (für regelmäßige Updates)
2. **App-Layer Rebuild** - Software neu installieren
3. **Vollständiger Rebuild** - Kompletter Neuaufbau
4. **Terraform Update** - Infrastruktur ändern

### Option B: Manuelle Ausführung

#### Schritt 1: Base Image erstellen

```bash
cd 01-base-packer
packer init .
packer validate .
packer build avd-base-image.pkr.hcl
```

**Dauer:** ~45-75 Minuten

**Was wird gemacht:**
- Windows 11 Marketplace Image als Basis
- Language Packs installieren (DE, EN, FR)
- WinRM konfigurieren
- Sysprep & Generalisierung

#### Schritt 2: App Layer erstellen

```bash
cd ../02-appscustom-packer
packer init .
packer validate .
packer build avd-image.pkr.hcl
```

**Dauer:** ~60-90 Minuten

**Was wird gemacht:**
- Base Image aus SIG nutzen
- Software installieren (7zip, Adobe Reader, etc.)
- Microsoft Office 365 installieren
- VDOT Optimierungen anwenden
- Windows Updates installieren
- Sysprep & Generalisierung

#### Schritt 3: Verifizierung

Prüfen Sie in Azure Portal:
1. Navigieren Sie zu **Shared Image Gallery** → `avd_sig`
2. Klicken Sie auf **avd-goldenimage**
3. Sie sollten eine neue Version sehen (Format: YYYY.MM.DD)

---

## 🔄 Monatliche Updates

Nach dem Initial Setup sind monatliche Updates sehr einfach:

### Automatisch (EMPFOHLEN)

```bash
# Windows
.\update-avd-image.ps1

# Linux/macOS
./update-avd-image.sh

# Wählen Sie Option 1: Monatliches Update
```

### Manuell

```bash
cd 03-monthly-packer
packer init .
packer build avd-monthly-image.pkr.hcl
```

**Dauer:** ~30-60 Minuten (schneller als vollständiger Rebuild!)

**Was wird gemacht:**
- Neueste Version aus SIG als Basis nutzen
- Windows Updates installieren
- Office 365 Updates installieren
- Software-Updates (Chocolatey)
- VDOT Re-Optimierung
- Neue Version in SIG speichern

---

## 🔧 Troubleshooting

### Problem: "No Packer variables found"

**Ursache:** Terraform wurde noch nicht ausgeführt

**Lösung:**
```bash
cd 00-avd-terraform
terraform init
terraform apply
```

### Problem: "Authentication failed"

**Ursache:** Service Principal Credentials sind falsch

**Lösung:**
1. Prüfen Sie `terraform.tfvars`
2. Testen Sie den Login:
   ```bash
   az login --service-principal \
     -u <client_id> \
     -p <client_secret> \
     --tenant <tenant_id>
   ```

### Problem: "Shared Image Gallery not found"

**Ursache:** Terraform Infrastruktur wurde nicht erstellt

**Lösung:**
```bash
cd 00-avd-terraform
terraform apply
```

### Problem: Packer Build hängt bei "Waiting for WinRM"

**Ursache:** Netzwerk/Firewall blockiert WinRM

**Lösungen:**
1. Prüfen Sie Network Security Groups in Azure
2. Stellen Sie sicher, dass Port 5985 (HTTP) oder 5986 (HTTPS) offen ist
3. Prüfen Sie Azure Firewall Regeln

### Problem: "Build failed" nach Sysprep

**Ursache:** Sysprep kann nach Windows Updates fehlschlagen

**Lösung:**
1. Führen Sie den Build erneut aus
2. Packer erstellt automatisch einen neuen Versuch

---

## 📊 Best Practices

### 1. Image Lifecycle

```
Base Image (monatlich)
   └─> App Layer (bei Software-Änderungen)
       └─> Monthly Updates (jeden Monat)
```

### 2. Versionierung

- **Format:** YYYY.MM.DD (z.B. 2025.01.25)
- **Automatisch:** Terraform generiert aktuelles Datum
- **Tracking:** SIG verwaltet alle Versionen

### 3. Rollback

Bei Problemen mit einer neuen Version:

```bash
# In AVD Host Pool → Session Hosts → Image Version ändern
# Oder via Terraform:
cd 00-avd-terraform
# Image Version in locals.tf anpassen
terraform apply
```

### 4. Secrets Management

**Nicht empfohlen:**
- ❌ Secrets in Git committen
- ❌ Plaintext Passwörter in Scripts

**Empfohlen:**
- ✅ Azure Key Vault für Produktiv-Umgebungen
- ✅ Azure DevOps Variable Groups
- ✅ Terraform Backend für State-Verschlüsselung
- ✅ `.gitignore` für `*.tfvars`

---

## 🎯 Nächste Schritte

Nach erfolgreichem Setup:

1. **CI/CD einrichten:**
   - Azure DevOps Pipeline (siehe `azure-pipelines.yml`)
   - GitHub Actions Workflow
   - Automatische monatliche Builds

2. **Monitoring:**
   - Azure Monitor für Build-Erfolg
   - Logs in Log Analytics
   - Alerts bei Build-Fehlern

3. **Erweiterungen:**
   - Zusätzliche Software-Pakete
   - Custom Scripts
   - Weitere Language Packs

4. **Dokumentation:**
   - Team-Runbook erstellen
   - Änderungen dokumentieren
   - Change Management Prozess

---

## 📚 Weitere Ressourcen

- **Terraform Docs:** https://www.terraform.io/docs
- **Packer Docs:** https://www.packer.io/docs
- **Azure AVD:** https://docs.microsoft.com/azure/virtual-desktop/
- **Shared Image Gallery:** https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries

---

## ❓ Support

Bei Fragen oder Problemen:

1. Prüfen Sie zuerst die [Troubleshooting](#-troubleshooting) Sektion
2. Lesen Sie die Logs in den entsprechenden Verzeichnissen
3. Kontaktieren Sie den Repository-Maintainer

---

**Viel Erfolg mit Ihrer AVD Image Pipeline!** 🎉
