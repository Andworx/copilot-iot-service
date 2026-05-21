---
description: "Use when creating new work items, features, or tasks for AgenticIoT. Ensures all requests are tracked as GitHub issues and added to the project board."
---

# Project Board Workflow — Issue Creation & Tracking

## Overview

All work on AgenticIoT must be tracked as GitHub issues and automatically added to the project board at **https://github.com/orgs/iot-agents/projects/YOUR_PROJECT_NUMBER**.

This instruction ensures:
- ✅ Every user request or task becomes a trackable issue
- ✅ Issues appear on the project board automatically
- ✅ Work follows a clear workflow: Backlog → In Progress → In Review → Done
- ✅ No work falls through the cracks

## When to Create an Issue

**Create an issue for:**
- ✅ New features or enhancements
- ✅ Bug fixes or defects
- ✅ Refactoring or code cleanup tasks
- ✅ Documentation updates
- ✅ Test improvements
- ✅ Infrastructure or deployment changes
- ✅ Any work that requires a PR to be merged

**Do NOT create an issue for:**
- ❌ Questions or discussions (use chat/comments instead)
- ❌ Administrative or meta-tasks not requiring code changes
- ❌ Urgent hotfixes that skip the process (but track them afterwards)

## Workflow: Create Issue Per Request

### Step 1: Understand the Request
When a user makes a request in this chat, clarify:
1. **What** needs to be done (feature/fix/task)
2. **Why** it's needed (context/acceptance criteria)
3. **Where** it affects (component/area)
4. **Scope** (small/medium/large; estimate complexity)

### Step 2: Create the GitHub Issue

**Use the "Tracked Work Item" template:**

1. Go to: https://github.com/iot-agents/AgenticIoT/issues/new?template=tracked-work.md
2. Fill in:
   - **Title**: Brief, descriptive title (max ~50 chars)
   - **Description**: Clear context and requirements
   - **Area**: Check the relevant component (dataverse/flows/agents/plugins/pages/reporting)
   - **Acceptance Criteria**: Numbered list of what "done" means
   - **Related Issues**: Link any related issues/PRs

3. **Add labels when creating:**
   - ✅ **REQUIRED**: `YOUR_PROJECT_LABEL` — enables project board tracking
   - ✅ **AREA**: One or more of:
     - `area:dataverse` (Dataverse schema changes)
     - `area:flows` (Power Automate workflows)
     - `area:agents` (Copilot Studio agents)
     - `area:plugins` (Dataverse plugins)
     - `area:pages` (Power Pages portals)
     - `area:reporting` (Power BI reports)
   - ✅ **OPTIONAL**: Other relevant labels for filtering

4. **Click "Create issue"**
   - Issue is automatically added to project board in **Backlog** column (via `project-auto-add.yml` workflow)

### Step 3: Communicate the Issue Back to User

Once the issue is created, provide:
- Issue number (e.g., `#123`)
- Link to the issue
- Link to the project board
- Brief summary of what will happen next

**Example response:**
```
✅ Created issue #123: "Add document sync to capture flow"
📋 Track it on the board: https://github.com/orgs/iot-agents/projects/YOUR_PROJECT_NUMBER
🔗 Issue: https://github.com/iot-agents/AgenticIoT/issues/123

Next steps:
1. Create a feature branch: git checkout -b feat/doc-sync
2. Make your changes
3. Open a PR linked to #123 (use "Fixes #123" in body)
4. Issue will auto-move to "In Review" when PR opens
5. After merge, issue auto-moves to "Done" and closes
```

## Workflow: Issue → Feature Branch → PR → Merge

Once an issue is created, the contributor follows this workflow:

### Phase 1: In Progress (Start Work)
1. Assign the issue to yourself (or appropriate team member)
2. Create a feature branch: `git checkout -b feat/short-description`
   - Branch naming: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/` prefixes (see [CONTRIBUTING.md](../../CONTRIBUTING.md))
3. Make changes with conventional commits: `feat(scope): description`
4. Push the branch: `git push -u origin feat/short-description`

### Phase 2: In Review (Submit for Approval)
1. Open a PR linked to the issue using: `Fixes #123` or `Closes #123` in the PR body
2. Fill out the PR template checklist
3. Submit for review
4. **Issue automatically moves to "In Review"** (via `project-auto-move.yml` workflow)

### Phase 3: Done (Merge & Close)
1. Get approval from reviewers
2. Merge the PR: `gh pr merge <number> --squash` (preferred merge strategy)
3. Feature branch is deleted automatically
4. **Issue automatically moves to "Done" and closes** (via `project-auto-move.yml` workflow)

## Automations

Three GitHub Actions workflows handle the board state automatically:

| Workflow | Trigger | Action |
|----------|---------|--------|
| `project-auto-add.yml` | Issue labeled `YOUR_PROJECT_LABEL` | Auto-adds to board, status = "Backlog" |
| `project-auto-move.yml` | PR opened/closed | Moves issue: Backlog→In Review (open), In Review→Done (merged), In Review→In Progress (closed unmerged) |
| `project-sync.yml` | PR opened | If linked issue missing `YOUR_PROJECT_LABEL` label, adds it automatically |

**No manual board management needed** — automations handle all status transitions.

## Best Practices

✅ **DO:**
- Create one issue per user request (unless clearly a single multi-step task)
- Use clear, descriptive titles
- Include acceptance criteria that define "done"
- Link related issues
- Add area labels for filtering
- Update the issue with blockers or dependencies as they arise

❌ **DON'T:**
- Create multiple small issues for a single cohesive task (combine them)
- Forget to add `YOUR_PROJECT_LABEL` label (won't appear on board)
- Create issues for non-code work (discussions, meta-tasks)
- Leave issues unlinked to PRs (breaks automation)
- Manually move items on the board (let automation handle it)

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Issue doesn't appear on board | Missing `YOUR_PROJECT_LABEL` label | Add the label to the issue |
| Issue stays in Backlog after PR opened | PR doesn't link to issue | Re-open PR with `Fixes #123` in body |
| Issue doesn't auto-close after merge | PR not merged properly or link broken | Manually close issue, or re-link in new PR |
| Workflow not triggering | Actions may be disabled | Check repo Settings → Actions → enabled |

## References

- **Project Board**: https://github.com/orgs/iot-agents/projects/YOUR_PROJECT_NUMBER
- **Issue Template**: https://github.com/iot-agents/AgenticIoT/issues/new?template=tracked-work.md
- **CONTRIBUTING.md**: Branch naming, commit conventions, PR workflow
- **PROJECT_BOARD_GUIDE.md**: User guide for the project board
