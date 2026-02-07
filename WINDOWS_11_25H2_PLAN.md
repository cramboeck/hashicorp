# 🎯 Windows 11 25H2 Multisession - Vorbereitungsplan

## Ziel
Nächste Woche erfolgreich ein Windows 11 25H2 Multisession AVD Image erstellen

## Zeitplan
- **HEUTE (Tag 0)**: Kritische Blocker beheben
- **Diese Woche**: Optimierungen & Tests
- **Nächste Woche**: Production Build

---

## 🔴 PHASE 1: KRITISCHE BLOCKER (HEUTE)

### Problem 1: SAS Tokens laufen ab ❌

**Gefundene SAS Tokens in `02-appscustom-packer/avd-image.pkr.hcl`:**

| Datei | Ablaufdatum | Status | Zeile |
|-------|-------------|--------|-------|
| PADT-Greenshot.zip | 2025-05-29 | ⚠️ In 112 Tagen | 98 |
| PADT-CountrySwitch.zip | 2025-06-07 | ⚠️ In 121 Tagen | 109 |
| PADT-Microsoft365.zip | 2025-06-07 | ⚠️ In 121 Tagen | 121 |
| VDOT.zip | 2025-06-06 | ⚠️ In 120 Tagen | 137 |

**Lösung - Option A (EMPFOHLEN):**
```hcl
# In variables.pkr.hcl
variable "padt_greenshot_url" {
  type        = string
  description = "URL zu PADT-Greenshot.zip (mit SAS Token)"
  sensitive   = true
}

variable "padt_countryswitch_url" {
  type        = string
  description = "URL zu PADT-CountrySwitch.zip (mit SAS Token)"
  sensitive   = true
}

variable "padt_microsoft365_url" {
  type        = string
  description = "URL zu PADT-Microsoft365.zip (mit SAS Token)"
  sensitive   = true
}

variable "vdot_url" {
  type        = string
  description = "URL zu VDOT.zip (mit SAS Token)"
  sensitive   = true
}
```

**Lösung - Option B (BESTE LÖSUNG):**
Azure Key Vault Integration:
```powershell
# In Packer provisioner
$sasToken = (Get-AzKeyVaultSecret -VaultName 'your-keyvault' -Name 'padt-greenshot-sas').SecretValueText
```

**ACTION ITEMS:**
- [ ] Neue SAS Tokens mit längerer Laufzeit generieren (12 Monate)
- [ ] Variablen in variables.pkr.hcl hinzufügen
- [ ] Hardcoded URLs durch Variablen ersetzen
- [ ] OR: Azure Key Vault für automatische Rotation einrichten

---

### Problem 2: Hardcoded Image Version ❌

**Gefunden in:**
- `02-appscustom-packer/avd-image.pkr.hcl` Zeile 46: `"2025.05.24"`
- `03-monthly-packer/avd-monthly-image.pkr.hcl` Zeile 40: `"2025-05-22"`

**Lösung:**
```hcl
# Verwende Variable statt hardcoded value
image_version = var.sig_image_version

# Terraform generiert automatisch aktuelles Datum
# In 00-avd-terraform/locals.tf:
sig_image_version = formatdate("YYYY.MM.DD", timestamp())
```

**ACTION ITEMS:**
- [ ] Hardcoded "2025.05.24" durch var.sig_image_version ersetzen
- [ ] Hardcoded "2025-05-22" durch var.sig_image_version ersetzen
- [ ] Verifizieren dass Terraform locals.tf korrekt ist

---

### Problem 3: Windows 11 24H2 → 25H2 Update ❌

**Aktuell in `01-base-packer/avd-base-image.pkr.hcl` Zeile 39:**
```hcl
image_sku = "win11-24h2-avd-m365"
```

**Benötigt für 25H2 Multisession:**
```hcl
image_publisher = "MicrosoftWindowsDesktop"
image_offer     = "office-365"
image_sku       = "win11-25h2-avd-m365"  # ODER "win11-25h2-avd" ohne Office
image_version   = "latest"
```

**WICHTIG: Multisession vs. Enterprise**
- `win11-25h2-avd-m365` = Multisession + Office 365
- `win11-25h2-ent` = Single-session Enterprise (NICHT für AVD!)
- `win11-25h2-avd` = Multisession ohne Office

**ACTION ITEMS:**
- [ ] Azure Portal prüfen: Welche SKUs sind verfügbar?
- [ ] Entscheiden: Mit oder ohne Office 365?
- [ ] `image_sku` auf Windows 11 25H2 ändern
- [ ] Notiz: Auch in 02-appscustom-packer falls dort nicht auskommentiert

---

## 🟡 PHASE 2: WICHTIGE OPTIMIERUNGEN (DIESE WOCHE)

### Optimierung 1: Terraform Module vervollständigen

**Fehlende Module:**
- `domain_join` - Komplett leer
- `storageaccount` - Komplett leer (für FSLogix Profile Container)

**Entscheidung erforderlich:**
- Benötigen Sie Domain Join? (Entra ID Join oder AD DS?)
- Benötigen Sie FSLogix Profile Storage?

**ACTION ITEMS:**
- [ ] Klären: Domain Join Anforderung?
- [ ] Klären: FSLogix Storage Anforderung?
- [ ] Falls JA: Module implementieren
- [ ] Falls NEIN: Module entfernen oder als "TODO" dokumentieren

---

### Optimierung 2: Script-Duplikate eliminieren

**Problem:**
`Enable-WinRM.ps1` existiert 3x identisch:
- `01-base-packer/scripts/Enable-WinRM.ps1`
- `02-appscustom-packer/scripts/Enable-WinRM.ps1`
- `03-monthly-packer/scripts/Enable-WinRM.ps1`

**Lösung:**
```
shared-scripts/
  └── Enable-WinRM.ps1

# In Packer:
provisioner "powershell" {
  script = "../shared-scripts/Enable-WinRM.ps1"
}
```

**ACTION ITEMS:**
- [ ] Shared-scripts Verzeichnis erstellen
- [ ] Enable-WinRM.ps1 verschieben
- [ ] Alle Packer Configs updaten

---

### Optimierung 3: Azure Pipeline vervollständigen

**Aktuell:** Nur Debug-Phase
**Benötigt:** Vollständige Build-Pipeline

**ACTION ITEMS:**
- [ ] Terraform apply Stage hinzufügen
- [ ] Packer build Stages hinzufügen (base, apps, monthly)
- [ ] Error Handling & Notifications
- [ ] Artifact Publishing

---

## 🟢 PHASE 3: BEST PRACTICES (NÄCHSTE WOCHE)

### Best Practice 1: Module Dokumentation

**ACTION ITEMS:**
- [ ] README.md für jedes Terraform Modul
- [ ] Input/Output Tabellen
- [ ] Beispiele

### Best Practice 2: Testing

**ACTION ITEMS:**
- [ ] Terraform validate in CI/CD
- [ ] Packer validate vor Build
- [ ] terraform-docs für Auto-Dokumentation

### Best Practice 3: Secrets Management

**ACTION ITEMS:**
- [ ] Azure Key Vault für alle Secrets
- [ ] Automatische SAS Token Rotation
- [ ] Keine Secrets in Git

---

## ✅ CHECKLISTE FÜR NÄCHSTE WOCHE

### Vor dem Build:
- [ ] Terraform Backend konfiguriert (00-avd-terraform/backend.tf)
- [ ] terraform.tfvars mit Azure Credentials erstellt
- [ ] SAS Tokens aktualisiert (oder in Key Vault)
- [ ] Image SKU auf Windows 11 25H2 gesetzt
- [ ] Alle Hardcoded Values durch Variablen ersetzt

### Build-Prozess:
1. [ ] `terraform init` (00-avd-terraform)
2. [ ] `terraform plan` prüfen
3. [ ] `terraform apply` (erstellt Infrastruktur + Packer vars)
4. [ ] `packer build` (01-base-packer) - Base Image
5. [ ] Verifizieren: Base Image in SIG sichtbar?
6. [ ] `packer build` (02-appscustom-packer) - App Layer
7. [ ] Verifizieren: App Image in SIG sichtbar?
8. [ ] AVD Host Pool auf neues Image umstellen

### Nach dem Build:
- [ ] Image-Version in SIG verifizieren
- [ ] Test-VM von Image deployen
- [ ] Funktionstest durchführen
- [ ] Dokumentation aktualisieren
- [ ] Lessons Learned festhalten

---

## 📚 WISSEN VERTIEFEN: KEY CONCEPTS

### 1. Shared Image Gallery (SIG) Workflow
```
Marketplace Image (Win11 25H2)
    ↓
Base Image (mit Language Packs) → SIG Version 2025.02.15-base
    ↓
App Image (mit Software) → SIG Version 2025.02.15-apps
    ↓
Monthly Update → SIG Version 2025.03.01
```

### 2. Terraform → Packer Integration
```
Terraform (00-avd-terraform):
- Erstellt Azure Infrastruktur
- Erstellt SIG + Image Definition
- Generiert terraform.auto.pkrvars.json

Packer (01/02/03):
- Liest terraform.auto.pkrvars.json
- Nutzt SIG für Source & Destination
- Automatische Versionierung
```

### 3. Image Versioning Strategy
```
Format: YYYY.MM.DD (z.B. 2025.02.15)

Base:     2025.02.15-base
Apps:     2025.02.15-apps
Monthly:  2025.03.01
Monthly:  2025.04.01
```

### 4. AVD SKU Naming Convention
```
Pattern: {OS}-{Version}-{Type}-{Office}

Beispiele:
- win11-25h2-avd-m365    = Windows 11 25H2 Multisession + Office
- win11-25h2-avd         = Windows 11 25H2 Multisession ohne Office
- win11-25h2-ent         = Windows 11 25H2 Enterprise (Single-Session)
- win10-22h2-avd-m365    = Windows 10 22H2 Multisession + Office
```

---

## 🔧 OPTIMIERUNGEN: PRIORISIERTE LISTE

| # | Optimierung | Impact | Effort | Priorität | Für nächste Woche? |
|---|-------------|--------|--------|-----------|-------------------|
| 1 | SAS Tokens zu Variablen | 🔴 Hoch | 2h | P0 | ✅ JA |
| 2 | Windows 11 25H2 Update | 🔴 Hoch | 1h | P0 | ✅ JA |
| 3 | Hardcoded Versions fixen | 🔴 Hoch | 1h | P0 | ✅ JA |
| 4 | Script-Duplikate eliminieren | 🟡 Mittel | 2h | P1 | ⚠️ Optional |
| 5 | Module vervollständigen | 🟡 Mittel | 8h | P2 | ❌ NEIN |
| 6 | Azure Pipeline fertigstellen | 🟡 Mittel | 4h | P2 | ❌ NEIN |
| 7 | Key Vault Integration | 🟢 Niedrig | 4h | P3 | ❌ NEIN |
| 8 | Automatisierte Tests | 🟢 Niedrig | 8h | P3 | ❌ NEIN |

**FOKUS für nächste Woche:**
- ✅ P0 Items (1-3): MUSS gemacht werden
- ⚠️ P1 Items (4): Wenn Zeit ist
- ❌ P2/P3 Items (5-8): Nach erfolgreichem ersten Build

---

## 📊 ZEITPLAN

### HEUTE (Freitag, 7. Februar)
- ⏰ 2h: SAS Tokens aktualisieren & zu Variablen konvertieren
- ⏰ 1h: Windows 11 SKU auf 25H2 ändern
- ⏰ 1h: Hardcoded Image Versions fixen
- ⏰ 1h: Git Commit & Push

### Montag, 10. Februar
- ⏰ 2h: Terraform Backend & Variables konfigurieren
- ⏰ 1h: Azure Service Principal prüfen/erstellen
- ⏰ 2h: Terraform init, plan, apply (trockener Lauf)

### Dienstag, 11. Februar
- ⏰ 3h: Base Image Build (01-base-packer)
- ⏰ 1h: Verifizierung in SIG
- ⏰ 1h: Troubleshooting falls nötig

### Mittwoch, 12. Februar
- ⏰ 4h: App Image Build (02-appscustom-packer)
- ⏰ 1h: Verifizierung
- ⏰ 1h: Test-VM Deployment

### Donnerstag, 13. Februar
- ⏰ 2h: Funktionstest
- ⏰ 2h: Dokumentation
- ⏰ 1h: Lessons Learned
- ⏰ 1h: Optimierungen planen

### Freitag, 14. Februar
- ⏰ Buffer für unvorhergesehene Probleme
- ⏰ Oder: Monthly Update Process testen (03-monthly-packer)

---

## 💡 LESSONS LEARNED (bisher)

### Was funktioniert gut:
1. ✅ Modulare Terraform-Struktur
2. ✅ Getrennte Build-Stages (Base → Apps → Monthly)
3. ✅ Automatische Terraform → Packer Variable Generierung
4. ✅ Update-Scripts für einfache Bedienung

### Was verbesserungswürdig ist:
1. ⚠️ Hardcoded Werte (SAS Tokens, Versions, URLs)
2. ⚠️ Script-Duplikate (DRY Prinzip verletzt)
3. ⚠️ Fehlende Module (domain_join, storageaccount)
4. ⚠️ Unvollständige CI/CD Pipeline
5. ⚠️ Keine Modul-Dokumentation

### Was wir gelernt haben:
1. 📚 SIG Workflow: Base → Apps → Monthly für schnellere Updates
2. 📚 Terraform kann Packer-Variablen generieren
3. 📚 WinRM über HTTP OK für temporäre Build-VMs
4. 📚 Image Versioning mit Datum (YYYY.MM.DD) ist praktisch
5. 📚 Automation-Scripts verbessern User Experience erheblich

---

## 🎓 VERTIEFUNG: TECHNISCHE DETAILS

### AVD Multisession Besonderheiten

**Was ist Multisession?**
- Mehrere Benutzer gleichzeitig auf einer VM
- Windows 11/10 Enterprise Multi-Session Lizenz
- Optimiert für AVD (Remote Desktop Session Host)

**SKU Unterschiede:**
```
Single-Session (VDI):
- win11-25h2-ent (Enterprise)
- 1 Benutzer pro VM
- Persönlicher Desktop

Multi-Session (AVD):
- win11-25h2-avd (AVD Multi-Session)
- Mehrere Benutzer pro VM
- Pooled Desktops
- Kostengünstiger
```

**Für AVD wählen Sie:** `win11-25h2-avd-m365` oder `win11-25h2-avd`

### Image Build Pipeline Details

**Warum 3 Stages?**

1. **Base Image** (01-base-packer)
   - Grund: OS + Language Packs ändern sich selten
   - Build-Zeit: ~45-60 Min
   - Häufigkeit: 1x pro Quarter oder bei OS-Updates

2. **App Image** (02-appscustom-packer)
   - Grund: Software-Änderungen häufiger
   - Build-Zeit: ~60-90 Min
   - Häufigkeit: Bei Software-Updates

3. **Monthly Update** (03-monthly-packer)
   - Grund: Windows Updates monatlich
   - Build-Zeit: ~30-45 Min (schneller!)
   - Häufigkeit: Monatlich (automatisiert)

**Vorteil:** Statt 2h kompletter Rebuild nur 30-45min für Updates!

---

## 🎯 ERFOLGSKRITERIEN

### Nächste Woche ist erfolgreich wenn:
- [ ] Windows 11 25H2 Multisession Base Image in SIG
- [ ] App Image mit allen benötigten Anwendungen in SIG
- [ ] Test-VM erfolgreich von neuem Image deployed
- [ ] Alle Applikationen funktionieren
- [ ] Office 365 korrekt installiert und lizenziert
- [ ] User kann sich anmelden und arbeiten
- [ ] Dokumentiert: Was funktioniert hat, was nicht

---

## 📞 HILFE & RESSOURCEN

### Wenn Probleme auftreten:

**Problem: "Packer kann nicht zur VM verbinden"**
→ Lösung: WinRM Firewall-Regeln prüfen, NSG-Regeln prüfen

**Problem: "SAS Token expired"**
→ Lösung: Neue SAS Tokens generieren (12 Monate Gültigkeit)

**Problem: "Image nicht in SIG sichtbar"**
→ Lösung: Packer Logs prüfen, Subscription ID verifizieren

**Problem: "Terraform apply schlägt fehl"**
→ Lösung: Service Principal Berechtigungen prüfen (Contributor Role)

### Nützliche Commands:

```bash
# Terraform Debug
export TF_LOG=DEBUG
terraform apply

# Packer Debug
export PACKER_LOG=1
packer build -debug avd-base-image.pkr.hcl

# Azure CLI Debug
az account show
az sig image-definition list --gallery-name avd_sig --resource-group <RG-NAME>
```

---

## ✅ FINALE CHECKLISTE

Vor dem Start nächste Woche:
- [ ] Alle P0 Optimierungen implementiert
- [ ] Git Repository committed & gepusht
- [ ] Azure Credentials bereit
- [ ] Service Principal mit Contributor Role
- [ ] Storage Account für Terraform Backend bereit
- [ ] Dieser Plan ausgedruckt oder griffbereit
- [ ] Zeitslots im Kalender geblockt
- [ ] Kollegen informiert (falls Support benötigt)

---

**Erstellt:** 2025-02-07
**Für:** Windows 11 25H2 Multisession Image Build
**Ziel:** Nächste Woche (11.-14. Februar) Production-Ready Image
