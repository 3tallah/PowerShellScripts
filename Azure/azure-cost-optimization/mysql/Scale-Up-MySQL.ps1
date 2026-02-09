<#
.SYNOPSIS
    Generic MySQL Flexible Server Scale-Up Runbook
    Scales up Azure Database for MySQL to high-performance tier during business hours
    
.DESCRIPTION
    This runbook automates the scaling up of Azure MySQL Flexible Server to high-performance tier during peak hours.
    Features include:
    - Automatic module management
    - Retry logic with configurable attempts
    - Webhook notifications on failure
    - Managed Identity authentication
    - Comprehensive logging
    
.PARAMETER ResourceGroupName
    Resource group containing the MySQL server
    
.PARAMETER ServerName
    Name of the Azure MySQL Flexible Server
    
.PARAMETER TargetTier
    Target compute tier (e.g., Burstable, GeneralPurpose, MemoryOptimized)
    
.PARAMETER TargetSKU
    Target SKU name (e.g., Standard_D4ads_v5, Standard_D8ads_v5)
    
.PARAMETER BackupRetentionDays
    Number of days to retain backups (default: 7)
    
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
    -ServerName "MyMySQLServer" `
    -TargetTier "GeneralPurpose" `
    -TargetSKU "Standard_D4ads_v5"
    
.EXAMPLE
    # With webhook notifications
    -ResourceGroupName "MyResourceGroup" `
    -ServerName "MyMySQLServer" `
    -TargetTier "MemoryOptimized" `
    -TargetSKU "Standard_E4ads_v5" `
    -WebhookUri "https://example.webhook.office.com/..."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$ServerName,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetTier,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetSKU,
    
    [int]$BackupRetentionDays = 7,
    [int]$MaxRetryAttempts = 3,
    [int]$RetryIntervalSeconds = 60,
    [string]$WebhookUri = "",
    [switch]$UpdateModules = $true
)

# Initialize logging
$startTime = Get-Date
$scriptName = "MySQL Scale-Up"
$operationId = [System.Guid]::NewGuid().ToString().Substring(0, 8)

Write-Output "=== $scriptName Operation [$operationId] ==="
Write-Output "Start Time: $startTime"
Write-Output "Server: $ServerName (Resource Group: $ResourceGroupName)"
Write-Output "Target Configuration: $TargetSKU ($TargetTier)"

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
            serverName = $ServerName
            resourceGroup = $ResourceGroupName
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            targetSku = $TargetSKU
            targetTier = $TargetTier
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

# Function to get current server state
function Get-CurrentServerState {
    param(
        [string]$Name,
        [string]$ResourceGroup
    )
    
    try {
        $server = Get-AzMySqlFlexibleServer -Name $Name -ResourceGroupName $ResourceGroup
        return @{
            Name = $server.Name
            SkuName = $server.Sku.Name
            SkuTier = $server.Sku.Tier
            State = $server.State
            Location = $server.Location
            Version = $server.Version
            FullyQualifiedDomainName = $server.FullyQualifiedDomainName
            Success = $true
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Function to wait for server to reach Ready state
function Wait-ForServerState {
    param(
        [string]$Name,
        [string]$ResourceGroup,
        [string]$DesiredState = "Ready",
        [int]$MaxAttempts = 40,
        [int]$IntervalSeconds = 15
    )
    
    $attempt = 0
    
    do {
        Start-Sleep -Seconds $IntervalSeconds
        $server = Get-AzMySqlFlexibleServer -Name $Name -ResourceGroupName $ResourceGroup
        $attempt++
        
        Write-Output "   [$attempt/$MaxAttempts] State: $($server.State)"
        
        if ($server.State -eq $DesiredState) {
            return @{
                Success = $true
                State = $server.State
                SkuName = $server.Sku.Name
                SkuTier = $server.Sku.Tier
                Attempts = $attempt
            }
        }
    } while ($attempt -lt $MaxAttempts)
    
    return @{
        Success = $false
        State = $server.State
        Attempts = $attempt
    }
}

# Main execution
try {
    # Install/Update required modules
    Write-Output "`n📦 Checking required modules..."
    $requiredModules = @("Az.MySql", "Az.Accounts", "Az.Resources")
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
            $currentState = Get-CurrentServerState -Name $ServerName -ResourceGroup $ResourceGroupName
            
            if (-not $currentState.Success) {
                throw "Failed to retrieve server state: $($currentState.Error)"
            }
            
            Write-Output "Current Configuration:"
            Write-Output "   SKU: $($currentState.SkuName)"
            Write-Output "   Tier: $($currentState.SkuTier)"
            Write-Output "   State: $($currentState.State)"
            Write-Output "   Location: $($currentState.Location)"
            
            # Check if already at target
            if ($currentState.SkuName -eq $TargetSKU) {
                Write-Output "`n⚠️ Server already at target SKU ($TargetSKU). No action needed."
                $success = $true
                break
            }
            
            # Validate current state allows scaling
            if ($currentState.State -ne "Ready") {
                throw "Server is not in 'Ready' state (current: $($currentState.State)). Cannot scale."
            }
            
            # Perform scale operation
            Write-Output "`n⬆️  Initiating scale-up to $TargetSKU ($TargetTier)..."
            
            $updateParams = @{
                Name = $ServerName
                ResourceGroupName = $ResourceGroupName
                Sku = $TargetSKU
                SkuTier = $TargetTier
                BackupRetentionDay = $BackupRetentionDays
            }
            
            Update-AzMySqlFlexibleServer @updateParams | Out-Null
            
            # Wait for completion
            Write-Output "`n⏳ Waiting for scaling operation to complete..."
            $waitResult = Wait-ForServerState -Name $ServerName -ResourceGroup $ResourceGroupName
            
            if ($waitResult.Success) {
                $duration = (Get-Date) - $startTime
                
                Write-Output "`n✅ Scale-up completed successfully!"
                Write-Output "   New SKU: $($waitResult.SkuName)"
                Write-Output "   New Tier: $($waitResult.SkuTier)"
                Write-Output "   Final State: $($waitResult.State)"
                Write-Output "   Wait Attempts: $($waitResult.Attempts)"
                Write-Output "   Total Duration: $($duration.ToString('mm\:ss'))"
                
                # Performance note
                $performanceNote = "High-performance tier active - optimized for peak workloads"
                Write-Output "   🚀 $performanceNote"
                
                Send-Notification -Status "Success" -Message "Scale-up completed" `
                    -Details "Scaled to $($waitResult.SkuName) in $($duration.ToString('mm\:ss'))"
                
                $success = $true
            } else {
                throw "Server did not reach Ready state after $($waitResult.Attempts) attempts. Final state: $($waitResult.State)"
            }
            
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
