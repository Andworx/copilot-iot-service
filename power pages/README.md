# power pages Portal

This folder contains the portal assets for `AgenticIoT` managed by PAC CLI v2.

## Structure

```
power pages/
└── YOUR_PORTAL_FOLDER/          # PAC CLI portal root
    └── YOUR_PORTAL_SLUG/        # Site content folder (upload path)
        ├── web-templates/
        ├── web-pages/
        ├── content-snippets/
        ├── web-files/
        ├── site-settings/
        └── website.yml
```

## PAC CLI Commands

See `PAC_COMMANDS.md` at the repo root for the full download/upload reference.

Quick reference:
```powershell
# Download
pac pages download --overwrite --path "power pages\\\YOUR_PORTAL_FOLDER" --webSiteId YOUR_WEBSITE_ID --modelVersion "2"

# Upload
pac pages upload --path "power pages\\\YOUR_PORTAL_FOLDER\YOUR_PORTAL_SLUG" --modelVersion "2"
```

## Table Permissions

Configure table permissions in the **power pages admin center** — not via PAC CLI or the Dataverse API. See `.github/instructions/power-pages.instructions.md` for details.

## Key Conventions

- Always use `--modelVersion 2` with PAC CLI v2
- Upload targets the `YOUR_PORTAL_SLUG\` subfolder (where the manifest lives)
- Download targets the parent folder; PAC creates/updates the site subfolder
- GUIDs in YML files are lowercase with no braces
