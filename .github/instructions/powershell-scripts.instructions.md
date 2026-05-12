---
description: "Use when writing or modifying PowerShell scripts for Dataverse deployment, export, or API operations. Covers parameter patterns, error handling, logging, and API conventions."
applyTo: "scripts/**/*.ps1"
---
# PowerShell Script Conventions

## Documentation

Every script starts with a comment-based help block:

```powershell
<#
.SYNOPSIS
    One-line description.
.DESCRIPTION
    Detailed explanation.
.PARAMETER Name
    Purpose and accepted values.
.EXAMPLE
    .\Script.ps1 -Param value
    # What it does
#>
```

## Parameters

- Use `[Parameter(Mandatory = $true)]` for required params
- Use `[ValidateSet()]` for constrained values (environments, job names)
- Provide defaults for optional params: `[string]$Environment = 'dev'`
- Use `[switch]$DryRun` for safe preview mode

## Error Handling

- Set `$ErrorActionPreference = 'Stop'` at script start for deployment scripts
- Use `$ErrorActionPreference = 'Continue'` for validation/diagnostic scripts
- Wrap API calls in try-catch with descriptive messages: `throw "Authentication failed: $($_.Exception.Message)"`
- Validate prerequisites early: `if (-not (Test-Path $ConfigPath)) { throw "..." }`

## Logging

Color-coded output with scope prefixes:

```powershell
Write-Host "[Auth] Token acquired." -ForegroundColor Green
Write-Host "[API] Throttled (429). Retry..." -ForegroundColor Yellow
Write-Host "  [PASS] $Name" -ForegroundColor Green
Write-Host "  [FAIL] $Name" -ForegroundColor Red
Write-Host "  [WARN] $Name" -ForegroundColor Yellow
```

Prefix convention: `[Scope]` where Scope = Auth, API, Tables, Solution, etc.

## Dataverse API Patterns

- Connection object is an `[ordered]@{}` hashtable with keys: `Headers`, `ApiBase`, `SolutionName`, `Config`
- API base URL format: `https://{org}.crm.dynamics.com/api/data/v9.2`
- Always handle HTTP 429 with retry using the `Retry-After` header
- Return structured results as `[ordered]@{} | ConvertTo-Json -Depth 10`

### Cloud Flow Workflow Records (`workflows`, category 5)

- For `POST`/`PATCH` on cloud flow records, always include `definition`.
- Send `definition` as a serialized JSON string (primitive), not a nested object.
- When patching optional fields (`clientdata`, `description`), keep `definition` in the same request to avoid `DefinitionRequestMissingFields` regressions.
- Prefer in-place repair/update before delete/recreate when a record is in a corrupted state.

### Recovery Guidance

- If a cloud flow cannot be edited/deleted and returns `DefinitionRequestMissingFields`, run `scripts/Repair-FlowDefinition.ps1` first if available.
- If the record remains undeletable, use replacement mode to retire the broken record and create a clean replacement workflow.

## Environment & Secrets

- Config files: `config-{environment}.json`
- Secret lookup chain: env-specific var → generic fallback → throw
- Variable names: `DATAVERSE_CLIENT_SECRET_DEV`, `DATAVERSE_CLIENT_SECRET_PROD`
- Never hardcode secrets or commit `.env` files
