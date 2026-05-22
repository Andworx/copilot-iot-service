# andy_technician — Technician

## Purpose

Stores field technician records available for IoT fault dispatch. Each technician optionally links to a Dataverse system user (providing name/email/phone). The dispatch agent queries this table to find the nearest `Available` technician when an IoT device reports a fault.

## Key Columns

| Column | Type | Notes |
|--------|------|-------|
| `andy_name` | Text | Primary name — full display name |
| `andy_user_id` | Lookup → `systemuser` | Optional link to Power Platform user |
| `andy_availability` | Choice | `Available` / `On Job` / `Off Shift` |
| `andy_skill_level` | Choice | `Junior` / `Mid` / `Senior` |
| `andy_latitude` | Decimal | Current GPS latitude |
| `andy_longitude` | Decimal | Current GPS longitude |
| `andy_location_label` | Text | Human-readable location (e.g. "Boston – Back Bay") |

Built-in `statecode`/`statuscode` columns handle active/inactive — no custom `andy_active` column needed.

## Choices Used

- `andy_technician_availability` — `tables/choices/andy_technician_availability.json`
- `andy_technician_skill_level` — `tables/choices/andy_technician_skill_level.json`

## Relationships

| Relationship | Type | Notes |
|---|---|---|
| `andy_technician_dispatchhistory` | 1:N | One tech → many dispatch history records |
| `andy_systemuser_technician` | N:1 | Optional link to system user |

## Deployment

Deploy after choices. No dependencies on other custom tables.

```powershell
.\Deploy-Project.ps1 -Job Import-Choices -Environment dev
.\Deploy-Project.ps1 -Job Import-Tables  -Environment dev
```

## Seed Data

25 simulated technicians across US East (NYC to Charlotte corridor). Run after table deployment:

```powershell
.\scripts\Seed-TechnicianData.ps1 -Environment dev
```

## Updating This README

Update when: columns are added/removed, relationships change, or seed data script is modified.
