# Validation, troubleshooting and rollback

Track [issue #206](https://github.com/Andworx/copilot-iot-service/issues/206). No live network tests are marked passed by this documentation. Use an attended maintenance window with a working public-path rollback before each service restriction.

| Symptom | Investigate first |
|---|---|
| Router cannot import profile | Firmware/hardware revision, embedded cert/key support, TLS options; never remove server validation |
| Tunnel up, Pi unreachable | Destination policy versus full tunnel, SNAT to P2S address, return path, overlap and PE NSG |
| DNS timeout | Router-generated DNS routing, inbound IP route, UDP/TCP 53 and source-address NSG match |
| Public answer/NXDOMAIN | OS/browser DNS bypass, conditional public suffix, VNet link, approved endpoint zone group, missing shared service record |
| MQTT connects, events stop | Device auth, IoT route delivery errors, Event Hub managed identity/trusted-service exception and downstream consumer offsets |
| Function trigger stalls | Hosting support, outbound VNet integration, DNS, Event Hub authorization, host/checkpoint storage and scale behavior |
| Dashboard stops | Browser is on demo LAN, negotiation Function private reachability, SignalR SKU and separate client/server network ACLs |
| Prize fails on cellular | Remaining dependency on private Function APIs; rollback public access and finish server-side Dataverse separation |
| Deployment fails after lockdown | GitHub runner network access, SCM DNS, deployment storage and current runtime deployment method |
| Recovery fails | Captive portal, stale DNS, client certificate validity/router time, boot order and reconnect policy |

## Gates and evidence

For every service keep: previous effective policy (sanitized), intended change, owner, what-if, commit SHA, deployment run URL, test time, FQDN and observed route, successful authorized operation, off-network denial, rollback result. Never include keys, complete VPN profiles, claims or app-setting dumps. Keep sensitive exact inventory in an access-controlled operations record.

Before disabling public access, prove telemetry through physical GPIO, both Event Hub consumers, SignalR delivery to both display/PC and public QR redemption from cellular. Check deployment access, storage, DPS reprovisioning, token renewal, DNS and router reboot. Run identity-appropriate data-plane negative tests off VPN; TCP handshake or DNS resolution alone is insufficient. Mark each service **Verify** until these live tests pass. Strict all-public-access-off remains blocked if the IoT routing exception cannot meet it.

## Rollback order

1. Stop rollout. Restore the specific service's previous public network/firewall configuration through its owning deployment mechanism; do not replay an old whole-resource template or overwrite all app settings. Restore only the changed SignalR ACLs or Event Hub rules. Keep least-privilege service authentication.
2. Confirm the previous public data path works from an appropriate authorized client. For Event Hub, restore prior route authentication/configuration only if it was changed, retaining consumer groups/checkpoints to avoid replay or loss. Review both apps.
3. Restore previous LAN conditional forwarder/DHCP configuration or unlink only the affected new DNS zone group/link. Clear OS/browser caches. This matters because re-enabling public access alone does not stop clients resolving private IPs.
4. Revert a Function hosting migration using its approved application rollback, never by deleting the shared app/storage. Keep old runtime configuration securely until validation and cutover complete. No hosting migration is included in this PR.
5. If needed, disable router VPN policy after the public Azure path is working. Verify normal venue Internet, telemetry, dashboard and cellular prizes.
6. Remove unused new endpoints/gateway/resolver only through a reviewed explicit operation against exact IDs after checking dependencies. Setting `deployVpn=false` or removing array items in incremental Bicep is not deletion. Do not delete existing service resources, shared DNS zones, storage, identities or telemetry history. Preserve gateway logs for incident review.

Network changes and application releases are separate. Follow the existing application workflows; do not substitute local Function publishing, PAC uploads or a public management backdoor. Log rollback outcome on the issue and return affected acceptance items to pending.
