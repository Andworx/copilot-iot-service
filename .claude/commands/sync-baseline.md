# /sync-baseline — Baseline Update Workflow

Guide the user through cherry-picking baseline updates from the upstream template using `Sync-BaselineUpdate.ps1`.

## When to Use

Run this when the andworx-power-platform-starter-template baseline has been updated and you want to bring those improvements into this downstream project.

Check `BASELINE_VERSION.md` to see the current baseline version and what changed.

## Steps

1. **Check current baseline version**

   Read `BASELINE_VERSION.md` to see the current version applied to this repo.

2. **Identify target baseline tag**

   Check the upstream template repository for available baseline tags. Baseline tags follow the format `baseline/vX.Y.Z`.

3. **Run the sync script**

   ```powershell
   .\scripts\Sync-BaselineUpdate.ps1 -BaselineTag baseline/vX.Y.Z
   ```

   The script performs a cherry-pick of changes from the specified baseline tag onto the current branch.

4. **Review cherry-picked changes**

   ```powershell
   git diff HEAD~1
   ```

   Review all changes for conflicts or customisations that need to be preserved.

5. **Resolve conflicts if any**

   If cherry-pick produces conflicts, resolve them manually. Prefer keeping project-specific customisations over baseline defaults where they conflict.

6. **Update BASELINE_VERSION.md**

   Update `BASELINE_VERSION.md` to record the new baseline version applied.

7. **Commit and push**

   ```powershell
   git add -A
   git commit -m "chore: sync baseline to vX.Y.Z"
   ```

8. **Create release tag (if required)**

   If creating a repository release tag after baseline sync, use only the format `vx.x.x`.

   ```powershell
   git tag v1.2.3
   git push origin v1.2.3
   ```

## Notes

- Always review `BASELINE_VERSION.md` changelog entries between the current version and the target version before running the sync
- Cherry-pick one baseline version at a time when skipping multiple versions
- Baseline source tags may use `baseline/vX.Y.Z`, but repository release tags must use only `vx.x.x`
- If the sync script is not available, check `scripts/Sync-BaselineUpdate.ps1` exists; it may need to be added from the latest template
