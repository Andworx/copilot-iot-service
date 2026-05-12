# /deploy — Guided Deployment Workflow

Guide the user through deploying Power Platform components to the target environment.

## Steps

1. **Confirm environment** — ask which environment to deploy to (dev / test / prod) if not provided as `$ARGUMENTS`

2. **Check prerequisites**
   - Verify `scripts/config-{env}.json` exists (ask user to copy from `config-{env}.example.json` if missing)
   - Verify the `DATAVERSE_CLIENT_SECRET_*` environment variable is set for the target environment
   - Check `.\scripts\Validate-DeploymentSetup.ps1` can be run

3. **Run validation**
   ```powershell
   .\scripts\Validate-DeploymentSetup.ps1 -Environment <env>
   ```
   Report any failures and help the user resolve them before proceeding.

4. **Select deployment jobs**
   Show the user which `Deploy-Project.ps1` jobs are available and confirm which to run.

5. **Run deployment**
   ```powershell
   .\scripts\Deploy-Project.ps1 -Environment <env> -Job <JobName>
   ```
   Use `-DryRun` first if the user wants to preview.

6. **Post-deployment**
   - Set related plan items in `requirements/PLAN.md` to `⬜ Verify`
   - Remind the user to perform post-deployment validation before marking items `✅ Done`

## Notes

- Always use `-DryRun` to preview before first real run in a new environment
- Secrets go in environment variables, never in config files
- See `scripts/DEPLOYMENT_GUIDE.md` for full reference
