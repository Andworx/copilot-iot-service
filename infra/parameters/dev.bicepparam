using '../main.bicep'

// Example foundation only; this is not a claim that a separate dev environment exists.
// Verify CIDR overlap, location, ownership, costs and resource-group selection first.
param location = 'eastus'
param prefix = 'iot-demo'
param deployVpn = false
param endpoints = []
