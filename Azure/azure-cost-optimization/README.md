# Azure Cost Optimization: Automated Workload Scaling

[![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat&logo=powershell&logoColor=white)](https://docs.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Production-ready automation scripts to reduce Azure costs by 40-60% through intelligent VM and Database scaling.**

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Deployment](#-deployment)
- [Configuration](#-configuration)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

This repository contains Azure Automation runbooks that automatically scale your Virtual Machines and Azure Database for MySQL Flexible Server based on scheduled times. Perfect for workloads with predictable usage patterns (e.g., business hours vs. off-hours).

### Supported Services

| Service | Scale Type | Savings |
|---------|-----------|---------|
| Azure VMs | Resize (SKU change) | ~40-50% |
| Azure MySQL Flexible Server | Tier/Sku change | ~40-50% |

### Key Features

- ✅ **Zero-downtime scaling** for most operations
- ✅ **Managed Identity** authentication (no credentials in code)
- ✅ **Retry logic** with configurable attempts
- ✅ **Webhook notifications** for failures
- ✅ **Idempotent operations** (safe to re-run)
- ✅ **Comprehensive logging** for audit trails
- ✅ **Generic scripts** (not tied to specific resources)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│     Azure Automation Account            │
│  ├─ Scale-Up Runbook   (Scheduled)     │
│  ├─ Scale-Down Runbook (Scheduled)     │
│  └─ System-Assigned Managed Identity    │
└─────────────────────────────────────────┘
                    │
    ┌───────────────┴───────────────┐
    ▼                               ▼
┌─────────┐                   ┌──────────┐
│   VM    │                   │  MySQL   │
│ Resize  │                   │  Resize  │
│D2↔D16v7 │                   │D2↔D8ads  │
└─────────┘                   └──────────┘
```

### Scaling Schedule Example

| Time | Action | VM Size | MySQL Tier |
|------|--------|---------|-----------|
| 10:00 AM | Scale Up | D16s_v7 (16 vCPU, 64GB) | D8ads_v5 (8 vCPU, 32GB) |
| 01:00 AM | Scale Down | D2s_v7 (2 vCPU, 8GB) | D2ads_v5 (2 vCPU, 8GB) |

---

## 📦 Prerequisites

### Azure Requirements

- [Azure Subscription](https://azure.microsoft.com/free/)
- [Azure Automation Account](https://docs.microsoft.com/azure/automation/)
- Existing Azure VM and/or Azure MySQL Flexible Server
- Appropriate RBAC permissions (Contributor or custom roles)

### Required Azure Modules

The scripts automatically install these modules if missing:

| Module | Purpose |
|--------|---------|
| `Az.Accounts` | Azure authentication |
| `Az.Compute` | VM management |
| `Az.MySql` | MySQL server management |
| `Az.Resources` | Resource management |

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/3tallah/azure-cost-optimization.git
cd azure-cost-optimization
```

### 2. Deploy Infrastructure

Choose your preferred method:

#### Option A: Azure CLI

```bash
# Make script executable
chmod +x deployment/deploy-cli.sh

# Run deployment
./deployment/deploy-cli.sh \
  --resource-group "MyResourceGroup" \
  --automation-account "MyAutomationAccount" \
  --location "francecentral"
```

#### Option B: PowerShell

```powershell
.\deployment\deploy-ps.ps1 `
  -ResourceGroupName "MyResourceGroup" `
  -AutomationAccountName "MyAutomationAccount" `
  -Location "francecentral"
```

#### Option C: Bicep/ARM

```bash
az deployment group create \
  --resource-group "MyResourceGroup" \
  --template-file deployment/bicep/main.bicep \
  --parameters automationAccountName="MyAutomationAccount"
```

### 3. Configure Parameters

Edit the parameter files in `examples/` directory:

```json
{
  "ResourceGroupName": "MyDB-RG",
  "ServerName": "MyMySQLServer",
  "TargetTier": "GeneralPurpose",
  "TargetSKU": "Standard_D2ads_v5",
  "WebhookUri": "https://your-webhook-url"
}
```

### 4. Link Schedules

```bash
# Scale-Up: Daily at 10:00 AM
az automation schedule runbook-link create \
  --automation-account-name "MyAutomationAccount" \
  --resource-group "MyResourceGroup" \
  --schedule-name "Daily-10AM" \
  --runbook-name "Scale-Up-MySQL" \
  --parameters @examples/parameters-scale-up.json

# Scale-Down: Daily at 01:00 AM
az automation schedule runbook-link create \
  --automation-account-name "MyAutomationAccount" \
  --resource-group "MyResourceGroup" \
  --schedule-name "Daily-1AM" \
  --runbook-name "Scale-Down-MySQL" \
  --parameters @examples/parameters-scale-down.json
```

---

## 📁 Repository Structure

```
azure-cost-optimization/
├── 📁 mysql/                          # MySQL scaling runbooks
│   ├── Scale-Up-MySQL.ps1            # Scale up to high-performance tier
│   ├── Scale-Down-MySQL.ps1          # Scale down to cost-optimized tier
│   └── README.md                     # MySQL-specific documentation
│
├── 📁 vm/                             # VM scaling runbooks
│   ├── Scale-Up-VM.ps1               # Scale up VM size
│   ├── Scale-Down-VM.ps1             # Scale down VM size
│   └── README.md                     # VM-specific documentation
│
├── 📁 deployment/                     # Deployment scripts
│   ├── deploy-cli.sh                 # Azure CLI deployment
│   ├── deploy-ps.ps1                 # PowerShell deployment
│   └── bicep/                        # Infrastructure as Code
│       ├── main.bicep
│       └── rbac.bicep
│
├── 📁 examples/                       # Example configurations
│   ├── parameters-dev.json
│   ├── parameters-prod.json
│   └── schedules.json
│
├── LICENSE
├── CONTRIBUTING.md
└── README.md                          # This file
```

---

## ⚙️ Configuration

### Required Parameters

#### MySQL Scaling

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ResourceGroupName` | string | ✅ | Resource group containing MySQL server |
| `ServerName` | string | ✅ | Name of Azure MySQL Flexible Server |
| `TargetTier` | string | ✅ | Target compute tier (Burstable/GeneralPurpose/MemoryOptimized) |
| `TargetSKU` | string | ✅ | Target SKU name (e.g., Standard_D2ads_v5) |
| `BackupRetentionDays` | int | ❌ | Backup retention period (default: 7) |
| `MaxRetryAttempts` | int | ❌ | Max retry attempts (default: 3) |
| `WebhookUri` | string | ❌ | Webhook URL for failure notifications |

#### VM Scaling

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ResourceGroupName` | string | ✅ | Resource group containing VM |
| `VMName` | string | ✅ | Name of Azure VM |
| `TargetSize` | string | ✅ | Target VM size (e.g., Standard_D16s_v7) |
| `MaxRetryAttempts` | int | ❌ | Max retry attempts (default: 3) |
| `WebhookUri` | string | ❌ | Webhook URL for failure notifications |

### Time Zone Configuration

Scripts support any IANA time zone. Common examples:

| Location | Time Zone |
|----------|-----------|
| Paris, France | `Europe/Paris` |
| Cairo, Egypt | `Africa/Cairo` or `Egypt Standard Time` |
| Dubai, UAE | `Asia/Dubai` |
| New York, USA | `America/New_York` |
| London, UK | `Europe/London` |

---

## 📊 Monitoring

### View Job Status

```bash
# List recent jobs
az automation job list \
  --automation-account-name "MyAutomationAccount" \
  --resource-group "MyResourceGroup" \
  --query "[?startTime > '$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)']" \
  -o table
```

### View Job Output

```bash
# Get job output
az automation job stream list \
  --automation-account-name "MyAutomationAccount" \
  --resource-group "MyResourceGroup" \
  --job-id "00000000-0000-0000-0000-000000000000" \
  -o table
```

### Azure Monitor Integration

Enable diagnostic settings to send logs to:
- Log Analytics Workspace
- Azure Storage Account
- Azure Event Hub

```bash
az monitor diagnostic-settings create \
  --name "AutomationLogs" \
  --resource "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Automation/automationAccounts/{aa}" \
  --workspace "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{ws}" \
  --logs '[{"category": "JobLogs", "enabled": true}]'
```

---

## 🐛 Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Module not found` | Az.MySql not installed | Wait for module import or install manually |
| `Authentication failed` | Managed Identity not enabled | Enable System-Assigned Managed Identity |
| `Authorization failed` | Missing RBAC | Assign VM Contributor / MySQL Contributor roles |
| `Server not in Ready state` | Previous operation in progress | Wait and retry |
| `Webhook notification failed` | Invalid webhook URL | Verify URL and network connectivity |

### Debug Mode

Run runbook with verbose logging:

```powershell
# In Azure Portal: Test Pane
-VerbosePreference "Continue"
-DebugPreference "Continue"
```

### Support

- 📖 [Documentation](docs/TROUBLESHOOTING.md)
- 🐛 [Issue Tracker](../../issues)
- 💬 [Discussions](../../discussions)

---

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest features
- 📖 Improve documentation
- 🔧 Submit pull requests

### Development Setup

```bash
# Fork and clone
git clone https://github.com/YOUR-USERNAME/azure-cost-optimization.git

# Create branch
git checkout -b feature/my-feature

# Make changes and commit
git commit -m "Add: my feature"

# Push and create PR
git push origin feature/my-feature
```

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

---

## 🙏 Acknowledgments

- [Azure Automation Team](https://docs.microsoft.com/azure/automation/)
- [PowerShell Community](https://powershell.org/)
- Contributors and testers

---

## 📬 Contact

- **Author:** [Mahmoud Atallah](https://www.3tallah.com)
- **LinkedIn:** [linkedin.com/in/mahmoudatallah](https://linkedin.com/in/mahmoudatallah)
- **Twitter/X:** [@Mahmoud_Atallah](https://twitter.com/Mahmoud_Atallah)

---

**If this project helped you save on Azure costs, please ⭐ star the repo and share your experience!**
