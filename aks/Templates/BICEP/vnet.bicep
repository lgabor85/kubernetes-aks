param location string = resourceGroup().location
param virtualNetworkName string
param virtualNetworkAddressPrefix string
param snetAddressPrefix string
param snetName string
param subnets array = [
  {
    name: snetName
    addressPrefix: snetAddressPrefix
  }
]

var subnetsToCreate = [
  for item in subnets: {
    name: item.name
    properties: {
      addressPrefix: item.addressPrefix
    }
  }
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: virtualNetworkName
  location: location
  tags: {
    Department: 'engineering'
    Application: 'aksPoc'
    Owner: 'development'
    OTAP: 'test'
    Service: 'aksCluster'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: subnetsToCreate
  }
}
