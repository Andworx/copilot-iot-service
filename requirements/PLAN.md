# Private demo network implementation plan

Scope: [issue #206](https://github.com/Andworx/copilot-iot-service/issues/206).
This plan covers the new network initiative only, not the repository's other work.

| Phase | Status | Exit condition |
|---|---|---|
| Discovery | Verify | Initial source/read-only inventory complete; reconcile detailed dependencies and owners before rollout |
| Network foundation | Verify | Azure what-if passed: 14 Create, no Modify/Delete; manual workflow prepared; identity/environment, PR review, deployment and live validation pending |
| VPN POC | TODO | TL-WR3002X profile, LAN SNAT/return path, split tunneling and recovery proven |
| Private endpoints | TODO | Supported hosting/SKUs and one-service-at-a-time live tests passed |
| Private DNS | TODO | Normal FQDNs resolve privately from all demo devices and Functions |
| Lockdown | TODO | Prize separation, routing exception, deployment access and off-VPN denial validated |
| Documentation | Verify | Initial architecture/runbooks present; operating evidence and final decisions pending |

Totals: Done 0; Verify 3; TODO 4; Future 0. No Azure deployment has occurred.
Use the issue for evidence/run links and keep statuses at Verify until live acceptance passes.
