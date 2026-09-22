// One-time operator bootstrap. Never called by the identity it creates.
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param identityName string = 'id-gha-iot-demo-network'

@description('Exact GitHub OIDC subject verified from the repository customization settings.')
param githubSubject string = 'repo:Andworx/copilot-iot-service:environment:network-deploy'

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: { purpose: 'demo-network-deployment' }
}

resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: 'github-network-deploy'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    audiences: ['api://AzureADTokenExchange']
    subject: githubSubject
  }
}

resource role 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, 'iot-demo-network-deployer-v1')
  properties: {
    roleName: 'IoT Demo Network Deployer ${uniqueString(resourceGroup().id)}'
    description: 'Create/update the demo network foundation and VPN only. No service, secret, identity, RBAC or resource deletion rights.'
    type: 'CustomRole'
    assignableScopes: [resourceGroup().id]
    permissions: [{
      actions: [
        '*/read'
        'Microsoft.Resources/deployments/*'
        'Microsoft.Network/virtualNetworks/write'
        'Microsoft.Network/virtualNetworks/subnets/write'
        'Microsoft.Network/virtualNetworks/subnets/join/action'
        'Microsoft.Network/networkSecurityGroups/write'
        'Microsoft.Network/networkSecurityGroups/join/action'
        'Microsoft.Network/privateDnsZones/write'
        'Microsoft.Network/privateDnsZones/virtualNetworkLinks/write'
        'Microsoft.Network/dnsResolvers/write'
        'Microsoft.Network/dnsResolvers/inboundEndpoints/write'
        'Microsoft.Network/publicIPAddresses/write'
        'Microsoft.Network/publicIPAddresses/join/action'
        'Microsoft.Network/virtualNetworkGateways/write'
        'Microsoft.OperationalInsights/workspaces/write'
        'Microsoft.Insights/diagnosticSettings/write'
      ]
      notActions: []
      dataActions: []
      notDataActions: []
    }]
  }
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, identity.id, role.id)
  properties: {
    roleDefinitionId: role.id
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output clientId string = identity.properties.clientId
output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
