# Private demo network implementation plan

Scope: [issue #206](https://github.com/Andworx/copilot-iot-service/issues/206).
This plan covers networking only. [Manual evidence and browser API follow-up](../docs/architecture/manual-build-status.md) supersedes initial deployment assumptions.

| Phase | Status | Exit condition |
|---|---|---|
| Discovery | Verify | Reconcile manual inventory, detailed dependencies and owners |
| Network foundation | Verify | Manually built; reconcile Bicep and run a fresh what-if before any deployment |
| VPN POC | Verify | Beryl AX 4.11.0 working per operator; capture firmware persistence and venue interruption recovery |
| Private endpoints | Verify | IoT Hub, Event Hub, SignalR, game Function and blob tested; legacy Function/DPS/storage dependencies remain |
| Private DNS | Verify | Private paths tested; browser Function split-DNS boundary must be resolved |
| Browser control API | TODO | Select direct authenticated public API or gateway, enforce Entra staff authorization, retire browser keys and validate hosted app |
| Lockdown | TODO | Prize separation, routing exception, deployment access and off-VPN denial validated |
| Documentation | Verify | Manual outcomes captured; final adoption, costs and live acceptance evidence pending |

Totals: Done 0; Verify 6; TODO 2; Future 0. Resources were built manually by the operator; no automated network deployment or public-access lockdown is claimed.
Use the issue for evidence/run links and keep statuses at Verify until full acceptance passes.
