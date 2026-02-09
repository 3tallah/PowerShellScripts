// =============================================================================
// Azure Cost Optimization - Bicep Deployment Template
// =============================================================================
// This template deploys an Azure Automation Account with auto-scaling runbooks
// =============================================================================

@description('Name of the Azure Automation Account')
param automationAccountName string

@description('Location for the Automation Account')
param location string = resourceGroup().location

@description('MySQL Server Resource Group Name')
param mysqlResourceGroupName string = ''

@description('MySQL Server Name')
param mysqlServerName string = ''

@description('MySQL Scale Up SKU')
param mysqlScaleUpSku string = 'Standard_D4ads_v5'

@description('MySQL Scale Up Tier')
param mysqlScaleUpTier string = 'GeneralPurpose'

@description('MySQL Scale Down SKU')
param mysqlScaleDownSku string = 'Standard_B2s'

@description('MySQL Scale Down Tier')
param mysqlScaleDownTier string = 'Burstable'

@description('VM Resource Group Name')
param vmResourceGroupName string = ''

@description('VM Name')
param vmName string = ''

@description('VM Scale Up Size')
param vmScaleUpSize string = 'Standard_D4s_v5'

@description('VM Scale Down Size')
param vmScaleDownSize string = 'Standard_B2s'

@description('Scale Up Time (HH:mm format, UTC)')
param scaleUpTime string = '07:00'

@description('Scale Down Time (HH:mm format, UTC)')
param scaleDownTime string = '19:00'

@description('Optional Webhook URI for notifications')
param webhookUri string = ''

@description('Tags to apply to resources')
param tags object = {
  Environment: 'Production'
  Purpose: 'CostOptimization'
}

// =============================================================================
// Variables
// =============================================================================

var deployMySQL = !empty(mysqlResourceGroupName) && !empty(mysqlServerName)
var deployVM = !empty(vmResourceGroupName) && !empty(vmName)

// Calculate start times for schedules (tomorrow at specified times)
var baseDate = dateTimeAdd(utcNow('yyyy-MM-dd'), 'P1D')
var scaleUpStartTime = '${baseDate}T${scaleUpTime}:00Z'
var scaleDownStartTime = '${baseDate}T${scaleDownTime}:00Z'

// =============================================================================
// Automation Account
// =============================================================================

resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    publicNetworkAccess: true
  }
}

// =============================================================================
// Schedules
// =============================================================================

resource scaleUpSchedule 'Microsoft.Automation/automationAccounts/schedules@2023-11-01' = {
  parent: automationAccount
  name: 'Daily-ScaleUp'
  properties: {
    startTime: scaleUpStartTime
    frequency: 'Day'
    interval: 1
    timeZone: 'UTC'
    description: 'Daily schedule for scaling up resources during business hours'
  }
}

resource scaleDownSchedule 'Microsoft.Automation/automationAccounts/schedules@2023-11-01' = {
  parent: automationAccount
  name: 'Daily-ScaleDown'
  properties: {
    startTime: scaleDownStartTime
    frequency: 'Day'
    interval: 1
    timeZone: 'UTC'
    description: 'Daily schedule for scaling down resources during off-hours'
  }
}

// =============================================================================
// MySQL Runbooks (conditional)
// =============================================================================

resource mysqlScaleUpRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (deployMySQL) {
  parent: automationAccount
  name: 'MySQL-ScaleUp'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: true
    logVerbose: false
    description: 'Scales up MySQL Flexible Server during business hours'
  }
}

resource mysqlScaleDownRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (deployMySQL) {
  parent: automationAccount
  name: 'MySQL-ScaleDown'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: true
    logVerbose: false
    description: 'Scales down MySQL Flexible Server during off-hours'
  }
}

// =============================================================================
// VM Runbooks (conditional)
// =============================================================================

resource vmScaleUpRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (deployVM) {
  parent: automationAccount
  name: 'VM-ScaleUp'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: true
    logVerbose: false
    description: 'Scales up VM during business hours'
  }
}

resource vmScaleDownRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = if (deployVM) {
  parent: automationAccount
  name: 'VM-ScaleDown'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    logProgress: true
    logVerbose: false
    description: 'Scales down VM during off-hours'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output automationAccountId string = automationAccount.id
output automationAccountName string = automationAccount.name
output principalId string = automationAccount.identity.principalId
output scaleUpScheduleName string = scaleUpSchedule.name
output scaleDownScheduleName string = scaleDownSchedule.name

output mysqlRunbooks object = deployMySQL ? {
  scaleUp: mysqlScaleUpRunbook.name
  scaleDown: mysqlScaleDownRunbook.name
} : {}

output vmRunbooks object = deployVM ? {
  scaleUp: vmScaleUpRunbook.name
  scaleDown: vmScaleDownRunbook.name
} : {}

output deploymentSummary object = {
  automationAccount: automationAccountName
  location: location
  deployedMySQLRunbooks: deployMySQL
  deployedVMRunbooks: deployVM
  scaleUpTime: scaleUpTime
  scaleDownTime: scaleDownTime
}
