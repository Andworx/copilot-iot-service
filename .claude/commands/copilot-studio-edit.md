# /copilot-studio-edit — Copilot Studio Editing Workflow

Claude Code equivalent of the GitHub Copilot "Copilot Studio Author" agent. Invokes the full authoring guardrails and verification workflow for Copilot Studio agent edits.

Always run this command at the start of any Copilot Studio editing session, before making any changes to `copilot agents/`.

## Step 1 — Verify GitHub CLI

```powershell
gh --version
```

If not installed, install from https://cli.github.com (recommended, not blocking — note the gap if unavailable).

## Step 2 — Confirm Agent Guardrails

Before editing, confirm the agent will comply with these guardrails:
- Does not provide legal advice
- Does not invent contact information
- Does not reveal internal workflow/assignment details
- Does not promise specific resolution dates (uses SLA ranges)
- Redirects politely for out-of-scope questions
- For safety concerns, directs users to emergency services first

If the proposed change would violate any guardrail, flag it and suggest a compliant alternative.

## Step 3 — Pull Latest Assets

Pull the latest agent assets from Copilot Studio before editing. Confirm the user has pulled the most recent exported state into `copilot agents/`.

## Step 4 — Review Proposed Changes

For each topic or settings change:
- Use clear `componentName` values that match user intent
- Use broad but meaningful `triggerQueries` — avoid overfitting to one phrase
- Prefer concise branching with explicit escalation paths
- Reuse existing escalation topic handoff
- Keep user-facing text short, plain, and empathetic

## Step 5 — Push & Publish

After editing in source control:
1. Push changes back to Copilot Studio
2. Publish the agent
3. Validate behavior in test chat and the embedded portal experience

## Step 6 — Verification Checklist

- [ ] Primary intents still trigger expected topics
- [ ] Escalation intent routes to escalation topic
- [ ] Fallback behavior works after unmatched inputs
- [ ] Safety prompts return emergency-first response
- [ ] Any submission/report flows align with current portal UX

## Per-Agent Structure Reminder

Each agent under `copilot agents/` must have:
- A dedicated folder with one canonical `README.md`
- Runtime-exported files grouped by agent runtime name
- One topic per `topics/*.mcs.yml` file
