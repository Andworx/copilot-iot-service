param location string
param prefix string
param tags object
param vnetPrefix string
param gatewayPrefix string
param endpointPrefix string
param functionPrefix string
param resolverPrefix string
param vpnClientPrefix string
param functionDelegation string

// P2S clients must SNAT LAN traffic into the assigned client address pool.
// No NSG or UDR on GatewaySubnet; do not block managed gateway control traffic.
resource endpointNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${prefix}-pe-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowDemoAndFunctions'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefixes: [vpnClientPrefix, functionPrefix]
          sourcePortRange: '*'
          destinationAddressPrefix: endpointPrefix
          destinationPortRanges: ['443', '5671', '8883']
        }
      }
      {
        name: 'DenyOtherInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource dnsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${prefix}-dns-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowDemoDns'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefixes: [vpnClientPrefix, functionPrefix]
          sourcePortRange: '*'
          destinationAddressPrefix: resolverPrefix
          destinationPortRange: '53'
        }
      }
      {
        name: 'DenyOtherInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${prefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [vnetPrefix] }
    subnets: [
      { name: 'GatewaySubnet', properties: { addressPrefix: gatewayPrefix } }
      {
        name: 'private-endpoints'
        properties: {
          addressPrefix: endpointPrefix
          privateEndpointNetworkPolicies: 'NetworkSecurityGroupEnabled'
          networkSecurityGroup: { id: endpointNsg.id }
        }
      }
      {
        name: 'function-integration'
        properties: {
          addressPrefix: functionPrefix
          delegations: [{ name: 'functions', properties: { serviceName: functionDelegation } }]
        }
      }
      {
        name: 'dns-inbound'
        properties: {
          addressPrefix: resolverPrefix
          networkSecurityGroup: { id: dnsNsg.id }
          delegations: [{ name: 'dns', properties: { serviceName: 'Microsoft.Network/dnsResolvers' } }]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output gatewaySubnetId string = '${vnet.id}/subnets/GatewaySubnet'
output endpointSubnetId string = '${vnet.id}/subnets/private-endpoints'
output functionSubnetId string = '${vnet.id}/subnets/function-integration'
output resolverSubnetId string = '${vnet.id}/subnets/dns-inbound'
