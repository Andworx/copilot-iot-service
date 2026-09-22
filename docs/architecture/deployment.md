# Network deployment and operating record

Tracks issue #206 and PR #207. User authorized proceeding with network construction after reviewing estimated costs. Public connectivity must remain enabled until end-to-end validation passes.

## Current evidence

- Last successful fetch found no newer upstream application commit than the initial network branch base.
- Read-only subscription VNet inventory found no overlap with the proposed Azure `10.20.0.0/16` range. Router LAN/gateway were supplied privately and also do not overlap that range or the P2S pool. Exact LAN settings are kept in the local ignored operations notes.
- Foundation Azure what-if **Succeeded**, with **14 Create**, **0 Modify**, **0 Delete**. Existing application services were Ignore. No gateway or service endpoint was enabled in this preview.
- Initial template compilation and CI passed on commit `37251ce393320ce7f70bf336928ef1f309ff26f3`: [run](https://github.com/Andworx/copilot-iot-service/actions/runs/35724588307).
- Current deployment-workflow changes have local Python safety tests; new CI results must be attached after pushing. A successful preview is not a deployment or connectivity test.
- No Azure resources have been created. Required PR review, network deployment identity/environment and certificates are still outstanding. The last remote operations were blocked by tool-account usage limits.

Do not publish full Azure what-if JSON, credentials, router backups, VPN profiles or live inventory in this public repository. Store sanitized status/counts here, and keep exact operator configuration in approved private storage. Record actual deployment SHA/run URL only after deployment.

## Main-only manual workflow

`.github/workflows/deploy-network.yml` is separate from application workflows and never runs on push. It accepts `action=what-if|deploy` and `stage=foundation|vpn-poc`. Both stages use the same names/address plan, so VPN adds to the existing foundation.

Before the workflow can run:

1. Have the network PR reviewed and merged under existing branch protection. Do not override review requirements. A new `workflow_dispatch` workflow must exist on the default branch before dispatch.
2. Create the `network-deploy` GitHub environment restricted to `main`, with required reviewers where available. The workflow also refuses non-main refs.
3. Provision a dedicated OIDC deployment identity using a reviewed bootstrap IaC change. This workflow does not create its own identity or grant itself roles. Read the repository's actual OIDC subject customization before creating its federated credential; do not assume the default subject if the organization uses immutable IDs. Trust only this repository and `network-deploy` environment, with Azure token-exchange audience.
4. Scope permissions to the chosen network resource group and the required networking, DNS, workspace, diagnostic-setting and ARM deployment operations. This initial workflow needs no IoT Hub, Event Hub, Function, SignalR, storage, RBAC or secret write permissions. Do not grant subscription Contributor/Owner. Later endpoint connection approvals require separate target-specific review.
5. Set these **environment variables**: `AZURE_NETWORK_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `NETWORK_RESOURCE_GROUP`. IDs are configuration, not credentials; do not commit live inventory just to populate them.
6. Review the committed stage parameters, cost and CIDR plan. Foundation provisions the resolver and starts its recurring charges even before VPN is enabled.

After those prerequisites, from an authorized operator session:

```powershell
gh workflow run deploy-network.yml --repo Andworx/copilot-iot-service --ref main -f action=what-if -f stage=foundation
gh run list --repo Andworx/copilot-iot-service --workflow deploy-network.yml --limit 5
# Review successful preview before the authorized deployment:
gh workflow run deploy-network.yml --repo Andworx/copilot-iot-service --ref main -f action=deploy -f stage=foundation
```

Every deploy re-runs what-if against the same checked-out commit. `check_network_plan.py` rejects Modify, Delete, Deploy, Unsupported and unknown change types, as well as creation of unexpected resource types. Changes to existing resources require a separately reviewed workflow/template evolution; do not weaken the gate to ignore unexplained drift. Raw preview files and compiled certificate parameters stay in temporary runner storage and are not uploaded as artifacts. Step summaries show counts, source SHA and stage only.

The deploy step checks ARM provisioning success. Then an operator must verify VNet/subnet CIDRs, resolver address, DNS links, workspace retention and expected NSGs. Live device tests remain **Verify**. Keep the PR/issue open for remaining phases.

## Certificate and VPN stage

No existing root/client certificate was supplied. Prepare a dedicated VPN root and one router client credential on the operator's trusted workstation using [Azure certificate guidance](https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-vpn-client-certificates-azure-certificates). Keep the root private key protected/offline and the client private key only in approved operator storage and the router. Do not generate them on a public CI runner or put them in Git, chat or workflow artifacts.

Export only the base64 **public root certificate body** to the environment secret `DEMO_VPN_ROOT_PUBLIC_CERT`. The secure Bicep input never expects a private key, PFX, or full client profile. Record certificate expiry and custody privately. Maintain revoked client thumbprints in the reviewed VPN parameters before every later deployment; an empty list must never overwrite a real revocation list.

Dispatch the VPN stage first as what-if, then deploy after review:

```powershell
gh workflow run deploy-network.yml --repo Andworx/copilot-iot-service --ref main -f action=what-if -f stage=vpn-poc
gh workflow run deploy-network.yml --repo Andworx/copilot-iot-service --ref main -f action=deploy -f stage=vpn-poc
```

Download the generated profile privately and configure the router per [VPN setup](vpn-setup.md). Prove the tunnel and resolver reachability from a Pi before adding service endpoints. The router must SNAT LAN traffic into the P2S address and support destination split routing. No client software is required on the Pis.

## Service sequence

1. Preserve current public data-plane tests and capture rollback settings privately.
2. Prove VPN plus DNS from the router LAN.
3. Add the IoT endpoint in a separate reviewed parameter change; validate normal FQDN resolution and real telemetry.
4. Coordinate Event Hub private connectivity with both Function consumers and IoT routing authentication; do not disable its public path prematurely.
5. Upgrade SignalR through the companion repository's existing Bicep/workflow, preserving current public settings and Serverless mode. Then add and validate its endpoint.
6. Review legacy Function hosting migration and Flex outbound integration independently. Include host storage, consumer checkpoints and deployment access.
7. Separate any public prize API dependency before restricting Function ingress. Test an attendee phone on cellular.

This workflow intentionally exposes only foundation and VPN stages. It cannot change service SKU, attach Functions or disable public access. Represent every later Azure addition and configuration change in its owning repository before deployment. See [rollback](troubleshooting.md).
