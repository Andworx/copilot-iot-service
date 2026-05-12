---
description: "Use when creating or modifying Copilot Studio agents and topic YAML files under copilot agents/. Covers structure, naming, pull/push workflow, testing, and escalation patterns."
applyTo: "copilot agents/**"
---
# Copilot Studio Agent Conventions

## Scope

Apply these rules whenever editing Copilot Studio assets in `copilot agents/`, including:
- `*.mcs.yml` topic files
- Agent `settings.mcs.yml`
- Agent-level operational documentation

## Source Of Truth Pattern

- Keep one canonical `README.md` per agent folder.
- Keep runtime-exported assets under the runtime folder.
- Keep one topic per `topics/*.mcs.yml` file.
- Keep repo-wide operating standards in `.github/instructions/` so future agents inherit consistent practices.

## Topic Authoring Standards

- Use clear `componentName` values that match user intent.
- Use broad but meaningful `triggerQueries` and avoid overfitting to one phrase.
- Prefer concise branching logic with explicit escalation paths.
- Reuse existing escalation topic handoff instead of duplicating handoff logic in each topic.
- Keep user-facing text short, plain, and empathetic.
- For safety concerns, direct users to emergency services (911) first before non-emergency guidance.

## Agent Guardrails (customize per project)

- Do not provide legal advice.
- Do not invent contact information.
- Do not reveal internal workflow/assignment details.
- Do not promise specific resolution dates; use SLA ranges.
- For out-of-scope questions, redirect politely.

## Prerequisites

Before editing any Copilot Studio agent assets, confirm the following are in place:

### GitHub CLI (`gh`)

- **Recommended** (warn, not blocking): GitHub CLI is used for branching, PR creation, and release workflows tied to agent changes.
- Verify it is installed by running: `gh --version`
- If missing, install from <https://cli.github.com>.
- If `gh` is unavailable, the edit workflow may still proceed, but raise a warning before continuing and note the gap in the PR description.
- If creating a Git tag as part of a release workflow, use only `vx.x.x` format (lowercase `v` plus three numeric segments), for example `v1.2.3`.
- Never create tags using uppercase `V`, prefixes, suffixes, or qualifiers.

### Copilot Studio Author Agent

- **Always invoke the Copilot Studio Author agent at the start of every editing session**, before making any changes.
- This applies to topic edits, settings changes, and new agent creation.
- Invoking it ensures the agent applies the correct authoring conventions, guardrails, and verification standards for this repo.
- To invoke: open GitHub Copilot Chat and use **@Copilot Studio Author** (or select it from the agent picker) before beginning your work.

---

## Pull/Edit/Push Workflow

0. **Verify GitHub CLI** — run `gh --version`. If not installed, note the gap and install from <https://cli.github.com> (recommended, not blocking).
1. **Invoke the Copilot Studio Author agent** in GitHub Copilot Chat before making any changes.
2. Pull latest agent assets from Copilot Studio.
3. Edit in source control with focused, reviewable diffs.
4. Push back to Copilot Studio.
5. Publish the agent.
6. Validate behavior in test chat and the embedded portal experience.

## Verification Minimums After Push

- Confirm primary intents still trigger expected topics.
- Confirm escalation intent routes to escalation topic.
- Confirm fallback behavior still works after unmatched inputs.
- Confirm safety prompts return emergency-first response.
- Confirm any submission/report flows align with current portal UX.

## Per-Agent Structure

For each new agent under `copilot agents/`:
- Create a dedicated folder with one canonical README.
- Keep exported runtime files grouped by agent runtime name.
- Reuse this workflow and checklist before promoting changes.
