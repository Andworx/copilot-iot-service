# IoT Panel Dashboard

Real-time IoT panel status dashboard — React 19 + Vite SPA deployed as a Power Pages code site.

Displays live switch states and LED indicators from Raspberry Pi IoT nodes, surfacing telemetry via Azure SignalR Service and persisting events to Dataverse. Also embeds the **IoT Panel Troubleshooting Agent** (Copilot Studio) so users can query live device state and walk through diagnostics without leaving the portal.

---

## Pages

| Route | Page | Data source |
|-------|------|-------------|
| `/` | Dashboard | SignalR `SendTelemetryUpdate` messages — live switch + LED state |
| `/history` | Event History | Dataverse WebAPI `andy_iottelemetryevents` — paginated event log |
| `/devices` | Device Status | Dataverse WebAPI `andy_iot_sensors` — health cards per node |

---

## Project Structure

```
iot-panel-dashboard/
├── src/
│   ├── components/
│   │   ├── Layout.tsx          # App shell — Navbar + main + Footer
│   │   ├── Navbar.tsx          # Sticky nav with active route + SignalR status badge
│   │   ├── Footer.tsx          # Minimal footer
│   │   ├── StatusBadge.tsx     # online / offline / warning / connecting indicator
│   │   ├── SwitchIndicator.tsx # Read-only toggle with animated track
│   │   └── LedIndicator.tsx    # LED dot with pulse glow animation
│   ├── pages/
│   │   ├── Home.tsx            # Dashboard page (/)
│   │   ├── History.tsx         # Event log (/history)
│   │   └── DeviceStatus.tsx    # Device health (/devices)
│   ├── styles/
│   │   └── theme.css           # Design tokens — IBM Plex Mono/Sans, CSS vars, animations
│   ├── App.tsx                 # Router — wires Layout + 3 routes
│   └── main.tsx                # React entry point
├── public/
├── dist/                       # Built output (gitignored) — uploaded to Power Pages
├── .env.local.example          # Template for local dev environment variables
├── index.html                  # HTML entry — loads IBM Plex fonts from Google Fonts
├── package.json
├── powerpages.config.json      # Power Pages deployment config (siteName, compiledPath)
├── vite.config.ts
└── tsconfig.json
```

---

## Environment Variables

The SPA reads three Vite environment variables at build time. In CI these are injected as repository secrets (see the GitHub Actions workflow). For local dev, copy `.env.local.example` to `.env.local` and fill in real values.

| Variable | Required | Description |
|----------|----------|-------------|
| `VITE_SIGNALR_NEGOTIATE_URL` | ✅ | Base URL of the Azure Function App — e.g. `https://func-aw-iot-copilot.azurewebsites.net` |
| `VITE_DIRECTLINE_TOKEN_URL` | ✅ | Full URL to `/api/directline-token` — the Function App endpoint that exchanges the Direct Line secret for a short-lived token. The secret itself stays server-side. |
| `VITE_TARGET_DEVICE_ID` | optional | IoT Hub device ID to scope SignalR messages to. Defaults to `raspberry-pi-iotpanel`. |
| `VITE_DATAVERSE_URL` | local dev only | Dataverse org URL — used by the Vite dev server proxy for `/api/data/*` calls. Not injected in CI. |

> **Security:** All `VITE_*` values are baked into the JS bundle at build time and are visible to any browser user. Never put secrets here. The Direct Line secret stays in the Azure Function App settings — the `/api/directline-token` endpoint handles the exchange.

---

## Local Development

```powershell
# 1. Copy and fill in env vars
cd "power pages\iot-panel-dashboard"
cp .env.local.example .env.local
# Edit .env.local — add real Function App URL, DirectLine token URL, Dataverse URL

# 2. Install dependencies (first time only)
npm install

# 3. Start the dev server
npm run dev
# → http://localhost:5173

# 4. Production build (generates dist/)
npm run build

# 5. Preview the production build locally
npm run preview
# → http://localhost:4173
```

---

## Deployment

### Automated (recommended) — GitHub Actions

Merging to `main` automatically builds and publishes the site. The workflow `deploy-pages-spa.yml` triggers on any change to `src/`, `public/`, `index.html`, `vite.config.ts`, `tsconfig*.json`, or `package*.json`. See [`power pages/README.md`](../README.md#github-actions-deployment) for the full workflow documentation including required secrets.

### Manual — ad-hoc deploy

Use this when you need to deploy without going through a PR, e.g. after environment re-provisioning.

```powershell
# 1. Authenticate
pac auth create \
  --tenant "<TENANT_ID>" \
  --applicationId "<CLIENT_ID>" \
  --clientSecret "<CLIENT_SECRET>" \
  --environment "https://YOUR_ORG_NAME.crm.dynamics.com/"

# 2. Build with real env vars
cd "power pages\iot-panel-dashboard"
# Set VITE_* variables in .env.local first, then:
npm run build

# 3. Upload
pac pages upload-code-site --rootPath "."
```

> **Never use `pac pages upload`** — that command targets portal-studio sites and will corrupt code site metadata.

### First deployment — activate the site

If this is the very first deploy to a new environment, the site needs to be provisioned with a live URL before it is reachable:

```powershell
pac pages activate --webSiteId <WEBSITE_GUID>
```

Or activate via the [Power Pages admin center](https://make.powerpages.microsoft.com).

---

## Troubleshooting

### Upload fails — `.js` attachments blocked

```
Error: Unable to upload webfile ... as '.js' type attachments are currently blocked
```

Remove `js` from the environment blocked attachments list:

```powershell
pac env list-settings | Select-String "blockedattachments"
pac env update-settings --name blockedattachments --value "<current-list-without-js>"
```

### Upload fails — stale manifest (misleading `.html` error)

If the error mentions `.html` being blocked, the real cause is a stale manifest file:

```powershell
Remove-Item "power pages\iot-panel-dashboard\.powerpages-site\YOUR_ORG_NAME.crm.dynamics.com-manifest.yml"
pac pages upload-code-site --rootPath "power pages\iot-panel-dashboard"
```

---

## Data Integration

The dashboard currently uses mock data stubs. Replace with real data calls when the Azure middleware stack is ready:

| Page | Data source | Stub location |
|------|-------------|---------------|
| Dashboard | SignalR hub (Issue #12) + Dataverse `andy_iottelemetryevent` | `Home.tsx` — `useEffect` timer mock |
| History | Dataverse WebAPI `andy_iottelemetryevents` | `History.tsx` — `useEffect` timer mock |
| Device Status | Dataverse WebAPI `andy_iot_sensors` | `DeviceStatus.tsx` — `useEffect` timer mock |

**Dataverse WebAPI base URL:**  
`https://YOUR_ORG_NAME.crm.dynamics.com/api/data/v9.2/`

**Example query — latest 50 telemetry events:**
```
GET /andy_iottelemetryevents?$orderby=createdon desc&$top=50
```

---

## Design System

| Token | Value | Usage |
|-------|-------|-------|
| `--font-heading` | IBM Plex Mono | Headings, labels, metadata |
| `--font-body` | IBM Plex Sans | Body text, descriptions |
| `--color-bg` | `#F8F9FA` | Page background |
| `--color-surface` | `#FFFFFF` | Cards, navbar, footer |
| `--color-primary` | `#0066CC` | Active nav links, primary actions |
| `--color-accent` | `#00C49A` | LED on-state, switch on-state, online badge |
| `--color-text` | `#0D1117` | Main text |
| `--color-text-muted` | `#6B7280` | Labels, metadata |
| `--color-danger` | `#EF4444` | Error/offline states |

All tokens are defined in `src/styles/theme.css`.

---

## Updating This README

Update this README when:
- A new page or route is added (update the Pages table)
- Environment variables change (update the Environment Variables table)
- The Dataverse table names or WebAPI endpoint changes
- The GitHub Actions workflow trigger paths or secrets change
- SignalR or Direct Line integration details change
