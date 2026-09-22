# Additive private demo network

Tracks [#206](https://github.com/Andworx/copilot-iot-service/issues/206). This is an initial design, not a deployed or validated private demo. Keep existing public access operational.

Existing infrastructure uses `scripts/New-AzureIotInfrastructure.ps1`, `scripts/New-AzureMiddleware.ps1` and `azure infrastructure/*/config.json`. No declarative IaC standard was found in this repository. Bicep manages **new networking only**; the scripts and live application resources are retained. Shared Event Hub/SignalR lifecycle changes belong to their existing owner in the companion game repository. Never run two authoritative templates against the same service.

## Structure

`main.bicep` composes `modules/network.bicep`, `private-dns.bicep`, `monitoring.bicep`, optional `vpn.bicep`, and opt-in `private-endpoints.bicep`. `parameters/dev.bicepparam` is an example foundation configuration, not a new environment. There is no automatic deployment. `validate-network.yml` compiles and checks safety properties without Azure credentials.

## Review and validation

1. Reconcile the source configurations with a secret-free live inventory. Record resource IDs privately, region, SKU, identities, endpoint/consumer settings, storage dependencies, firewall policies, deployment agents and owners. Do not use commands that dump connection strings, keys or app settings into logs.
2. Verify the proposed address ranges do not overlap router LAN, venue LAN, existing VNets, VPN pools or peers. Update **all** CIDR parameters and DNS address together. Check regional support for three-zone Standard public IP and VpnGw1AZ (default example eastus).
3. Approve costs for always-on VPN Gateway and DNS resolver, endpoint hours/data and log ingestion. Review SignalR paid tier and any Function migration separately. Do not substitute Basic VPN (no OpenVPN).
4. Build locally, then preview only in the intended resource group with an authorized identity:

```powershell
az bicep build --file infra/main.bicep
az bicep build-params --file infra/parameters/dev.bicepparam
az deployment group what-if --resource-group <network-resource-group> --template-file infra/main.bicep --parameters infra/parameters/dev.bicepparam --mode Incremental
```

Expected initial preview: new VNet with four subnets, two NSGs, four private DNS zones and VNet links, DNS resolver and inbound endpoint, Log Analytics workspace. No service, plan, routing, app-setting, identity or firewall modifications. Stop on any unexpected Modify/Delete or collision with an existing network/zone. The template assumes it owns these newly named network resources; use existing-resource references after review if discovery finds equivalents. Never use complete-mode deployment or deployment-stack deletion.

Deployment is an explicitly requested operation after review. The manual, main-only `deploy-network.yml` workflow now prepares foundation and VPN stages with a fail-closed what-if gate. Its OIDC identity and protected environment must be configured before use; see the [deployment runbook](../docs/architecture/deployment.md). Existing app workflows remain authoritative for application releases. Deployment operators need scoped network/DNS permissions on the network resource group and only the necessary private-endpoint connection approval rights on target services when those stages are added; avoid subscription-wide Owner/Contributor. IaC does not grant itself RBAC. No deployment has yet occurred.

## Staged parameters

Foundation: `deployVpn = false`, `endpoints = []`. DNS forwarding remains unconfigured on the LAN until records and routing are ready. VNet-integrated clients use Azure DNS by default; no custom VNet DNS setting is changed.

VPN POC: create an ignored `infra/parameters/poc.local.bicepparam` using the same prefix/CIDRs; set `deployVpn = true`. Supply the root's **public certificate body** using `readEnvironmentVariable('DEMO_VPN_ROOT_PUBLIC_CERT')` for `vpnRootCertificateData`. Never put client profiles, private keys or certificate files in the repository. Use certificate authentication compatible with generic OpenVPN, not an assumed Entra/Azure VPN Client integration. Store root keys offline, distribute only a unique client credential to the router and maintain `vpnRevokedCertificates` (objects with `name` and `thumbprint`) in controlled configuration. Removing a revoked thumbprint reauthorizes that certificate.

One-service endpoint stage (example schematic; substitute privately verified ARM ID):

```bicep
param endpoints = [
  {
    name: 'iot'
    resourceId: '/subscriptions/<subscription>/resourceGroups/<existing-rg>/providers/Microsoft.Devices/IotHubs/<existing-hub>'
    groupId: 'iotHub'
    zoneNames: [
      'privatelink.azure-devices.net'
      'privatelink.servicebus.windows.net'
    ]
  }
]
```

The endpoint module references an existing target by full ARM ID; it does not redeploy that service. Keep previous endpoint entries on subsequent deployments. Connection approval, target-region constraints and supported SKU remain deployment prerequisites. A private endpoint does not disable public access or grant application authorization.

| Target | Group | Zone(s) | Gate |
|---|---|---|---|
| IoT Hub | `iotHub` | `privatelink.azure-devices.net`, `privatelink.servicebus.windows.net` | Include built-in Event Hub hostname; test existing device identities and provisioning |
| Event Hub namespace | `namespace` | `privatelink.servicebus.windows.net` | Supported tier, IoT Hub routing exception, both consumers |
| Function app | `sites` | `privatelink.azurewebsites.net` | Flex/Premium/Dedicated, outbound integration, storage and deployment path |
| SignalR | `signalr` | `privatelink.service.signalr.net` | Paid supported SKU, backend and browser network ACLs |

Function subnet default delegates to Flex (`Microsoft.App/environments`). A Premium/Dedicated migration needs `Microsoft.Web/serverFarms` in its own subnet; do not change an occupied Flex subnet to migrate the legacy app. This initial design reserves one integration subnet only: add a second via reviewed IaC if both plan types are retained. No Function is attached automatically. Plan storage endpoints (blob/queue/table/file according to actual runtime) and DPS separately; this initial endpoint module deliberately supports only the four requested services. Do not disable storage or DPS public access with incomplete coverage.

## Safety and limits

- No public-access switch exists in this template. Lockdown belongs to a later owner-reviewed change with measured gates and rollback.
- Incremental deployments are repeatable for declared resources, but removing an endpoint from the array or setting `deployVpn=false` does **not** delete existing resources. DNS records/zone groups can still change when their declarations change. Explicitly review rollback deletions.
- PE NSG allows VPN-pool and Function-subnet TCP 443/5671/8883, then denies other inbound traffic. Private endpoint NSG policy is enabled. GatewaySubnet has neither NSG nor UDR. Function egress stays permissive until runtime dependencies are measured; this is not a claim of complete egress isolation.
- DNS NSG allows port 53 from VPN clients and Function subnet. No management VM, public SSH/RDP, NAT gateway or WireGuard appliance is created.
- Workspace retention is 30 days with a 1 GB/day ingestion cap. The cap can suspend logs; operational owners must set quota alerts/budgets and revisit it. VPN diagnostics are created only with the gateway. Existing App Insights is retained; service-specific diagnostic settings, metric alerts and Defender review are rollout tasks, not claimed complete.
- Key Vault references and managed-identity migrations require owner-reviewed application configuration and permissions. No vault, secrets or credentials are provisioned speculatively.

See [architecture](../docs/architecture/network-architecture.md), [VPN POC](../docs/architecture/vpn-setup.md), [DNS](../docs/architecture/private-dns.md) and [troubleshooting/rollback](../docs/architecture/troubleshooting.md). Update this README whenever parameters, modules, ownership or rollout steps change.
