---
description: "Use when editing power pages portal files — web templates, web pages, page templates, content snippets, site settings, weblink sets, or any .yml/.html in power pages/. Covers PAC CLI v2 format, Liquid templating, and portal structure."
applyTo: "power pages/**"
---
# power pages Conventions (PAC CLI v2)

## Portal Structure

- Canonical portal folder: `YOUR_PORTAL_FOLDER/`
- Site content folder (created by PAC): `YOUR_PORTAL_FOLDER/YOUR_PORTAL_SLUG/`
- Use the site content folder for `pac pages upload`
- Use the parent folder for `pac pages download` (PAC appends `YOUR_PORTAL_SLUG\` automatically)
- Always use `--modelVersion 2` with PAC CLI commands
- Website ID: `YOUR_WEBSITE_ID`

## YML File Format

- All portal attributes use the `adx_` prefix (power pages standard)
- Site settings use hierarchical slash paths: `Authentication/Registration/LocalLoginEnabled`, `Header/OutputCache/Enabled`
- GUIDs are lowercase, no braces

## File Naming

- Folders: `kebab-case` (e.g., `layout-2-column-wide-left/`, `search-results/`)
- Web template files: `PascalCase.webtemplate.source.html`
- Web page files: `PascalCase.webpage.copy.html`, `.webpage.custom_css.css`, `.webpage.custom_javascript.js`
- Content snippets: `name.en-US.contentsnippet.yml` + `.value.html`

## Liquid Templating Patterns

```liquid
{% extends 'Layout 2 Column Wide Left' %}
{% block main %}...{% endblock %}
{% include 'Page Header' title: title %}
{% assign snippet = snippets["Search/ResultsTitle"] %}
{% if snippet %}{% assign val = snippet | liquid %}{% endif %}
```

- Use `{% extends %}` for template inheritance with named blocks (`main`, `aside`, `breadcrumbs`, `title`)
- Reference snippets with hierarchical paths: `snippets["Section/Name"]`
- Always null-check snippets before use

## CSS Webfile Annotation Bug

PAC CLI v2 does not export `annotationid` for CSS webfiles, but requires it for upload. If adding CSS webfiles, include `annotationid` from a v1 export or the Dataverse record.

## Table Permissions

- Table permissions must be configured through the **power pages admin center**, not via the Dataverse API or PAC CLI.
- Do not create, update, or delete table permission records programmatically.
- When a new table requires portal access, configure its table permissions in the admin center manually.

## Web API Query Shape Guidance

- When troubleshooting portal `403`/`404` issues, prefer matching proven query shapes already working on adjacent pages.
- Avoid custom cache-buster query suffixes on power pages Web API GET calls unless validated in that environment.
- If a request detail page fails while list pages work, keep fallback stages but keep each stage on the same permission-safe query pattern.
