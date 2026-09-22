# Network deployment identity bootstrap

`network-identity.bicep` declares the dedicated user-assigned identity, GitHub OIDC credential,
resource-group-scoped custom role and role assignment. It is separate from the network
workflow: CI cannot create identities, grant itself roles or read service secrets.

The operator needs identity/resource deployment rights plus permission to create the scoped
custom role and assignment. Preview this template separately and confirm exactly four
additions before creating it. This is the one-time identity bootstrap, not an alternative
to the main-only workflow for network or application releases.

```powershell
az deployment group what-if --resource-group <target-rg> --template-file infra/bootstrap/network-identity.bicep --mode Incremental
# After inspecting the preview, an authorized bootstrap operator applies the same template:
az deployment group create --resource-group <target-rg> --name iot-demo-network-identity --template-file infra/bootstrap/network-identity.bicep --mode Incremental --output none
```

The default OIDC subject was verified against this repository's API: standard, non-immutable
`repo:Andworx/copilot-iot-service:environment:network-deploy`. If repository customization
changes, review the subject before reapplying. Restrict the GitHub environment to `main`
before first login. No shared secret is generated.

The custom role allows reading resource metadata and creating/updating only the network,
DNS, logging and VPN resource types needed by the first two stages. It has no data actions,
application service writes, key-listing actions, identity/RBAC writes or resource deletion.
ARM deployment-history operations are allowed. Permissions cover these resource types in
the target group; they are not restricted to a name prefix. Keep unrelated networking out
of this group. Private endpoint creation/approval is intentionally absent until its later
reviewed stage. Rollback deletion requires an authorized operator, not this CI identity.

Get the deployment's non-secret `clientId`, `tenantId` and `subscriptionId` outputs privately
and set `network-deploy` environment variables using the deployment runbook. Do not publish
the raw deployment record. Update this README when trust or role permissions change.
