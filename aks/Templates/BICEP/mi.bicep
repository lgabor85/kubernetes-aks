param managedIdentityName string
param vnetName string
param subnetName string
param roleDefinitionIds array
param location string = resourceGroup().location

var roleAssignmentsToCreate = [
  for roleDefinitionId in roleDefinitionIds: {
    name: guid(managedIdentity.id, resourceGroup().id, roleDefinitionId, subnet.id)
    roleDefinitionId: roleDefinitionId
  }
]

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
  tags: {
    Department: 'engineering'
    Application: 'aksPoc'
    Owner: 'development'
    OTAP: 'test'
    Service: 'aksCluster'
  }
}
resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  parent: vnet
  name: subnetName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [
  for roleAssignmentToCreate in roleAssignmentsToCreate: {
    name: roleAssignmentToCreate.name
    scope: subnet
    properties: {
      principalId: managedIdentity.properties.principalId
      roleDefinitionId: subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        roleAssignmentToCreate.roleDefinitionId
      )
      principalType: 'ServicePrincipal' // See https://docs.microsoft.com/azure/role-based-access-control/role-assignments-template#new-service-principal to understand why this property is included.
    }
  }
]

@description('The resource ID of the user-assigned managed identity.')
output managedIdentityResourceId string = managedIdentity.id

@description('The ID of the Azure AD application associated with the managed identity.')
output managedIdentityClientId string = managedIdentity.properties.clientId

@description('The ID of the Azure AD service principal associated with the managed identity.')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
