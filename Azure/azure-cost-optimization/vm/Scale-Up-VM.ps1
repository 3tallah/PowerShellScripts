<#
.SYNOPSIS
    Generic Azure VM Scale-Up Runbook
    Scales up Azure Virtual Machines to high-performance size during business hours
    
.DESCRIPTION
    This runbook automates the scaling up of Azure VMs to high-performance size during peak hours.
    Features include:
    - Automatic module management
    - Retry logic with configurable attempts
    - Webhook notifications on failure
    - Managed Identity authentication
    - Comprehensive logging
    - Graceful VM restart handling
    
.PARAMETER ResourceGroupName
    Resource group containing the VM
    
.PARAMETER VMName
    Name of the Azure Virtual Machine
    
.PARAMETER TargetSize
    Target VM size (e.g., Standard_D4s_v5, Standard_D8s_v5)
    
.PARAMETER MaxRetryAttempts
    Maximum number of retry attempts on failure (default: 3)
    
.PARAMETER RetryIntervalSeconds
    Seconds to wait between retry attempts (default: 60)
    
.PARAMETER WebhookUri
    Optional webhook URI for failure notifications (Action Group, Logic App, Teams, etc.)
    
.PARAMETER UpdateModules
    Whether to check for and install module updates (default: $true)
    
.EXAMPLE
    # Basic usage with required parameters
    -ResourceGroupName "MyResourceGroup" `
    -VMName "MyVM" `
    -TargetSize "Standard_D4s_v5"
    
.EXAMPLE
    # With webhook notifications
    -ResourceGroupName "MyResourceGroup" `
    -VMName "MyVM" `
    -TargetSize "Standard_D8s_v5" `
    -WebhookUri "https://example.webhook.office.com/..."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$VMName,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetSize,
    
    [int]$MaxRetryAttempts = 3,
    [int]$RetryIntervalSeconds = 60,
    [string]$WebhookUri = "",
    [switch]$UpdateModules = $true
)

# Initialize logging
$startTime = Get-Date
$scriptName = "VM Scale-Up"
$operationId = [System.Guid]::NewGuid().ToString().Substring(0, 8)

Write-Output "=== $scriptName Operation [$operationId] ==="
Write-Output "Start Time: $startTime"
Write-Output "VM: $VMName (Resource Group: $ResourceGroupName)"
Write-Output "Target Size: $TargetSize"

# Function to check and install/update required modules
function Install-OrUpdateModules {
    param(
        [string[]]$ModuleNames,
        [bool]$UpdateModules = $true
    )
    
    $installedModules = @()
    
    foreach ($ModuleName in $ModuleNames) {
        try {
            $CurrentModule = Get-Module -Name $ModuleName -ListAvailable | 
                Sort-Object Version -Descending | 
                Select-Object -First 1
            
            if (-not $CurrentModule) {
                Write-Output "Installing $ModuleName module..."
                Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
                Import-Module -Name $ModuleName -Force
                Write-Output "✅ $ModuleName module installed and imported"
            } else {
                Write-Output "✅ $ModuleName module available (v$($CurrentModule.Version))"
                
                if ($UpdateModules) {
                    try {
                        $LatestModule = Find-Module -Name $ModuleName -Repository PSGallery -ErrorAction SilentlyContinue
                        if ($LatestModule -and [version]$LatestModule.Version -gt [version]$CurrentModule.Version) {
                            Write-Output "Updating $ModuleName to v$($LatestModule.Version)..."
                            Update-Module -Name $ModuleName -Force -Scope CurrentUser
                            Import-Module -Name $ModuleName -Force -RequiredVersion $LatestModule.Version
                            Write-Output "✅ Updated to v$($LatestModule.Version)"
                        }
                    } catch {
                        Write-Warning "Could not check for updates to ${ModuleName}: $($_.Exception.Message)"
                    }
                }
                
                Import-Module -Name $ModuleName -Force
            }
            
            $installedModules += $ModuleName
        } catch {
            Write-Error "Failed to install/import $ModuleName : $($_.Exception.Message)"
            throw
        }
    }
    
    return $installedModules
}

# Function to send notification via webhook
function Send-Notification {
    param(
        [string]$Status,
        [string]$Message,
        [string]$Details = "",
        [string]$WebhookUri = $WebhookUri
    )
    
    if ([string]::IsNullOrWhiteSpace($WebhookUri)) {
        Write-Output "No webhook URI configured. Skipping notification."
        return
    }
    
    try {
        $payload = @{
            operationId = $operationId
            scriptName = $scriptName
            status = $Status
            message = $Message
            details = $Details
            vmName = $VMName
            resourceGroup = $ResourceGroupName
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            targetSize = $TargetSize
        }
        
        $jsonPayload = $payload | ConvertTo-Json -Depth 10
        
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        Invoke-RestMethod -Uri $WebhookUri -Method Post -Headers $headers -Body $jsonPayload -ErrorAction Stop | Out-Null
        
        Write-Output "📧 Notification sent: $Status"
    } catch {
        Write-Warning "Failed to send notification: $($_.Exception.Message)"
    }
}

# Function to get current VM state
function Get-CurrentVMState {
    param(
        [string]$Name,
        [string]$ResourceGroup
    )
    
    try {
        $vm = Get-AzVM -Name $Name -ResourceGroupName $ResourceGroup -Status
        $vmInfo = Get-AzVM -Name $Name -ResourceGroupName $ResourceGroup
        
        $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
        
        return @{
            Name = $vmInfo.Name
            Size = $vmInfo.HardwareProfile.VmSize
            Location = $vmInfo.Location
            PowerState = $powerState
            ProvisioningState = ($vm.Statuses | Where-Object { $_.Code -like "ProvisioningState/*" }).DisplayStatus
            Success = $true
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Function to wait for VM to reach desired power state
function Wait-ForVMState {
    param(
        [string]$Name,
        [string]$ResourceGroup,
        [string]$DesiredState = "VM running",
        [int]$MaxAttempts = 40,
        [int]$IntervalSeconds = 15
    )
    
    $attempt = 0
    
    do {
        Start-Sleep -Seconds $IntervalSeconds
        $vm = Get-AzVM -Name $Name -ResourceGroupName $ResourceGroup -Status
        $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
        $attempt++
        
        Write-Output "   [$attempt/$MaxAttempts] Power State: $powerState"
        
        if ($powerState -eq $DesiredState) {
            $vmInfo = Get-AzVM -Name $Name -ResourceGroupName $ResourceGroup
            return @{
                Success = $true
                PowerState = $powerState
                Size = $vmInfo.HardwareProfile.VmSize
                Attempts = $attempt
            }
        }
    } while ($attempt -lt $MaxAttempts)
    
    return @{
        Success = $false
        PowerState = $powerState
        Attempts = $attempt
    }
}

# Main execution
try {
    # Install/Update required modules
    Write-Output "`n📦 Checking required modules..."
    $requiredModules = @("Az.Compute", "Az.Accounts", "Az.Resources")
    Install-OrUpdateModules -ModuleNames $requiredModules -UpdateModules $UpdateModules
    
    # Authenticate
    Write-Output "`n🔐 Authenticating..."
    try {
        $null = Connect-AzAccount -Identity
        $context = Get-AzContext
        Write-Output "✅ Authenticated via Managed Identity"
        Write-Output "   Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
    } catch {
        Write-Error "❌ Authentication failed: $($_.Exception.Message)"
        Send-Notification -Status "Failed" -Message "Authentication failed" -Details $_.Exception.Message
        exit 1
    }
    
    # Main retry loop
    $attempt = 1
    $success = $false
    
    while ($attempt -le $MaxRetryAttempts -and -not $success) {
        Write-Output "`n🔄 Attempt $attempt of $MaxRetryAttempts"
        Write-Output "----------------------------------------------"
        
        try {
            # Get current state
            $currentState = Get-CurrentVMState -Name $VMName -ResourceGroup $ResourceGroupName
            
            if (-not $currentState.Success) {
                throw "Failed to retrieve VM state: $($currentState.Error)"
            }
            
            Write-Output "Current Configuration:"
            Write-Output "   Size: $($currentState.Size)"
            Write-Output "   Power State: $($currentState.PowerState)"
            Write-Output "   Location: $($currentState.Location)"
            
            # Check if already at target size
            if ($currentState.Size -eq $TargetSize) {
                Write-Output "`n⚠️ VM already at target size ($TargetSize). No action needed."
                $success = $true
                break
            }
            
            # Store original power state
            $wasRunning = $currentState.PowerState -eq "VM running"
            
            # Stop VM if running (required for resize)
            if ($wasRunning) {
                Write-Output "`n🛑 Stopping VM for resize operation..."
                Stop-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -Force | Out-Null
                
                # Wait for VM to stop
                $stopResult = Wait-ForVMState -Name $VMName -ResourceGroup $ResourceGroupName -DesiredState "VM deallocated"
                if (-not $stopResult.Success) {
                    throw "VM failed to stop after $($stopResult.Attempts) attempts. Current state: $($stopResult.PowerState)"
                }
                Write-Output "✅ VM stopped successfully"
            }
            
            # Perform resize operation
            Write-Output "`n⬆️  Resizing VM to $TargetSize..."
            
            $vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName
            $vm.HardwareProfile.VmSize = $TargetSize
            Update-AzVM -VM $vm -ResourceGroupName $ResourceGroupName | Out-Null
            
            Write-Output "✅ VM resized successfully"
            
            # Restart VM if it was originally running
            if ($wasRunning) {
                Write-Output "`n▶️  Starting VM..."
                Start-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName | Out-Null
                
                # Wait for VM to start
                $startResult = Wait-ForVMState -Name $VMName -ResourceGroup $ResourceGroupName -DesiredState "VM running"
                if (-not $startResult.Success) {
                    throw "VM failed to start after $($startResult.Attempts) attempts. Current state: $($startResult.PowerState)"
                }
            }
            
            # Get final state
            $finalState = Get-CurrentVMState -Name $VMName -ResourceGroup $ResourceGroupName
            $duration = (Get-Date) - $startTime
            
            Write-Output "`n✅ Scale-up completed successfully!"
            Write-Output "   New Size: $($finalState.Size)"
            Write-Output "   Power State: $($finalState.PowerState)"
            Write-Output "   Total Duration: $($duration.ToString('mm\:ss'))"
            
            # Performance note
            $performanceNote = "High-performance tier active - optimized for peak workloads"
            Write-Output "   🚀 $performanceNote"
            
            Send-Notification -Status "Success" -Message "Scale-up completed" `
                -Details "Resized to $($finalState.Size) in $($duration.ToString('mm\:ss'))"
            
            $success = $true
            
        } catch {
            $errorMessage = $_.Exception.Message
            $errorDetails = "Attempt $attempt failed: $errorMessage`nStack: $($_.ScriptStackTrace)"
            
            Write-Error "❌ $errorMessage"
            
            # Send failure notification
            Send-Notification -Status "Failed" -Message "Scale-up failed on attempt $attempt" -Details $errorMessage
            
            # Retry logic
            if ($attempt -lt $MaxRetryAttempts) {
                Write-Output "`n⏱️  Retrying in $RetryIntervalSeconds seconds..."
                Start-Sleep -Seconds $RetryIntervalSeconds
                $attempt++
            } else {
                Write-Error "❌ All $MaxRetryAttempts attempts exhausted. Operation failed."
                Send-Notification -Status "Failed" -Message "All retry attempts exhausted" -Details $errorMessage
                exit 1
            }
        }
    }
    
    if ($success) {
        Write-Output "`n=== Operation Completed Successfully [$operationId] ==="
        exit 0
    } else {
        Write-Error "`n=== Operation Failed [$operationId] ==="
        exit 1
    }
    
} catch {
    $fatalError = $_.Exception.Message
    Write-Error "❌ Fatal error: $fatalError"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    
    Send-Notification -Status "FatalError" -Message "Script encountered fatal error" -Details $fatalError
    
    exit 1
}
