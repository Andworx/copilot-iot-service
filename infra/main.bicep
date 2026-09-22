targetScope = 'resourceGroup'

@description('Additive network only. Never declares or changes existing IoT/application resources.')
param location string = resourceGroup().location
param prefix string = 'iot-demo'
param tags object = { project: 'iot-demo', purpose: 'private-network' }
param vnetPrefix string = '10.20.0.0/16'
param gatewayPrefix string = '10.20.0.0/27'
param endpointPrefix string = '10.20.1.0/24'
param functionPrefix string = '10.20.2.0/26'
param resolverPrefix string = '10.20.3.0/28'
param resolverAddress string = '10.20.3.4'
param vpnClientPrefix string = '172.27.240.0/24'

@allowed(['Microsoft.App/environments', 'Microsoft.Web/serverFarms'])
@description('Flex uses Microsoft.App/environments; Premium/Dedicated uses Microsoft.Web/serverFarms. Never mix delegations.')
param functionDelegation string = 'Microsoft.App/environments'

@description('Enable only after cost, certificate custody and router POC preparation are reviewed.')
param deployVpn bool = false
@secure()
@description('Base64 public root certificate body only. Required when deployVpn=true. Never provide the private key.')
param vpnRootCertificateData string = ''
@description('Revoked client certificate thumbprints. Preserve this list on every redeployment.')
param vpnRevokedCertificates array = []

@description('Opt-in endpoints for existing resources. Leave empty for foundation. See README for schema and prerequisites.')
param endpoints array = []

module network 'modules/network.bicep' = {
  name: '${prefix}-network'
  params: {
    location: location
    prefix: prefix
    tags: tags
    vnetPrefix: vnetPrefix
    gatewayPrefix: gatewayPrefix
    endpointPrefix: endpointPrefix
    functionPrefix: functionPrefix
    resolverPrefix: resolverPrefix
    vpnClientPrefix: vpnClientPrefix
    functionDelegation: functionDelegation
  }
}

module dns 'modules/private-dns.bicep' = {
  name: '${prefix}-dns'
  params: {
    location: location
    prefix: prefix
    tags: tags
    vnetId: network.outputs.vnetId
    resolverSubnetId: network.outputs.resolverSubnetId
    resolverAddress: resolverAddress
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: '${prefix}-monitoring'
  params: { location: location, prefix: prefix, tags: tags }
}

module vpn 'modules/vpn.bicep' = if (deployVpn) {
  name: '${prefix}-vpn'
  params: {
    location: location
    prefix: prefix
    tags: tags
    gatewaySubnetId: network.outputs.gatewaySubnetId
    vpnClientPrefix: vpnClientPrefix
    rootCertificateData: vpnRootCertificateData
    revokedCertificates: vpnRevokedCertificates
    workspaceId: monitoring.outputs.workspaceId
  }
}

module privateEndpoints 'modules/private-endpoints.bicep' = [for endpoint in endpoints: {
  name: '${prefix}-pe-${endpoint.name}'
  params: {
    location: location
    name: '${prefix}-pe-${endpoint.name}'
    tags: tags
    subnetId: network.outputs.endpointSubnetId
    targetResourceId: endpoint.resourceId
    groupId: endpoint.groupId
    zoneIds: [for zoneName in endpoint.zoneNames: dns.outputs.zoneIds[zoneName]]
  }
}]

output vnetId string = network.outputs.vnetId
output functionIntegrationSubnetId string = network.outputs.functionSubnetId
output privateEndpointSubnetId string = network.outputs.endpointSubnetId
output dnsInboundAddress string = dns.outputs.inboundAddress
output workspaceId string = monitoring.outputs.workspaceId
