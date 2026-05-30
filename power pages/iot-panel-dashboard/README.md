# IoT Panel Dashboard

Real-time IoT panel status dashboard — React 19 + Vite SPA deployed as a Power Pages code site.

Tracks switch states, LED indicators, and device health for Raspberry Pi IoT nodes connected to the AgenticIoT Dataverse environment.

---

## Pages

| Route | Page | Description |
|-------|------|-------------|
| `/` | Dashboard | Live switch grid + LED indicator grid with shimmer loading |
| `/history` | Event History | Paginated telemetry event log from `andy_iottelemetryevent` |
| `/devices` | Device Status | Health cards per node — online/offline, firmware, last seen |

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
├── index.html                  # HTML entry — loads IBM Plex fonts from Google Fonts
├── package.json
├── powerpages.config.json      # Power Pages deployment config
├── vite.config.ts
└── tsconfig.json
```

---

## Prerequisites

| Tool | Minimum Version | How to Install |
|------|----------------|----------------|
| Node.js | 18.x | https://nodejs.org |
| npm | 9.x (bundled with Node) | — |
| PAC CLI | latest | `dotnet tool install --global Microsoft.PowerApps.CLI.Tool` |
| .NET SDK | 6+ (for PAC CLI) | https://dot.net |

---

## Local Development

```powershell
# 1. Install dependencies (first time only)
cd "power pages\iot-panel-dashboard"
npm install

# 2. Start the dev server
npm run dev
# → http://localhost:5173

# 3. Production build (generates dist/)
npm run build

# 4. Preview the production build locally
npm run preview
# → http://localhost:4173
```

---

## Deployment to Power Pages

### 1. Authenticate with PAC CLI

```powershell
# Create an auth profile for the IoT-Agents environment
pac auth create --environment "https://<your-org>.crm.dynamics.com"

# Verify you are connected to the correct environment
pac auth who
```

Expected output from `pac auth who`:
```
Connected to...
Environment: IoT-Agents
Environment URL: https://<your-org>.crm.dynamics.com
```

### 2. Build the site

```powershell
cd "power pages\iot-panel-dashboard"
npm run build
```

This compiles TypeScript and produces the `dist/` folder (≈250 KB JS + CSS).

### 3. Upload to Power Pages

```powershell
# From inside the project folder
pac pages upload-code-site --rootPath "."

# Or from the repo root
pac pages upload-code-site --rootPath "power pages\iot-panel-dashboard"
```

> **Never use `pac pages upload`** — that command is for portal-studio sites and will corrupt code site metadata if run against this project.

### 4. Verify deployment

After upload, PAC CLI creates/updates a `.powerpages-site/` folder containing:

```
.powerpages-site/
├── YOUR_ORG_NAME.crm.dynamics.com-manifest.yml   # file → Dataverse record ID map
├── site-settings/
├── table-permissions/
└── web-roles/
```

### First deployment — activate the site

If this is the first deployment, the site needs to be provisioned with a live URL:

```powershell
pac pages activate --webSiteId <WEBSITE_GUID>
```

Or activate via the [Power Pages admin center](https://make.powerpages.microsoft.com).

---

## Troubleshooting

### Upload fails — `.js` attachments blocked

If you see an error like:
```
Error: Unable to upload webfile ... as '.js' type attachments are currently blocked
```

Remove `js` from the environment's blocked attachments list:

```powershell
# 1. Get the current list
pac env list-settings | Select-String "blockedattachments"

# 2. Update — paste the full list with 'js' removed
pac env update-settings --name blockedattachments --value "<list-without-js>"
```

Then retry the upload.

### Upload fails — `.html` blocked (misleading error)

If the error mentions `.html` being blocked, the real cause is a stale manifest file:

```powershell
# Delete the stale manifest
Remove-Item "power pages\iot-panel-dashboard\.powerpages-site\YOUR_ORG_NAME.crm.dynamics.com-manifest.yml"

# Retry upload
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
- A new page or route is added
- The Dataverse table names or WebAPI endpoint changes
- The PAC CLI auth environment URL changes
- SignalR integration (Issue #12) is implemented — update the Data Integration table
