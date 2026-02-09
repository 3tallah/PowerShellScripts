# Azure VM Auto-Scaling Scripts

This folder contains PowerShell runbooks for automatically scaling Azure Virtual Machines to optimize costs.

## Scripts

| Script | Purpose | Typical Schedule |
|--------|---------|------------------|
| `Scale-Up-VM.ps1` | Scale to high-performance size | Business hours (e.g., 7 AM) |
| `Scale-Down-VM.ps1` | Scale to cost-optimized size | Off-hours (e.g., 7 PM) |

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `ResourceGroupName` | ✅ | - | Resource group containing the VM |
| `VMName` | ✅ | - | Name of the Azure Virtual Machine |
| `TargetSize` | ✅ | - | Target VM size (e.g., Standard_B2s, Standard_D4s_v5) |
| `MaxRetryAttempts` | ❌ | 3 | Maximum retry attempts on failure |
| `RetryIntervalSeconds` | ❌ | 60 | Seconds between retry attempts |
| `WebhookUri` | ❌ | "" | Webhook URI for notifications |
| `UpdateModules` | ❌ | $true | Check for module updates |

## Available VM Sizes

### Burstable Series (B-series) - Cost-Optimized
- `Standard_B1s` - 1 vCPU, 1 GB RAM
- `Standard_B1ms` - 1 vCPU, 2 GB RAM
- `Standard_B2s` - 2 vCPUs, 4 GB RAM
- `Standard_B2ms` - 2 vCPUs, 8 GB RAM
- `Standard_B4ms` - 4 vCPUs, 16 GB RAM

### General Purpose (Dv5-series) - Balanced
- `Standard_D2s_v5` - 2 vCPUs, 8 GB RAM
- `Standard_D4s_v5` - 4 vCPUs, 16 GB RAM
- `Standard_D8s_v5` - 8 vCPUs, 32 GB RAM
- `Standard_D16s_v5` - 16 vCPUs, 64 GB RAM

### General Purpose (Dadsv5-series) - AMD-based
- `Standard_D2ads_v5` - 2 vCPUs, 8 GB RAM
- `Standard_D4ads_v5` - 4 vCPUs, 16 GB RAM
- `Standard_D8ads_v5` - 8 vCPUs, 32 GB RAM

### Memory Optimized (Ev5-series)
- `Standard_E2s_v5` - 2 vCPUs, 16 GB RAM
- `Standard_E4s_v5` - 4 vCPUs, 32 GB RAM
- `Standard_E8s_v5` - 8 vCPUs, 64 GB RAM

## Usage Examples

### Scale Down (Off-Hours)
```powershell
.\Scale-Down-VM.ps1 `
    -ResourceGroupName "MyResourceGroup" `
    -VMName "my-vm" `
    -TargetSize "Standard_B2s"
```

### Scale Up (Business Hours)
```powershell
.\Scale-Up-VM.ps1 `
    -ResourceGroupName "MyResourceGroup" `
    -VMName "my-vm" `
    -TargetSize "Standard_D4s_v5"
```

### With Webhook Notifications
```powershell
.\Scale-Down-VM.ps1 `
    -ResourceGroupName "MyResourceGroup" `
    -VMName "my-vm" `
    -TargetSize "Standard_B2s" `
    -WebhookUri "https://prod-webhook.azure.com/..."
```

## Prerequisites

1. **Azure Automation Account** with System-Assigned Managed Identity
2. **RBAC Permissions**: Managed Identity needs `Virtual Machine Contributor` role on the VM
3. **PowerShell Modules**: Az.Compute, Az.Accounts, Az.Resources (auto-installed)

## Important Notes

### VM Restart Required
- Resizing a VM requires stopping and restarting it
- The scripts handle this automatically
- If the VM was running, it will be restarted after resize
- If the VM was stopped, it will remain stopped after resize

### Availability Considerations
- There will be a brief downtime during resize (typically 2-5 minutes)
- Schedule scaling during low-traffic periods
- Consider using Azure Load Balancer or Availability Sets for high-availability scenarios

### Size Constraints
- Not all sizes are available in all regions
- Some sizes require specific VM configurations
- Check Azure documentation for size compatibility

## Deployment

See the [deployment folder](../deployment/) for deployment scripts and Bicep templates.

## Cost Savings Estimation

| Scenario | Peak Size | Off-Peak Size | Estimated Savings |
|----------|-----------|---------------|-------------------|
| Standard | Standard_D4s_v5 | Standard_B2s | ~60-70% during off-hours |
| High Load | Standard_D8s_v5 | Standard_B2ms | ~65-75% during off-hours |
| Memory Intensive | Standard_E4s_v5 | Standard_B2s | ~70-80% during off-hours |

> **Note**: Actual savings depend on your usage patterns and region pricing.

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Ensure Managed Identity is enabled on Automation Account
   - Verify RBAC permissions on the VM

2. **VM Failed to Stop/Start**
   - Check if there are any pending operations on the VM
   - Verify the VM is not in a failed state

3. **Size Not Available**
   - The target size may not be available in your region
   - Check available sizes: `Get-AzVMSize -Location "your-location"`

4. **Module Installation Failed**
   - Check network connectivity from Automation Account
   - Verify PSGallery is accessible

### Logs

All operations are logged with:
- Unique Operation ID for tracking
- Timestamps for each action
- Detailed error messages with stack traces
