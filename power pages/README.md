# Power Pages

This folder contains the source for the **IoT Panel Dashboard** — a React 19 + Vite SPA deployed as a Power Pages code site. It is the browser-facing layer of the AgenticIoT solution: it receives live telemetry from Azure SignalR Service and displays it in real time, embeds the Copilot Studio troubleshooting agent, and shows a scrollable history of past IoT events from Dataverse.

## Portals

| Slug | Type | Folder |
|------|------|--------|
| `iot-panel-dashboard` | Code Site (React/Vite SPA) | `iot-panel-dashboard/` |

See [`iot-panel-dashboard/README.md`](iot-panel-dashboard/README.md) for the full developer guide.

---

## GitHub Actions Deployment

The workflow **`deploy-pages-spa.yml`** automatically builds and publishes the site whenever relevant source files are merged to `main`.

### When it runs

| Trigger | Condition |
|---------|-----------|
| `push` to `main` | Any file changed under `power pages/iot-panel-dashboard/src/`, `public/`, `index.html`, `vite.config.ts`, `tsconfig*.json`, `package*.json`, or the workflow file itself |
| `workflow_dispatch` | Manual trigger from GitHub Actions UI — choose `dev` or `prod` |

### What it does

1. **Checkout** — checks out `main`
2. **Node.js 20 setup** — restores `npm ci` cache keyed to `package-lock.json`
3. **Install** — `npm ci` (clean install, reproducible)
4. **Build** — `npm run build` with three Vite environment variables injected from repository secrets:
   - `VITE_SIGNALR_NEGOTIATE_URL` — base URL of the Azure Function App (SignalR negotiate endpoint)
   - `VITE_DIRECTLINE_TOKEN_URL` — URL of the `/api/directline-token` endpoint (Copilot agent token exchange)
   - `VITE_TARGET_DEVICE_ID` — IoT Hub device ID (defaults to `raspberry-pi-iotpanel` if secret is unset)
5. **Install PAC CLI** — installs `Microsoft.PowerApps.CLI.Tool` as a global dotnet tool
6. **Authenticate** — `pac auth create` using a service principal (see Required Secrets below)
7. **Upload** — `pac pages upload-code-site --rootPath "."` from inside `iot-panel-dashboard/`

### Required Secrets

Configure these in **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `VITE_SIGNALR_NEGOTIATE_URL` | Azure Function App base URL — e.g. `https://func-aw-iot-copilot.azurewebsites.net` |
| `VITE_DIRECTLINE_TOKEN_URL` | Full URL to `/api/directline-token` on the Function App |
| `VITE_TARGET_DEVICE_ID` | IoT Hub device ID — optional, defaults to `raspberry-pi-iotpanel` |
| `DATAVERSE_TENANT_ID` | Microsoft Entra tenant ID for service-principal auth |
| `DATAVERSE_CLIENT_ID` | Application (client) ID of the service principal |
| `DATAVERSE_CLIENT_SECRET` | Client secret for the service principal |

> The service principal must have the **Service Writer** (or equivalent) role in the Power Platform environment so PAC CLI can upload site files.

---

## Local Development

```powershell
cd "power pages\iot-panel-dashboard"
cp .env.local.example .env.local   # fill in real values — see file for guidance
npm install
npm run dev    # → http://localhost:5173
```

See `.env.local.example` for the full list of local environment variables and their descriptions.

---

## Conventions

- This is a **code site** — always use `pac pages upload-code-site`, never `pac pages upload`
- `powerpages.config.json` defines `siteName` and `compiledPath` (points to `dist/`)
- `dist/` and `node_modules/` are gitignored — never commit them
- `--modelVersion 2` applies only to traditional portal (non-code-site) PAC commands

## Updating This README

Update this file when a new portal is added, the deployment workflow changes, new secrets are required, or the environment URL changes.
