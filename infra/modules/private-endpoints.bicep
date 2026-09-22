param location string
param name string
param tags object
param subnetId string
@description('Full ARM ID of an existing resource; this module never declares that service.')
param targetResourceId string
@allowed(['iotHub', 'namespace', 'sites', 'signalr'])
param groupId string
@minLength(1)
param zoneIds array

resource endpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [{
      name: name
      properties: {
        privateLinkServiceId: targetResourceId
        groupIds: [groupId]
      }
    }]
  }
}

resource group 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: endpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [for (zoneId, i) in zoneIds: {
      name: 'zone-${i}'
      properties: { privateDnsZoneId: zoneId }
    }]
  }
}
