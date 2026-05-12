---
name: andworx-style-diagram-generator
description: 'Generate draw.io diagrams in the andworx professional engineering-drawing style. Use when creating swim lane process flows, entity relationship diagrams (ERDs), or pipeline/deployment diagrams. Supports natural language intake, asks structured questions, outputs .drawio XML files matching your style guide (engineering border, coordinate labels, title block, orthogonal connectors).'
argument-hint: 'Describe the diagram you want: e.g., "swim lane for the ALM process with 5 lanes" or "ERD for the data model"'
user-invocable: true
---

# Andworx Style Diagram Generator

Generate production-ready **draw.io diagrams** matching the andworx professional engineering-drawing aesthetic—complete with engineering borders, coordinate grids, swim lanes, title blocks, and orthogonal connectors.

## When to Use

- **Swim lane diagrams** — Cross-functional process flows with multiple actors/departments
- **Entity Relationship Diagrams (ERDs)** — Database schema and entity relationships
- **Pipeline diagrams** — CI/CD workflows, deployment stages, multi-environment flows
- Any diagram that needs to match your professional engineering-drawing style

## Workflow

### 1. Invoke the Skill

Type `/andworx-style-diagram-generator` and provide a brief description:

> "Create a swim lane diagram for the project intake process"

Or let it prompt you interactively.

### 2. Answer Intake Questions

The skill will ask:

| Question | Purpose | Example |
|----------|---------|---------|
| **Diagram Type** | Choose: Swim Lane / ERD / Pipeline | `Swim Lane` |
| **Diagram Title** | Title for the diagram (goes in title block) | `Project Intake Process` |
| **Version** | Version number | `1.0` |
| **Lanes/Entities/Stages** | Comma-separated list of primary actors or items | `Customer, Management, Developers, BA, Automations` |
| **Main Activities/Relationships** | Key steps or relationships to include | `Requests Project, Review Solution, Approval` |

### 3. Generate Output

The skill generates a `.drawio` XML file in your workspace and opens it (or saves to a named location).

---

## Diagram Types

### Swim Lane (Cross-Functional Process)

**Use for:** Sequential processes involving multiple departments/roles.

**Features:**
- Engineering border with A–D row labels and 1–4 column labels
- Vertical "The Process" label
- 5 horizontal swim lanes (Customer, Management, Developers, BA, Automations)
- Start event (open circle), activities (rounded rectangles with shadow), end event (filled circle)
- Orthogonal connectors with arrowheads
- Title block (bottom-right): Title | Version | Page

**Example flow:**
```
[Start] → Customer: Requests Project
         → Management: Review Solution
         → Developers: Develop Solution
         → BA: Gather Requirements
         → Automations: [End]
```

### ERD (Entity Relationship)

**Use for:** Database schemas, data models, and entity relationships.

**Features:**
- Engineering border with coordinate labels
- Entity tables with headers and attributes (PK = primary key, FK = foreign key)
- One-to-many (1:N) relationship lines between tables
- Title block
- Clean gray header styling for entities, white background for attributes

**Example structure:**
```
[Customers] --1:N--> [Projects] --1:N--> [Tasks]
  PK: ID                PK: ID               PK: ID
  Name, Email          FK: CustomerID       FK: ProjectID
                       Title, Description   Description
```

### Pipeline (Multi-Stage Deployment)

**Use for:** CI/CD workflows, deployment pipelines, environment progression.

**Features:**
- Environment labels (DEV, TEST, STAGING, PROD)
- Stage boxes connected with directional flow
- Approval gates (diamond decision shapes)
- Vertical progression through environments
- Title block with version and page tracking

**Example stages:**
```
Build → Unit Test → Deploy to DEV → E2E Test → Deploy to TEST
  → [Approval Gate] → Deploy to Staging → Smoke Test → Deploy to PROD
```

---

## Style Reference

See [style-guide.md](./assets/style-guide.md) for complete draw.io style properties:

- **Colors:** Dark gray borders (#333333), white fill, light blue-gray swim lanes (#E8E8F0)
- **Fonts:** 11 pt Helvetica for activities, 12 pt for headers, 9 pt for annotations
- **Shapes:** Rounded rectangles with shadow, circles for events, diamonds for gates, rectangles for tables
- **Connectors:** Orthogonal routing, 2 px stroke weight, filled arrowheads
- **Layout Grid:** 1008 × 612 px (16:9 landscape), 40 px margins

---

## Template Files

The skill uses three baseline templates stored in `assets/`:

| Template | File | Purpose |
|----------|------|---------|
| Swim Lane | [swimlane-template.xml](./assets/swimlane-template.xml) | Reference for lane structure and styling |
| ERD | [erd-template.xml](./assets/erd-template.xml) | Sample entity table and relationship layout |
| Pipeline | [pipeline-template.xml](./assets/pipeline-template.xml) | Multi-stage flow with approval gates |

Each template includes the full engineering border, coordinate labels, and title block. Templates are customized based on your input.

---

## Output & Next Steps

### Generated File

The skill produces a `.drawio` file with naming convention:

```
<DiagramType>-<Title>-v<Version>.drawio
```

Examples:
- `swimlane-ProjectIntakeProcess-v1.0.drawio`
- `erd-DataModel-v1.0.drawio`
- `pipeline-Deployment-v1.0.drawio`

### Opening in draw.io

1. **VS Code Integration** (recommended): Install the [Draw.io Integration extension](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio). `.drawio` files will open in a side panel with full editing capability.

2. **diagrams.net web**: Upload the `.drawio` file to [diagrams.net](https://www.diagrams.net) (no account needed, 100% offline).

3. **diagrams.net desktop**: Download the [desktop app](https://github.com/jgraph/drawio-desktop/releases)—works completely offline.

---

## Best Practices

1. **Keep swim lanes focused:** Use 3–7 lanes for clarity. More than 7 becomes cluttered.

2. **Label every connector:** Add decision labels ("approved", "rejected") on conditional flows.

3. **Version tracking:** Update the version number when the diagram changes. Title block tracks it.

4. **Accessibility:** Use clear, concise activity names (2–4 words max).

5. **One diagram = one concept:** Don't mix process flow and data model in a single diagram.

6. **Commit to version control:** Store `.drawio` files in your repository alongside documentation.

---

## Customization

After generation, you can:

- **Edit in draw.io:** Add shapes, connectors, annotations
- **Adjust styling:** Change colors via the Style tab (matches defined color palette)
- **Add notes:** Insert text annotations or decision details
- **Expand pages:** Duplicate the diagram structure for multi-page flowcharts

All changes remain in the `.drawio` XML format—fully version-control compatible.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Diagram doesn't render in VS Code | Install Draw.io Integration extension |
| File is blank after opening | XML file may be corrupted; regenerate using the skill |
| Style doesn't match your Visio style | Refer to [style-guide.md](./assets/style-guide.md) to adjust colors/fonts manually |
| Swim lanes overlapping or cramped | Increase page width or reduce number of lanes |

---

## Examples

### Example 1: Project Intake Swim Lane

**Input:**
```
Diagram Type: Swim Lane
Title: Project Intake Process
Version: 1.0
Lanes: Customer, Management, Developers, BA, Automations
Activities: Requests Project, Review Solution, Develop Solution, Gather Requirements
```

**Output:** `swimlane-ProjectIntakeProcess-v1.0.drawio` — 5-lane cross-functional diagram with approval gate between Management and Developers.

### Example 2: Data Model ERD

**Input:**
```
Diagram Type: ERD
Title: Application Data Model
Version: 1.0
Entities: Customers, Projects, Tasks, Assignments
Relationships: Customers 1:N Projects, Projects 1:N Tasks, Tasks 1:N Assignments
```

**Output:** `erd-ApplicationDataModel-v1.0.drawio` — 4-table ERD with PK/FK relationships and title block.

### Example 3: CI/CD Pipeline

**Input:**
```
Diagram Type: Pipeline
Title: Deployment Pipeline
Version: 2.1
Stages: Build, Unit Test, Deploy to DEV, E2E Test, Deploy to TEST, Approval Gate, Deploy to Staging, Smoke Test, Deploy to PROD
Environments: DEV, TEST, STAGING, PROD
```

**Output:** `pipeline-DeploymentPipeline-v2.1.drawio` — Multi-stage pipeline with approval gate and environment progression.

---

## Support & Feedback

- **Questions?** Review [style-guide.md](./assets/style-guide.md) for style properties and layout rules.
- **Found a bug?** Edit templates in `assets/` or adjust via draw.io directly.
- **Custom shapes?** Extend templates by editing the XML or importing custom shape libraries into diagrams.net.
