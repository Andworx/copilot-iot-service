# Private DNS and split tunneling

Applications keep their normal Azure FQDNs. Private DNS changes resolution only for participating clients. The foundation creates zones/links but does not configure router DNS or attach existing Functions.

| Service | Forward public suffix from LAN | Linked private zone |
|---|---|---|
| IoT Hub | `azure-devices.net` | `privatelink.azure-devices.net` |
| Dedicated and built-in Event Hub | `servicebus.windows.net` | `privatelink.servicebus.windows.net` |
| Function and SCM | `azurewebsites.net` | `privatelink.azurewebsites.net` (verify both app and SCM records) |
| SignalR | `service.signalr.net` | `privatelink.service.signalr.net` |

PE DNS zone groups populate service records. Verify each endpoint's actual `customDnsConfigs`, particularly IoT Hub's built-in Event Hub alias; do not fabricate hostnames. [Azure zone mappings](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns).

Path: Pi → LAN DNS forwarder → VPN → DNS Private Resolver inbound `10.20.3.4` → linked Azure zones → PE address. The `/28` resolver subnet is dedicated and delegated to `Microsoft.Network/dnsResolvers`. In-VNet clients can use Azure-provided DNS. Off-VNet clients cannot use `168.63.129.16` directly; send their queries to the inbound endpoint. No outbound endpoint or forwarding ruleset is needed for this one-way lookup design. [Resolver architecture](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview).

Prefer conditional forwarding of the **public suffixes**, so Azure follows the public-to-private CNAME chain. Keep other DNS on the venue/public path. Verify whether TL-WR3002X firmware supports conditional forwarding and router-originated VPN DNS. If it does not, use a LAN DNS forwarder on an existing Pi (dnsmasq/Unbound, no VPN client), DHCP-advertised to all demo equipment; check availability on reboot. Its configuration is a later POC deliverable after capability validation. Sending all DNS through Azure is a distinct tradeoff and does not meet the preferred private-only forwarding policy without explicit review.

Do not advertise an unreachable resolver before the tunnel is proven. Do not configure public DNS as an equal secondary for private zones (clients may randomly bypass private DNS). Browser secure-DNS settings must respect the chosen resolver on demo devices. Normal non-Azure traffic retains the venue default route; only resolver and Azure private destination packets traverse VPN.

Empty linked zones can return NXDOMAIN for other private-link-enabled instances without local records. Test every dependency, including other SignalR instances, before integrating Functions or forwarding whole suffixes. Do not link these zones to unrelated production VNets. Populate appropriate records via endpoints or review Azure's fallback-to-Internet behavior for a specific use case; never add guessed static PE records.

Validation: from each Pi/PC query the resolver explicitly, then the normal OS resolver; inspect CNAME/A records and compare with endpoint NIC addresses. Test UDP and TCP DNS 53, clear caches after changes, and prove TLS using normal FQDNs. Verify app/SCM hostnames from deployment agents. Cellular devices should remain on public DNS and cannot reach private service data planes after lockdown. Public DNS/TCP success alone is not evidence of service access; test an actual operation. Store expected/actual results and timestamp in issue #206.

DPS and storage are not privatized by the initial four-zone template. Inventory actual provisioning and runtime endpoints first, then add the required zones/endpoints through reviewed IaC before restricting them. Preserve Function host storage/checkpoints and outbound identity/Dataverse/monitoring resolution.
