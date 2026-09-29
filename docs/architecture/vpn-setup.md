# TL-WR3002X VPN proof of concept

Status: **not tested on hardware**. Router OpenVPN support is not proof of Azure profile, LAN forwarding or split-route compatibility. Record hardware revision, region and firmware version in issue #206 without attaching credentials. See [TP-Link travel-router VPN guidance](https://community.tp-link.com/en/home/kb/detail/412968) and [Azure certificate OpenVPN setup](https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-vpn-client-certificate-openvpn-linux).

## Preparation and manual configuration

1. Back up router settings privately. Use supported Router/Hotspot mode for the actual firmware. Join venue Wi-Fi and complete its captive portal before starting VPN. Disable remote administration on the WAN; set a unique admin password and maintain current supported firmware.
2. Check LAN/venue/VNet/P2S address overlap. Baseline Pi normal Internet egress. Review recurring gateway/resolver costs. Deploy the additive foundation only after its what-if and ownership checks pass.
3. Provision a unique client certificate/key for this router under an offline-protected root. Store credentials outside Git and chat. Configure IaC P2S with OpenVPN/certificate auth and the public root body. No username/password or Entra-only profile assumption.
4. Download Azure's OpenVPN profile after the gateway exists. Inspect the actual profile's server name, certificate verification, TLS options, cipher support and TCP 443 transport. Azure generates the configuration; do not disable certificate checking or invent profile directives to get an import accepted. Embed or securely reference the client certificate/key as the firmware requires. `.ovpn` files are ignored because they may contain private keys.
5. Import the profile on the TL-WR3002X. Verify whether its importer supports embedded credentials, Azure TLS options and noninteractive startup. Configure autoconnect and save persistent settings. A successful import is only the first gate.
6. Route only `10.20.0.0/16` (or the reviewed VNet ranges) into VPN. No `redirect-gateway`, `0.0.0.0/0`, or paired `/1` full-tunnel routes. Per-device VPN selection is **not** sufficient proof of destination split tunneling: the same Pi must reach Azure privately while its general Internet traffic exits the venue.
7. Establish how LAN traffic gets a valid return path. Azure P2S assigns the router one client IP; it does not automatically learn the LAN behind it. Verify router SNAT from demo LAN to that P2S address, using counters/logs/capture. If it sends unchanged LAN addresses without supported return routing, the design has failed even when router-originated traffic works. Do not assume an Azure UDR can target a dynamic P2S client.
8. Configure DNS forwarding per [private-dns.md](private-dns.md). Ensure router-originated DNS packets also enter/SNAT through the tunnel. Include both Pis and PC in policy rules; no Pi VPN software.

## Evidence checklist

| Test | Required result/evidence |
|---|---|
| Azure P2S | Router client session visible, TCP 443, client certificate auth |
| Profile import | Supported firmware/options; no server-verification bypass |
| Pi private-IP reachability | Reach resolver private IP on DNS port 53; then actual PE TLS service port (ping may be unsupported) |
| Route/NAT | Azure destination uses tunnel, source observed from P2S pool; response returns to Pi |
| DNS | Pi normal service FQDN resolves to PE; record TTL and resolver used |
| Split tunnel | Same Pi's non-Azure Internet egress IP matches venue baseline; route capture shows no default route through VPN |
| Telemetry | Physical input produces IoT receipt, Event Hub delivery, Function processing and dashboard update |
| Public experience | Wi-Fi disabled on attendee phone; QR redemption works without VPN |
| Recovery | Interrupt venue uplink, restore, reboot router and Pis; repeat at least three cycles, record reconnection time and missed/duplicate events |
| Captive portal | Portal re-authentication restores underlying Internet before VPN; record manual steps |
| Cross-venue | Test hotel/conference-style NAT and a mobile hotspot; record TCP 443 filtering, MTU and latency |

Useful Pi probes (substitute actual service FQDN, never a private IP in application configuration): `ip route get 10.20.3.4`, `dig @10.20.3.4 <service-fqdn>`, `dig <service-fqdn>`, and `openssl s_client -connect <iot-fqdn>:8883 -servername <iot-fqdn>`. Pi routing usually points only to its router; inspect the router's routing/NAT too. TLS success is not authorization or message delivery; run an authenticated device telemetry test. Retain only sanitized evidence.

TCP 443 traverses many NATs, but is not HTTPS and may still be blocked by DPI or captive portals. TCP-over-TCP can reduce throughput. Define an acceptable recovery/latency target before POC and record measurements; do not advertise universal venue compatibility.

## Conditional fallback

If profile compatibility, LAN forwarding or destination split routing cannot be supported on the actual firmware, document the failed test before considering TL-WR3002X → WireGuard → Azure appliance → VNet. Do not deploy it preemptively.

A subsequent fallback PR must define appliance subnet/NIC, minimal supported Linux VM, Standard public IP for WireGuard UDP only, host IP forwarding, routes or SNAT for return traffic, NSG and host firewall, patching, monitoring and key custody as IaC/configuration. No public SSH/RDP; manage over the tunnel or an approved private management path. Router AllowedIPs includes only VNet CIDRs; use keepalive behind NAT and verify DNS/recovery again. WireGuard uses UDP, so it may be less usable at restrictive venues than OpenVPN TCP 443. Retain a mobile-hotspot operational fallback; do not expose private services to compensate for an untested appliance.
