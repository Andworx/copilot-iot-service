using '../main.bicep'

// Same foundation and names: the second stage adds the gateway, not another VNet.
param location = 'eastus'
param prefix = 'iot-demo'
param deployVpn = true
param vpnRootCertificateData = readEnvironmentVariable('DEMO_VPN_ROOT_PUBLIC_CERT', '')
param vpnRevokedCertificates = []
param endpoints = []
