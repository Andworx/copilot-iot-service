# /export — Guided Component Export Workflow

Guide the user through exporting Power Platform components from the source environment.

## Steps

1. **Confirm environment and component** — ask which environment to export from and which component type(s) to export if not provided as `$ARGUMENTS`

   Available component types:
   - `tables` — Dataverse table definitions (`Export-Tables.ps1`)
   - `flows` — Power Automate flow definitions (`Export-Flows.ps1`)
   - `views` — Table views (`Export-Views.ps1`)
   - `forms` — Table forms (`Export-Forms.ps1`)
   - `choices` — Global option sets (part of `Export-Tables.ps1`)
   - `relationships` — Table relationships (`Export-Relationships.ps1`)
   - `canvas-apps` — Canvas app definitions (`Export-CanvasApps.ps1`)
   - `web-resources` — Web resources (`Export-WebResources.ps1`)
   - `security-roles` — Security role definitions (`Export-SecurityRoles.ps1`)
   - `env-variables` — Environment variable definitions (`Export-EnvironmentVariables.ps1`)

2. **Check prerequisites**
   - Verify `scripts/config-{env}.json` exists for the source environment
   - Verify the `DATAVERSE_CLIENT_SECRET_*` environment variable is set

3. **Run the export script**
   ```powershell
   .\scripts\Export-<ComponentType>.ps1 -Environment <env>
   ```

4. **Review output**
   - Exports land in `scripts/exports/YOUR_SOLUTION_NAME/<component-type>/`
   - Each export includes a `_summary.json`
   - Review the exported files for accuracy before committing

5. **Commit exported files**
   - Stage only the relevant export output
   - Commit with a message describing what was exported and from which environment

## Notes

- Exports are always from the source (dev) environment
- Never commit secrets or connection credentials from export output
- See `scripts/QUICK_REFERENCE.md` for a quick command summary
