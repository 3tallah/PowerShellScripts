<#
.SYNOPSIS
    Azure Cost Optimization - Deployment Script (PowerShell)
    
.DESCRIPTION
    This script deploys the auto-scaling runbooks to Azure Automation Account
    
.PARAMETER AutomationAccountName
    Name of the Azure Automation Account
    
.PARAMETER ResourceGroupName
    Resource group for the Automation Account
    
.PARAMETER Location
    Azure region for resources
    
.PARAMETER MySQLResourceGroupName
    Resource group containing the MySQL server
    
.PARAMETER MySQLServerName
    Name of the MySQL server
    
.PARAMETER VMResourceGroupName
    Resource group containing the VM
    
.PARAMETER VMName
    Name of the VM
    
.PARAMETER ScaleUpTime
    Time to scale up (HH:mm format, UTC)
    
.PARAMETER ScaleDownTime
    Time to scale down (HH:mm format, UTC)
    
.PARAMETER WebhookUri
    Optional webhook URI for notifications
    
.EXAMPLE
    .\deploy-ps.ps1 `
        -AutomationAccountName "MyAutomation" `
        -ResourceGroupName "MyRG" `
        -Location "eastus" `
        -MySQLResourceGroupName "MySQL-RG" `
        -MySQLServerName "my-mysql" `
        -VMResourceGroupName "VM-RG" `
        -VMName "my-vm"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$MySQLResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$MySQLServerName,
    
    [Parameter(Mandatory = $false)]
    [string]$MySQLScaleUpSKU = "Standard_D4ads_v5",
    
    [Parameter(Mandatory = $false)]
    [string]$MySQLScaleUpTier = "GeneralPurpose",
    
    [Parameter(Mandatory = $false)]
    [string]$MySQLScaleDownSKU = "Standard_B2s",
    
    [Parameter(Mandatory = $false)]
    [string]$MySQLScaleDownTier = "Burstable",
    
    [Parameter(Mandatory = $false)]
    [string]$VMResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [string]$VMScaleUpSize = "Standard_D4s_v5",
    
    [Parameter(Mandatory = $false)]
    [string]$VMScaleDownSize = "Standard_B2s",
    
    [Parameter(Mandatory = $false)]
    [string]$ScaleUpTime = "07:00",
    
    [Parameter(Mandatory = $false)]
    [string]$ScaleDownTime = "19:00",
    
    [Parameter(Mandatory = $false)]
    [string]$TimeZone = "UTC",
    
    [Parameter(Mandatory = $false)]
    [string]$WebhookUri = ""
)

# =============================================================================
# Configuration
# =============================================================================

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# =============================================================================
# Functions
# =============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
    }
    
    Write-Host "[$Level] $timestamp - $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check Azure PowerShell module
    if (-not (Get-Module -ListAvailable -Name Az.Automation)) {
        throw "Az.Automation module is not installed. Please install it with: Install-Module -Name Az -Scope CurrentUser"
    }
    
    # Check if logged in
    try {
        $context = Get-AzContext
        if (-not $context) {
            throw "Not logged in to Azure"
        }
        Write-Log "Logged in as: $($context.Account.Id)" -Level "SUCCESS"
        Write-Log "Subscription: $($context.Subscription.Name)"
    } catch {
        throw "Not logged in to Azure. Please run 'Connect-AzAccount' first."
    }
    
    Write-Log "Prerequisites check passed" -Level "SUCCESS"
}

function New-AutomationAccountIfNotExists {
    Write-Log "Creating/verifying Automation Account: $AutomationAccountName"
    
    $account = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction SilentlyContinue
    
    if (-not $account) {
        # Ensure resource group exists
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-Log "Creating resource group: $ResourceGroupName"
            New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
        }
        
        # Create Automation Account
        New-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -Location $Location -Plan Basic | Out-Null
        Write-Log "Automation Account created" -Level "SUCCESS"
    } else {
        Write-Log "Automation Account already exists"
    }
    
    # Enable System-Assigned Managed Identity
    Write-Log "Enabling System-Assigned Managed Identity..."
    Set-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -AssignSystemIdentity | Out-Null
    Write-Log "Managed Identity enabled" -Level "SUCCESS"
}

function New-Runbook {
    param(
        [string]$RunbookName,
        [string]$ScriptPath
    )
    
    Write-Log "Creating runbook: $RunbookName"
    
    # Check if runbook exists
    $existing = Get-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $RunbookName -ErrorAction SilentlyContinue
    
    if ($existing) {
        Write-Log "Runbook already exists, updating..."
        Remove-AzAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $RunbookName -Force | Out-Null
    }
    
    # Import runbook
    Import-AzAutomationRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $RunbookName `
        -Path $ScriptPath `
        -Type PowerShell `
        -Published | Out-Null
    
    Write-Log "Runbook $RunbookName created and published" -Level "SUCCESS"
}

function New-Schedule {
    param(
        [string]$ScheduleName,
        [string]$StartTime
    )
    
    Write-Log "Creating schedule: $ScheduleName"
    
    # Check if schedule exists
    $existing = Get-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $ScheduleName -ErrorAction SilentlyContinue
    
    if ($existing) {
        Write-Log "Schedule already exists, removing..."
        Remove-AzAutomationSchedule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $ScheduleName -Force | Out-Null
    }
    
    # Calculate start date (tomorrow at specified time)
    $time = [DateTime]::ParseExact($StartTime, "HH:mm", $null)
    $startDate = (Get-Date).Date.AddDays(1).Add($time.TimeOfDay)
    
    # Create schedule
    New-AzAutomationSchedule `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $ScheduleName `
        -StartTime $startDate `
        -DayInterval 1 `
        -TimeZone $TimeZone | Out-Null
    
    Write-Log "Schedule $ScheduleName created" -Level "SUCCESS"
}

function Register-RunbookSchedule {
    param(
        [string]$RunbookName,
        [string]$ScheduleName,
        [hashtable]$Parameters
    )
    
    Write-Log "Linking schedule $ScheduleName to runbook $RunbookName"
    
    # Unregister existing if any
    $existing = Get-AzAutomationScheduledRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -RunbookName $RunbookName `
        -ScheduleName $ScheduleName `
        -ErrorAction SilentlyContinue
    
    if ($existing) {
        Unregister-AzAutomationScheduledRunbook `
            -ResourceGroupName $ResourceGroupName `
            -AutomationAccountName $AutomationAccountName `
            -RunbookName $RunbookName `
            -ScheduleName $ScheduleName `
            -Force | Out-Null
    }
    
    # Register runbook with schedule
    Register-AzAutomationScheduledRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -RunbookName $RunbookName `
        -ScheduleName $ScheduleName `
        -Parameters $Parameters | Out-Null
    
    Write-Log "Schedule linked to runbook" -Level "SUCCESS"
}

function Set-RbacPermissions {
    Write-Log "Assigning RBAC permissions..."
    
    # Get Managed Identity Principal ID
    $account = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
    $principalId = $account.Identity.PrincipalId
    
    if (-not $principalId) {
        Write-Log "Could not get Managed Identity Principal ID" -Level "ERROR"
        return
    }
    
    Write-Log "Principal ID: $principalId"
    $subscriptionId = (Get-AzContext).Subscription.Id
    
    # Assign permissions for MySQL
    if ($MySQLResourceGroupName) {
        Write-Log "Assigning Contributor role on MySQL resource group..."
        $scope = "/subscriptions/$subscriptionId/resourceGroups/$MySQLResourceGroupName"
        
        try {
            New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Contributor" -Scope $scope -ErrorAction Stop | Out-Null
            Write-Log "Role assignment created for MySQL" -Level "SUCCESS"
        } catch {
            if ($_.Exception.Message -like "*already exists*") {
                Write-Log "Role assignment already exists for MySQL"
            } else {
                Write-Log "Failed to assign role: $($_.Exception.Message)" -Level "WARNING"
            }
        }
    }
    
    # Assign permissions for VM
    if ($VMResourceGroupName) {
        Write-Log "Assigning Virtual Machine Contributor role on VM resource group..."
        $scope = "/subscriptions/$subscriptionId/resourceGroups/$VMResourceGroupName"
        
        try {
            New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Virtual Machine Contributor" -Scope $scope -ErrorAction Stop | Out-Null
            Write-Log "Role assignment created for VM" -Level "SUCCESS"
        } catch {
            if ($_.Exception.Message -like "*already exists*") {
                Write-Log "Role assignment already exists for VM"
            } else {
                Write-Log "Failed to assign role: $($_.Exception.Message)" -Level "WARNING"
            }
        }
    }
}

# =============================================================================
# Main Deployment
# =============================================================================

try {
    Write-Log "Starting Azure Cost Optimization deployment..."
    Write-Log "=========================================="
    
    Test-Prerequisites
    New-AutomationAccountIfNotExists
    
    # Deploy MySQL runbooks if configured
    if ($MySQLResourceGroupName -and $MySQLServerName) {
        Write-Log "Deploying MySQL scaling runbooks..."
        
        New-Runbook -RunbookName "MySQL-ScaleUp" -ScriptPath "$scriptDir\..\mysql\Scale-Up-MySQL.ps1"
        New-Runbook -RunbookName "MySQL-ScaleDown" -ScriptPath "$scriptDir\..\mysql\Scale-Down-MySQL.ps1"
    }
    
    # Deploy VM runbooks if configured
    if ($VMResourceGroupName -and $VMName) {
        Write-Log "Deploying VM scaling runbooks..."
        
        New-Runbook -RunbookName "VM-ScaleUp" -ScriptPath "$scriptDir\..\vm\Scale-Up-VM.ps1"
        New-Runbook -RunbookName "VM-ScaleDown" -ScriptPath "$scriptDir\..\vm\Scale-Down-VM.ps1"
    }
    
    # Create schedules
    Write-Log "Creating schedules..."
    New-Schedule -ScheduleName "Daily-ScaleUp" -StartTime $ScaleUpTime
    New-Schedule -ScheduleName "Daily-ScaleDown" -StartTime $ScaleDownTime
    
    # Link MySQL runbooks to schedules
    if ($MySQLResourceGroupName -and $MySQLServerName) {
        Write-Log "Linking MySQL runbooks to schedules..."
        
        $mysqlScaleUpParams = @{
            ResourceGroupName = $MySQLResourceGroupName
            ServerName = $MySQLServerName
            TargetTier = $MySQLScaleUpTier
            TargetSKU = $MySQLScaleUpSKU
        }
        if ($WebhookUri) { $mysqlScaleUpParams["WebhookUri"] = $WebhookUri }
        
        $mysqlScaleDownParams = @{
            ResourceGroupName = $MySQLResourceGroupName
            ServerName = $MySQLServerName
            TargetTier = $MySQLScaleDownTier
            TargetSKU = $MySQLScaleDownSKU
        }
        if ($WebhookUri) { $mysqlScaleDownParams["WebhookUri"] = $WebhookUri }
        
        Register-RunbookSchedule -RunbookName "MySQL-ScaleUp" -ScheduleName "Daily-ScaleUp" -Parameters $mysqlScaleUpParams
        Register-RunbookSchedule -RunbookName "MySQL-ScaleDown" -ScheduleName "Daily-ScaleDown" -Parameters $mysqlScaleDownParams
    }
    
    # Link VM runbooks to schedules
    if ($VMResourceGroupName -and $VMName) {
        Write-Log "Linking VM runbooks to schedules..."
        
        $vmScaleUpParams = @{
            ResourceGroupName = $VMResourceGroupName
            VMName = $VMName
            TargetSize = $VMScaleUpSize
        }
        if ($WebhookUri) { $vmScaleUpParams["WebhookUri"] = $WebhookUri }
        
        $vmScaleDownParams = @{
            ResourceGroupName = $VMResourceGroupName
            VMName = $VMName
            TargetSize = $VMScaleDownSize
        }
        if ($WebhookUri) { $vmScaleDownParams["WebhookUri"] = $WebhookUri }
        
        Register-RunbookSchedule -RunbookName "VM-ScaleUp" -ScheduleName "Daily-ScaleUp" -Parameters $vmScaleUpParams
        Register-RunbookSchedule -RunbookName "VM-ScaleDown" -ScheduleName "Daily-ScaleDown" -Parameters $vmScaleDownParams
    }
    
    # Assign RBAC permissions
    Set-RbacPermissions
    
    Write-Log "=========================================="
    Write-Log "Deployment completed successfully!" -Level "SUCCESS"
    Write-Log ""
    Write-Log "Deployed resources:"
    Write-Log "  - Automation Account: $AutomationAccountName"
    if ($MySQLServerName) {
        Write-Log "  - Runbooks: MySQL-ScaleUp, MySQL-ScaleDown"
    }
    if ($VMName) {
        Write-Log "  - Runbooks: VM-ScaleUp, VM-ScaleDown"
    }
    Write-Log "  - Schedules: Daily-ScaleUp ($ScaleUpTime), Daily-ScaleDown ($ScaleDownTime)"
    Write-Log ""
    Write-Log "Next steps:"
    Write-Log "  1. Verify RBAC permissions in Azure Portal"
    Write-Log "  2. Test runbooks manually before relying on schedules"
    Write-Log "  3. Monitor job execution in Automation Account"
    
} catch {
    Write-Log "Deployment failed: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
