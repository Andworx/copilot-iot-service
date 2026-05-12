# Copilot Studio Agent Conventions

Applies to all files under `copilot agents/`.

## Source Of Truth Pattern

- Keep one canonical `README.md` per agent folder
- Keep runtime-exported assets under the runtime folder
- Keep one topic per `topics/*.mcs.yml` file
- Keep repo-wide operating standards in `.github/instructions/` so future agents inherit consistent practices

## Topic Authoring Standards

- Use clear `componentName` values that match user intent
- Use broad but meaningful `triggerQueries`; avoid overfitting to one phrase
- Prefer concise branching logic with explicit escalation paths
- Reuse existing escalation topic handoff instead of duplicating handoff logic
- Keep user-facing text short, plain, and empathetic
- For safety concerns, direct users to emergency services (911) first before non-emergency guidance

## Agent Guardrails

- Do not provide legal advice
- Do not invent contact information
- Do not reveal internal workflow/assignment details
- Do not promise specific resolution dates; use SLA ranges
- For out-of-scope questions, redirect politely

## Prerequisites Before Editing

### GitHub CLI (`gh`)

Recommended (warn, not blocking): run `gh --version` to verify. If missing, install from https://cli.github.com. Note the gap in the PR description if unavailable.

### Copilot Studio Author Agent (GitHub Copilot)

The GitHub Copilot "Copilot Studio Author" agent must be invoked at the start of every editing session in GitHub Copilot Chat. In Claude Code, use the `/copilot-studio-edit` slash command instead — it applies the same authoring conventions, guardrails, and verification workflow.

## Pull/Edit/Push Workflow

1. Verify GitHub CLI — run `gh --version`
2. In Claude Code, run `/copilot-studio-edit` (replaces GitHub Copilot "Copilot Studio Author" agent invocation)
3. Pull latest agent assets from Copilot Studio
4. Edit in source control with focused, reviewable diffs
5. Push back to Copilot Studio
6. Publish the agent
7. Validate behavior in test chat and the embedded portal experience

## Verification Minimums After Push

- Confirm primary intents still trigger expected topics
- Confirm escalation intent routes to escalation topic
- Confirm fallback behavior still works after unmatched inputs
- Confirm safety prompts return emergency-first response
- Confirm any submission/report flows align with current portal UX

## Per-Agent Structure

For each new agent under `copilot agents/`:
- Create a dedicated folder with one canonical README
- Keep exported runtime files grouped by agent runtime name
- Run through this workflow and checklist before promoting changes
