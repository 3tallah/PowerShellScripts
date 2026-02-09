// =============================================================================
// Azure Cost Optimization - RBAC Module
// =============================================================================
// This module assigns required RBAC permissions to the Automation Account
// =============================================================================

@description('Principal ID of the Automation Account Managed Identity')
param principalId string

@description('MySQL Resource Group Name for role assignment')
param mysqlResourceGroupName string = ''

@description('VM Resource Group Name for role assignment')
param vmResourceGroupName string = ''

// =============================================================================
// Variables
// =============================================================================

var assignMySQLRole = !empty(mysqlResourceGroupName)
var assignVMRole = !empty(vmResourceGroupName)

// Built-in role definition IDs
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var vmContributorRoleId = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'

// =============================================================================
// MySQL Role Assignment
// =============================================================================

resource mysqlRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignMySQLRole) {
  name: guid(mysqlResourceGroupName, principalId, 'contributor')
  scope: resourceGroup(mysqlResourceGroupName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
    description: 'Allows Automation Account to scale MySQL Flexible Server'
  }
}

// =============================================================================
// VM Role Assignment
// =============================================================================

resource vmRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignVMRole) {
  name: guid(vmResourceGroupName, principalId, 'vm-contributor')
  scope: resourceGroup(vmResourceGroupName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmContributorRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
    description: 'Allows Automation Account to resize VMs'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output mysqlRoleAssigned bool = assignMySQLRole
output vmRoleAssigned bool = assignVMRole
