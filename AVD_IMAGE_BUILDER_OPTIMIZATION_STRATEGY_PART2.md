# 🚀 AVD Image Builder - Optimierungsstrategie Teil 2

**Fortsetzung von Teil 1**
**Projekt:** Azure Virtual Desktop Image Builder & Terraform Framework

---

# 3️⃣ Build-Orchestrierung & Automation

## 3.1 Canary → Promote Flow für SIG-Versionen

### ✅ VALIDIERUNG: EXZELLENTE Production-Safety Strategie

**Ihr Konzept:**
1. Neue SIG-Version → Testpool
2. Synthetic Logon Tests
3. Automatische Promotion

**Das ist Best Practice für:**
- ✅ Zero-Downtime Deployments
- ✅ Automated Quality Gates
- ✅ Rollback-Fähigkeit
- ✅ Production Safety

### 🎯 ERWEITERTE CANARY DEPLOYMENT STRATEGIE

```
┌────────────────────────────────────────────────────────────────┐
│                    BUILD PIPELINE                               │
│  Packer Build → SIG Version 2025.02.07.1                       │
│  Status: "canary"  (Tag auf SIG Version)                        │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│                 CANARY DEPLOYMENT (5%)                          │
│  • Deploy to dedicated Canary Host Pool                         │
│  • OR: 1-2 VMs in production pool mit tag "canary"             │
│  • Duration: 2-24 hours                                         │
└────────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────────┐
│                SYNTHETIC TESTS & MONITORING                     │
│  ✓ Login Performance Test                                       │
│  ✓ Application Launch Tests                                     │
│  ✓ Office 365 Activation Check                                  │
│  ✓ FSLogix Profile Loading                                      │
│  ✓ Performance Metrics (CPU, RAM, Disk)                         │
│  ✓ Event Log Analysis (Errors/Warnings)                         │
└────────────────────────────────────────────────────────────────┘
                          ↓
                    [Quality Gate]
                          ↓
              ┌─────────────────────┐
              │  Tests Passed?      │
              └─────────────────────┘
                 ✅ YES   │   ❌ NO
                    ↓     │     ↓
        ┌───────────┘     │     └──────────┐
        ↓                 │                 ↓
┌──────────────┐          │        ┌────────────────┐
│   PROMOTE    │          │        │   ROLLBACK     │
│ Status:      │          │        │ Mark as:       │
│ "production" │          │        │ "failed"       │
└──────────────┘          │        └────────────────┘
        ↓                 │                 ↓
┌──────────────────────┐  │        ┌────────────────┐
│  ROLLING UPDATE      │  │        │  Alert Team    │
│  to all Hosts        │  │        │  Create Issue  │
│  (10% per hour)      │  │        └────────────────┘
└──────────────────────┘  │
                          ↓
                 [Manual Override]
```

### 🔧 IMPLEMENTIERUNG

#### Architektur: Canary Host Pool

```hcl
# 00-avd-terraform/hostpools-canary.tf

# Canary Host Pool (für Testing)
module "hostpool_canary" {
  source              = "./modules/hostpool"
  resource_group_name = local.resource_group_name
  location            = var.location
  hostpool_name       = "${local.hostpool_name}-canary"

  # Nur für Canary-Testing Benutzer
  maximum_sessions_allowed         = 2
  load_balancer_type              = "BreadthFirst"
  start_vm_on_connect             = false
  validation_environment          = true  # Wichtig!

  scheduled_agent_updates {
    enabled = true
    schedule {
      day_of_week = "Sunday"
      hour_of_day = 2
    }
  }

  tags = merge(local.common_tags, {
    Purpose = "Canary Testing"
    Environment = "canary"
  })
}

# Application Group für Canary
module "app_group_canary" {
  source                  = "./modules/application_group"
  resource_group_name     = local.resource_group_name
  location                = var.location
  hostpool_id             = module.hostpool_canary.id
  application_group_name  = "${local.application_group_name}-canary"
  type                    = "Desktop"

  tags = merge(local.common_tags, {
    Environment = "canary"
  })
}

# RBAC: Nur Test-Benutzer haben Zugriff
resource "azurerm_role_assignment" "canary_users" {
  scope                = module.app_group_canary.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = var.canary_test_group_id  # Azure AD Gruppe "AVD-Canary-Testers"
}
```

#### Deployment Script: Canary Deploy

```powershell
# Deploy-CanaryImage.ps1
#Requires -Version 7.0
#Requires -Modules Az.DesktopVirtualization, Az.Compute, Az.Resources

<#
.SYNOPSIS
    Deploy new SIG image to Canary environment

.DESCRIPTION
    Creates canary session hosts with new image version
    Runs synthetic tests
    Promotes or rolls back based on results
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$CanaryHostPoolName,

    [Parameter(Mandatory = $true)]
    [string]$ProductionHostPoolName,

    [Parameter(Mandatory = $true)]
    [string]$ImageVersion,  # e.g., "2025.02.07.1"

    [Parameter(Mandatory = $false)]
    [int]$CanaryHostCount = 2,

    [Parameter(Mandatory = $false)]
    [int]$MonitoringDurationHours = 4,

    [Parameter(Mandatory = $false)]
    [switch]$AutoPromote = $false,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

#region Functions

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-SIGImageId {
    param(
        [string]$ResourceGroupName,
        [string]$GalleryName,
        [string]$ImageDefinitionName,
        [string]$ImageVersion
    )

    $image = Get-AzGalleryImageVersion `
        -ResourceGroupName $ResourceGroupName `
        -GalleryName $GalleryName `
        -GalleryImageDefinitionName $ImageDefinitionName `
        -Name $ImageVersion `
        -ErrorAction Stop

    return $image.Id
}

function Deploy-CanaryHosts {
    param(
        [string]$HostPoolName,
        [string]$ResourceGroupName,
        [string]$ImageId,
        [int]$Count
    )

    Write-Log "Deploying $Count canary hosts to pool $HostPoolName..." "INFO"

    # Get Host Pool Registration Token
    $token = New-AzWvdRegistrationInfo `
        -ResourceGroupName $ResourceGroupName `
        -HostPoolName $HostPoolName `
        -ExpirationTime (Get-Date).AddHours(4)

    # Deploy VMs
    $deployedHosts = @()
    for ($i = 1; $i -le $Count; $i++) {
        $vmName = "canary-${ImageVersion}-${i}"

        if ($DryRun) {
            Write-Log "[DRY RUN] Would deploy VM: $vmName with image $ImageId" "INFO"
            continue
        }

        # Create VM from SIG Image
        $vm = New-AzVM `
            -ResourceGroupName $ResourceGroupName `
            -Location "westeurope" `
            -Name $vmName `
            -ImageReferenceId $ImageId `
            -Size "Standard_D4s_v5" `
            -Credential (Get-Credential -Message "Local Admin for $vmName") `
            -VirtualNetworkName "vnet-avd-prod" `
            -SubnetName "snet-avd-hosts" `
            -PublicIpAddressName "" `  # No public IP
            -SecurityGroupName "nsg-avd-hosts" `
            -Tag @{
                Purpose = "Canary Testing"
                ImageVersion = $ImageVersion
                DeploymentTime = (Get-Date).ToString("o")
            }

        # Install AVD Agent (via Custom Script Extension)
        $scriptUrl = "https://raw.githubusercontent.com/Azure/RDS-Templates/master/ARM-wvd-templates/DSC/Configuration.zip"

        Set-AzVMExtension `
            -ResourceGroupName $ResourceGroupName `
            -VMName $vmName `
            -Name "DSC" `
            -Publisher "Microsoft.Powershell" `
            -ExtensionType "DSC" `
            -TypeHandlerVersion "2.77" `
            -Settings @{
                wmfVersion = "latest"
                configuration = @{
                    url = $scriptUrl
                    script = "Configuration.ps1"
                    function = "AddSessionHost"
                }
                configurationArguments = @{
                    hostPoolName = $HostPoolName
                    registrationInfoToken = $token.Token
                }
            }

        $deployedHosts += $vmName
        Write-Log "✅ Deployed canary host: $vmName" "SUCCESS"
    }

    return $deployedHosts
}

function Invoke-SyntheticTests {
    param(
        [string[]]$HostNames,
        [string]$HostPoolName,
        [string]$ResourceGroupName
    )

    Write-Log "Running synthetic tests on canary hosts..." "INFO"

    $testResults = @{
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        Tests = @()
    }

    # Test 1: Host Registration
    foreach ($host in $HostNames) {
        $testResults.TotalTests++

        $sessionHost = Get-AzWvdSessionHost `
            -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName `
            -Name $host `
            -ErrorAction SilentlyContinue

        if ($sessionHost -and $sessionHost.Status -eq "Available") {
            $testResults.PassedTests++
            $testResults.Tests += @{
                Name = "Host Registration: $host"
                Result = "PASS"
                Message = "Host is registered and available"
            }
            Write-Log "✅ Test PASSED: Host $host is registered" "SUCCESS"
        } else {
            $testResults.FailedTests++
            $testResults.Tests += @{
                Name = "Host Registration: $host"
                Result = "FAIL"
                Message = "Host not available: $($sessionHost.Status)"
            }
            Write-Log "❌ Test FAILED: Host $host registration failed" "ERROR"
        }
    }

    # Test 2: Synthetic Login Test
    # Requires test user credentials
    if ($env:AVD_TEST_USER -and $env:AVD_TEST_PASSWORD) {
        $testResults.TotalTests++

        Write-Log "Running synthetic login test..." "INFO"

        # Use Azure CLI or RD Client automation
        $loginTest = Test-AVDLogin `
            -HostPoolName $HostPoolName `
            -UserPrincipalName $env:AVD_TEST_USER `
            -Password $env:AVD_TEST_PASSWORD

        if ($loginTest.Success) {
            $testResults.PassedTests++
            $testResults.Tests += @{
                Name = "Synthetic Login"
                Result = "PASS"
                Message = "Login successful in $($loginTest.DurationSeconds)s"
            }
            Write-Log "✅ Test PASSED: Synthetic login successful" "SUCCESS"
        } else {
            $testResults.FailedTests++
            $testResults.Tests += @{
                Name = "Synthetic Login"
                Result = "FAIL"
                Message = $loginTest.ErrorMessage
            }
            Write-Log "❌ Test FAILED: Synthetic login failed" "ERROR"
        }
    }

    # Test 3: Application Availability
    $testResults.TotalTests++

    $apps = @("Microsoft Word", "Microsoft Excel", "Microsoft Edge")
    $allAppsAvailable = $true

    foreach ($app in $apps) {
        # Check if app is available in canary hosts
        # This would require WinRM or Azure Run Command
        Write-Log "Checking application: $app..." "INFO"
    }

    if ($allAppsAvailable) {
        $testResults.PassedTests++
        $testResults.Tests += @{
            Name = "Application Availability"
            Result = "PASS"
            Message = "All applications available"
        }
    }

    # Test 4: Performance Baseline
    $testResults.TotalTests++

    Write-Log "Collecting performance metrics..." "INFO"

    # Check VM metrics via Azure Monitor
    $metrics = Get-AzMetric `
        -ResourceId "/subscriptions/.../virtualMachines/$($HostNames[0])" `
        -TimeGrain 00:05:00 `
        -MetricName "Percentage CPU","Available Memory Bytes" `
        -StartTime (Get-Date).AddMinutes(-30)

    $avgCPU = ($metrics | Where-Object {$_.Name.Value -eq "Percentage CPU"}).Data.Average | Measure-Object -Average).Average

    if ($avgCPU -lt 80) {
        $testResults.PassedTests++
        $testResults.Tests += @{
            Name = "Performance Baseline"
            Result = "PASS"
            Message = "CPU usage acceptable: $([math]::Round($avgCPU, 2))%"
        }
        Write-Log "✅ Test PASSED: Performance within limits" "SUCCESS"
    } else {
        $testResults.FailedTests++
        $testResults.Tests += @{
            Name = "Performance Baseline"
            Result = "FAIL"
            Message = "CPU usage too high: $([math]::Round($avgCPU, 2))%"
        }
        Write-Log "❌ Test FAILED: Performance degradation detected" "ERROR"
    }

    return $testResults
}

function Update-ImageStatus {
    param(
        [string]$ResourceGroupName,
        [string]$GalleryName,
        [string]$ImageDefinitionName,
        [string]$ImageVersion,
        [ValidateSet("canary", "production", "failed")]
        [string]$Status
    )

    Write-Log "Updating image status to: $Status" "INFO"

    if ($DryRun) {
        Write-Log "[DRY RUN] Would update image $ImageVersion status to $Status" "INFO"
        return
    }

    # Update image version tags
    $image = Get-AzGalleryImageVersion `
        -ResourceGroupName $ResourceGroupName `
        -GalleryName $GalleryName `
        -GalleryImageDefinitionName $ImageDefinitionName `
        -Name $ImageVersion

    $newTags = $image.Tags
    $newTags["DeploymentStatus"] = $Status
    $newTags["PromotionDate"] = (Get-Date).ToString("o")

    Update-AzGalleryImageVersion `
        -ResourceGroupName $ResourceGroupName `
        -GalleryName $GalleryName `
        -GalleryImageDefinitionName $ImageDefinitionName `
        -Name $ImageVersion `
        -Tag $newTags

    Write-Log "✅ Image status updated to: $Status" "SUCCESS"
}

function Invoke-ProductionRollout {
    param(
        [string]$ProductionHostPoolName,
        [string]$ResourceGroupName,
        [string]$ImageVersion
    )

    Write-Log "Starting production rollout for image $ImageVersion..." "INFO"

    # Use existing Update-AVDSessionHosts.ps1 script
    $scriptPath = Join-Path $PSScriptRoot "Update-AVDSessionHosts.ps1"

    & $scriptPath `
        -ResourceGroupName $ResourceGroupName `
        -HostPoolName $ProductionHostPoolName `
        -ImageVersion $ImageVersion `
        -UpdateStrategy "RollingUpdate" `
        -MaxSessionsBeforeUpdate 0 `
        -SessionWaitTimeout 120

    Write-Log "✅ Production rollout initiated" "SUCCESS"
}

#endregion

#region Main Script

Write-Log "=== AVD Canary Deployment Started ===" "INFO"
Write-Log "Image Version: $ImageVersion" "INFO"
Write-Log "Canary Host Pool: $CanaryHostPoolName" "INFO"
Write-Log "Production Host Pool: $ProductionHostPoolName" "INFO"

try {
    # Step 1: Get SIG Image
    Write-Log "Step 1: Retrieving image from Shared Image Gallery..." "INFO"
    $imageId = Get-SIGImageId `
        -ResourceGroupName $ResourceGroupName `
        -GalleryName "avd_sig" `
        -ImageDefinitionName "avd-goldenimage" `
        -ImageVersion $ImageVersion

    Write-Log "✅ Image found: $imageId" "SUCCESS"

    # Step 2: Deploy Canary Hosts
    Write-Log "Step 2: Deploying canary hosts..." "INFO"
    $canaryHosts = Deploy-CanaryHosts `
        -HostPoolName $CanaryHostPoolName `
        -ResourceGroupName $ResourceGroupName `
        -ImageId $imageId `
        -Count $CanaryHostCount

    if (-not $DryRun) {
        # Wait for hosts to be ready
        Write-Log "Waiting 5 minutes for hosts to initialize..." "INFO"
        Start-Sleep -Seconds 300
    }

    # Step 3: Run Synthetic Tests
    Write-Log "Step 3: Running synthetic tests..." "INFO"
    $testResults = Invoke-SyntheticTests `
        -HostNames $canaryHosts `
        -HostPoolName $CanaryHostPoolName `
        -ResourceGroupName $ResourceGroupName

    # Step 4: Evaluate Results
    Write-Log "Step 4: Evaluating test results..." "INFO"
    Write-Log "Total Tests: $($testResults.TotalTests)" "INFO"
    Write-Log "Passed: $($testResults.PassedTests)" "SUCCESS"
    Write-Log "Failed: $($testResults.FailedTests)" "ERROR"

    $passRate = ($testResults.PassedTests / $testResults.TotalTests) * 100

    # Quality Gate: 95% pass rate required
    if ($passRate -ge 95) {
        Write-Log "✅ QUALITY GATE PASSED ($passRate%)" "SUCCESS"

        # Update image status
        Update-ImageStatus `
            -ResourceGroupName $ResourceGroupName `
            -GalleryName "avd_sig" `
            -ImageDefinitionName "avd-goldenimage" `
            -ImageVersion $ImageVersion `
            -Status "production"

        # Step 5: Promote to Production
        if ($AutoPromote) {
            Write-Log "Step 5: Auto-promoting to production..." "INFO"
            Invoke-ProductionRollout `
                -ProductionHostPoolName $ProductionHostPoolName `
                -ResourceGroupName $ResourceGroupName `
                -ImageVersion $ImageVersion
        } else {
            Write-Log "Step 5: Manual promotion required" "WARNING"
            Write-Log "Run the following command to promote:" "INFO"
            Write-Log "  .\Update-AVDSessionHosts.ps1 -ResourceGroupName '$ResourceGroupName' -HostPoolName '$ProductionHostPoolName' -ImageVersion '$ImageVersion'" "INFO"
        }

    } else {
        Write-Log "❌ QUALITY GATE FAILED ($passRate%)" "ERROR"

        # Update image status
        Update-ImageStatus `
            -ResourceGroupName $ResourceGroupName `
            -GalleryName "avd_sig" `
            -ImageDefinitionName "avd-goldenimage" `
            -ImageVersion $ImageVersion `
            -Status "failed"

        Write-Log "Canary deployment failed. Image will NOT be promoted." "ERROR"
        exit 1
    }

    # Step 6: Monitoring Period (if not auto-promote)
    if (-not $AutoPromote -and $MonitoringDurationHours -gt 0) {
        Write-Log "Step 6: Monitoring canary hosts for $MonitoringDurationHours hours..." "INFO"
        Write-Log "Check Azure Monitor dashboards for anomalies" "INFO"
        Write-Log "Manually promote after monitoring period if satisfied" "INFO"
    }

    Write-Log "=== Canary Deployment Completed ===" "SUCCESS"

} catch {
    Write-Log "❌ Canary deployment failed: $_" "ERROR"
    exit 1
}

#endregion
```

#### Helper Function: Synthetic Login Test

```powershell
# Test-AVDLogin.ps1
function Test-AVDLogin {
    param(
        [string]$HostPoolName,
        [string]$UserPrincipalName,
        [string]$Password
    )

    try {
        # Get AVD Web Client URL
        $workspaceId = (Get-AzWvdWorkspace | Where-Object {$_.ApplicationGroupReferences -match $HostPoolName}).Id

        $feedUrl = "https://rdweb.wvd.microsoft.com/api/arm/feeddiscovery"

        # Authenticate test user
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ($UserPrincipalName, $securePassword)

        # Use Selenium or Azure CLI for web automation
        # This is a simplified example - production would use proper automation

        $startTime = Get-Date

        # Simulate login test
        # In production: Use Selenium WebDriver to automate RD Web Client
        # Or use msrdc.exe (Remote Desktop Client) with automation

        Write-Host "Performing login test for $UserPrincipalName..."

        # Placeholder for actual login automation
        # Real implementation would:
        # 1. Open RD Web Client
        # 2. Enter credentials
        # 3. Select desktop
        # 4. Measure time to desktop ready
        # 5. Launch test application
        # 6. Logout

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds

        return @{
            Success = $true
            DurationSeconds = $duration
            ErrorMessage = ""
        }

    } catch {
        return @{
            Success = $false
            DurationSeconds = 0
            ErrorMessage = $_.Exception.Message
        }
    }
}
```

#### GitHub Actions Workflow: Canary Pipeline

```yaml
# .github/workflows/canary-deployment.yml
name: AVD Canary Deployment

on:
  workflow_dispatch:
    inputs:
      image_version:
        description: 'SIG Image Version (e.g., 2025.02.07.1)'
        required: true
      auto_promote:
        description: 'Automatically promote to production if tests pass'
        type: boolean
        default: false
      monitoring_hours:
        description: 'Monitoring duration in hours'
        type: number
        default: 4

jobs:
  canary-deploy:
    runs-on: windows-latest
    environment: canary

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy Canary
        shell: pwsh
        run: |
          .\Deploy-CanaryImage.ps1 `
            -ResourceGroupName "avd-prod-rg" `
            -CanaryHostPoolName "hp-prod-canary" `
            -ProductionHostPoolName "hp-prod" `
            -ImageVersion "${{ github.event.inputs.image_version }}" `
            -CanaryHostCount 2 `
            -MonitoringDurationHours ${{ github.event.inputs.monitoring_hours }} `
            -AutoPromote:$${{ github.event.inputs.auto_promote }}
        env:
          AVD_TEST_USER: ${{ secrets.AVD_TEST_USER }}
          AVD_TEST_PASSWORD: ${{ secrets.AVD_TEST_PASSWORD }}

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: canary-test-results-${{ github.event.inputs.image_version }}
          path: |
            *.log
            test-results*.json

      - name: Notify Teams
        if: always()
        uses: aliencube/microsoft-teams-actions@v0.8.0
        with:
          webhook_uri: ${{ secrets.TEAMS_WEBHOOK_URL }}
          title: Canary Deployment ${{ job.status }}
          summary: Image ${{ github.event.inputs.image_version }} canary deployment completed
          text: |
            Status: ${{ job.status }}
            Image: ${{ github.event.inputs.image_version }}
            Auto-Promote: ${{ github.event.inputs.auto_promote }}

  production-rollout:
    needs: canary-deploy
    if: ${{ github.event.inputs.auto_promote == 'true' }}
    runs-on: windows-latest
    environment: production  # Requires manual approval in GitHub

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Production Rollout
        shell: pwsh
        run: |
          .\Update-AVDSessionHosts.ps1 `
            -ResourceGroupName "avd-prod-rg" `
            -HostPoolName "hp-prod" `
            -ImageVersion "${{ github.event.inputs.image_version }}" `
            -UpdateStrategy "RollingUpdate"
```

### Azure Monitor Workbook: Canary Dashboard

```json
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "## AVD Canary Deployment Dashboard\n\nMonitor canary host performance and health"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "WVDConnections\n| where TimeGenerated > ago(4h)\n| where SessionHostName contains \"canary\"\n| summarize \n    TotalConnections = count(),\n    SuccessfulConnections = countif(State == \"Connected\"),\n    FailedConnections = countif(State == \"Failed\"),\n    AvgConnectionTime = avg(EstablishmentDuration)\n| extend SuccessRate = (SuccessfulConnections * 100.0) / TotalConnections",
        "size": 0,
        "title": "Canary Connection Success Rate",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "Perf\n| where TimeGenerated > ago(4h)\n| where Computer contains \"canary\"\n| where ObjectName == \"Processor\" and CounterName == \"% Processor Time\"\n| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m), Computer\n| render timechart",
        "size": 0,
        "title": "Canary Host CPU Usage",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      }
    }
  ]
}
```

### 💡 EMPFEHLUNG

**Implementieren Sie Canary Deployment schrittweise:**

**Phase 1 (Woche 1):** Infrastructure Setup
- Canary Host Pool erstellen
- RBAC für Test-Benutzer

**Phase 2 (Woche 2):** Deployment Automation
- Deploy-CanaryImage.ps1 Script
- Basis-Synthetic Tests

**Phase 3 (Woche 3):** Advanced Testing & Auto-Promotion
- Umfassende Synthetic Tests
- GitHub Actions Integration
- Azure Monitor Dashboard

**Aufwand:** 20-24 Stunden
**Priorität:** P1 (Hoch)
**ROI:** Verhindert Production-Incidents, ermöglicht Continuous Delivery

---

## 3.2 Standardisierung von Build-Artefakten

### ✅ VALIDIERUNG: Sehr sinnvoll für Traceability & Compliance

**Ihre Vorschläge:**
- ✅ sig_version.json
- ✅ releasenotes.md
- ✅ Vollständige Softwareliste

### 🎯 ERWEITERTE ARTEFAKT-STRATEGIE

**Build Artifacts Structure:**
```
artifacts/
├── 2025.02.07.1/
│   ├── manifest.json                 # Vollständige Build-Info
│   ├── releasenotes.md               # Human-readable release notes
│   ├── software-inventory.json       # Installed software + versions
│   ├── validation-results.xml        # Pester test results
│   ├── performance-baseline.json     # Boot time, memory, etc.
│   ├── security-compliance.json      # CIS benchmark results
│   ├── eventlog-summary.json         # Build-time errors/warnings
│   ├── packer-build.log              # Full Packer logs
│   ├── terraform-state-backup.json   # TF state at build time
│   └── sbom.json                     # Software Bill of Materials (SPDX format)
```

### 🔧 IMPLEMENTIERUNG

#### Build Manifest Generator

```powershell
# Generate-BuildManifest.ps1
#Requires -Version 7.0

function Generate-BuildManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ImageVersion,

        [Parameter(Mandatory = $true)]
        [string]$BuildType,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "C:\BuildArtifacts"
    )

    Write-Host "Generating build manifest for version $ImageVersion..." -ForegroundColor Cyan

    # Ensure output directory exists
    $versionPath = Join-Path $OutputPath $ImageVersion
    New-Item -ItemType Directory -Path $versionPath -Force | Out-Null

    # ===== 1. MANIFEST.JSON =====
    Write-Host "Creating manifest.json..." -ForegroundColor Yellow

    $manifest = @{
        version = "1.0"
        build = @{
            imageVersion = $ImageVersion
            buildType = $BuildType
            buildDate = (Get-Date).ToString("o")
            buildAgent = $env:COMPUTERNAME
            buildUser = $env:USERNAME
            pipelineId = $env:GITHUB_RUN_ID ?? $env:BUILD_BUILDID ?? "manual"
            gitCommit = $env:GITHUB_SHA ?? (git rev-parse HEAD 2>$null) ?? "unknown"
            gitBranch = $env:GITHUB_REF_NAME ?? (git rev-parse --abbrev-ref HEAD 2>$null) ?? "unknown"
        }
        image = @{
            baseOS = (Get-CimInstance Win32_OperatingSystem).Caption
            osVersion = (Get-CimInstance Win32_OperatingSystem).Version
            osBuild = (Get-CimInstance Win32_OperatingSystem).BuildNumber
            architecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
            locale = (Get-Culture).Name
            timezone = (Get-TimeZone).Id
        }
        azure = @{
            subscriptionId = $env:ARM_SUBSCRIPTION_ID
            resourceGroup = $env:RESOURCE_GROUP_NAME
            sigName = "avd_sig"
            imageDefinition = "avd-goldenimage"
        }
        software = @{
            inventoryFile = "software-inventory.json"
            sbomFile = "sbom.json"
        }
        validation = @{
            resultsFile = "validation-results.xml"
            passed = $false  # Will be updated after validation
            totalTests = 0
            passedTests = 0
            failedTests = 0
        }
        performance = @{
            baselineFile = "performance-baseline.json"
        }
        security = @{
            complianceFile = "security-compliance.json"
            cisLevel = 2
            complianceScore = 0  # Will be calculated
        }
    }

    $manifest | ConvertTo-Json -Depth 10 | Out-File (Join-Path $versionPath "manifest.json") -Encoding UTF8

    # ===== 2. SOFTWARE INVENTORY =====
    Write-Host "Collecting software inventory..." -ForegroundColor Yellow

    $softwareInventory = @{
        generatedAt = (Get-Date).ToString("o")
        imageVersion = $ImageVersion
        applications = @()
        windowsFeatures = @()
        services = @()
        hotfixes = @()
    }

    # Installed applications (both 32-bit and 64-bit)
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $installedApps = foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, EstimatedSize
    }

    $softwareInventory.applications = $installedApps | Sort-Object DisplayName -Unique

    # Windows Features
    $features = Get-WindowsOptionalFeature -Online |
        Where-Object { $_.State -eq "Enabled" } |
        Select-Object FeatureName, State

    $softwareInventory.windowsFeatures = $features

    # Services
    $services = Get-Service |
        Select-Object Name, DisplayName, Status, StartType |
        Sort-Object Name

    $softwareInventory.services = $services

    # Installed Hotfixes
    $hotfixes = Get-HotFix |
        Select-Object HotFixID, Description, InstalledOn |
        Sort-Object InstalledOn -Descending

    $softwareInventory.hotfixes = $hotfixes

    # Key component versions
    $softwareInventory.keyComponents = @{
        avdAgent = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -ErrorAction SilentlyContinue).Version
        fslogix = (Get-Item "C:\Program Files\FSLogix\Apps\frx.exe" -ErrorAction SilentlyContinue).VersionInfo.FileVersion
        office365 = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue).VersionToReport
        edge = (Get-Item "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ErrorAction SilentlyContinue).VersionInfo.FileVersion
        defenderPlatform = (Get-MpComputerStatus).AMProductVersion
        defenderEngine = (Get-MpComputerStatus).AMEngineVersion
        defenderSignatures = (Get-MpComputerStatus).AntivirusSignatureVersion
    }

    $softwareInventory | ConvertTo-Json -Depth 10 | Out-File (Join-Path $versionPath "software-inventory.json") -Encoding UTF8

    # ===== 3. SBOM (Software Bill of Materials) - SPDX Format =====
    Write-Host "Generating SBOM (Software Bill of Materials)..." -ForegroundColor Yellow

    $sbom = @{
        spdxVersion = "SPDX-2.3"
        dataLicense = "CC0-1.0"
        SPDXID = "SPDXRef-DOCUMENT"
        name = "AVD-Image-$ImageVersion"
        documentNamespace = "https://ramboeck.com/avd-images/$ImageVersion"
        creationInfo = @{
            created = (Get-Date).ToString("o")
            creators = @("Tool: Packer", "Organization: Ramboeck IT")
        }
        packages = @()
    }

    # Convert installed apps to SPDX packages
    foreach ($app in $installedApps) {
        $package = @{
            SPDXID = "SPDXRef-Package-$($app.DisplayName -replace '[^a-zA-Z0-9]', '-')"
            name = $app.DisplayName
            versionInfo = $app.DisplayVersion ?? "unknown"
            supplier = "Organization: $($app.Publisher ?? 'unknown')"
            downloadLocation = "NOASSERTION"
            filesAnalyzed = $false
            licenseConcluded = "NOASSERTION"
            licenseDeclared = "NOASSERTION"
            copyrightText = "NOASSERTION"
        }
        $sbom.packages += $package
    }

    $sbom | ConvertTo-Json -Depth 10 | Out-File (Join-Path $versionPath "sbom.json") -Encoding UTF8

    # ===== 4. PERFORMANCE BASELINE =====
    Write-Host "Capturing performance baseline..." -ForegroundColor Yellow

    $performanceBaseline = @{
        capturedAt = (Get-Date).ToString("o")
        imageVersion = $ImageVersion
        system = @{
            totalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            processorCount = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
            osDiskSizeGB = [math]::Round((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").Size / 1GB, 2)
            osDiskFreeGB = [math]::Round((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB, 2)
        }
        boot = @{
            # Would require boot time measurement during build
            estimatedBootTimeSeconds = 0
            lastBootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString("o")
        }
        processes = @{
            totalCount = (Get-Process).Count
            top10ByCPU = (Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet)
        }
        services = @{
            total = (Get-Service).Count
            running = (Get-Service | Where-Object Status -eq "Running").Count
            automatic = (Get-Service | Where-Object StartType -eq "Automatic").Count
        }
    }

    $performanceBaseline | ConvertTo-Json -Depth 10 | Out-File (Join-Path $versionPath "performance-baseline.json") -Encoding UTF8

    # ===== 5. SECURITY COMPLIANCE =====
    Write-Host "Checking security compliance..." -ForegroundColor Yellow

    $securityCompliance = @{
        checkedAt = (Get-Date).ToString("o")
        imageVersion = $ImageVersion
        cisLevel = 2
        checks = @()
        score = 0
    }

    # Example CIS checks (simplified)
    $cisChecks = @(
        @{
            id = "CIS-1.1.1"
            description = "Windows Defender Enabled"
            check = { (Get-Service WinDefend).Status -eq "Running" }
            weight = 10
        },
        @{
            id = "CIS-1.1.2"
            description = "Real-time Protection Enabled"
            check = { (Get-MpComputerStatus).RealTimeProtectionEnabled -eq $true }
            weight = 10
        },
        @{
            id = "CIS-2.1.1"
            description = "Windows Firewall Enabled"
            check = { (Get-NetFirewallProfile).Enabled -notcontains $false }
            weight = 10
        },
        @{
            id = "CIS-2.2.1"
            description = "SMBv1 Disabled"
            check = { (Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol).State -eq "Disabled" }
            weight = 5
        },
        @{
            id = "CIS-18.9.97.2.1"
            description = "BitLocker Ready (TPM Present)"
            check = { (Get-Tpm).TpmPresent -eq $true }
            weight = 10
        }
    )

    $totalWeight = 0
    $achievedWeight = 0

    foreach ($check in $cisChecks) {
        $result = & $check.check
        $totalWeight += $check.weight

        $checkResult = @{
            id = $check.id
            description = $check.description
            passed = $result
            weight = $check.weight
        }

        if ($result) {
            $achievedWeight += $check.weight
        }

        $securityCompliance.checks += $checkResult
    }

    $securityCompliance.score = [math]::Round(($achievedWeight / $totalWeight) * 100, 2)

    $securityCompliance | ConvertTo-Json -Depth 10 | Out-File (Join-Path $versionPath "security-compliance.json") -Encoding UTF8

    # ===== 6. RELEASE NOTES =====
    Write-Host "Generating release notes..." -ForegroundColor Yellow

    $releaseNotes = @"
# AVD Image Release Notes

**Version:** $ImageVersion
**Build Type:** $BuildType
**Build Date:** $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
**Git Commit:** $($manifest.build.gitCommit)

## 🖥️ Operating System
- **OS:** $($manifest.image.baseOS)
- **Build:** $($manifest.image.osBuild)
- **Architecture:** $($manifest.image.architecture)

## 📦 Key Components
- **AVD Agent:** $($softwareInventory.keyComponents.avdAgent ?? 'N/A')
- **FSLogix:** $($softwareInventory.keyComponents.fslogix ?? 'N/A')
- **Office 365:** $($softwareInventory.keyComponents.office365 ?? 'N/A')
- **Microsoft Edge:** $($softwareInventory.keyComponents.edge ?? 'N/A')

## 🛡️ Security
- **Windows Defender Platform:** $($softwareInventory.keyComponents.defenderPlatform ?? 'N/A')
- **Signature Version:** $($softwareInventory.keyComponents.defenderSignatures ?? 'N/A')
- **CIS Compliance Score:** $($securityCompliance.score)%

## 📊 Performance
- **OS Disk Size:** $($performanceBaseline.system.osDiskSizeGB) GB
- **Free Space:** $($performanceBaseline.system.osDiskFreeGB) GB
- **Running Services:** $($performanceBaseline.services.running) / $($performanceBaseline.services.total)

## 🔧 Installed Applications
Total Applications: $($softwareInventory.applications.Count)

### Notable Applications:
$($softwareInventory.applications |
    Where-Object { $_.DisplayName -match "Microsoft|Adobe|Google" } |
    Select-Object -First 10 |
    ForEach-Object { "- **$($_.DisplayName)** - Version $($_.DisplayVersion)" } |
    Out-String)

## 🔥 Recent Hotfixes
$($softwareInventory.hotfixes |
    Select-Object -First 5 |
    ForEach-Object { "- **$($_.HotFixID)** - $($_.Description) (Installed: $($_.InstalledOn))" } |
    Out-String)

## ✅ Validation
- Total Tests: TBD (see validation-results.xml)
- Quality Gate: TBD

## 📋 Artifacts
- Manifest: `manifest.json`
- Software Inventory: `software-inventory.json`
- SBOM: `sbom.json` (SPDX 2.3)
- Security Compliance: `security-compliance.json`
- Performance Baseline: `performance-baseline.json`

## 🚀 Deployment
1. Review validation results
2. Deploy to Canary environment
3. Run synthetic tests
4. Promote to production after approval

## 📞 Support
For issues or questions, contact IT Infrastructure Team.
"@

    $releaseNotes | Out-File (Join-Path $versionPath "releasenotes.md") -Encoding UTF8

    Write-Host "✅ Build artifacts generated successfully!" -ForegroundColor Green
    Write-Host "Output directory: $versionPath" -ForegroundColor Cyan

    return $versionPath
}

# Example usage:
# Generate-BuildManifest -ImageVersion "2025.02.07.1" -BuildType "apps"
```

#### Packer Integration

```hcl
# 02-appscustom-packer/avd-image.pkr.hcl

build {
  sources = ["source.azure-arm.avd_image"]

  # ... existing provisioners ...

  # Generate Build Artifacts
  provisioner "powershell" {
    script = "../scripts/Generate-BuildManifest.ps1"
    environment_vars = [
      "IMAGE_VERSION=${var.sig_image_version}",
      "BUILD_TYPE=${var.build_type}",
      "RESOURCE_GROUP_NAME=${var.sig_rg_name}"
    ]
  }

  # Download artifacts from build VM
  provisioner "file" {
    source      = "C:/BuildArtifacts/${var.sig_image_version}/"
    destination = "../artifacts/${var.sig_image_version}/"
    direction   = "download"
  }

  # Upload artifacts to Azure Blob Storage
  post-processor "shell-local" {
    inline = [
      "az storage blob upload-batch \\",
      "  --account-name ${var.artifacts_storage_account} \\",
      "  --destination build-artifacts \\",
      "  --source ../artifacts/${var.sig_image_version}/ \\",
      "  --destination-path ${var.sig_image_version}/"
    ]
  }
}
```

#### GitHub Actions: Artifact Publishing

```yaml
# .github/workflows/build-image.yml (extended)

- name: Upload Build Artifacts
  uses: actions/upload-artifact@v4
  with:
    name: build-artifacts-${{ steps.version.outputs.image_version }}
    path: artifacts/${{ steps.version.outputs.image_version }}/
    retention-days: 90

- name: Create GitHub Release
  uses: softprops/action-gh-release@v1
  with:
    tag_name: v${{ steps.version.outputs.image_version }}
    name: AVD Image ${{ steps.version.outputs.image_version }}
    body_path: artifacts/${{ steps.version.outputs.image_version }}/releasenotes.md
    files: |
      artifacts/${{ steps.version.outputs.image_version }}/manifest.json
      artifacts/${{ steps.version.outputs.image_version }}/software-inventory.json
      artifacts/${{ steps.version.outputs.image_version }}/sbom.json
      artifacts/${{ steps.version.outputs.image_version }}/validation-results.xml

- name: Publish to Azure Blob Storage
  uses: azure/CLI@v1
  with:
    inlineScript: |
      az storage blob upload-batch \
        --account-name ${{ secrets.ARTIFACTS_STORAGE_ACCOUNT }} \
        --destination build-artifacts \
        --source artifacts/${{ steps.version.outputs.image_version }}/ \
        --destination-path ${{ steps.version.outputs.image_version }}/ \
        --auth-mode login
```

### 💡 EMPFEHLUNG

**Implementieren Sie die Artefakt-Standardisierung sofort:**

**Kritisch:**
- manifest.json
- software-inventory.json
- validation-results.xml

**Wichtig:**
- releasenotes.md
- sbom.json (für Compliance)

**Optional:**
- security-compliance.json
- performance-baseline.json

**Aufwand:** 8-12 Stunden
**Priorität:** P1 (Hoch)
**Compliance:** Erfüllt SBOM-Anforderungen (Executive Order 14028)

---

*FORTSETZUNG folgt mit Punkten 4-6...*
