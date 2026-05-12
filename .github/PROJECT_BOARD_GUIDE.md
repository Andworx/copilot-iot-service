# YOUR_PROJECT_NAME Project Board Guide

This guide explains how to use the GitHub Project Board to track work on the YOUR_PROJECT_NAME solution.

## Quick Start

### Adding Work to the Project Board

1. **Create an issue** using the "Tracked Work Item" template (in Issues → New Issue)
2. **Add the label** `YOUR_PROJECT_LABEL` to the issue
3. **The issue automatically appears** on the project board in the "Backlog" column

### Moving Work Through the Workflow

**Backlog → In Progress → In Review → Done**

| Status | Trigger | Meaning |
|--------|---------|---------|
| **Backlog** | Issue created with `YOUR_PROJECT_LABEL` label | Ready to start, not yet assigned |
| **In Progress** | You start working on the issue | You've claimed the work and begun implementation |
| **In Review** | Open a PR linked to the issue | Waiting for code review and approval |
| **Done** | PR is merged | Work is complete, issue auto-closes |

---

## Detailed Workflow

### 1. Create an Issue

Use the **"Tracked Work Item"** template when creating issues. This template:
- Pre-fills relevant area labels (`area:dataverse`, `area:flows`, etc.)
- Reminds you to add the `YOUR_PROJECT_LABEL` label
- References branch naming and commit conventions from [CONTRIBUTING.md](../CONTRIBUTING.md)
- Includes placeholders for acceptance criteria

**Steps:**
1. Go to **Issues → New Issue**
2. Choose **"Tracked Work Item"** template
3. Fill in the description and acceptance criteria
4. When creating the issue, add labels:
   - `YOUR_PROJECT_LABEL` (required — enables project board tracking)
   - One or more `area:*` labels (e.g., `area:flows`, `area:dataverse`)

**Result:** Issue appears in **Backlog** column on project board (auto-added by `project-auto-add.yml` workflow)

---

### 2. Claim the Work & Start In Progress

Once you're ready to work on an issue:

1. **Assign yourself** to the issue (or have the issue assigned to you)
2. **Create a feature branch** following naming convention:
   - `feat/brief-description` (for new features)
   - `fix/brief-description` (for bug fixes)
   - See [CONTRIBUTING.md](../CONTRIBUTING.md#branch-naming) for full details
3. **Manually move the issue** to **In Progress** column (or use a label if configured)

---

### 3. Create a Pull Request & Move to In Review

When your work is ready for review:

1. **Create a conventional commit** on your feature branch:
   ```
   feat(component): description of change
   ```

2. **Open a pull request** with:
   - Title: Same as commit message
   - **Link the issue** in the PR body using one of these formats:
     - `Fixes #123` (auto-closes issue when merged)
     - `Closes #123`
     - `Resolves #123`
   - Fill out the PR template checklist

3. **Submit for review** — the issue **automatically moves** to **In Review** column (via `project-auto-move.yml` workflow)

**Result:** Linked issue moves to **In Review** column automatically

---

### 4. Merge & Complete

Once your PR is approved and merged:

1. **Squash and merge** to `main` (see [CONTRIBUTING.md](../CONTRIBUTING.md#merge-strategy) for details)
2. The linked issue **automatically**:
   - Moves to **Done** column
   - Closes (status changed to "Closed")

**Result:** Issue is complete, work is tracked as done on the project board

---

## Key Automations

### Workflow: `project-auto-add.yml`
- **Trigger:** Issue labeled with `YOUR_PROJECT_LABEL`
- **Action:** Adds issue to project board, sets status to "Backlog"
- **File:** `.github/workflows/project-auto-add.yml`

### Workflow: `project-auto-move.yml`
- **Trigger:** PR opened/closed
- **Actions:**
  - PR opened → linked issue moves to "In Review"
  - PR merged → linked issue moves to "Done" & closes
  - PR closed (unmerged) → linked issue moves to "In Progress"
- **File:** `.github/workflows/project-auto-move.yml`

### Workflow: `project-sync.yml`
- **Trigger:** PR opened
- **Action:** If linked issue missing `YOUR_PROJECT_LABEL` label, auto-adds it
- **File:** `.github/workflows/project-sync.yml`

---

## Labels Reference

### Project Label
| Label | Usage | Color |
|-------|-------|-------|
| `YOUR_PROJECT_LABEL` | Issues tracked on this project board | 🔵 Blue |

### Status Labels (for filtering)
| Label | Meaning | Color |
|-------|---------|-------|
| `status:backlog` | Item in backlog, not yet started | 🟣 Purple |
| `status:in-progress` | Currently being worked on | 🟡 Yellow |
| `status:in-review` | In code review (PR open) | 🟡 Gold |
| `status:done` | Completed and merged | 🟢 Green |

### Area Labels (for filtering by component)
| Label | Usage | Color |
|-------|-------|-------|
| `area:dataverse` | Dataverse table/schema changes | 🩷 Pink |
| `area:flows` | Power Automate workflows | 💚 Green |
| `area:agents` | Copilot Studio agents | 💙 Light Blue |
| `area:plugins` | Dataverse plugins | 🟠 Orange |
| `area:pages` | Power Pages portals | 💜 Purple |
| `area:reporting` | Power BI reports | 🟡 Yellow |

---

## Setup Requirements

### 1. Create the GitHub Projects v2 Board

1. Go to your organisation on GitHub
2. Click **Projects** → **New project**
3. Choose **Board** layout
4. Name it (e.g., `YOUR_PROJECT_NAME`)
5. Note the project number from the URL (e.g., `https://github.com/orgs/YOUR_ORG_NAME/projects/2` → number is `2`)
6. Set `YOUR_PROJECT_NUMBER` in `project.tokens.json` and re-run `Apply-ProjectTokens.ps1`

### 2. Create Required Labels

Create these labels in your GitHub repository (Issues → Labels):

**Project label** (required for board automation):
- `YOUR_PROJECT_LABEL` (e.g., `project:my-project`) — Blue `#0075ca`

**Status labels:**
- `status:backlog` — Purple `#7057ff`
- `status:in-progress` — Yellow `#fbca04`
- `status:in-review` — Gold `#e4a015`
- `status:done` — Green `#0e8a16`

**Type labels:**
- `type:epic` — Dark red `#b60205`
- `type:feature` — Blue `#0052cc`
- `type:task` — Light blue `#bfd4f2`

**Area labels:**
- `area:dataverse` — Pink `#f9d0c4`
- `area:flows` — Green `#c2e0c6`
- `area:agents` — Light blue `#c5def5`
- `area:plugins` — Orange `#e99695`
- `area:pages` — Purple `#d4c5f9`
- `area:reporting` — Yellow `#fef2c0`

**Planning labels:**
- `priority:high` — Red `#d93f0b`
- `blocked` — Red `#ee0701`

### 3. Configure `PAT_PROJECT` Secret

The workflows use `PAT_PROJECT` for org-level project access (org projects require elevated scopes that `GITHUB_TOKEN` doesn't provide).

1. Create a Personal Access Token (PAT) with scopes: `repo`, `read:project`, `write:project`
2. Authorize the PAT for your organisation (SSO → Authorize)
3. Go to **Repository Settings → Secrets and variables → Actions**
4. Add secret: `PAT_PROJECT` = your PAT value

> **Tip:** Without `PAT_PROJECT`, issue creation still works but project board automation will fail gracefully with a logged warning.

---

## Common Tasks

### Reopen a Closed Issue
If a linked PR is reverted or closed without merging, the issue moves back to **In Progress** automatically.

To manually reopen:
1. Go to the issue
2. Click **"Reopen issue"** button
3. Move it back to appropriate column on project board

### Link an Issue to an Existing PR
If you forgot to link an issue in your PR, you can edit the PR body:
1. Open the PR
2. Click the three-dot menu (⋯) → **Edit**
3. Add `Fixes #123` to the PR body
4. Save — the automation will trigger

### Move Work Manually (if automation fails)
If an issue doesn't move automatically:
1. Go to the project board
2. Click the issue card
3. Change the "Status" field in the sidebar
4. Or drag the card between columns

---

## Best Practices

✅ **DO:**
- Use the "Tracked Work Item" template for all project work
- Always link issues to PRs (use `Fixes #123` in PR body)
- Add `YOUR_PROJECT_LABEL` label when creating issues
- Keep issue descriptions clear and include acceptance criteria
- Reference related issues if applicable

❌ **DON'T:**
- Create issues without labeling them `YOUR_PROJECT_LABEL` (they won't appear on the board)
- Open PRs without linking to an issue (manual board management required)
- Manually close issues before merging the PR (let automation handle it)
- Move items backwards in the workflow (use PR revert/close instead)

---

## Troubleshooting

### Issue not appearing on project board
**Cause:** Missing `YOUR_PROJECT_LABEL` label  
**Fix:** Add the label to the issue

### PR opened but issue didn't move to "In Review"
**Cause:** Issue not linked in PR body  
**Fix:** Edit PR body to include `Fixes #123` (or similar)

### Issue not auto-closing when PR merged
**Cause:** PR body doesn't include issue link  
**Fix:** Re-merge PR with proper issue link, or manually close issue

### Workflows not triggering
**Cause:** GitHub Actions may be disabled or token lacks permissions  
**Fix:** Check repository settings → Actions → General → "All actions and reusable workflows" is enabled

---

## Project Board Configuration

### Columns
- **Backlog:** Issues ready to start (default for new tracked issues)
- **In Progress:** Issues being actively worked on
- **In Review:** Issues with open PRs waiting for approval
- **Done:** Issues completed and merged

### Custom Fields
None required by default, but can be added:
- "Priority" (High/Medium/Low)
- "Assignee"
- "Target Release" (vX.X.X)

---

## References

- **Branch & Commit Conventions:** See [CONTRIBUTING.md](../CONTRIBUTING.md)
- **Component Guidelines:** See [.github/instructions/](./instructions/)
- **Project Status Tracker:** See [requirements/PLAN.md](../requirements/PLAN.md)
- **GitHub Projects v2 Docs:** https://docs.github.com/en/issues/planning-and-tracking-with-projects/
