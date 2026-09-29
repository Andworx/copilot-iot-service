param location string
param prefix string
param tags object
param gatewaySubnetId string
param vpnClientPrefix string
@secure()
@minLength(1)
param rootCertificateData string
param revokedCertificates array
param workspaceId string

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${prefix}-vpn-pip'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  zones: ['1', '2', '3']
  properties: { publicIPAllocationMethod: 'Static' }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: '${prefix}-vpn'
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    activeActive: false
    enableBgp: false
    vpnGatewayGeneration: 'Generation1'
    sku: { name: 'VpnGw1AZ', tier: 'VpnGw1AZ' }
    ipConfigurations: [{
      name: 'gateway'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: { id: gatewaySubnetId }
        publicIPAddress: { id: publicIp.id }
      }
    }]
    vpnClientConfiguration: {
      vpnClientAddressPool: { addressPrefixes: [vpnClientPrefix] }
      vpnClientProtocols: ['OpenVPN']
      vpnAuthenticationTypes: ['Certificate']
      vpnClientRootCertificates: [{ name: 'demo-root', properties: { publicCertData: rootCertificateData } }]
      vpnClientRevokedCertificates: [for cert in revokedCertificates: {
        name: cert.name
        properties: { thumbprint: cert.thumbprint }
      }]
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${prefix}-vpn-logs'
  scope: gateway
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'GatewayDiagnosticLog', enabled: true }
      { category: 'TunnelDiagnosticLog', enabled: true }
      { category: 'P2SDiagnosticLog', enabled: true }
    ]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}
