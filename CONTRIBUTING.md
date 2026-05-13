# Contributing to AgenticIoT

All contributions — features, fixes, documentation, and configuration changes — must follow the branch-and-PR workflow described here. Direct pushes to `main` are not permitted.

## Prerequisites

- [Git](https://git-scm.com/)
- [GitHub CLI (`gh`)](https://cli.github.com/) — required for opening PRs from the terminal

## Branch Naming

| Prefix | Use for |
|--------|---------|
| `feat/short-description` | New features |
| `fix/short-description` | Bug fixes |
| `chore/short-description` | Maintenance, dependency updates, config |
| `docs/short-description` | Documentation-only changes |
| `refactor/short-description` | Code restructuring with no behaviour change |
| `release/vx.x.x` | Release preparation (version bump, changelog) |

Use lowercase kebab-case after the prefix. Examples: `feat/my-new-feature`, `fix/null-handling`, `chore/update-connection-refs`.

## Step-by-Step Workflow

### 1. Start from an up-to-date `main`

```bash
git checkout main
git pull origin main
```

### 2. Create your feature branch

```bash
git checkout -b feat/my-feature
```

### 3. Make your changes and commit

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
feat(scope): short description
fix(scope): short description
chore: short description
docs: short description
refactor(scope): short description
```

- Scope is optional but recommended for `feat` and `fix` commits
- Keep the subject line under 72 characters
- Use the imperative mood ("add", "fix", "update" — not "added", "fixed")

### 4. Push your branch

```bash
git push -u origin feat/my-feature
```

### 5. Open a pull request

```bash
gh pr create --title "feat(scope): short description" --body "$(cat <<'EOF'
## Summary
- What this PR does (bullet points)

## Test plan
- [ ] Deployed to dev environment
- [ ] Feature validated end-to-end
- [ ] No regressions in related areas

## Related items
- Fixes #123
EOF
)"
```

Or open the PR in the browser:

```bash
gh pr create --web
```

### 6. Address review feedback

Push additional commits to the same branch — they are automatically included in the open PR:

```bash
git add .
git commit -m "fix(scope): address review feedback"
git push
```

### 7. Merge

Once approved, the maintainer will **squash-merge** the PR into `main`. The branch is deleted after merge.

After your PR is merged, update your local `main`:

```bash
git checkout main
git pull origin main
```

---

## PR Checklist

Before marking a PR as ready for review, confirm:

- [ ] Branch is based on the latest `main`
- [ ] Commit messages follow Conventional Commits format
- [ ] Changes are scoped to a single concern (one feature or fix per PR)
- [ ] `requirements/PLAN.md` updated if the PR completes a tracked item
- [ ] No secrets or environment-specific values committed (use env vars)
- [ ] If flows/agents were changed, the exported YAML/JSON files are included

---

## Merge Strategy

- **Squash merge** into `main` — keeps history clean with one commit per feature/fix
- Branch is deleted from remote after merge
- Release tags use format `vx.x.x` (see [Git Tags](#git-tags) below)

## Git Tags

Release tags follow the format `vx.x.x` — lowercase `v`, three dot-separated integers, no suffixes:

```bash
git tag v1.2.3
git push origin v1.2.3
```

## Branch Protection

The `main` branch is protected on GitHub:

- Direct pushes to `main` are blocked
- All changes require a pull request
- At least one approving review is required before merge

To enable this in your repo: **Settings → Branches → Branch protection rules → Add rule** for `main`, and check "Require a pull request before merging"
