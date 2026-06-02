# /iot-edge-module — Python Azure IoT Edge Module Workflow

Design, implement, and validate Python-based IoT Edge modules. Claude Code equivalent of the `.github/skills/python-azure-iot-edge-modules` GitHub Copilot skill.

Reference docs in `.github/skills/python-azure-iot-edge-modules/references/`.

## Mandatory Docs Review (Before Recommending)

Before proposing any runtime behavior or deployment decisions, review:
- https://learn.microsoft.com/azure/iot-edge/
- https://learn.microsoft.com/es-es/azure/iot-edge/

Minimum checks:
- Runtime architecture and module lifecycle
- Supported host OS and versions
- Deployment model and configuration flow
- Current release/version guidance

If documentation cannot be fetched, proceed with explicit assumptions and flag them clearly.

Also consult official Python docs at https://docs.python.org/3/ before proposing Python implementation details.

## Step 1 — Contract and Interfaces

Define:
- Module inputs and outputs
- Message schema and versioning policy
- Routes and priorities for normal vs critical telemetry
- Desired properties used for dynamic configuration

## Step 2 — Runtime and Packaging

Specify:
- Python runtime version target
- Container image strategy (base image, slim footprint, CVE hygiene)
- Resource profile (CPU/memory bounds)
- Startup and health checks

## Step 3 — Reliability Design

Implement and validate:
- Retries with exponential backoff and jitter
- Graceful degradation on upstream failures
- Local queueing strategy where needed
- Idempotent processing for replayed messages

## Step 4 — Security Controls

Require:
- No plaintext secrets in code or manifest
- Least-privilege module behavior
- Secure transport and trusted cert chain handling
- Traceability for command handling and state changes

## Step 5 — Deployment and Operations

Define:
- Environment-specific deployment manifests
- Rollout strategy (pilot → staged → broad)
- Rollback criteria
- SLOs and alerting conditions

## Module Use Cases

- Protocol adapter (serial/Modbus/OPC-UA to IoT message format)
- Telemetry enrichment and normalization
- Local anomaly detection or inference
- Command orchestration and local actuator control

## Required Deliverables

Always provide:
1. Module design brief (purpose, inputs, outputs)
2. Deployment model (image, manifest, env settings)
3. Reliability and error-handling strategy
4. Security and operations checklist
5. Test matrix (functional, chaos, performance, rollback)

## Guardrails

- Do not recommend direct production rollout without a pilot stage
- Do not embed secrets in Dockerfiles, source, or manifests
- Do not omit health probes, restart behavior, and rollback criteria
- Always explain why IoT Edge is or is not required for the scenario
- Include operational implications: update strategy, observability, support model
- Prioritize secure defaults: managed identity, least privilege, secret management, network isolation
