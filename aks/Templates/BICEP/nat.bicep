param vnetName string
param vnetAddressPrefix string
param subnetName string
param subnetAddressPrefix string
param natName string
param publicIpName string
param location string = resourceGroup().location

resource publicip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: publicIpName
  location: location
  tags: {
    Department: 'development'
    Application: 'aksPoc'
    Owner: 'engineering'
    OTAP: 'test'
    Service: 'aksCluster'
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnetName
  location: location
  tags: {
    Department: 'development'
    Application: 'aksPoc'
    Owner: 'engineering'
    OTAP: 'test'
    Service: 'aksCluster'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          natGateway: {
            id: natgateway.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource natgateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: natName
  location: location
  sku: {
    name: 'Standard'
  }
  tags: {
    Department: 'development'
    Application: 'aksPoc'
    Owner: 'engineering'
    OTAP: 'test'
    Service: 'aksCluster'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: publicip.id
      }
    ]
  }
}
