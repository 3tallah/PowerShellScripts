# MySQL Flexible Server Auto-Scaling Scripts

This folder contains PowerShell runbooks for automatically scaling Azure Database for MySQL Flexible Server to optimize costs.

## Scripts

| Script | Purpose | Typical Schedule |
|--------|---------|------------------|
| `Scale-Up-MySQL.ps1` | Scale to high-performance tier | Business hours (e.g., 7 AM) |
| `Scale-Down-MySQL.ps1` | Scale to cost-optimized tier | Off-hours (e.g., 7 PM) |

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `ResourceGroupName` | ✅ | - | Resource group containing the MySQL server |
| `ServerName` | ✅ | - | Name of the Azure MySQL Flexible Server |
| `TargetTier` | ✅ | - | Target compute tier (Burstable, GeneralPurpose, MemoryOptimized) |
| `TargetSKU` | ✅ | - | Target SKU name (e.g., Standard_B2s, Standard_D4ads_v5) |
| `BackupRetentionDays` | ❌ | 7 | Number of days to retain backups |
| `MaxRetryAttempts` | ❌ | 3 | Maximum retry attempts on failure |
| `RetryIntervalSeconds` | ❌ | 60 | Seconds between retry attempts |
| `WebhookUri` | ❌ | "" | Webhook URI for notifications |
| `UpdateModules` | ❌ | $true | Check for module updates |

## Available SKUs

### Burstable Tier (Cost-Optimized)
- `Standard_B1s` - 1 vCore, 1 GB RAM
- `Standard_B1ms` - 1 vCore, 2 GB RAM
- `Standard_B2s` - 2 vCores, 4 GB RAM
- `Standard_B2ms` - 2 vCores, 8 GB RAM

### General Purpose Tier (Balanced)
- `Standard_D2ads_v5` - 2 vCores, 8 GB RAM
- `Standard_D4ads_v5` - 4 vCores, 16 GB RAM
- `Standard_D8ads_v5` - 8 vCores, 32 GB RAM
- `Standard_D16ads_v5` - 16 vCores, 64 GB RAM

### Memory Optimized Tier (High Performance)
- `Standard_E2ads_v5` - 2 vCores, 16 GB RAM
- `Standard_E4ads_v5` - 4 vCores, 32 GB RAM
- `Standard_E8ads_v5` - 8 vCores, 64 GB RAM
- `Standard_E16ads_v5` - 16 vCores, 128 GB RAM

## Usage Examples

### Scale Down (Off-Hours)
```powershell
.\Scale-Down-MySQL.ps1 `
    -ResourceGroupName "MyResourceGroup" `
    -ServerName "my-mysql-server" `
    -TargetTier "Burstable" `
    -TargetSKU "Standard_B2s"
```

### Scale Up (Business Hours)
```powershell
.\Scale-Up-MySQL.ps1 `
    -ResourceGroupName "MyResourceGroup" `
    -ServerName "my-mysql-server" `
    -TargetTier "GeneralPurpose" `
    -TargetSKU "Standard_D4ads_v5"
```

### With Webhook Notifications
```powershell
.\Scale-Down-MySQL.ps1 `
    -ResourceGroupName "MyResourceGroup" `
    -ServerName "my-mysql-server" `
    -TargetTier "Burstable" `
    -TargetSKU "Standard_B2s" `
    -WebhookUri "https://prod-webhook.azure.com/..."
```

## Prerequisites

1. **Azure Automation Account** with System-Assigned Managed Identity
2. **RBAC Permissions**: Managed Identity needs `Contributor` role on the MySQL server
3. **PowerShell Modules**: Az.MySql, Az.Accounts, Az.Resources (auto-installed)

## Deployment

See the [deployment folder](../deployment/) for deployment scripts and Bicep templates.

## Cost Savings Estimation

| Scenario | Peak SKU | Off-Peak SKU | Estimated Savings |
|----------|----------|--------------|-------------------|
| Standard | Standard_D4ads_v5 | Standard_B2s | ~60-70% during off-hours |
| High Load | Standard_D8ads_v5 | Standard_B2ms | ~65-75% during off-hours |
| Memory Intensive | Standard_E4ads_v5 | Standard_B2s | ~70-80% during off-hours |

> **Note**: Actual savings depend on your usage patterns and region pricing.

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Ensure Managed Identity is enabled on Automation Account
   - Verify RBAC permissions on the MySQL server

2. **Server Not in Ready State**
   - Wait for any pending operations to complete
   - Check Azure Portal for server status

3. **Module Installation Failed**
   - Check network connectivity from Automation Account
   - Verify PSGallery is accessible

### Logs

All operations are logged with:
- Unique Operation ID for tracking
- Timestamps for each action
- Detailed error messages with stack traces
