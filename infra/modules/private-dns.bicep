param location string
param prefix string
param tags object
param vnetId string
param resolverSubnetId string
param resolverAddress string

var zoneNames = [
  'privatelink.azure-devices.net'
  'privatelink.servicebus.windows.net'
  'privatelink.azurewebsites.net'
  'privatelink.service.signalr.net'
]

resource zones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for zoneName in zoneNames: {
  name: zoneName
  location: 'global'
  tags: tags
}]

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zoneName, i) in zoneNames: {
  parent: zones[i]
  name: '${prefix}-link'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: vnetId } }
}]

resource resolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: '${prefix}-resolver'
  location: location
  tags: tags
  properties: { virtualNetwork: { id: vnetId } }
}

resource inbound 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  parent: resolver
  name: 'inbound'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [{
      privateIpAllocationMethod: 'Static'
      privateIpAddress: resolverAddress
      subnet: { id: resolverSubnetId }
    }]
  }
}

output zoneIds object = toObject(zoneNames, zoneName => zoneName, zoneName => resourceId('Microsoft.Network/privateDnsZones', zoneName))
output inboundAddress string = inbound.properties.ipConfigurations[0].privateIpAddress
