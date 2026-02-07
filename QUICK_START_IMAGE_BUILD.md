# 🚀 Quick Start: AVD Image Build

**Ziel:** Ein neues Windows 11 25H2 AVD Image erstellen
**Geschätzte Zeit:** 2-3 Stunden (je nach Build-Geschwindigkeit)

---

## ✅ Voraussetzungen

### Benötigte Software (lokal)
- [ ] Azure CLI installiert (`az --version`)
- [ ] Terraform >= 1.9.0 (`terraform version`)
- [ ] Packer >= 1.9.0 (`packer version`)
- [ ] PowerShell 7+ oder Bash

### Azure-Berechtigungen
- [ ] Azure Subscription mit Contributor-Rechten
- [ ] Service Principal mit Contributor-Rolle ODER
- [ ] `az login` mit ausreichenden Rechten

---

## 📋 Schritt-für-Schritt Anleitung

### Schritt 1: Azure Login & Konfiguration

```bash
# Azure Login
az login

# Subscription auswählen
az account list --output table
az account set --subscription "Ihre-Subscription-ID"

# Subscription ID anzeigen (für später)
az account show --query id -o tsv
```

### Schritt 2: Service Principal erstellen (falls noch nicht vorhanden)

```bash
# Service Principal mit Contributor-Rolle erstellen
az ad sp create-for-rbac \
  --name "avd-image-builder-sp" \
  --role Contributor \
  --scopes /subscriptions/$(az account show --query id -o tsv)

# Output speichern - Sie erhalten:
# {
#   "appId": "xxxxx",        # = client_id
#   "password": "xxxxx",     # = client_secret
#   "tenant": "xxxxx"        # = tenant_id
# }
```

**WICHTIG:** Speichern Sie die Ausgabe - das Secret wird nur einmal angezeigt!

### Schritt 3: Terraform Konfiguration erstellen

```bash
cd 00-avd-terraform

# Kopieren Sie die Example-Datei
cp terraform.tfvars.example terraform.tfvars

# Bearbeiten Sie terraform.tfvars mit Ihren Werten
nano terraform.tfvars  # oder vim, code, etc.
```

**Minimal-Konfiguration** (terraform.tfvars):
```hcl
# Azure Authentication
client_id       = "Ihre-Service-Principal-AppId"
client_secret   = "Ihr-Service-Principal-Password"
subscription_id = "Ihre-Subscription-ID"
tenant_id       = "Ihre-Tenant-ID"

# Environment
customer    = "ramboeck"      # Ihr Firmenname/Kunde
environment = "dev"           # dev, test, oder prod
location    = "West Europe"   # Ihre bevorzugte Region
```

### Schritt 4: Terraform - Infrastruktur bereitstellen

```bash
# Im Verzeichnis: 00-avd-terraform

# Terraform initialisieren
terraform init

# Plan prüfen (was wird erstellt?)
terraform plan

# Infrastruktur erstellen
terraform apply

# Bei Frage "Do you want to perform these actions?" → yes eingeben
```

**Was wird erstellt:**
- Resource Group
- AVD Host Pool
- Application Group
- Workspace
- Shared Image Gallery (SIG)
- Packer Variables File (`../packer/terraform.auto.pkrvars.json`)

**Dauer:** ~5 Minuten

### Schritt 5: Packer Variables prüfen

```bash
# Prüfen Sie, ob Terraform die Packer-Variablen generiert hat
cat ../packer/terraform.auto.pkrvars.json

# Sollte enthalten:
# - sig_name
# - sig_image_name
# - sig_image_version
# - subscription_id, tenant_id, client_id, client_secret
# - winrm_password (automatisch generiert)
```

### Schritt 6: SAS Token URLs konfigurieren (OPTIONAL)

**Nur wenn Sie die Apps installieren wollen:**

Die folgenden URLs sind aktuell hardcoded in `02-appscustom-packer/avd-image.pkr.hcl` (mit abgelaufenen SAS Tokens). Sie haben 2 Optionen:

#### Option A: SAS URLs überspringen (schneller Test)
Sie können die App-Installation temporär überspringen, indem Sie die entsprechenden Provisioner in `02-appscustom-packer/avd-image.pkr.hcl` auskommentieren.

#### Option B: Neue SAS URLs generieren

```bash
# Beispiel: SAS Token für Blob Storage generieren (gültig 1 Jahr)
az storage blob generate-sas \
  --account-name IhrStorageAccount \
  --container-name artifacts \
  --name PADT-Greenshot.zip \
  --permissions r \
  --expiry $(date -u -d "1 year" '+%Y-%m-%dT%H:%MZ') \
  --https-only \
  --output tsv

# Vollständige URL erstellen:
# https://IhrStorageAccount.blob.core.windows.net/artifacts/PADT-Greenshot.zip?[SAS-Token]
```

Dann in `02-appscustom-packer/avd-image.pkr.hcl` die URLs aktualisieren.

### Schritt 7: Base Image bauen (ca. 45-60 Min)

```bash
cd ../01-base-packer

# Packer initialisieren
packer init .

# Packer validieren
packer validate \
  -var-file=../packer/terraform.auto.pkrvars.json \
  avd-base-image.pkr.hcl

# Base Image bauen
packer build \
  -var-file=../packer/terraform.auto.pkrvars.json \
  avd-base-image.pkr.hcl
```

**Was passiert:**
1. Azure VM wird erstellt (Standard_D4s_v3)
2. Windows 11 25H2 Multisession + Office 365 wird installiert
3. Language Packs werden installiert (de-DE)
4. WinRM wird konfiguriert
5. VM wird zu Image konvertiert
6. Image wird in Shared Image Gallery gespeichert
7. VM wird gelöscht

**Dauer:** 45-60 Minuten

**Debugging:**
- Logs werden in Echtzeit angezeigt
- Bei Fehlern: `export PACKER_LOG=1` für detaillierte Logs

### Schritt 8: Apps Image bauen (ca. 60-90 Min) - OPTIONAL

**NUR wenn Sie Apps installieren möchten UND SAS URLs haben:**

```bash
cd ../02-appscustom-packer

# Packer initialisieren
packer init .

# Apps Image bauen
packer build \
  -var-file=../packer/terraform.auto.pkrvars.json \
  avd-image.pkr.hcl
```

**Was passiert:**
- Nutzt das Base Image als Quelle
- Installiert: Greenshot, Country Switch, Office 365 (wenn URLs verfügbar)
- Optimiert mit VDOT (Virtual Desktop Optimization Tool)
- Installiert Windows Updates
- Speichert in SIG

**Dauer:** 60-90 Minuten

### Schritt 9: Image in SIG verifizieren

```bash
# Image Versionen anzeigen
az sig image-version list \
  --resource-group $(terraform output -raw resource_group_name) \
  --gallery-name avd_sig \
  --gallery-image-definition avd-goldenimage \
  --output table

# Details einer Version anzeigen
az sig image-version show \
  --resource-group $(terraform output -raw resource_group_name) \
  --gallery-name avd_sig \
  --gallery-image-definition avd-goldenimage \
  --gallery-image-version $(date +%Y.%m.%d) \
  --output json
```

### Schritt 10: Session Hosts aktualisieren (OPTIONAL)

**NUR wenn Sie bereits laufende Session Hosts haben:**

```powershell
# Aus dem Repository-Root
.\Update-AVDSessionHosts.ps1 `
    -ResourceGroupName "Ihre-RG" `
    -HostPoolName "Ihr-HostPool" `
    -ImageVersion "2025.02.07" `  # Ihr Image-Datum
    -DryRun  # Erst mal simulieren

# Wenn DryRun OK → ohne -DryRun ausführen
```

---

## 🔍 Troubleshooting

### Problem: "Azure login failed"
```bash
az login --use-device-code  # Alternative Login-Methode
```

### Problem: "terraform apply" schlägt fehl
```bash
# Detaillierte Logs aktivieren
export TF_LOG=DEBUG
terraform apply
```

### Problem: "Packer kann nicht zur VM verbinden"
```bash
# 1. Prüfen Sie NSG-Regeln
# 2. WinRM-Logs in Azure Portal → VM → Serial Console
# 3. Packer mit Debug-Modus:
export PACKER_LOG=1
packer build -debug ...
```

### Problem: "SAS Token expired"
```bash
# Neue SAS Tokens generieren (siehe Schritt 6)
# Oder App-Installation temporär überspringen
```

### Problem: "Image nicht in SIG sichtbar"
```bash
# Prüfen Sie Packer Logs:
# - Wurde das Image erfolgreich erstellt?
# - Ist die Resource Group korrekt?
# - Subscription ID korrekt?

# Manuelle Prüfung:
az sig image-version list \
  --resource-group "Ihre-RG" \
  --gallery-name avd_sig \
  --gallery-image-definition avd-goldenimage
```

---

## ⚡ Schnellstart (Minimal-Setup)

**Wenn Sie nur testen wollen:**

```bash
# 1. Login
az login
az account set --subscription "Ihre-Subscription"

# 2. Service Principal
SP=$(az ad sp create-for-rbac --name "avd-test-sp" --role Contributor --scopes /subscriptions/$(az account show --query id -o tsv))

# 3. Terraform Config
cd 00-avd-terraform
cp terraform.tfvars.example terraform.tfvars
# Editieren Sie terraform.tfvars mit SP-Daten

# 4. Terraform
terraform init
terraform apply -auto-approve

# 5. Base Image (OHNE Apps, schneller!)
cd ../01-base-packer
packer init .
packer build -var-file=../packer/terraform.auto.pkrvars.json avd-base-image.pkr.hcl

# Fertig! Image ist in SIG
```

**Dauer:** ~1 Stunde (ohne Apps)

---

## 📊 Erwartete Build-Zeiten

| Stage | Dauer | Bemerkung |
|-------|-------|-----------|
| Terraform Apply | 5 min | Infrastruktur |
| Base Image | 45-60 min | OS + Language Packs |
| Apps Image | 60-90 min | Nur wenn SAS URLs vorhanden |
| Monthly Updates | 30-45 min | Nur für Updates |

**Total (Base only):** ~1 Stunde
**Total (Full):** ~2.5-3 Stunden

---

## ✅ Erfolgskriterien

Nach dem Build sollten Sie haben:
- ✅ Resource Group in Azure
- ✅ AVD Host Pool, App Group, Workspace
- ✅ Shared Image Gallery mit Image-Version
- ✅ Image-Version im Format: YYYY.MM.DD (z.B. 2025.02.07)
- ✅ Packer-Logs ohne Fehler
- ✅ Image in SIG mit Status "Succeeded"

---

## 🎯 Nächste Schritte nach erfolgreichem Build

1. **Test-VM deployen** - VM von neuem Image erstellen und testen
2. **Session Hosts erstellen** - Neue AVD Session Hosts mit Image deployen
3. **User Testing** - Funktionstest mit echten Benutzern
4. **Optimierungen** - Wenn alles läuft → Optimierungen aus den Strategie-Dokumenten umsetzen

---

**Viel Erfolg! 🚀**

Bei Problemen: Prüfen Sie die Logs und das Troubleshooting-Kapitel.
