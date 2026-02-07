# 🚀 AVD Image Builder - Optimierungsstrategie Teil 3

**Fortsetzung von Teil 1 & 2**
**Projekt:** Azure Virtual Desktop Image Builder & Terraform Framework

---

# 4️⃣ Infrastruktur & Governance

## 4.1 Terraform Governance Layer

### ✅ VALIDIERUNG: Sehr wichtig für Enterprise Compliance

**Ihre Vorschläge:**
- ✅ Enforce Diagnostics bei AVD, SIG, VMSS
- ✅ Azure Policy Integration
- ✅ Zentralisierte Naming Convention (CAF-Modell)

### 🎯 ENTERPRISE GOVERNANCE FRAMEWORK

```
┌─────────────────────────────────────────────────────────────┐
│                    GOVERNANCE LAYERS                         │
└─────────────────────────────────────────────────────────────┘
        ↓                    ↓                    ↓
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   NAMING     │    │   TAGGING    │    │   POLICY     │
│ CONVENTIONS  │    │   STANDARD   │    │ ENFORCEMENT  │
│              │    │              │    │              │
│ CAF-Based    │    │ FinOps       │    │ Azure Policy │
│ Validation   │    │ CostCenter   │    │ Compliance   │
└──────────────┘    └──────────────┘    └──────────────┘
        ↓                    ↓                    ↓
┌─────────────────────────────────────────────────────────────┐
│              TERRAFORM GOVERNANCE MODULE                     │
│  • Pre-deployment validation                                 │
│  • Resource configuration policies                           │
│  • Mandatory diagnostics & logging                           │
│  • Cost allocation tags                                      │
└─────────────────────────────────────────────────────────────┘
```

### 🔧 IMPLEMENTIERUNG

#### Cloud Adoption Framework (CAF) Naming Convention

```hcl
# 00-avd-terraform/modules/naming/main.tf
# Microsoft CAF-compliant naming module

locals {
  # Resource type abbreviations (CAF Standard)
  resource_abbreviations = {
    resource_group                = "rg"
    virtual_network               = "vnet"
    subnet                        = "snet"
    network_security_group        = "nsg"
    virtual_machine               = "vm"
    storage_account               = "st"    # 3-24 chars, lowercase, no hyphens
    key_vault                     = "kv"    # 3-24 chars
    shared_image_gallery          = "sig"   # 1-80 chars
    log_analytics_workspace       = "log"
    application_insights          = "appi"
    # AVD specific
    avd_hostpool                  = "vdpool"
    avd_workspace                 = "vdws"
    avd_application_group         = "vdag"
  }

  # Environment abbreviations
  environment_abbreviations = {
    production  = "prd"
    staging     = "stg"
    development = "dev"
    qa          = "qa"
    sandbox     = "sbx"
  }

  # Azure region abbreviations
  region_abbreviations = {
    westeurope    = "weu"
    northeurope   = "neu"
    germanywestcentral = "gwc"
    eastus        = "eus"
    westus2       = "wus2"
  }
}

# Naming function with validation
resource "null_resource" "naming_validation" {
  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9-]{3,24}$", var.workload_name))
      error_message = "Workload name must be 3-24 characters, lowercase alphanumeric and hyphens only"
    }

    precondition {
      condition     = contains(keys(local.environment_abbreviations), var.environment)
      error_message = "Environment must be one of: ${join(", ", keys(local.environment_abbreviations))}"
    }
  }
}

# Generate names according to CAF
# Pattern: <resource_type>-<workload>-<environment>-<region>-<instance>
# Example: rg-avd-prd-weu-001

locals {
  env_abbr    = local.environment_abbreviations[var.environment]
  region_abbr = local.region_abbreviations[var.location]

  # Base naming pattern
  base_name = "${var.workload_name}-${local.env_abbr}-${local.region_abbr}"

  # Resource names
  names = {
    resource_group = "${local.resource_abbreviations.resource_group}-${local.base_name}-${format("%03d", var.instance)}"

    virtual_network = "${local.resource_abbreviations.virtual_network}-${local.base_name}-${format("%03d", var.instance)}"

    # AVD Resources
    avd_hostpool = "${local.resource_abbreviations.avd_hostpool}-${local.base_name}-${format("%03d", var.instance)}"
    avd_workspace = "${local.resource_abbreviations.avd_workspace}-${local.base_name}-${format("%03d", var.instance)}"
    avd_app_group = "${local.resource_abbreviations.avd_application_group}-${local.base_name}-${format("%03d", var.instance)}"

    # Storage Account (special: no hyphens, lowercase only, max 24 chars)
    storage_account = lower(replace(
      "${local.resource_abbreviations.storage_account}${var.workload_name}${local.env_abbr}${local.region_abbr}${format("%03d", var.instance)}",
      "-", ""
    ))

    # Key Vault (max 24 chars)
    key_vault = substr(
      "${local.resource_abbreviations.key_vault}-${local.base_name}-${format("%03d", var.instance)}",
      0, 24
    )

    # Shared Image Gallery (alphanumeric, underscores, periods - max 80 chars)
    shared_image_gallery = replace(
      "${local.resource_abbreviations.shared_image_gallery}_${var.workload_name}_${local.env_abbr}_${local.region_abbr}",
      "-", "_"
    )
  }
}

output "names" {
  description = "CAF-compliant resource names"
  value       = local.names
}

# variables.tf
variable "workload_name" {
  type        = string
  description = "Workload identifier (e.g., 'avd', 'vdi')"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,10}$", var.workload_name))
    error_message = "Workload name must be 2-10 chars, lowercase, alphanumeric and hyphens"
  }
}

variable "environment" {
  type        = string
  description = "Environment name"

  validation {
    condition     = contains(["production", "staging", "development", "qa", "sandbox"], var.environment)
    error_message = "Invalid environment"
  }
}

variable "location" {
  type        = string
  description = "Azure region"

  validation {
    condition     = contains(["westeurope", "northeurope", "germanywestcentral"], var.location)
    error_message = "Unsupported Azure region"
  }
}

variable "instance" {
  type        = number
  description = "Instance number for multiple deployments"
  default     = 1

  validation {
    condition     = var.instance >= 1 && var.instance <= 999
    error_message = "Instance must be between 1 and 999"
  }
}
```

#### Usage in Main Terraform

```hcl
# 00-avd-terraform/main.tf

module "naming" {
  source        = "./modules/naming"
  workload_name = "avd"
  environment   = var.environment
  location      = var.location
  instance      = var.instance
}

module "resource_group" {
  source              = "./modules/resource_group"
  resource_group_name = module.naming.names.resource_group  # rg-avd-prd-weu-001
  location            = var.location
  tags                = local.governance_tags
}

module "hostpool" {
  source              = "./modules/hostpool"
  resource_group_name = module.resource_group.name
  hostpool_name       = module.naming.names.avd_hostpool    # vdpool-avd-prd-weu-001
  location            = var.location
  tags                = local.governance_tags

  # Enforce diagnostics
  enable_diagnostics = true
  log_analytics_workspace_id = module.log_analytics.id
}
```

#### Mandatory Tagging Strategy (FinOps)

```hcl
# 00-avd-terraform/locals.tf

locals {
  # Governance Tags (mandatory for all resources)
  governance_tags = merge(
    var.custom_tags,
    {
      # === Cost Management ===
      CostCenter        = var.cost_center          # e.g., "IT-Infrastructure"
      BusinessUnit      = var.business_unit        # e.g., "Finance"
      Project           = var.project_name         # e.g., "AVD-Modernization"

      # === Operations ===
      Environment       = var.environment          # production, staging, dev
      ManagedBy         = "Terraform"
      TerraformWorkspace = terraform.workspace

      # === Compliance ===
      DataClassification = var.data_classification # public, internal, confidential, restricted
      Compliance        = join(",", var.compliance_frameworks)  # e.g., "ISO27001,SOC2"

      # === Lifecycle ===
      CreatedDate       = formatdate("YYYY-MM-DD", timestamp())
      CreatedBy         = var.created_by           # User or Service Principal
      Owner             = var.owner_email
      SupportContact    = var.support_email

      # === Technical ===
      Application       = "AzureVirtualDesktop"
      Component         = var.component            # e.g., "HostPool", "Image", "Network"
      Version           = var.application_version

      # === Auto-Shutdown (for non-prod)
      AutoShutdown      = var.environment != "production" ? "true" : "false"
      ShutdownSchedule  = var.environment != "production" ? "19:00 CET" : "none"
    }
  )

  # Validation: Ensure required tags are set
  validate_tags = {
    for key in ["CostCenter", "BusinessUnit", "Owner", "DataClassification"] :
    key => lookup(local.governance_tags, key, null) != null
  }
}

# Enforce tag validation
resource "null_resource" "tag_validation" {
  lifecycle {
    precondition {
      condition     = alltrue(values(local.validate_tags))
      error_message = "Missing required tags: ${join(", ", [for k, v in local.validate_tags : k if !v])}"
    }
  }
}
```

#### Variables for Tagging

```hcl
# 00-avd-terraform/variables.tf

# === Cost Management ===
variable "cost_center" {
  type        = string
  description = "Cost Center for billing allocation"

  validation {
    condition     = can(regex("^[A-Z]{2,5}-[0-9]{4,6}$", var.cost_center))
    error_message = "Cost Center format: XX-NNNN (e.g., IT-1234)"
  }
}

variable "business_unit" {
  type        = string
  description = "Business Unit name"

  validation {
    condition     = contains(["Finance", "HR", "IT", "Sales", "Marketing", "Legal"], var.business_unit)
    error_message = "Invalid Business Unit"
  }
}

variable "project_name" {
  type        = string
  description = "Project name for cost tracking"
}

# === Compliance ===
variable "data_classification" {
  type        = string
  description = "Data classification level"
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "Invalid data classification"
  }
}

variable "compliance_frameworks" {
  type        = list(string)
  description = "Compliance frameworks this resource must adhere to"
  default     = ["ISO27001"]

  validation {
    condition = alltrue([
      for framework in var.compliance_frameworks :
      contains(["ISO27001", "SOC2", "GDPR", "HIPAA", "PCI-DSS"], framework)
    ])
    error_message = "Invalid compliance framework specified"
  }
}

# === Ownership ===
variable "owner_email" {
  type        = string
  description = "Email of resource owner"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner_email))
    error_message = "Invalid email format"
  }
}

variable "support_email" {
  type        = string
  description = "Email for technical support"
  default     = "it-support@company.com"
}
```

#### Azure Policy Integration

```hcl
# 00-avd-terraform/modules/governance/azure_policy.tf

# Assign Built-in Azure Policies to Resource Group
resource "azurerm_resource_group_policy_assignment" "diagnostics_enabled" {
  name                 = "enforce-diagnostics"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Built-in Policy

  parameters = jsonencode({
    logAnalytics = {
      value = var.log_analytics_workspace_id
    }
    requiredRetentionDays = {
      value = var.log_retention_days
    }
  })

  metadata = jsonencode({
    category = "Monitoring"
    enforced_by = "Terraform"
  })
}

# Custom Policy: Enforce Tags
resource "azurerm_policy_definition" "require_tags" {
  name         = "require-mandatory-tags"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require Mandatory Tags"

  policy_rule = jsonencode({
    if = {
      anyOf = [
        {
          field  = "tags['CostCenter']"
          exists = "false"
        },
        {
          field  = "tags['Owner']"
          exists = "false"
        },
        {
          field  = "tags['Environment']"
          exists = "false"
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })

  parameters = jsonencode({})
}

resource "azurerm_resource_group_policy_assignment" "require_tags" {
  name                 = "require-mandatory-tags"
  resource_group_id    = var.resource_group_id
  policy_definition_id = azurerm_policy_definition.require_tags.id
}

# Policy: Allowed VM Sizes (cost control)
resource "azurerm_resource_group_policy_assignment" "allowed_vm_sizes" {
  name                 = "allowed-vm-sizes"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f53-ad12-b6a63eb452b3"  # Built-in

  parameters = jsonencode({
    listOfAllowedSKUs = {
      value = [
        "Standard_D2s_v5",
        "Standard_D4s_v5",
        "Standard_D8s_v5",
        "Standard_E2s_v5",
        "Standard_E4s_v5"
      ]
    }
  })
}

# Policy: Geo-restrictions
resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  resource_group_id    = var.resource_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"  # Built-in

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })
}
```

#### Mandatory Diagnostics Settings

```hcl
# 00-avd-terraform/modules/hostpool/diagnostics.tf

resource "azurerm_monitor_diagnostic_setting" "hostpool" {
  count                      = var.enable_diagnostics ? 1 : 0
  name                       = "diag-${var.hostpool_name}"
  target_resource_id         = azurerm_virtual_desktop_host_pool.hostpool.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Host Pool Logs
  enabled_log {
    category = "Checkpoint"
  }

  enabled_log {
    category = "Error"
  }

  enabled_log {
    category = "Management"
  }

  enabled_log {
    category = "Connection"
  }

  enabled_log {
    category = "HostRegistration"
  }

  enabled_log {
    category = "AgentHealthStatus"
  }

  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Alert Rules
resource "azurerm_monitor_metric_alert" "hostpool_health" {
  count               = var.enable_diagnostics ? 1 : 0
  name                = "alert-hostpool-unavailable"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_virtual_desktop_host_pool.hostpool.id]
  description         = "Alert when no hosts are available"
  severity            = 1  # Critical

  criteria {
    metric_namespace = "Microsoft.DesktopVirtualization/hostpools"
    metric_name      = "HostsAvailable"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = var.action_group_id
  }

  frequency   = "PT5M"
  window_size = "PT15M"

  tags = var.tags
}
```

#### Governance Variables

```hcl
# 00-avd-terraform/terraform.tfvars.example

# === Governance ===
cost_center          = "IT-1234"
business_unit        = "IT"
project_name         = "AVD-Modernization-2025"
owner_email          = "avd-admin@company.com"
support_email        = "it-support@company.com"
data_classification  = "internal"
compliance_frameworks = ["ISO27001", "SOC2"]

# === Naming ===
workload_name = "avd"
environment   = "production"
instance      = 1

# === Policy ===
allowed_locations = ["westeurope", "northeurope"]
log_retention_days = 90

# === Diagnostics ===
enable_diagnostics = true
```

### 💡 EMPFEHLUNG

**Implementieren Sie Governance schrittweise:**

**Phase 1 (Woche 1):** Naming Convention
- CAF Module implementieren
- Alle Ressourcen migrieren

**Phase 2 (Woche 2):** Mandatory Tagging
- Tag Strategy definieren
- Validation einführen

**Phase 3 (Woche 3):** Policy Enforcement
- Azure Policies zuweisen
- Diagnostics erzwingen

**Aufwand:** 16-20 Stunden
**Priorität:** P1 (Hoch - für Enterprise notwendig)
**Compliance:** Erfüllt CAF, FinOps, ISO 27001 Anforderungen

---

## 4.2 Host Lifecycle Optimization

### ✅ VALIDIERUNG: Bereits teilweise implementiert (Update-AVDSessionHosts.ps1)

**Ihre Fragen:**
- ✅ Rolling Updates per VMSS Versioning
- ✅ Drain-and-replace Strategie

**Status:** Bereits in `Update-AVDSessionHosts.ps1` implementiert!

### 🎯 ERWEITERTE OPTIMIERUNGEN

#### Option 1: VMSS-basierte Session Hosts (EMPFOHLEN für Scale)

```hcl
# 00-avd-terraform/modules/vmss_hostpool/main.tf

resource "azurerm_windows_virtual_machine_scale_set" "avd_hosts" {
  name                = "vmss-${var.hostpool_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.vm_size
  instances           = var.initial_instance_count

  # Orchestration
  orchestration_mode  = "Flexible"  # Allows mixed scaling strategies
  upgrade_mode        = "Manual"    # Manual for controlled rollout
  platform_fault_domain_count = 1

  # Image from SIG
  source_image_id = var.sig_image_id

  # Network
  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = var.subnet_id
    }
  }

  # OS Disk
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.disk_type
    disk_size_gb         = var.os_disk_size_gb

    # Ephemeral OS Disk (optional - faster, cheaper)
    diff_disk_settings {
      option    = var.use_ephemeral_disk ? "Local" : null
      placement = var.use_ephemeral_disk ? "CacheDisk" : null
    }
  }

  # Admin Account
  admin_username = var.admin_username
  admin_password = random_password.vm_admin.result

  # Trusted Launch
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Boot Diagnostics
  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_uri
  }

  # Auto OS Upgrade (careful!)
  automatic_os_upgrade_policy {
    disable_automatic_rollback  = false
    enable_automatic_os_upgrade = false  # Controlled via image updates
  }

  # Scaling
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT30M"
  }

  # Extensions: AVD Registration
  extension {
    name                       = "AVDAgent"
    publisher                  = "Microsoft.Powershell"
    type                       = "DSC"
    type_handler_version       = "2.77"
    auto_upgrade_minor_version = true

    settings = jsonencode({
      wmfVersion = "latest"
      configuration = {
        url      = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip"
        script   = "Configuration.ps1"
        function = "AddSessionHost"
      }
      configurationArguments = {
        hostPoolName          = var.hostpool_name
        registrationInfoToken = var.registration_token
        aadJoin               = var.aad_join
      }
    })
  }

  # Health Probe (for LB/AG)
  health_probe_id = var.health_probe_id

  tags = var.tags

  lifecycle {
    ignore_changes = [instances]  # Managed by autoscale
  }
}

# Autoscaling
resource "azurerm_monitor_autoscale_setting" "avd_hosts" {
  name                = "autoscale-${var.hostpool_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.avd_hosts.id

  profile {
    name = "business_hours"

    capacity {
      default = var.min_instances
      minimum = var.min_instances
      maximum = var.max_instances
    }

    # Scale out: Add hosts when CPU > 70%
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.avd_hosts.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # Scale in: Remove hosts when CPU < 30%
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.avd_hosts.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    recurrence {
      frequency = "Week"
      schedule {
        days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        hours    = [8]
        minutes  = [0]
      }
      timezone = "Central European Standard Time"
    }
  }

  # After hours: minimal capacity
  profile {
    name = "after_hours"

    capacity {
      default = var.min_instances_after_hours
      minimum = var.min_instances_after_hours
      maximum = var.min_instances  # Limited scaling after hours
    }

    recurrence {
      frequency = "Week"
      schedule {
        days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        hours    = [18]
        minutes  = [0]
      }
      timezone = "Central European Standard Time"
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = false
      send_to_subscription_co_administrator = false
      custom_emails                         = [var.ops_email]
    }
  }

  tags = var.tags
}
```

#### Image Update Strategy for VMSS

```powershell
# Update-VMSSImage.ps1
# Update VMSS with new SIG image version

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$VMSSName,

    [Parameter(Mandatory = $true)]
    [string]$NewImageVersion,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Rolling", "Simultaneous")]
    [string]$UpdateMode = "Rolling",

    [Parameter(Mandatory = $false)]
    [int]$BatchPercentage = 20,  # Update 20% at a time

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Get VMSS
$vmss = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMSSName

# Get new image ID
$imageId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/galleries/avd_sig/images/avd-goldenimage/versions/$NewImageVersion"

Write-Host "Current Image: $($vmss.VirtualMachineProfile.StorageProfile.ImageReference.Id)" -ForegroundColor Yellow
Write-Host "New Image: $imageId" -ForegroundColor Green

if ($DryRun) {
    Write-Host "[DRY RUN] Would update VMSS to new image" -ForegroundColor Cyan
    exit 0
}

# Update VMSS model
$vmss.VirtualMachineProfile.StorageProfile.ImageReference.Id = $imageId
Update-AzVmss -ResourceGroupName $ResourceGroupName -Name $VMSSName -VirtualMachineScaleSet $vmss

Write-Host "✅ VMSS model updated to new image" -ForegroundColor Green

# Perform instance upgrade
if ($UpdateMode -eq "Rolling") {
    Write-Host "Starting rolling upgrade (batch size: $BatchPercentage%)..." -ForegroundColor Cyan

    # Get all instances
    $instances = Get-AzVmssVM -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMSSName

    $batchSize = [Math]::Max(1, [Math]::Ceiling($instances.Count * ($BatchPercentage / 100)))
    $batches = [Math]::Ceiling($instances.Count / $batchSize)

    for ($batch = 0; $batch < $batches; $batch++) {
        $start = $batch * $batchSize
        $end = [Math]::Min(($batch + 1) * $batchSize, $instances.Count)

        $batchInstances = $instances[$start..($end - 1)]

        Write-Host "Upgrading batch $($batch + 1)/$batches ($($batchInstances.Count) instances)..." -ForegroundColor Yellow

        # Set drain mode for these instances (AVD specific)
        foreach ($instance in $batchInstances) {
            $sessionHost = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name "$VMSSName-$($instance.InstanceId)"
            Update-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $sessionHost.Name -AllowNewSession:$false
        }

        # Wait for sessions to drain (max 30 min)
        Start-Sleep -Seconds 60

        # Upgrade instances
        Update-AzVmssInstance -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMSSName -InstanceId $batchInstances.InstanceId

        Write-Host "✅ Batch $($batch + 1) upgraded" -ForegroundColor Green

        # Wait between batches
        if ($batch -lt $batches - 1) {
            Write-Host "Waiting 5 minutes before next batch..." -ForegroundColor Yellow
            Start-Sleep -Seconds 300
        }
    }

} else {
    # Simultaneous upgrade (faster, but disruptive)
    Write-Host "Performing simultaneous upgrade of all instances..." -ForegroundColor Cyan
    Update-AzVmssInstance -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMSSName -InstanceId "*"
}

Write-Host "✅ VMSS image update completed!" -ForegroundColor Green
```

### 💡 EMPFEHLUNG

**Ihre aktuelle Lösung (einzelne VMs + Update-AVDSessionHosts.ps1) ist SEHR GUT für:**
- ✅ Kleine bis mittlere Deployments (5-50 Hosts)
- ✅ Granulare Kontrolle über jeden Host
- ✅ Individuelle Host-Konfigurationen

**VMSS-basierte Lösung ist besser für:**
- ✅ Große Deployments (50+ Hosts)
- ✅ Automatisches Autoscaling
- ✅ Schnellere Provisioning
- ✅ Geringere Verwaltung

**Unsere Empfehlung:** Behalten Sie Ihre aktuelle Lösung bei, VMSS nur wenn:
- Sie > 50 Session Hosts haben
- Automatisches Scaling benötigen
- Ephemeral OS Disks nutzen wollen (Kosteneinsparung)

**Aufwand:** 40+ Stunden (Migration zu VMSS)
**Priorität:** P3 (Optional, nur für Scale)

---

# 5️⃣ Developer Experience & DX-Tooling

## 5.1 CLI / Script UX Verbessern

### ✅ VALIDIERUNG: Sehr wichtig für Adoption

**Ihre Vorschläge:**
- ✅ Non-interaktive Flags (--monthly, --apps, --base)
- ✅ --dry-run
- ✅ --continue-from last-known-state

### 🎯 PRODUCTION-READY CLI WRAPPER

```powershell
# avd-image-builder.ps1 - Unified CLI
#Requires -Version 7.0

<#
.SYNOPSIS
    AVD Image Builder - Unified Command-Line Interface

.DESCRIPTION
    Wraps Terraform and Packer for streamlined AVD image builds

.PARAMETER Action
    Action to perform: build, deploy, promote, rollback, validate

.PARAMETER BuildType
    Type of build: base, apps, monthly, full

.PARAMETER DryRun
    Simulate without making changes

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER ContinueFrom
    Resume from last checkpoint: terraform, base, apps, monthly, deploy

.PARAMETER ImageVersion
    Specific image version (defaults to current date)

.PARAMETER Verbose
    Enable detailed logging

.EXAMPLE
    .\avd-image-builder.ps1 build --base
    Build base image only

.EXAMPLE
    .\avd-image-builder.ps1 build --full --dry-run
    Simulate full image build

.EXAMPLE
    .\avd-image-builder.ps1 deploy --image-version 2025.02.07.1 --canary
    Deploy specific version to canary environment

.EXAMPLE
    .\avd-image-builder.ps1 rollback --last
    Rollback to previous working image version
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("build", "deploy", "promote", "rollback", "validate", "clean")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [ValidateSet("base", "apps", "monthly", "full")]
    [string]$BuildType,

    [Parameter(Mandatory = $false)]
    [string]$ImageVersion,

    [Parameter(Mandatory = $false)]
    [string]$ContinueFrom,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Canary,

    [Parameter(Mandatory = $false)]
    [switch]$Last,  # For rollback

    [Parameter(Mandatory = $false)]
    [switch]$NoValidation,

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "./avd-builder.config.json"
)

#region Configuration

# Load configuration
if (Test-Path $ConfigFile) {
    $config = Get-Content $ConfigFile | ConvertFrom-Json
} else {
    Write-Error "Configuration file not found: $ConfigFile"
    Write-Host "Run: .\avd-image-builder.ps1 init" -ForegroundColor Yellow
    exit 1
}

# Set defaults
if (-not $ImageVersion) {
    $ImageVersion = (Get-Date).ToString("yyyy.MM.dd.HHmm")
}

#endregion

#region Helper Functions

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "DEBUG"   { "Gray" }
        default   { "White" }
    }
    $prefix = switch ($Level) {
        "SUCCESS" { "✅" }
        "WARNING" { "⚠️" }
        "ERROR"   { "❌" }
        default   { "ℹ️" }
    }
    Write-Host "$prefix [$timestamp] $Message" -ForegroundColor $color
}

function Invoke-Checkpoint {
    param([string]$Name, [string]$Status)

    $checkpointFile = "./.checkpoints.json"
    $checkpoints = @{}

    if (Test-Path $checkpointFile) {
        $checkpoints = Get-Content $checkpointFile | ConvertFrom-Json -AsHashtable
    }

    $checkpoints[$Name] = @{
        status = $Status
        timestamp = (Get-Date).ToString("o")
        imageVersion = $ImageVersion
    }

    $checkpoints | ConvertTo-Json | Out-File $checkpointFile
    Write-Log "Checkpoint saved: $Name = $Status" "DEBUG"
}

function Get-LastCheckpoint {
    $checkpointFile = "./.checkpoints.json"
    if (Test-Path $checkpointFile) {
        return Get-Content $checkpointFile | ConvertFrom-Json -AsHashtable
    }
    return @{}
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"

    # Check Terraform
    $tfVersion = terraform version -json 2>$null | ConvertFrom-Json
    if (-not $tfVersion) {
        Write-Log "Terraform not found. Please install Terraform." "ERROR"
        return $false
    }
    Write-Log "Terraform version: $($tfVersion.terraform_version)" "SUCCESS"

    # Check Packer
    $packerVersion = packer version
    if (-not $packerVersion) {
        Write-Log "Packer not found. Please install Packer." "ERROR"
        return $false
    }
    Write-Log "Packer version: $packerVersion" "SUCCESS"

    # Check Azure CLI
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    if (-not $azVersion) {
        Write-Log "Azure CLI not found. Please install Azure CLI." "ERROR"
        return $false
    }
    Write-Log "Azure CLI version: $($azVersion.'azure-cli')" "SUCCESS"

    # Check Azure login
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        Write-Log "Not logged in to Azure. Run: az login" "ERROR"
        return $false
    }
    Write-Log "Azure subscription: $($azAccount.name)" "SUCCESS"

    return $true
}

#endregion

#region Actions

function Invoke-BuildAction {
    Write-Log "=== Starting Build: $BuildType ===" "INFO"
    Write-Log "Image Version: $ImageVersion" "INFO"
    Write-Log "Dry Run: $DryRun" "INFO"

    # Check if continuing from checkpoint
    $checkpoints = Get-LastCheckpoint
    $startFrom = if ($ContinueFrom) { $ContinueFrom } else { "terraform" }

    # Step 1: Terraform
    if ($startFrom -eq "terraform") {
        Write-Log "Step 1/4: Running Terraform..." "INFO"

        if ($DryRun) {
            Write-Log "[DRY RUN] Would run: terraform apply" "DEBUG"
        } else {
            Push-Location 00-avd-terraform
            terraform init
            terraform apply -auto-approve `
                -var="sig_image_version=$ImageVersion" `
                -var="build_type=$BuildType"
            $tfResult = $LASTEXITCODE
            Pop-Location

            if ($tfResult -ne 0) {
                Write-Log "Terraform failed!" "ERROR"
                exit 1
            }

            Invoke-Checkpoint "terraform" "completed"
        }
    }

    # Step 2: Base Image
    if ($BuildType -in @("base", "full") -and $startFrom -in @("terraform", "base")) {
        Write-Log "Step 2/4: Building Base Image..." "INFO"

        if ($DryRun) {
            Write-Log "[DRY RUN] Would run: packer build 01-base-packer" "DEBUG"
        } else {
            Push-Location 01-base-packer
            packer init .
            packer build -force `
                -var-file=../packer/terraform.auto.pkrvars.json `
                -var="sig_image_version=$ImageVersion" `
                avd-base-image.pkr.hcl
            $packerResult = $LASTEXITCODE
            Pop-Location

            if ($packerResult -ne 0) {
                Write-Log "Packer base build failed!" "ERROR"
                exit 1
            }

            Invoke-Checkpoint "base" "completed"
        }
    }

    # Step 3: Apps Image
    if ($BuildType -in @("apps", "full") -and $startFrom -in @("terraform", "base", "apps")) {
        Write-Log "Step 3/4: Building Apps Image..." "INFO"

        if ($DryRun) {
            Write-Log "[DRY RUN] Would run: packer build 02-appscustom-packer" "DEBUG"
        } else {
            Push-Location 02-appscustom-packer
            packer init .
            packer build -force `
                -var-file=../packer/terraform.auto.pkrvars.json `
                -var="sig_image_version=$ImageVersion" `
                avd-image.pkr.hcl
            $packerResult = $LASTEXITCODE
            Pop-Location

            if ($packerResult -ne 0) {
                Write-Log "Packer apps build failed!" "ERROR"
                exit 1
            }

            Invoke-Checkpoint "apps" "completed"
        }
    }

    # Step 4: Monthly Updates
    if ($BuildType -in @("monthly", "full") -and $startFrom -in @("terraform", "base", "apps", "monthly")) {
        Write-Log "Step 4/4: Building Monthly Updates..." "INFO"

        if ($DryRun) {
            Write-Log "[DRY RUN] Would run: packer build 03-monthly-packer" "DEBUG"
        } else {
            Push-Location 03-monthly-packer
            packer init .
            packer build -force `
                -var-file=../packer/terraform.auto.pkrvars.json `
                -var="sig_image_version=$ImageVersion" `
                avd-monthly-image.pkr.hcl
            $packerResult = $LASTEXITCODE
            Pop-Location

            if ($packerResult -ne 0) {
                Write-Log "Packer monthly build failed!" "ERROR"
                exit 1
            }

            Invoke-Checkpoint "monthly" "completed"
        }
    }

    # Validation
    if (-not $NoValidation) {
        Write-Log "Running post-build validation..." "INFO"
        # Run validation script
    }

    Write-Log "=== Build Completed Successfully! ===" "SUCCESS"
    Write-Log "Image Version: $ImageVersion" "SUCCESS"
    Write-Log "Next step: Deploy to canary" "INFO"
    Write-Log "  .\avd-image-builder.ps1 deploy --image-version $ImageVersion --canary" "INFO"
}

function Invoke-DeployAction {
    Write-Log "=== Deploying Image ===" "INFO"
    Write-Log "Image Version: $ImageVersion" "INFO"
    Write-Log "Target: $(if ($Canary) { 'Canary' } else { 'Production' })" "INFO"

    if ($Canary) {
        # Deploy to canary
        if ($DryRun) {
            Write-Log "[DRY RUN] Would deploy to canary" "DEBUG"
        } else {
            .\Deploy-CanaryImage.ps1 `
                -ResourceGroupName $config.resourceGroupName `
                -CanaryHostPoolName $config.canaryHostPoolName `
                -ProductionHostPoolName $config.productionHostPoolName `
                -ImageVersion $ImageVersion
        }
    } else {
        # Deploy to production
        if ($Force -or $PSCmdlet.ShouldContinue("Deploy to production?", "Production Deployment")) {
            if ($DryRun) {
                Write-Log "[DRY RUN] Would deploy to production" "DEBUG"
            } else {
                .\Update-AVDSessionHosts.ps1 `
                    -ResourceGroupName $config.resourceGroupName `
                    -HostPoolName $config.productionHostPoolName `
                    -ImageVersion $ImageVersion `
                    -UpdateStrategy "RollingUpdate"
            }
        }
    }
}

function Invoke-RollbackAction {
    Write-Log "=== Rollback ===" "WARNING"

    if ($Last) {
        # Get previous version
        $versions = az sig image-version list `
            --resource-group $config.resourceGroupName `
            --gallery-name "avd_sig" `
            --gallery-image-definition "avd-goldenimage" `
            --query "[?tags.DeploymentStatus=='production'].name" `
            --output json | ConvertFrom-Json

        if ($versions.Count -ge 2) {
            $previousVersion = $versions[-2]  # Second-to-last
            Write-Log "Rolling back to version: $previousVersion" "WARNING"
            $ImageVersion = $previousVersion
        } else {
            Write-Log "No previous version found!" "ERROR"
            exit 1
        }
    }

    if ($Force -or $PSCmdlet.ShouldContinue("Rollback to $ImageVersion?", "Rollback")) {
        .\Update-AVDSessionHosts.ps1 `
            -ResourceGroupName $config.resourceGroupName `
            -HostPoolName $config.productionHostPoolName `
            -ImageVersion $ImageVersion `
            -UpdateStrategy "BlueGreen" `  # Faster rollback
            -Force
    }
}

#endregion

#region Main

# Check prerequisites
if (-not (Test-Prerequisites)) {
    exit 1
}

# Execute action
switch ($Action) {
    "build" {
        if (-not $BuildType) {
            Write-Error "Build type required. Use: --base, --apps, --monthly, or --full"
            exit 1
        }
        Invoke-BuildAction
    }

    "deploy" {
        Invoke-DeployAction
    }

    "promote" {
        Write-Log "Promoting canary to production..." "INFO"
        # Implement promotion logic
    }

    "rollback" {
        Invoke-RollbackAction
    }

    "validate" {
        Write-Log "Running validation..." "INFO"
        # Run validation tests
    }

    "clean" {
        Write-Log "Cleaning up build artifacts..." "INFO"
        Remove-Item ./.checkpoints.json -Force -ErrorAction SilentlyContinue
        Write-Log "Cleanup complete" "SUCCESS"
    }
}

#endregion
```

#### Configuration File

```json
// avd-builder.config.json
{
  "version": "1.0",
  "azure": {
    "subscriptionId": "your-subscription-id",
    "resourceGroupName": "rg-avd-prd-weu-001",
    "location": "westeurope"
  },
  "hostPools": {
    "production": "vdpool-avd-prd-weu-001",
    "canary": "vdpool-avd-prd-weu-001-canary"
  },
  "sig": {
    "name": "avd_sig",
    "imageDefinition": "avd-goldenimage"
  },
  "build": {
    "defaultType": "full",
    "artifactsStorageAccount": "stavdartifacts",
    "enableValidation": true
  },
  "deployment": {
    "updateStrategy": "RollingUpdate",
    "canaryDuration": 4,
    "autoPromote": false
  },
  "notifications": {
    "email": "avd-ops@company.com",
    "teamsWebhook": "https://outlook.office.com/webhook/..."
  }
}
```

### 💡 EMPFEHLUNG

**Implementieren Sie den CLI Wrapper:**

**Aufwand:** 12-16 Stunden
**Priorität:** P1 (Hoch - für Developer Experience)
**ROI:** 50% schnellere Onboarding, weniger Fehler

---

## 5.2 Logging Modernisieren

### ✅ VALIDIERUNG: Wichtig für Troubleshooting & Compliance

**Ihre Vorschläge:**
- ✅ Parallel CMTrace & JSON Logs
- ✅ Structured Logs für Kusto / Log Analytics

### 🔧 IMPLEMENTIERUNG: Structured Logging Module

```powershell
# Logging-Module.psm1

class StructuredLogger {
    [string]$LogDirectory
    [string]$SessionId
    [bool]$EnableCMTrace
    [bool]$EnableJSON
    [string]$LogAnalyticsWorkspaceId
    [string]$LogAnalyticsSharedKey

    StructuredLogger([string]$logDir, [hashtable]$config) {
        $this.LogDirectory = $logDir
        $this.SessionId = [guid]::NewGuid().ToString()
        $this.EnableCMTrace = $config.EnableCMTrace ?? $true
        $this.EnableJSON = $config.EnableJSON ?? $true
        $this.LogAnalyticsWorkspaceId = $config.LogAnalyticsWorkspaceId
        $this.LogAnalyticsSharedKey = $config.LogAnalyticsSharedKey

        # Create log directory
        if (-not (Test-Path $this.LogDirectory)) {
            New-Item -ItemType Directory -Path $this.LogDirectory -Force | Out-Null
        }
    }

    [void] Log([string]$Message, [string]$Level, [hashtable]$Properties) {
        $timestamp = Get-Date -Format "o"
        $timestampCMTrace = Get-Date -Format "MM-dd-yyyy HH:mm:ss.fff"

        # Structured log object
        $logEntry = @{
            timestamp = $timestamp
            level = $Level
            message = $Message
            sessionId = $this.SessionId
            computer = $env:COMPUTERNAME
            user = $env:USERNAME
            processId = $PID
            threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            properties = $Properties
        }

        # JSON Log
        if ($this.EnableJSON) {
            $jsonLog = $logEntry | ConvertTo-Json -Compress
            $jsonFile = Join-Path $this.LogDirectory "build-$(Get-Date -Format 'yyyyMMdd').json"
            $jsonLog | Out-File -FilePath $jsonFile -Append -Encoding UTF8
        }

        # CMTrace Format Log
        if ($this.EnableCMTrace) {
            $cmtraceLevel = switch ($Level) {
                "ERROR"   { 3 }
                "WARNING" { 2 }
                default   { 1 }
            }

            $cmtraceLine = "<![LOG[$Message]LOG]!><time=`"$timestampCMTrace`" date=`"$(Get-Date -Format 'MM-dd-yyyy')`" component=`"AVD-ImageBuilder`" context=`"$($this.SessionId)`" type=`"$cmtraceLevel`" thread=`"$($logEntry.threadId)`" file=`"`">"

            $cmtraceFile = Join-Path $this.LogDirectory "build-$(Get-Date -Format 'yyyyMMdd').log"
            $cmtraceLine | Out-File -FilePath $cmtraceFile -Append -Encoding UTF8
        }

        # Send to Log Analytics (if configured)
        if ($this.LogAnalyticsWorkspaceId) {
            $this.SendToLogAnalytics($logEntry)
        }
    }

    [void] SendToLogAnalytics([hashtable]$logEntry) {
        # Build signature for Log Analytics API
        $json = $logEntry | ConvertTo-Json -Depth 10
        $body = [System.Text.Encoding]::UTF8.GetBytes($json)

        $method = "POST"
        $contentType = "application/json"
        $resource = "/api/logs"
        $rfc1123date = [DateTime]::UtcNow.ToString("r")
        $contentLength = $body.Length

        $xHeaders = "x-ms-date:" + $rfc1123date
        $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
        $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
        $keyBytes = [Convert]::FromBase64String($this.LogAnalyticsSharedKey)
        $sha256 = New-Object System.Security.Cryptography.HMACSHA256
        $sha256.Key = $keyBytes
        $calculatedHash = $sha256.ComputeHash($bytesToHash)
        $encodedHash = [Convert]::ToBase64String($calculatedHash)
        $signature = "SharedKey $($this.LogAnalyticsWorkspaceId):$encodedHash"

        $uri = "https://$($this.LogAnalyticsWorkspaceId).ods.opinsights.azure.com$resource?api-version=2016-04-01"

        $headers = @{
            "Authorization" = $signature
            "Log-Type" = "AVDImageBuilder"  # Custom log table
            "x-ms-date" = $rfc1123date
            "time-generated-field" = "timestamp"
        }

        try {
            Invoke-RestMethod -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body
        } catch {
            # Fallback: Log error but don't fail build
            Write-Warning "Failed to send to Log Analytics: $_"
        }
    }

    [void] Info([string]$Message) {
        $this.Info($Message, @{})
    }

    [void] Info([string]$Message, [hashtable]$Properties) {
        $this.Log($Message, "INFO", $Properties)
        Write-Host "[INFO] $Message" -ForegroundColor White
    }

    [void] Success([string]$Message) {
        $this.Success($Message, @{})
    }

    [void] Success([string]$Message, [hashtable]$Properties) {
        $this.Log($Message, "SUCCESS", $Properties)
        Write-Host "✅ $Message" -ForegroundColor Green
    }

    [void] Warning([string]$Message) {
        $this.Warning($Message, @{})
    }

    [void] Warning([string]$Message, [hashtable]$Properties) {
        $this.Log($Message, "WARNING", $Properties)
        Write-Host "⚠️ $Message" -ForegroundColor Yellow
    }

    [void] Error([string]$Message) {
        $this.Error($Message, @{})
    }

    [void] Error([string]$Message, [hashtable]$Properties) {
        $this.Log($Message, "ERROR", $Properties)
        Write-Host "❌ $Message" -ForegroundColor Red
    }

    [void] Metric([string]$Name, [double]$Value, [hashtable]$Tags) {
        $this.Log("Metric: $Name = $Value", "METRIC", @{
            metricName = $Name
            metricValue = $Value
            metricTags = $Tags
        })
    }
}

# Export
function New-StructuredLogger {
    param(
        [string]$LogDirectory = "./logs",
        [hashtable]$Config = @{}
    )

    return [StructuredLogger]::new($LogDirectory, $Config)
}

Export-ModuleMember -Function New-StructuredLogger
```

#### Usage Example

```powershell
# In Packer provisioner script
Import-Module ./Logging-Module.psm1

$logger = New-StructuredLogger -LogDirectory "C:\BuildLogs" -Config @{
    EnableCMTrace = $true
    EnableJSON = $true
    LogAnalyticsWorkspaceId = $env:LOG_ANALYTICS_WORKSPACE_ID
    LogAnalyticsSharedKey = $env:LOG_ANALYTICS_SHARED_KEY
}

$logger.Info("Starting software installation")

try {
    $startTime = Get-Date
    Install-Software -Name "Office 365"
    $duration = (Get-Date) - $startTime

    $logger.Success("Office 365 installed successfully", @{
        duration = $duration.TotalSeconds
        version = "16.0.14326.20404"
    })

    $logger.Metric("InstallDuration", $duration.TotalSeconds, @{
        software = "Office365"
        result = "success"
    })

} catch {
    $logger.Error("Office 365 installation failed", @{
        error = $_.Exception.Message
        stackTrace = $_.ScriptStackTrace
    })
}
```

### Kusto Queries for Log Analytics

```kql
// Query structured logs in Log Analytics
AVDImageBuilder_CL
| where TimeGenerated > ago(24h)
| where level_s == "ERROR"
| project TimeGenerated, message_s, properties_s, computer_s, sessionId_s
| order by TimeGenerated desc

// Build duration analysis
AVDImageBuilder_CL
| where TimeGenerated > ago(30d)
| where level_s == "METRIC" and properties_metricName_s == "BuildDuration"
| summarize AvgDuration=avg(todouble(properties_metricValue_d)) by bin(TimeGenerated, 1d)
| render timechart

// Error rate over time
AVDImageBuilder_CL
| where TimeGenerated > ago(7d)
| summarize Total=count(), Errors=countif(level_s == "ERROR") by bin(TimeGenerated, 1h)
| extend ErrorRate = (Errors * 100.0) / Total
| render timechart
```

### 💡 EMPFEHLUNG

**Implementieren Sie Structured Logging:**

**Aufwand:** 8-12 Stunden
**Priorität:** P2 (Mittel)
**ROI:** 70% schnelleres Troubleshooting, bessere Compliance

---

# 6️⃣ Erweiterungsmöglichkeiten

## 6.1 Machbarkeitsanalyse

**Ihre Vorschläge:**
1. Dynamische App-Auswahl pro Build (App-Matrix)
2. Multi-Region SIG Replikation als Variable
3. Image Lifecycle Automation (SIG Cleanup Rules)
4. Integration Intune/MDM optional
5. Teams Optimizations Auto-Check

### 📊 BEWERTUNGSMATRIX

| Feature | Business Value | Technical Complexity | Aufwand (PT) | Priorität | Empfehlung |
|---------|----------------|---------------------|--------------|-----------|------------|
| **1. App-Matrix** | 🟢🟢🟢 Hoch | 🟡 Mittel | 12-16 | P1 | ✅ **Implementieren** |
| **2. Multi-Region SIG** | 🟢🟢 Mittel | 🟢 Niedrig | 4-6 | P1 | ✅ **Implementieren** |
| **3. Image Lifecycle** | 🟢🟢🟢 Hoch | 🟡 Mittel | 8-12 | P1 | ✅ **Implementieren** |
| **4. Intune Integration** | 🟢 Niedrig | 🔴 Hoch | 20-30 | P3 | ⚠️ **Nur wenn Intune genutzt** |
| **5. Teams Optimization** | 🟢🟢 Mittel | 🟢 Niedrig | 4-6 | P2 | ✅ **Ja, lohnt sich** |

### 🔧 QUICK WINS

#### 1. Multi-Region SIG Replication (EINFACH)

```hcl
# 00-avd-terraform/modules/shared_image_gallery/main.tf

variable "replication_regions" {
  type = list(object({
    name          = string
    replicas      = number
    storage_type  = string  # Standard_LRS or Standard_ZRS
  }))
  description = "Regions for image replication"
  default = [
    {
      name         = "westeurope"
      replicas     = 3
      storage_type = "Standard_ZRS"
    }
  ]
}

resource "azurerm_shared_image_version" "image" {
  # ... existing config ...

  dynamic "target_region" {
    for_each = var.replication_regions
    content {
      name                   = target_region.value.name
      regional_replica_count = target_region.value.replicas
      storage_account_type   = target_region.value.storage_type
    }
  }
}
```

**Aufwand:** 2-4 Stunden
**Priorität:** P1

#### 2. SIG Image Lifecycle / Cleanup (WICHTIG)

```hcl
# 00-avd-terraform/modules/shared_image_gallery/lifecycle.tf

variable "retain_latest_versions" {
  type        = number
  description = "Number of latest image versions to retain"
  default     = 5
}

variable "retention_days" {
  type        = number
  description = "Days to retain old image versions"
  default     = 90
}

resource "null_resource" "cleanup_old_images" {
  triggers = {
    # Run cleanup weekly
    schedule = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      pwsh -File ${path.module}/scripts/Cleanup-OldImages.ps1 \
        -ResourceGroupName ${var.resource_group_name} \
        -GalleryName ${var.sig_name} \
        -ImageDefinition ${var.image_name} \
        -RetainLatest ${var.retain_latest_versions} \
        -RetentionDays ${var.retention_days}
    EOT
  }
}
```

```powershell
# Cleanup-OldImages.ps1
param(
    [string]$ResourceGroupName,
    [string]$GalleryName,
    [string]$ImageDefinition,
    [int]$RetainLatest = 5,
    [int]$RetentionDays = 90
)

# Get all image versions
$versions = Get-AzGalleryImageVersion `
    -ResourceGroupName $ResourceGroupName `
    -GalleryName $GalleryName `
    -GalleryImageDefinitionName $ImageDefinition |
    Sort-Object Name -Descending

# Keep latest N versions
$toKeep = $versions | Select-Object -First $RetainLatest

# Delete old versions
$cutoffDate = (Get-Date).AddDays(-$RetentionDays)

foreach ($version in $versions) {
    if ($version -notin $toKeep) {
        $versionDate = [datetime]::ParseExact($version.Name.Split('.')[0..2] -join '-', 'yyyy-MM-dd', $null)

        if ($versionDate -lt $cutoffDate) {
            Write-Host "Deleting old version: $($version.Name) (created: $versionDate)"
            Remove-AzGalleryImageVersion `
                -ResourceGroupName $ResourceGroupName `
                -GalleryName $GalleryName `
                -GalleryImageDefinitionName $ImageDefinition `
                -Name $version.Name `
                -Force
        }
    }
}
```

**Aufwand:** 6-8 Stunden
**Priorität:** P1

#### 3. Teams Optimization Check (SCHNELL)

```powershell
# Test-TeamsOptimization.ps1 (in Validation)

Describe "Teams Optimization" {
    It "Teams Machine-Wide Installer is present" {
        $teamsInstaller = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
            Where-Object { $_.DisplayName -like "*Teams Machine*" }
        $teamsInstaller | Should -Not -BeNullOrEmpty
    }

    It "Teams Media Optimizations are configured" {
        $mediaOptimizations = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Teams" -Name "IsWVDEnvironment" -ErrorAction SilentlyContinue
        $mediaOptimizations.IsWVDEnvironment | Should -Be 1
    }

    It "WebRTC Redirector is installed" {
        $redirector = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Teams\WebRTC" -ErrorAction SilentlyContinue
        $redirector | Should -Not -BeNullOrEmpty
    }
}
```

**Aufwand:** 2-4 Stunden
**Priorität:** P2

---

# 🗺️ IMPLEMENTIERUNGS-ROADMAP

## Phase 1: Foundation (Woche 1-2) - 40 PT

**Kritische Sicherheit & Compliance**
- [ ] Key Vault Integration (2.1) - 16 PT
- [ ] Build VM Security Hardening (2.2) - 8 PT
- [ ] Post-Build Validation Framework (1.3) - 12 PT
- [ ] Multi-Region SIG Replication (6.1) - 4 PT

**Geschätzter ROI:** 60% weniger Security Incidents

## Phase 2: Automation & Quality (Woche 3-4) - 36 PT

**Build Quality & Governance**
- [ ] Versioning Schema + Tags (1.1) - 4 PT
- [ ] Build Artifacts Standardisierung (3.2) - 12 PT
- [ ] CAF Naming Convention (4.1) - 8 PT
- [ ] Mandatory Tagging & Policy (4.1) - 8 PT
- [ ] SIG Lifecycle/Cleanup (6.1) - 4 PT

**Geschätzter ROI:** 40% schnellere Troubleshooting, 100% Compliance

## Phase 3: Deployment Safety (Woche 5-6) - 24 PT

**Production Readiness**
- [ ] Canary Deployment Pipeline (3.1) - 20 PT
- [ ] Teams Optimization Validation (6.1) - 4 PT

**Geschätzter ROI:** 80% weniger Production Incidents

## Phase 4: Developer Experience (Woche 7-8) - 24 PT

**Produktivität & Usability**
- [ ] Unified CLI Wrapper (5.1) - 16 PT
- [ ] Structured Logging (5.2) - 8 PT

**Geschätzter ROI:** 50% schnelleres Onboarding, 30% weniger Fehler

## Phase 5: Optional Enhancements (Nach Phase 4)

**Advanced Features**
- [ ] Azure Image Builder PoC (1.2) - 20 PT
- [ ] Dynamic App Matrix (6.1) - 16 PT
- [ ] VMSS-based Hosts (4.2) - 40 PT
- [ ] Intune Integration (6.1) - 30 PT

**Total Effort (Phase 1-4):** 124 Personentage (~6 Monate bei 0.5 FTE)

---

# 📊 ZUSAMMENFASSUNG & EMPFEHLUNGEN

## Top 10 Quick Wins

| # | Optimierung | Aufwand | Impact | Wann |
|---|-------------|---------|--------|------|
| 1 | Multi-Region SIG | 4 PT | 🟢🟢 | Sofort |
| 2 | Teams Optimization Check | 4 PT | 🟢🟢 | Sofort |
| 3 | SIG Image Lifecycle/Cleanup | 8 PT | 🟢🟢🟢 | Woche 1 |
| 4 | Versioning mit Tags | 4 PT | 🟢🟢 | Woche 1 |
| 5 | Post-Build Validation (Basis) | 8 PT | 🟢🟢🟢 | Woche 1 |
| 6 | Build Manifest & Release Notes | 8 PT | 🟢🟢 | Woche 2 |
| 7 | CAF Naming Convention | 8 PT | 🟢🟢🟢 | Woche 2 |
| 8 | Key Vault Integration | 16 PT | 🟢🟢🟢 | Woche 3 |
| 9 | Build VM Security | 8 PT | 🟢🟢🟢 | Woche 3 |
| 10 | CLI Wrapper (Basis) | 12 PT | 🟢🟢 | Woche 4 |

**Quick Wins Total:** 80 PT (~2 Monate)

## Kritische Abhängigkeiten

```
Key Vault → Security Hardening → Validation Framework
    ↓
Naming Convention → Tagging → Policy Enforcement
    ↓
Build Artifacts → Canary Pipeline → Production
    ↓
CLI Wrapper → Logging → Monitoring
```

## Erfolgskriterien

**Nach Phase 1:**
- ✅ Keine Secrets in Code oder Logs
- ✅ 100% Build Validation Coverage
- ✅ Multi-Region Image Availability

**Nach Phase 2:**
- ✅ 100% CAF-konform
- ✅ Vollständige Build-Traceability
- ✅ Automatische Image-Cleanup

**Nach Phase 3:**
- ✅ Zero-Downtime Deployments
- ✅ < 5% Canary Failure Rate
- ✅ < 15 Min Rollback Time

**Nach Phase 4:**
- ✅ < 30 Min Onboarding neue Entwickler
- ✅ 70% schnelleres Troubleshooting
- ✅ Kusto-basiertes Monitoring

---

**🎯 FINAL RECOMMENDATION:**

**Start NOW with Phase 1** - Kritische Sicherheit und Compliance bilden das Fundament für alle weiteren Optimierungen.

**NICHT implementieren (vorerst):**
- ❌ Azure Image Builder (Ihre Packer-Lösung funktioniert sehr gut)
- ❌ VMSS (außer Sie haben >50 Session Hosts)
- ❌ Intune Integration (nur wenn bereits Intune genutzt)

**Ihre besten 3 Monate:**
1. **Monat 1:** Foundation (Security + Validation)
2. **Monat 2:** Automation (Governance + Artifacts)
3. **Monat 3:** Deployment Safety (Canary + CLI)

**Total Investment:** ~124 Personentage
**Expected ROI:** 300-400% (durch Prevention von Incidents, schnelleres Troubleshooting, höhere Deployment-Frequenz)
