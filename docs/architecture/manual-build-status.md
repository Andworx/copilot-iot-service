# Manual build and browser API follow-up

Recorded 2026-09-29 from operator reports; not a fresh Azure inventory. The manual
build supersedes the initial plan's statement that no resources exist. The Bicep
has not yet been reconciled with those resources: do not replay the old what-if
or deploy the initial template as an adoption operation.

## Reported working configuration

- VNet, VPN gateway/P2S certificate authentication, private endpoint subnet,
  Flex Function integration subnet and DNS Resolver inbound endpoint are built.
- The travel router is now GL.iNet Beryl AX GL-MT3000, firmware 4.11.0; the
  TL-WR3002X was replaced after its VPN client lost Internet access for selected
  devices. Beryl LAN is `192.168.8.0/24`, router `192.168.8.1`.
- OpenVPN DCO must be disabled for the Azure tunnel. Destination policy sends
  `10.20.0.0/16` through VPN; other traffic uses venue Internet. Masquerading is
  enabled. Private DNS resolver is `10.20.3.4`.
- IoT Hub, Event Hubs, SignalR, game Function and its blob storage have private
  endpoints. SignalR was upgraded to Standard; game Function VNet integration
  and IoT Hub managed-identity Event Hub routing were reported working.
- The one completed Pi sends telemetry; private service DNS/TCP and real
  SignalR display updates passed. Additional Pis are not built and untested.
- Azure public access remains enabled. Working private paths are not evidence
  of public isolation. Trusted-service firewall restrictions, legacy Y1 Function
  migration, DPS, full storage dependency inventory and deployment lockdown are
  still outstanding.

Keep exact resource identifiers and operational exports in access-controlled
inventory. Reconcile ownership with the game repository before Bicep adoption.

## Router persistence lesson

GL firmware policy routing uses table 1011 for `ovpnclient1`. Router-originated
DNS initially followed the venue default route. A UCI route configured for main
table was still installed in table 1011. The working fix installed the resolver
host route in the main table when the VPN interface came up:

```sh
ip route replace 10.20.3.4/32 dev ovpnclient1 table main
```

The custom `/etc/hotplug.d/iface/99-iot-azure-dns` hook was removed by a firmware
update and recreated. On 4.11.0, the operator reported successful private DNS,
SignalR and Internet after reboot; the route existed but the tagged log was
empty, so successful hook execution was not independently established. Preserve
and inspect the hook across updates; verify both route and actual data traffic.
Earlier firmware sometimes needed a VPN disconnect/reconnect after reboot.

Forward Azure service domains to the private resolver only where private
resolution is intended. VPN DNS is also set to that resolver; inspect both the
main dnsmasq and the VPN instance on port 4153 when diagnosing conflicting answers.

## New browser API boundary

The hosted Power Apps Code App stopped loading state after Function private DNS
was introduced. PowerShell still read state, while Edge denied local address-space
access. This requires a supported browser/API boundary, not a blanket browser
security bypass or a claim that the Function is down.

The companion [control API plan](https://github.com/Andworx/Copilot-IoT-Game/blob/feat/control-api-network-plan/docs/CONTROL_API_NETWORK_PLAN.md)
records consumer separation, Entra authorization, DNS cutover, rollback and tests.
Preferred cost-conscious option is a public authenticated control API with private
downstream access, avoiding a new gateway fee. APIM Developer is an alternative
at approximately $48/month (East US retail USD, 730 hours, development/test without
SLA); Standard v2 is approximately $700/month before extras. Selection remains
pending confirmation; neither gateway nor authentication cutover is deployed.

The public API is an explicit application exception to the original all-private
Function target. Keep public prize token redemption separate from staff controls.
Do not change Azure VNet DNS links just to restore browser access, globally require
staff login on the shared Function, or disable public access before testing hosted
Code App, kiosk, cellular claims and CI/CD. Public prize separation and negative
authorization tests remain lockdown gates.

Next: choose the API boundary, implement Entra validation and supported token
acquisition, retire client-bundled Function keys, validate live, then capture the
final manually built configuration in Bicep with a new what-if.
