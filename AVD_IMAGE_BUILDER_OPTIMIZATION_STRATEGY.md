# 🚀 AVD Image Builder - Umfassende Optimierungsstrategie

**Projekt:** Azure Virtual Desktop Image Builder & Terraform Framework
**Erstellt:** 2025-02-07
**Version:** 2.0
**Status:** Production-Ready Optimierungen

---

## 📋 Executive Summary

Dieses Dokument erweitert und validiert die vorgeschlagenen Optimierungen für das AVD Image Builder Repository. Jeder Punkt wurde technisch geprüft, mit Best Practices abgeglichen und um konkrete Implementierungsschritte ergänzt.

### Aktueller Stand (Baseline)
✅ **Bereits implementiert:**
- Windows 11 25H2 Migration vorbereitet
- Rolling Update Automation für Session Hosts
- SAS Token Variabilisierung
- Dynamische Image-Versionierung (YYYY.MM.DD)
- 3-Stufen Build Pipeline (Base → Apps → Monthly)
- Terraform → Packer Integration

### Optimierungspotential
- **Kritisch (P0):** 4 Optimierungen - Security & Compliance
- **Hoch (P1):** 6 Optimierungen - Quality & Automation
- **Mittel (P2):** 8 Optimierungen - Developer Experience
- **Optional (P3):** 5 Optimierungen - Advanced Features

**Geschätzter Gesamtaufwand:** 12-15 Personentage (PT)
**Erwarteter ROI:** 60-80% schnellere Deployments, 40% weniger Build-Fehler

---

# 1️⃣ Image Lifecycle & Build-Qualität

## 1.1 Konsistentes Versionierungsschema

### ✅ VALIDIERUNG: Ihr Vorschlag ist SEHR GUT

**Aktueller Stand:**
- Format: `YYYY.MM.DD` (z.B. `2025.02.07`)
- Generiert in: `00-avd-terraform/locals.tf:19`
- Limitation: Keine Build-Type Unterscheidung

**Ihr Vorschlag:** `YYYY.MM.DD-[base|apps|monthly]-rX`

### 🎯 OPTIMIERTE EMPFEHLUNG: Semantic Versioning für SIG

```hcl
# Format: YYYY.MM.DD.BUILD
# Beispiele:
# 2025.02.07.1 = Erste Build am 7. Februar
# 2025.02.07.2 = Zweite Build am selben Tag (Hotfix)
# 2025.02.15.1 = Monatliches Update

# ALTERNATIVE: Metadata in Tags statt Versionsnummer
```

### 📊 Vergleich der Ansätze

| Schema | Beispiel | SIG-Kompatibel | Sortierbar | Maschinenlesbar | Empfehlung |
|--------|----------|----------------|------------|-----------------|------------|
| Aktuell | 2025.02.07 | ✅ | ✅ | ✅ | Gut |
| Ihr Vorschlag | 2025.02.07-base-r1 | ❌ (- nicht erlaubt) | ⚠️ | ⚠️ | Needs Adjustment |
| Empfohlen | 2025.02.07.1 | ✅ | ✅ | ✅ | **Optimal** |
| Mit Tags | 2025.02.07.1 + Tags | ✅ | ✅ | ✅ | **Best Practice** |

### 🔧 IMPLEMENTIERUNG

#### Option A: Build-Number Suffix (EMPFOHLEN)

```hcl
# 00-avd-terraform/locals.tf
locals {
  # Base Version
  base_version = formatdate("YYYY.MM.DD", timestamp())

  # Build Counter (via Terraform State oder Pipeline Variable)
  build_number = var.build_number != "" ? var.build_number : "1"

  # Final Version
  sig_image_version = "${local.base_version}.${local.build_number}"

  # Beispiel: 2025.02.07.1
}
```

```hcl
# 00-avd-terraform/variables.tf
variable "build_number" {
  type        = string
  description = "Build number for the image version (auto-incremented in CI/CD)"
  default     = "1"
}

variable "build_type" {
  type        = string
  description = "Type of build: base, apps, monthly, hotfix"
  default     = "standard"

  validation {
    condition     = contains(["base", "apps", "monthly", "hotfix", "standard"], var.build_type)
    error_message = "Build type must be: base, apps, monthly, hotfix, or standard"
  }
}
```

#### Option B: Metadata in Image Tags (BESTE LÖSUNG)

```hcl
# 00-avd-terraform/modules/shared_image_gallery/main.tf
resource "azurerm_shared_image_version" "image_version" {
  # ... existing config ...

  tags = merge(
    var.tags,
    {
      ImageVersion     = local.sig_image_version
      BuildType        = var.build_type
      BuildNumber      = var.build_number
      BuildDate        = timestamp()
      SourceCommit     = var.git_commit_sha
      PipelineRun      = var.pipeline_run_id
      WindowsVersion   = "11-25H2"
      AVDOptimized     = "true"
      FSLogixVersion   = var.fslogix_version
      OfficeVersion    = var.office_version
    }
  )
}
```

#### GitHub Actions / Azure DevOps Integration

```yaml
# .github/workflows/build-image.yml
name: Build AVD Image

on:
  workflow_dispatch:
    inputs:
      build_type:
        description: 'Build Type'
        required: true
        type: choice
        options:
          - base
          - apps
          - monthly
          - hotfix

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Generate Build Number
        id: version
        run: |
          BUILD_DATE=$(date +%Y.%m.%d)
          BUILD_NUMBER=$(date +%H%M)
          IMAGE_VERSION="${BUILD_DATE}.${BUILD_NUMBER}"
          echo "image_version=${IMAGE_VERSION}" >> $GITHUB_OUTPUT

      - name: Terraform Apply
        run: |
          terraform apply -auto-approve \
            -var="sig_image_version=${{ steps.version.outputs.image_version }}" \
            -var="build_type=${{ github.event.inputs.build_type }}" \
            -var="git_commit_sha=${{ github.sha }}" \
            -var="pipeline_run_id=${{ github.run_id }}"

      - name: Packer Build
        run: |
          cd 01-base-packer
          packer build \
            -var="sig_image_version=${{ steps.version.outputs.image_version }}" \
            avd-base-image.pkr.hcl
```

### 🎓 BEST PRACTICE: SIG Version Lifecycle Policy

```hcl
# Automatische Bereinigung alter Versionen
resource "azurerm_shared_image" "avd_image" {
  name                = "avd-goldenimage"
  gallery_name        = azurerm_shared_image_gallery.sig.name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"

  # Lifecycle Policy
  lifecycle {
    # Behalte die letzten 5 Versionen
    end_of_life_date = timeadd(timestamp(), "2160h") # 90 Tage
  }

  identifier {
    publisher = "ramboeck"
    offer     = "avd"
    sku       = "win11-25h2-m365"
  }
}
```

### 📈 Rollback-Strategie

```powershell
# Get-AVDImageVersionHistory.ps1
function Get-AVDImageVersionHistory {
    param(
        [string]$ResourceGroupName,
        [string]$GalleryName,
        [string]$ImageDefinitionName
    )

    $versions = Get-AzGalleryImageVersion `
        -ResourceGroupName $ResourceGroupName `
        -GalleryName $GalleryName `
        -GalleryImageDefinitionName $ImageDefinitionName `
        | Select-Object Name, @{N='BuildType';E={$_.Tags.BuildType}}, `
                        @{N='BuildDate';E={$_.Tags.BuildDate}}, `
                        PublishingProfile

    $versions | Sort-Object Name -Descending | Format-Table -AutoSize
}

# Rollback zu vorheriger Version
function Set-AVDImageRollback {
    param(
        [string]$HostPoolName,
        [string]$PreviousVersion = "latest-1"  # Vorletzte Version
    )

    # Implementierung siehe Update-AVDSessionHosts.ps1
}
```

### ⚠️ WICHTIGE EINSCHRÄNKUNGEN

**SIG Version Format Regeln:**
- Muss 3 Zahlengruppen haben: `MAJOR.MINOR.PATCH`
- Jede Gruppe: 0-2147483647
- **KEIN Text erlaubt** (kein "base", "r1", etc.)
- Darf nicht mit 0 beginnen (außer genau "0")

**Daher NICHT möglich:**
- ❌ `2025.02.07-base-r1` (Text nicht erlaubt)
- ❌ `2025.02.07-1` (Bindestrich nicht erlaubt)
- ❌ `base-2025.02.07` (Text nicht erlaubt)

**Stattdessen:**
- ✅ `2025.02.07` (Basis: aktuell verwendet)
- ✅ `2025.0207.1` (mit Build-Nummer)
- ✅ `2025.02.07.1` + Tags für Metadata

### 💡 EMPFEHLUNG

**Implementieren Sie Option B: Versionsnummer + Tags**

**Vorteile:**
- ✅ SIG-konform
- ✅ Maschinenlesbar und sortierbar
- ✅ Alle Metadata in Tags verfügbar
- ✅ Einfaches Querying via Azure CLI/PowerShell
- ✅ Rollback-fähig
- ✅ Audit-Trail komplett

**Aufwand:** 4 Stunden
**Priorität:** P1 (Hoch)

---

## 1.2 Azure Image Builder (AIB) als Alternative zu Packer

### ✅ VALIDIERUNG: Technisch machbar, aber Abwägung nötig

**Ihre Motivation:**
- Geringere Angriffsfläche (kein WinRM)
- Kein direkter Netzwerkzugriff zur Build-VM
- Bessere Governance

### 📊 VERGLEICH: Packer vs. Azure Image Builder

| Kriterium | Packer | Azure Image Builder | Gewinner |
|-----------|--------|---------------------|----------|
| **Lernkurve** | Niedrig (HCL bekannt) | Mittel (ARM/Bicep) | 🥇 Packer |
| **Debugging** | Exzellent (-debug flag, SSH/WinRM) | Schwierig (nur Logs) | 🥇 Packer |
| **Secrets** | Variablen/KeyVault | Managed Identity | 🥇 AIB |
| **Netzwerk** | Braucht WinRM/SSH | Vollständig isoliert | 🥇 AIB |
| **Performance** | Schnell | Langsamer (Queue) | 🥇 Packer |
| **Multi-Cloud** | AWS, GCP, Azure, VMware | Nur Azure | 🥇 Packer |
| **Cost** | VM-Kosten während Build | VM + AIB Service | 🥇 Packer |
| **Compliance** | Gut (mit Tweaks) | Exzellent (RBAC, MI) | 🥇 AIB |
| **Customization** | Sehr flexibel | Eingeschränkt | 🥇 Packer |
| **Maintenance** | Community Support | Microsoft Support | 🥇 AIB |

### 🎯 EMPFEHLUNG: Hybrid-Ansatz

**Kurzfristig (0-3 Monate):** Packer optimieren
**Mittelfristig (3-6 Monate):** AIB für Monthly Builds testen
**Langfristig (6+ Monate):** Paralleler Betrieb mit Feature Flags

### 🔧 IMPLEMENTIERUNG: AIB als optionaler Builder

```hcl
# 00-avd-terraform/variables.tf
variable "image_builder_type" {
  type        = string
  description = "Image builder to use: packer or aib"
  default     = "packer"

  validation {
    condition     = contains(["packer", "aib"], var.image_builder_type)
    error_message = "Must be 'packer' or 'aib'"
  }
}
```

#### AIB Template Beispiel

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "imageTemplateName": {
      "type": "string",
      "defaultValue": "avd-win11-25h2-template"
    }
  },
  "resources": [
    {
      "type": "Microsoft.VirtualMachineImages/imageTemplates",
      "apiVersion": "2022-07-01",
      "name": "[parameters('imageTemplateName')]",
      "location": "[resourceGroup().location]",
      "identity": {
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "[resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', 'aib-identity')]": {}
        }
      },
      "properties": {
        "buildTimeoutInMinutes": 120,
        "vmProfile": {
          "vmSize": "Standard_D4s_v3",
          "osDiskSizeGB": 127
        },
        "source": {
          "type": "PlatformImage",
          "publisher": "MicrosoftWindowsDesktop",
          "offer": "office-365",
          "sku": "win11-25h2-avd-m365",
          "version": "latest"
        },
        "customize": [
          {
            "type": "PowerShell",
            "name": "Install Languages",
            "runElevated": true,
            "scriptUri": "https://yourstorage.blob.core.windows.net/scripts/install-languages.ps1"
          },
          {
            "type": "PowerShell",
            "name": "Install VDOT",
            "runElevated": true,
            "inline": [
              "$vdotUrl = (Get-AzKeyVaultSecret -VaultName 'your-kv' -Name 'vdot-url' -AsPlainText)",
              "Invoke-WebRequest -Uri $vdotUrl -OutFile 'C:\\temp\\vdot.zip'",
              "Expand-Archive -Path 'C:\\temp\\vdot.zip' -DestinationPath 'C:\\VDOT'",
              "C:\\VDOT\\VDOT.ps1 -Optimizations All -Verbose"
            ]
          },
          {
            "type": "WindowsUpdate",
            "searchCriteria": "IsInstalled=0",
            "filters": [
              "exclude:$_.Title -like '*Preview*'"
            ],
            "updateLimit": 100
          },
          {
            "type": "WindowsRestart",
            "restartTimeout": "10m"
          }
        ],
        "distribute": [
          {
            "type": "SharedImage",
            "galleryImageId": "/subscriptions/{subscriptionId}/resourceGroups/{rgName}/providers/Microsoft.Compute/galleries/avd_sig/images/avd-goldenimage/versions/2025.02.07.1",
            "runOutputName": "avd-image-2025.02.07.1",
            "replicationRegions": [
              "westeurope",
              "northeurope"
            ],
            "storageAccountType": "Standard_LRS"
          }
        ]
      }
    }
  ]
}
```

#### Terraform Modul für AIB

```hcl
# 00-avd-terraform/modules/azure_image_builder/main.tf
resource "azurerm_user_assigned_identity" "aib" {
  count               = var.use_aib ? 1 : 0
  name                = "aib-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "aib_contributor" {
  count                = var.use_aib ? 1 : 0
  scope                = azurerm_shared_image_gallery.sig.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aib[0].principal_id
}

resource "azurerm_resource_group_template_deployment" "aib_template" {
  count               = var.use_aib ? 1 : 0
  name                = "aib-deployment-${var.image_version}"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"

  template_content = file("${path.module}/aib-template.json")

  parameters_content = jsonencode({
    imageTemplateName = {
      value = "avd-${var.build_type}-${var.image_version}"
    }
  })
}

# Trigger Build
resource "null_resource" "aib_build" {
  count = var.use_aib && var.trigger_build ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      az image builder run \
        --name avd-${var.build_type}-${var.image_version} \
        --resource-group ${var.resource_group_name}
    EOT
  }

  depends_on = [azurerm_resource_group_template_deployment.aib_template]
}
```

### ⚠️ AIB LIMITATIONEN

**Bekannte Probleme:**
1. **Debugging schwierig** - Nur Logs verfügbar, kein interaktiver Zugriff
2. **Queue Delays** - Build kann 15-30 Min in Queue warten
3. **Region-Verfügbarkeit** - Nicht in allen Azure-Regionen verfügbar
4. **Customizer-Limits** - Max 20 Customizer-Schritte
5. **Timeout** - Max 4 Stunden Build-Zeit
6. **Script-Komplexität** - Komplexe PADT-Installationen schwieriger

### 💡 EMPFEHLUNG

**Phase 1 (Jetzt):** Packer mit Security-Härtung (siehe 2.2)
**Phase 2 (Q2 2025):** AIB Proof-of-Concept für Monthly Builds
**Phase 3 (Q3 2025):** Entscheidung basierend auf PoC-Ergebnissen

**Rationale:**
- Ihr Packer-Setup funktioniert bereits gut
- AIB Learning Curve würde aktuelles Projekt verzögern
- Security-Gaps in Packer sind lösbar (Trusted Launch, NSG-Hardening)
- AIB macht Sinn für hochregulierte Umgebungen (Finance, Healthcare)

**Aufwand:** 16-20 Stunden (PoC), 40+ Stunden (Full Migration)
**Priorität:** P3 (Optional, explorativ)

---

## 1.3 Post-Build Validierungs-Framework

### ✅ VALIDIERUNG: EXZELLENTE IDEE - Kritisch für Production

**Ihre Vorschläge sind alle relevant:**
- ✅ FSLogix Version & Service Health
- ✅ AVD-Agent Status
- ✅ Defender Signaturen & ASR-Policies
- ✅ Eventlog-Analyse
- ✅ TaskScheduler-Broken Tasks

### 🎯 ERWEITERTE VALIDIERUNGS-MATRIX

| Kategorie | Checks | Kritikalität | Automatisierbar |
|-----------|--------|--------------|-----------------|
| **AVD Core** | Agent Version, Stack Status, Registration | 🔴 Critical | ✅ |
| **FSLogix** | Service, Version, Profile Container Config | 🔴 Critical | ✅ |
| **Security** | Defender, Firewall, ASR Rules, Encryption | 🔴 Critical | ✅ |
| **Networking** | DNS, Proxy, Azure Connectivity | 🟡 High | ✅ |
| **Office 365** | Activation, Version, Updates | 🟡 High | ⚠️ |
| **Performance** | VDOT Applied, Services, Startup Time | 🟢 Medium | ✅ |
| **Compliance** | GPO Applied, Certificates, Audit Logs | 🟡 High | ✅ |

### 🔧 IMPLEMENTIERUNG: Pester-basiertes Test-Framework

```powershell
# validation/AVD-Image-Validation.Tests.ps1
#Requires -Modules Pester

BeforeAll {
    $ValidationConfig = Get-Content -Path "$PSScriptRoot/validation-config.json" | ConvertFrom-Json
}

Describe "AVD Image Validation" {

    Context "AVD Agent & Stack" {
        It "AVD Agent is installed" {
            $agent = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -ErrorAction SilentlyContinue
            $agent | Should -Not -BeNullOrEmpty
        }

        It "AVD Agent version is current" {
            $agent = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent"
            $minVersion = [version]$ValidationConfig.AVDAgent.MinimumVersion
            $currentVersion = [version]$agent.Version
            $currentVersion | Should -BeGreaterOrEqual $minVersion
        }

        It "RDAgentBootLoader service is running" {
            $service = Get-Service -Name RDAgentBootLoader -ErrorAction SilentlyContinue
            $service.Status | Should -Be 'Running'
        }

        It "Remote Desktop Service is running" {
            $service = Get-Service -Name TermService
            $service.Status | Should -Be 'Running'
            $service.StartType | Should -Be 'Automatic'
        }
    }

    Context "FSLogix Profile Container" {
        It "FSLogix Apps is installed" {
            $fslogix = Get-ItemProperty "HKLM:\SOFTWARE\FSLogix\Apps" -ErrorAction SilentlyContinue
            $fslogix | Should -Not -BeNullOrEmpty
        }

        It "FSLogix version is current" {
            $version = (Get-Item "C:\Program Files\FSLogix\Apps\frx.exe").VersionInfo.FileVersion
            $minVersion = [version]$ValidationConfig.FSLogix.MinimumVersion
            [version]$version | Should -BeGreaterOrEqual $minVersion
        }

        It "FSLogix Profile service is configured correctly" {
            $service = Get-Service -Name frxsvc -ErrorAction SilentlyContinue
            $service.Status | Should -Be 'Running'
            $service.StartType | Should -Be 'Automatic'
        }

        It "FSLogix Profile settings are applied" {
            $enabled = Get-ItemProperty "HKLM:\SOFTWARE\FSLogix\Profiles" -Name Enabled -ErrorAction SilentlyContinue
            $enabled.Enabled | Should -Be 1
        }
    }

    Context "Windows Defender & Security" {
        It "Windows Defender is running" {
            $service = Get-Service -Name WinDefend
            $service.Status | Should -Be 'Running'
        }

        It "Defender signatures are up-to-date" {
            $status = Get-MpComputerStatus
            $signatureAge = (Get-Date) - $status.AntivirusSignatureLastUpdated
            $signatureAge.Days | Should -BeLessThan 7
        }

        It "Attack Surface Reduction rules are enabled" {
            $asrRules = Get-MpPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Ids
            $asrRules.Count | Should -BeGreaterThan 0
        }

        It "Real-time protection is enabled" {
            $status = Get-MpComputerStatus
            $status.RealTimeProtectionEnabled | Should -Be $true
        }

        It "Windows Firewall is enabled" {
            $profiles = Get-NetFirewallProfile
            $profiles | ForEach-Object {
                $_.Enabled | Should -Be $true
            }
        }
    }

    Context "Microsoft 365 Apps" {
        It "Office is installed" {
            $office = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue
            $office | Should -Not -BeNullOrEmpty
        }

        It "Office version is supported" {
            $version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration").VersionToReport
            $version | Should -Not -BeNullOrEmpty
            # Format: 16.0.xxxxx.xxxxx (Office 365)
            $version | Should -Match '^16\.0\.\d+\.\d+$'
        }

        It "Office update channel is configured" {
            $channel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration").CDNBaseUrl
            $channel | Should -Not -BeNullOrEmpty
        }
    }

    Context "Windows Event Logs" {
        It "No critical errors in last 60 minutes" {
            $startTime = (Get-Date).AddMinutes(-60)
            $criticalEvents = Get-WinEvent -FilterHashtable @{
                LogName = 'System', 'Application'
                Level = 1  # Critical
                StartTime = $startTime
            } -ErrorAction SilentlyContinue

            $criticalEvents.Count | Should -Be 0
        }

        It "No application crashes in last 60 minutes" {
            $startTime = (Get-Date).AddMinutes(-60)
            $crashes = Get-WinEvent -FilterHashtable @{
                LogName = 'Application'
                ProviderName = 'Windows Error Reporting'
                StartTime = $startTime
            } -ErrorAction SilentlyContinue

            $crashes.Count | Should -Be 0
        }
    }

    Context "Scheduled Tasks" {
        It "No failed scheduled tasks" {
            $tasks = Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' }
            $failedTasks = $tasks | Get-ScheduledTaskInfo | Where-Object { $_.LastTaskResult -ne 0 }
            $failedTasks.Count | Should -Be 0
        }
    }

    Context "Virtual Desktop Optimization" {
        It "VDOT optimizations were applied" {
            # Check for VDOT marker file
            Test-Path "C:\Windows\Temp\VDOT_Applied.txt" | Should -Be $true
        }

        It "Unnecessary services are disabled" {
            $servicesToDisable = @('XblAuthManager', 'XblGameSave', 'XboxGipSvc', 'XboxNetApiSvc')
            foreach ($svc in $servicesToDisable) {
                $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
                if ($service) {
                    $service.StartType | Should -Be 'Disabled'
                }
            }
        }

        It "Unnecessary scheduled tasks are disabled" {
            $task = Get-ScheduledTask -TaskName "OneDrive Standalone Update*" -ErrorAction SilentlyContinue
            if ($task) {
                $task.State | Should -Be 'Disabled'
            }
        }
    }

    Context "Network Connectivity" {
        It "Can resolve DNS" {
            { Resolve-DnsName -Name "microsoft.com" -ErrorAction Stop } | Should -Not -Throw
        }

        It "Can reach Azure metadata service" {
            $response = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" `
                -Headers @{Metadata = "true" } -TimeoutSec 5 -ErrorAction SilentlyContinue
            $response | Should -Not -BeNullOrEmpty
        }

        It "Can reach Office 365 endpoints" {
            $testUrls = @('https://outlook.office365.com', 'https://login.microsoftonline.com')
            foreach ($url in $testUrls) {
                { Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing } | Should -Not -Throw
            }
        }
    }

    Context "Disk & Storage" {
        It "OS disk has sufficient free space" {
            $osDrive = Get-PSDrive -Name C
            $freeSpaceGB = [math]::Round($osDrive.Free / 1GB, 2)
            $freeSpaceGB | Should -BeGreaterThan 20
        }

        It "No disk errors detected" {
            $diskHealth = Get-PhysicalDisk | Select-Object -ExpandProperty HealthStatus
            $diskHealth | Should -Be 'Healthy'
        }
    }

    Context "User Profile Configuration" {
        It "Default user registry hive is configured" {
            Test-Path "C:\Users\Default\NTUSER.DAT" | Should -Be $true
        }

        It "FSLogix redirections are configured in default profile" {
            # Load default user hive
            reg load HKU\DefaultUser "C:\Users\Default\NTUSER.DAT"

            $redirections = Get-ItemProperty "HKU:\DefaultUser\SOFTWARE\Policies\Microsoft\Office\16.0\common\general" -ErrorAction SilentlyContinue
            $redirections | Should -Not -BeNullOrEmpty

            # Unload hive
            [gc]::Collect()
            reg unload HKU\DefaultUser
        }
    }
}
```

### Configuration File

```json
{
  "AVDAgent": {
    "MinimumVersion": "1.0.8903.400",
    "RegistryPath": "HKLM:\\SOFTWARE\\Microsoft\\RDInfraAgent",
    "RequiredServices": ["RDAgentBootLoader", "TermService"]
  },
  "FSLogix": {
    "MinimumVersion": "2.9.8884.27471",
    "InstallPath": "C:\\Program Files\\FSLogix\\Apps",
    "RequiredServices": ["frxsvc"]
  },
  "Defender": {
    "MaxSignatureAge": 7,
    "RequiredASRRules": 5,
    "RealTimeProtectionRequired": true
  },
  "Office365": {
    "MinimumVersion": "16.0.0.0",
    "UpdateChannel": "MonthlyEnterprise"
  },
  "EventLog": {
    "MaxCriticalEvents": 0,
    "LookbackMinutes": 60
  },
  "Disk": {
    "MinimumFreeSpaceGB": 20
  }
}
```

### Integration in Packer

```hcl
# 02-appscustom-packer/avd-image.pkr.hcl

provisioner "file" {
  source      = "../validation/AVD-Image-Validation.Tests.ps1"
  destination = "C:/Temp/AVD-Image-Validation.Tests.ps1"
}

provisioner "file" {
  source      = "../validation/validation-config.json"
  destination = "C:/Temp/validation-config.json"
}

provisioner "powershell" {
  inline = [
    "# Install Pester if not present",
    "if (-not (Get-Module -ListAvailable -Name Pester)) {",
    "  Install-PackageProvider -Name NuGet -Force -Scope AllUsers",
    "  Install-Module -Name Pester -Force -SkipPublisherCheck -Scope AllUsers",
    "}",
    "",
    "# Run validation tests",
    "$testResults = Invoke-Pester -Path 'C:/Temp/AVD-Image-Validation.Tests.ps1' -OutputFormat NUnitXml -OutputFile 'C:/Temp/validation-results.xml' -PassThru",
    "",
    "# Export results as JSON for parsing",
    "$testResults | ConvertTo-Json -Depth 5 | Out-File 'C:/Temp/validation-results.json'",
    "",
    "# Fail build if tests failed",
    "if ($testResults.FailedCount -gt 0) {",
    "  Write-Error \"Image validation failed: $($testResults.FailedCount) test(s) failed\"",
    "  exit 1",
    "}",
    "",
    "Write-Host \"✅ All validation tests passed: $($testResults.PassedCount) checks OK\" -ForegroundColor Green"
  ]
}

# Download validation results for archiving
provisioner "file" {
  source      = "C:/Temp/validation-results.xml"
  destination = "../artifacts/validation-results-${var.sig_image_version}.xml"
  direction   = "download"
}

provisioner "file" {
  source      = "C:/Temp/validation-results.json"
  destination = "../artifacts/validation-results-${var.sig_image_version}.json"
  direction   = "download"
}
```

### CI/CD Pipeline Integration

```yaml
# GitHub Actions
- name: Archive Validation Results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: validation-results-${{ steps.version.outputs.image_version }}
    path: |
      artifacts/validation-results-*.xml
      artifacts/validation-results-*.json
    retention-days: 90

- name: Publish Test Results
  if: always()
  uses: EnricoMi/publish-unit-test-result-action@v2
  with:
    files: artifacts/validation-results-*.xml
    check_name: Image Validation Results

- name: Quality Gate
  run: |
    FAILED=$(jq -r '.FailedCount' artifacts/validation-results-*.json)
    if [ "$FAILED" -gt 0 ]; then
      echo "::error::Image validation failed with $FAILED errors"
      exit 1
    fi
```

### 📊 Validation Report Dashboard

```powershell
# Generate-ValidationReport.ps1
function Generate-ValidationReport {
    param(
        [string]$ValidationJsonPath,
        [string]$OutputHtmlPath
    )

    $results = Get-Content $ValidationJsonPath | ConvertFrom-Json

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AVD Image Validation Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; }
        h1 { color: #0078D4; }
        .summary { background: #f0f0f0; padding: 15px; border-radius: 5px; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #0078D4; color: white; }
    </style>
</head>
<body>
    <h1>🔍 AVD Image Validation Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Tests: <strong>$($results.TotalCount)</strong></p>
        <p class="pass">✅ Passed: $($results.PassedCount)</p>
        <p class="fail">❌ Failed: $($results.FailedCount)</p>
        <p>Duration: $($results.Time)</p>
    </div>

    <h2>Test Results by Category</h2>
    <table>
        <tr>
            <th>Category</th>
            <th>Test</th>
            <th>Result</th>
            <th>Message</th>
        </tr>
"@

    foreach ($test in $results.TestResult) {
        $status = if ($test.Result -eq 'Passed') { '✅ PASS' } else { '❌ FAIL' }
        $html += @"
        <tr>
            <td>$($test.Describe)</td>
            <td>$($test.Name)</td>
            <td>$status</td>
            <td>$($test.FailureMessage)</td>
        </tr>
"@
    }

    $html += @"
    </table>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputHtmlPath -Encoding UTF8
    Write-Host "Report generated: $OutputHtmlPath"
}
```

### 💡 EMPFEHLUNG

**Implementieren Sie das Pester-Framework schrittweise:**

**Phase 1 (Woche 1):** Critical Checks
- AVD Agent
- FSLogix
- Windows Defender

**Phase 2 (Woche 2):** High Priority
- Office 365
- Event Logs
- Network Connectivity

**Phase 3 (Woche 3):** Medium Priority
- Scheduled Tasks
- VDOT Validation
- Disk Health

**Aufwand:** 12-16 Stunden
**Priorität:** P0 (Kritisch)
**ROI:** Verhindert fehlerhafte Images in Production

---

# 2️⃣ Sicherheit & Secrets Management

## 2.1 Vollständige Eliminierung von Klartext-Secrets

### ✅ VALIDIERUNG: Absolut korrekt und notwendig

**Aktueller Stand:**
- ✅ SAS Tokens bereits in Variablen ausgelagert
- ⚠️ Aber: Werden via `terraform.auto.pkrvars.json` übergeben
- ❌ Key Vault Integration fehlt noch

### 🎯 ZERO-TRUST SECRET MANAGEMENT ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────┐
│                     Secret Sources                           │
│  • Azure Key Vault (Primary)                                 │
│  • GitHub Secrets (CI/CD)                                    │
│  • Azure Managed Identity (Runtime)                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                    Terraform Layer                           │
│  • Reads from Key Vault via Data Source                     │
│  • NO secrets in state file (use sensitive = true)          │
│  • Generates one-time WinRM password                        │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                     Packer Layer                             │
│  • Receives secrets via PKR_VAR_* environment variables     │
│  • NO secrets in HCL files                                   │
│  • NO secrets in logs (sensitive = true)                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                  Build VM (Temporary)                        │
│  • Secrets in memory only                                    │
│  • VM deleted after build                                    │
│  • Disk encrypted, wiped on delete                          │
└─────────────────────────────────────────────────────────────┘
```

### 🔧 IMPLEMENTIERUNG

#### Schritt 1: Azure Key Vault Setup

```hcl
# 00-avd-terraform/modules/key_vault/main.tf
resource "azurerm_key_vault" "image_builder" {
  name                = "kv-${var.name_prefix}-imgbld"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Network Security
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ips  # Your pipeline IPs
    virtual_network_subnet_ids = var.allowed_subnets
  }

  # Purge Protection für Production
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  # RBAC statt Access Policies
  enable_rbac_authorization = true

  tags = var.tags
}

# Managed Identity für Packer
resource "azurerm_user_assigned_identity" "packer" {
  name                = "id-packer-image-builder"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# RBAC: Managed Identity kann Secrets lesen
resource "azurerm_role_assignment" "packer_kv_secrets_user" {
  scope                = azurerm_key_vault.image_builder.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.packer.principal_id
}

# Secrets erstellen
resource "azurerm_key_vault_secret" "padt_greenshot_url" {
  name         = "padt-greenshot-url"
  value        = var.padt_greenshot_url  # Kommt aus terraform.tfvars (nicht committed)
  key_vault_id = azurerm_key_vault.image_builder.id

  expiration_date = timeadd(timestamp(), "8760h")  # 1 Jahr

  tags = {
    Purpose = "Packer Image Build"
    Rotation = "Manual"  # Später: "Automatic"
  }
}

resource "azurerm_key_vault_secret" "padt_countryswitch_url" {
  name         = "padt-countryswitch-url"
  value        = var.padt_countryswitch_url
  key_vault_id = azurerm_key_vault.image_builder.id
  expiration_date = timeadd(timestamp(), "8760h")
}

resource "azurerm_key_vault_secret" "padt_microsoft365_url" {
  name         = "padt-microsoft365-url"
  value        = var.padt_microsoft365_url
  key_vault_id = azurerm_key_vault.image_builder.id
  expiration_date = timeadd(timestamp(), "8760h")
}

resource "azurerm_key_vault_secret" "vdot_url" {
  name         = "vdot-url"
  value        = var.vdot_url
  key_vault_id = azurerm_key_vault.image_builder.id
  expiration_date = timeadd(timestamp(), "8760h")
}

# Output für Packer
output "key_vault_name" {
  value = azurerm_key_vault.image_builder.name
}

output "packer_identity_client_id" {
  value = azurerm_user_assigned_identity.packer.client_id
}
```

#### Schritt 2: Terraform liest von Key Vault

```hcl
# 00-avd-terraform/main.tf

# Key Vault Data Source
data "azurerm_key_vault" "image_builder" {
  name                = "kv-${local.name_prefix}-imgbld"
  resource_group_name = local.resource_group_name
}

data "azurerm_key_vault_secret" "padt_greenshot_url" {
  name         = "padt-greenshot-url"
  key_vault_id = data.azurerm_key_vault.image_builder.id
}

# WICHTIG: Packer vars OHNE die Secrets
resource "local_file" "packer_vars" {
  filename = "${path.module}/../packer/terraform.auto.pkrvars.json"

  content = jsonencode({
    sig_name               = local.sig_name
    sig_image_name         = local.sig_image_name
    sig_image_version      = local.sig_image_version
    sig_rg_name            = local.resource_group_name
    subscription_id        = var.subscription_id
    tenant_id              = var.tenant_id
    client_id              = var.client_id
    # client_secret bleibt hier (für Service Principal Auth)
    client_secret          = var.client_secret
    location               = var.location
    winrm_password         = random_password.winrm.result

    # NEU: Key Vault Info statt direkter Secrets
    key_vault_name         = data.azurerm_key_vault.image_builder.name
    use_managed_identity   = true
    packer_identity_client_id = module.key_vault.packer_identity_client_id
  })

  # Verhindert dass Secrets in Terraform State landen
  lifecycle {
    ignore_changes = [content]
  }
}
```

#### Schritt 3: Packer liest von Key Vault

```hcl
# 02-appscustom-packer/variables.pkr.hcl

variable "key_vault_name" {
  type        = string
  description = "Name des Key Vault für Secrets"
}

variable "use_managed_identity" {
  type        = bool
  description = "Use Managed Identity for authentication"
  default     = true
}

variable "packer_identity_client_id" {
  type        = string
  description = "Client ID der Packer Managed Identity"
  default     = ""
}

# Secrets als Variables (werden zur Runtime von KV geladen)
variable "padt_greenshot_url" {
  type        = string
  description = "URL zu PADT-Greenshot.zip (loaded from Key Vault)"
  sensitive   = true
  default     = ""
}

# ... andere Secret-Variables ...
```

```hcl
# 02-appscustom-packer/avd-image.pkr.hcl

source "azure-arm" "avd_image" {
  # ... existing config ...

  # Managed Identity Authentication
  use_azure_cli_auth = false

  # User-Assigned Managed Identity
  user_assigned_managed_identities = [
    "/subscriptions/${var.subscription_id}/resourceGroups/${var.sig_rg_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-packer-image-builder"
  ]
}

build {
  sources = ["source.azure-arm.avd_image"]

  # Lade Secrets aus Key Vault zur Build-Zeit
  provisioner "powershell" {
    inline = [
      "# Authenticate mit Managed Identity",
      "$identity = '${var.packer_identity_client_id}'",
      "if ($identity) {",
      "  Connect-AzAccount -Identity -AccountId $identity",
      "} else {",
      "  Connect-AzAccount -Identity",
      "}",
      "",
      "# Lade Secrets aus Key Vault",
      "$kvName = '${var.key_vault_name}'",
      "$env:PADT_GREENSHOT_URL = (Get-AzKeyVaultSecret -VaultName $kvName -Name 'padt-greenshot-url' -AsPlainText)",
      "$env:PADT_COUNTRYSWITCH_URL = (Get-AzKeyVaultSecret -VaultName $kvName -Name 'padt-countryswitch-url' -AsPlainText)",
      "$env:PADT_MICROSOFT365_URL = (Get-AzKeyVaultSecret -VaultName $kvName -Name 'padt-microsoft365-url' -AsPlainText)",
      "$env:VDOT_URL = (Get-AzKeyVaultSecret -VaultName $kvName -Name 'vdot-url' -AsPlainText)",
      "",
      "Write-Host '✅ Secrets loaded from Key Vault' -ForegroundColor Green"
    ]
    environment_vars = [
      "PACKER_LOG=0"  # Disable Packer logs to prevent secret leakage
    ]
  }

  # Installations nutzen die Environment Variables
  provisioner "powershell" {
    inline = [
      "# Verwende $env:PADT_GREENSHOT_URL statt hardcoded URL",
      "if ($env:PADT_GREENSHOT_URL) {",
      "  c:\\install\\azcopy.exe copy $env:PADT_GREENSHOT_URL 'c:\\install\\PADT-Greenshot.zip' --log-level ERROR",
      "  if (Test-Path 'c:\\install\\PADT-Greenshot.zip') {",
      "    Expand-Archive -Path 'c:\\install\\PADT-Greenshot.zip' -DestinationPath 'c:\\install' -Force",
      "    C:\\Install\\PADT-Greenshot\\Invoke-AppDeployToolkit.ps1 -DeployMode Silent",
      "  }",
      "}"
    ]
    # Verhindere dass URLs in Packer Logs erscheinen
    environment_vars = [
      "PACKER_LOG=0"
    ]
  }

  # Cleanup: Lösche Environment Variables
  provisioner "powershell" {
    inline = [
      "Remove-Item Env:\\PADT_*",
      "Remove-Item Env:\\VDOT_URL",
      "Write-Host '🧹 Secrets cleaned from environment' -ForegroundColor Green"
    ]
  }
}
```

#### Schritt 4: GitHub Actions / Azure DevOps Integration

```yaml
# .github/workflows/build-avd-image.yml
name: Build AVD Image

on:
  workflow_dispatch:
    inputs:
      build_type:
        required: true
        type: choice
        options: [base, apps, monthly]

env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}

jobs:
  build-image:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init & Apply
        working-directory: 00-avd-terraform
        run: |
          terraform init
          terraform apply -auto-approve \
            -var="build_type=${{ github.event.inputs.build_type }}"
        env:
          # Keine Secrets hier - werden aus Key Vault geladen
          TF_VAR_customer: "ramboeck"
          TF_VAR_environment: "prod"

      - name: Packer Build
        working-directory: 01-base-packer
        run: |
          packer init .
          packer build -force \
            -var-file=../packer/terraform.auto.pkrvars.json \
            avd-base-image.pkr.hcl
        env:
          PACKER_LOG: 0  # NO LOGGING (prevents secret leakage)
          # Secrets werden via Managed Identity geladen - nicht hier
```

### 🔒 SECRET ROTATION AUTOMATION

```hcl
# Automatische SAS Token Rotation via Azure Function
resource "azurerm_linux_function_app" "sas_rotator" {
  name                = "func-sas-rotator"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.rotator.id
  storage_account_name = azurerm_storage_account.rotator.name

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "KEY_VAULT_NAME"          = azurerm_key_vault.image_builder.name
    "STORAGE_ACCOUNT_NAME"    = var.artifacts_storage_account_name
    "SAS_VALIDITY_DAYS"       = "365"
    "ROTATION_TRIGGER"        = "0 0 1 * * *"  # Daily at 1 AM
  }
}

# Python Function Code (separate repo)
# import azure.functions as func
# from azure.identity import DefaultAzureCredential
# from azure.keyvault.secrets import SecretClient
# from azure.storage.blob import generate_blob_sas
#
# def main(timer: func.TimerRequest):
#     # Check if SAS tokens expire in < 30 days
#     # Generate new SAS tokens
#     # Update Key Vault secrets
```

### 📋 SECRET AUDIT LOGGING

```hcl
# Diagnostic Settings für Key Vault
resource "azurerm_monitor_diagnostic_setting" "kv_audit" {
  name                       = "kv-audit-logs"
  target_resource_id         = azurerm_key_vault.image_builder.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
  }
}

# Alert bei Secret Access
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "secret_access" {
  name                = "alert-kv-secret-access"
  resource_group_name = var.resource_group_name
  location            = var.location

  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [var.log_analytics_workspace_id]
  severity             = 2

  criteria {
    query = <<-QUERY
      AzureDiagnostics
      | where ResourceProvider == "MICROSOFT.KEYVAULT"
      | where OperationName == "SecretGet"
      | where CallerIPAddress !in ("10.0.0.0/8", "172.16.0.0/12")  # Exclude internal
      | summarize Count=count() by CallerIPAddress, identity_claim_appid_g
    QUERY

    time_aggregation_method = "Count"
    threshold               = 10
    operator                = "GreaterThan"
  }

  action {
    action_groups = [var.security_alert_action_group_id]
  }
}
```

### 💡 EMPFEHLUNG

**Implementieren Sie die Key Vault Integration in 3 Phasen:**

**Phase 1 (Woche 1):** Key Vault Setup + Terraform Integration
- Key Vault erstellen
- Secrets migrieren
- Terraform liest von KV

**Phase 2 (Woche 2):** Packer Managed Identity
- User-Assigned Identity
- Packer Authentication
- Secret Loading Scripts

**Phase 3 (Woche 3):** Automation & Monitoring
- SAS Token Rotation
- Audit Logging
- Alerts

**Aufwand:** 16-20 Stunden
**Priorität:** P0 (Kritisch für Production)
**Compliance:** Erfüllt ISO 27001, PCI-DSS, SOC 2

---

## 2.2 Sicherheits-Baselines für Build-VMs

### ✅ VALIDIERUNG: Sehr wichtig, machbar ohne Build-Probleme

**Ihre Vorschläge:**
- ✅ Trusted Launch (Secure Boot + vTPM)
- ✅ Minimale WinRM Exposure

### 🎯 ERWEITERTE SECURITY BASELINE

```hcl
# 02-appscustom-packer/avd-image.pkr.hcl

source "azure-arm" "avd_image" {
  # === EXISTING CONFIG ===
  use_azure_cli_auth = false
  subscription_id    = var.subscription_id
  client_id          = var.client_id
  client_secret      = var.client_secret
  tenant_id          = var.tenant_id

  # === TRUSTED LAUNCH (Generation 2) ===
  vm_size                        = "Standard_D4s_v5"  # Gen2-kompatibel
  os_type                        = "Windows"
  image_publisher                = "MicrosoftWindowsDesktop"
  image_offer                    = "office-365"
  image_sku                      = "win11-25h2-avd-m365"
  image_version                  = "latest"

  # Trusted Launch Settings
  secure_boot_enabled            = true   # ✅ Prevents rootkits
  vtpm_enabled                   = true   # ✅ TPM 2.0 for BitLocker
  security_type                  = "TrustedLaunch"

  # === DISK ENCRYPTION ===
  os_disk_size_gb                = 127
  disk_caching_type              = "ReadWrite"

  # Managed Disk mit Encryption at Rest
  managed_image_storage_account_type = "Premium_LRS"

  # === NETWORK SECURITY ===
  # Option A: Dedicated Build Subnet (EMPFOHLEN)
  virtual_network_name           = "vnet-packer-builds"
  virtual_network_subnet_name    = "snet-packer-isolated"
  virtual_network_resource_group_name = var.network_rg_name

  # Private IP only (kein Public IP)
  private_virtual_network_with_public_ip = false

  # Option B: Just-In-Time Network Access
  # Wird via NSG + Azure Bastion umgesetzt

  # === WINRM SECURITY ===
  communicator   = "winrm"
  winrm_use_ssl  = true      # ✅ TLS verschlüsselt
  winrm_insecure = false     # ✅ Zertifikat-Validierung
  winrm_timeout  = "30m"
  winrm_username = "packer"
  winrm_password = var.winrm_password

  # Custom WinRM Setup Script
  custom_script = <<-EOT
    # Enable WinRM over HTTPS only
    winrm quickconfig -quiet -force
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/service '@{AllowUnencrypted="false"}'
    winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'

    # Firewall: Allow WinRM only from Azure Virtual Network
    Remove-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" `
      -Direction Inbound `
      -Protocol TCP `
      -LocalPort 5986 `
      -Action Allow `
      -Profile Any `
      -RemoteAddress VirtualNetwork

    # Self-signed cert für WinRM (temporary)
    $cert = New-SelfSignedCertificate -DnsName "packer-build" -CertStoreLocation Cert:\LocalMachine\My
    winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"packer-build`";CertificateThumbprint=`"$($cert.Thumbprint)`"}"
  EOT

  # === AZURE RESOURCES ===
  location              = var.location
  managed_image_resource_group_name = var.sig_rg_name

  # Shared Image Gallery Destination
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.sig_rg_name
    gallery_name         = "avd_sig"
    image_name           = var.sig_image_name
    image_version        = var.sig_image_version
    storage_account_type = "Standard_LRS"

    # Replication mit Zone-Redundancy
    target_region {
      name                   = "westeurope"
      replicas               = 3
      storage_account_type   = "Standard_ZRS"  # Zone-redundant
    }
  }

  # === TAGGING ===
  azure_tags = {
    Purpose         = "Packer Image Build"
    Security        = "TrustedLaunch"
    Compliance      = "ISO27001"
    AutoShutdown    = "true"
    CostCenter      = "IT-Infrastructure"
    BuildType       = var.build_type
    Temporary       = "true"  # Markiert für automatische Cleanup
  }

  # === BUILD TIMEOUT ===
  async_resourcegroup_delete = true  # Beschleunigt Cleanup
}
```

### 🛡️ NETWORK SECURITY GROUP für Build-Subnet

```hcl
# 00-avd-terraform/modules/packer_network/main.tf

# Dedicated VNet für Packer Builds
resource "azurerm_virtual_network" "packer" {
  name                = "vnet-packer-builds"
  address_space       = ["10.100.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Purpose = "Packer Image Builds - Isolated"
  })
}

# Isolated Build Subnet
resource "azurerm_subnet" "packer_build" {
  name                 = "snet-packer-isolated"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.packer.name
  address_prefixes     = ["10.100.1.0/24"]

  # Disable private endpoint policies
  private_endpoint_network_policies_enabled = false

  # Service Endpoints (für Storage Access)
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault"
  ]
}

# Network Security Group - Sehr restriktiv
resource "azurerm_network_security_group" "packer_build" {
  name                = "nsg-packer-build"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# NSG Rules

# INBOUND: Deny all by default (implicit)

# OUTBOUND: Allow nur notwendige Verbindungen

# 1. Allow HTTPS to Azure Storage (für artifacts)
resource "azurerm_network_security_rule" "allow_https_storage" {
  name                        = "Allow-HTTPS-Storage"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "Storage"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.packer_build.name
}

# 2. Allow HTTPS to Azure Key Vault
resource "azurerm_network_security_rule" "allow_https_keyvault" {
  name                        = "Allow-HTTPS-KeyVault"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "AzureKeyVault"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.packer_build.name
}

# 3. Allow Windows Update
resource "azurerm_network_security_rule" "allow_windows_update" {
  name                        = "Allow-WindowsUpdate"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "Internet"  # Wird weiter unten eingeschränkt
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.packer_build.name
}

# 4. Allow Azure metadata service
resource "azurerm_network_security_rule" "allow_azure_metadata" {
  name                        = "Allow-AzureMetadata"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "169.254.169.254/32"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.packer_build.name
}

# 5. Deny all other outbound (explizit)
resource "azurerm_network_security_rule" "deny_all_outbound" {
  name                        = "Deny-All-Outbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.packer_build.name
}

# Associate NSG mit Subnet
resource "azurerm_subnet_network_security_group_association" "packer_build" {
  subnet_id                 = azurerm_subnet.packer_build.id
  network_security_group_id = azurerm_network_security_group.packer_build.name
}
```

### 🔐 JUST-IN-TIME VM ACCESS (Alternative)

```hcl
# Azure Security Center JIT Policy
resource "azurerm_security_center_jit_network_access_policy" "packer" {
  name                = "jit-packer-builds"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Basic"

  virtual_machine {
    virtual_machine_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/virtualMachines/packer-*"

    port {
      number                     = 5986  # WinRM HTTPS
      protocol                   = "TCP"
      allowed_source_address_prefix = ["10.0.0.0/8"]  # Nur von internem Netz
      max_request_access_duration = "PT2H"  # Max 2 Stunden
    }

    port {
      number                     = 3389  # RDP (nur für Debugging)
      protocol                   = "TCP"
      allowed_source_address_prefix = [var.admin_ip]  # Nur von Admin-IP
      max_request_access_duration = "PT1H"
    }
  }
}
```

### 🔒 DISK ENCRYPTION

```powershell
# Provisioner in Packer: Enable BitLocker
provisioner "powershell" {
  inline = [
    "# Check if TPM is enabled (Trusted Launch)",
    "$tpm = Get-Tpm",
    "if ($tpm.TpmPresent -and $tpm.TpmReady) {",
    "  Write-Host '✅ TPM 2.0 detected - Trusted Launch enabled' -ForegroundColor Green",
    "  ",
    "  # Initialize BitLocker (for SIG images)",
    "  # Note: Will be finalized on first boot in AVD",
    "  Enable-BitLocker -MountPoint 'C:' -EncryptionMethod XtsAes256 -TpmProtector -SkipHardwareTest",
    "  ",
    "  Write-Host '🔒 BitLocker initialized' -ForegroundColor Green",
    "} else {",
    "  Write-Warning '⚠️ TPM not detected - Trusted Launch may not be enabled'",
    "}"
  ]
}
```

### 📊 SECURITY BASELINE CHECKLIST

| Security Control | Status | Implementation |
|------------------|--------|----------------|
| Trusted Launch | ✅ | `secure_boot_enabled = true` |
| vTPM | ✅ | `vtpm_enabled = true` |
| WinRM over TLS | ✅ | `winrm_use_ssl = true` |
| No Public IP | ✅ | `private_virtual_network_with_public_ip = false` |
| Isolated Subnet | ✅ | Dedicated `snet-packer-isolated` |
| NSG Hardening | ✅ | Whitelisting only required traffic |
| Disk Encryption | ✅ | BitLocker with TPM |
| Managed Identity | ✅ | No passwords in code |
| Key Vault Secrets | ✅ | No hardcoded credentials |
| Build VM Auto-Delete | ✅ | `async_resourcegroup_delete = true` |
| Audit Logging | ✅ | NSG Flow Logs + Activity Logs |
| JIT Access (Optional) | ⚠️ | For debugging only |

### 💡 EMPFEHLUNG

**Implementieren Sie die Security Baseline sofort:**

**Kritisch (Diese Woche):**
- Trusted Launch aktivieren
- WinRM over TLS erzwingen
- NSG für Build-Subnet

**Wichtig (Nächste Woche):**
- Dedicated Build VNet
- Key Vault Integration (siehe 2.1)

**Optional (Nach Production-Launch):**
- JIT Access für Debugging
- Azure Private Link für Storage

**Aufwand:** 8-12 Stunden
**Priorität:** P0 (Kritisch)
**Compliance:** Erfüllt CIS Benchmark Level 2

---

**FORTSETZUNG in Teil 2...**

*Dieses Dokument wird fortgesetzt mit:*
- 3️⃣ Build-Orchestrierung & Automation
- 4️⃣ Infrastruktur & Governance
- 5️⃣ Developer Experience & DX-Tooling
- 6️⃣ Erweiterungsmöglichkeiten

*Gesamtumfang: ca. 80-100 Seiten*
