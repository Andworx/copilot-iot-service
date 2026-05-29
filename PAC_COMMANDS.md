# PAC CLI Commands — AgenticIoT Portal

## Authentication

```powershell
# List current auth profiles
pac auth list

# Create a new auth profile (interactive login)
pac auth create --environment "https://iot-agents.crm.dynamics.com/"

# Select an existing auth profile by index
pac auth select --index 1
```

## Code Site Upload (iot-panel-dashboard)

> **IMPORTANT:** `--rootPath` must be an absolute path or `.` when run from inside the project folder.
> Running with a relative path from a *different* directory doubles up and causes "directory not found".

```powershell
# Option A — from inside the project folder (recommended)
cd "c:\PowerPlatformProjects\copilot-iot-service\power pages\iot-panel-dashboard"
npm run build
pac pages upload-code-site --rootPath "."

# Option B — from repo root
cd "c:\PowerPlatformProjects\copilot-iot-service"
npm run build --prefix "power pages\iot-panel-dashboard"
pac pages upload-code-site --rootPath "c:\PowerPlatformProjects\copilot-iot-service\power pages\iot-panel-dashboard"
```

## Pages Download (portal-studio sites)

```powershell
# Download portal files (overwrites local changes)
# NOTE: PAC creates a subfolder named after the portal. Download into the parent folder;
# the actual content lands in YOUR_PORTAL_SLUG\ inside it.
pac pages download --overwrite `
  --path "power pages\YOUR_PORTAL_FOLDER" `
  --webSiteId YOUR_WEBSITE_ID `
  --modelVersion "2" `
  --overwrite true
```

## Pages Upload (portal-studio sites)

```powershell
# Upload portal files to Dataverse
pac pages upload `
  --path "power pages\YOUR_PORTAL_FOLDER\YOUR_PORTAL_SLUG" `
  --modelVersion "2"
```

## Reference

| Parameter | Value |
|-----------|-------|
| Website ID | `YOUR_WEBSITE_ID` |
| Model Version | `2` |
| Environment | `iot-agents.crm.dynamics.com/` |
| Code site root | `power pages\iot-panel-dashboard` (use absolute path or `.`) |
| Upload Path | `power pages\YOUR_PORTAL_FOLDER\YOUR_PORTAL_SLUG` |
| Download Path | `power pages\YOUR_PORTAL_FOLDER` (PAC appends `YOUR_PORTAL_SLUG\` automatically) |

Upload must point to the `YOUR_PORTAL_SLUG\` subfolder — that is where the manifest lives.
Download should target the parent folder; PAC will create/update `YOUR_PORTAL_SLUG\` inside it.
