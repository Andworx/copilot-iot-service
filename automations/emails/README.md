# Email Templates

This folder contains managed email template definitions for `YOUR_PROJECT_NAME`. Templates are deployed to Dataverse by `scripts/Import-EmailTemplates.ps1`.

## Files

| File / Folder | Purpose |
|---|---|
| `templates.json` | Manifest listing all managed templates to deploy |
| `*.html` | HTML body files referenced from `templates.json` |
| `example/` | Starter example — copy and adapt for your first template |

## Naming Convention

All managed template names must start with **`YOUR_EMAIL_TEMPLATE_PREFIX`** followed by a space, hyphen, space, and a descriptive name:

```
YOUR_EMAIL_TEMPLATE_PREFIX - Template Name
```

This is enforced by `Import-EmailTemplates.ps1` using the `YOUR_EMAIL_TEMPLATE_PREFIX` project token. Set the correct value in `project.tokens.json` under `project.required`, then run `Apply-ProjectTokens.ps1`.

## templates.json Schema

```json
[
  {
    "name": "YOUR_EMAIL_TEMPLATE_PREFIX - Template Name",
    "subject": "Email subject line",
    "bodyFile": "template-name.html",
    "description": "Purpose of this template",
    "templateTargetEntity": "contact",
    "placeholders": ["{{FirstName}}", "{{CaseNumber}}"],
    "version": "1.0"
  }
]
```

### Field Reference

| Field | Required | Description |
|---|---|---|
| `name` | ✅ | Unique display name in Dataverse. Must start with `YOUR_EMAIL_TEMPLATE_PREFIX - `. |
| `subject` | ✅ | Email subject line. May include placeholder tokens. |
| `bodyFile` | ✅ | Path to the HTML body file, relative to this folder. |
| `description` | recommended | Purpose of the template, stored in Dataverse. Placeholder tokens and version are appended automatically. |
| `templateTargetEntity` | optional | Logical name of the target Dataverse table. Defaults to `contact`. |
| `placeholders` | optional | Array of placeholder token strings shown in the description for reference. |
| `version` | optional | Semantic version string appended to the description (e.g. `1.0`). |

## Worked Example

### templates.json entry

```json
[
  {
    "name": "YOUR_EMAIL_TEMPLATE_PREFIX - Welcome Email",
    "subject": "Welcome to YOUR_PROJECT_NAME, {{FirstName}}!",
    "bodyFile": "example/YOUR_EMAIL_TEMPLATE_PREFIX - Welcome Email.html",
    "description": "Sent to new contacts on registration.",
    "templateTargetEntity": "contact",
    "placeholders": ["{{FirstName}}", "{{PortalUrl}}"],
    "version": "1.0"
  }
]
```

### Corresponding body file: `example/YOUR_EMAIL_TEMPLATE_PREFIX - Welcome Email.html`

See the file in the `example/` subfolder for the matching HTML starter.

## Adding a New Template

1. Create an HTML body file in this folder (or a subfolder).
2. Add an entry to `templates.json` following the schema above.
3. Ensure the `name` starts with `YOUR_EMAIL_TEMPLATE_PREFIX - `.
4. Run `scripts/Import-EmailTemplates.ps1` to deploy.
