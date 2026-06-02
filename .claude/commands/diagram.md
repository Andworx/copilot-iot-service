# /diagram — Andworx Style Diagram Generator

Generate production-ready **draw.io diagrams** in the andworx professional engineering-drawing style. Claude Code equivalent of the `.github/skills/andworx-style-diagram-generator` GitHub Copilot skill.

Template assets are in `.github/skills/andworx-style-diagram-generator/assets/`:
- `swimlane-template.xml` — swim lane reference
- `erd-template.xml` — ERD reference
- `pipeline-template.xml` — pipeline reference
- `style-guide.md` — full color, font, and layout spec

## Step 1 — Gather Requirements

Ask the user for (or extract from their prompt):

| Field | Purpose | Example |
|-------|---------|---------|
| **Type** | Swim Lane / ERD / Pipeline | `Swim Lane` |
| **Title** | Diagram title (goes in title block) | `Project Intake Process` |
| **Version** | Version number | `1.0` |
| **Lanes / Entities / Stages** | Primary actors or items | `Customer, Management, Developers, BA, Automations` |
| **Activities / Relationships** | Key steps or connections | `Requests Project, Review Solution, Approval` |

## Step 2 — Read the Style Guide

Read `.github/skills/andworx-style-diagram-generator/assets/style-guide.md` to confirm current style properties before generating XML.

## Step 3 — Generate the .drawio File

Output a `.drawio` XML file named: `<Type>-<Title>-v<Version>.drawio`

Examples:
- `swimlane-ProjectIntakeProcess-v1.0.drawio`
- `erd-DataModel-v1.0.drawio`
- `pipeline-Deployment-v2.1.drawio`

### Style Rules (from style-guide)

- **Colors:** Dark gray borders (`#333333`), white fill, light blue-gray swim lanes (`#E8E8F0`)
- **Fonts:** 11 pt Helvetica for activities, 12 pt for headers, 9 pt for annotations
- **Connectors:** Orthogonal routing, 2 px stroke weight, filled arrowheads
- **Layout:** 1008 × 612 px (16:9 landscape), 40 px margins, engineering border with coordinate labels
- **Title block:** Bottom-right — Title | Version | Page

### Swim Lane Structure

- Engineering border with A–D row labels and 1–4 column labels
- Vertical "The Process" label
- Horizontal swim lanes with rounded-rectangle activities and shadow
- Start event (open circle), End event (filled circle), Gates (diamond)

### ERD Structure

- Entity tables with PK/FK annotations
- One-to-many (1:N) lines between tables
- Gray header styling for entities, white background for attributes

### Pipeline Structure

- Environment labels (DEV, TEST, STAGING, PROD)
- Stage boxes connected with directional flow
- Approval gates (diamond decision shapes)

## Step 4 — Save the File

Write the `.drawio` XML file to the workspace root or a `diagrams/` folder if one exists.

## Best Practices

1. Use 3–7 swim lanes for clarity; more than 7 becomes cluttered.
2. Label every connector on conditional flows ("approved", "rejected").
3. Update the version number when the diagram changes.
4. Use clear, concise activity names (2–4 words max).
5. Commit `.drawio` files to version control alongside documentation.

## Opening the File

- **VS Code**: Install the Draw.io Integration extension — `.drawio` files open in a side panel.
- **diagrams.net web**: Upload to diagrams.net (no account needed).
- **Desktop app**: diagrams.net desktop works completely offline.
