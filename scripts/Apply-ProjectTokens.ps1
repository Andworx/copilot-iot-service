<#
.SYNOPSIS
    Apply project token values from project.tokens.json across the repo.
.DESCRIPTION
    Reads project-scoped and environment-scoped token values from project.tokens.json at the repo root.
    Compares against project.tokens.applied.json to determine what to apply,
    update (value changed since last run), or skip (not yet set / null / unchanged).

    Safe to re-run at any time:
      - Tokens still at their placeholder value are skipped (listed as Pending).
      - Tokens with a null value (optional) are skipped silently.
      - Tokens already applied with the same value are skipped (no changes needed).
      - Tokens whose value changed since the last run replace the old value in files.

    All file types searched: .ps1  .json  .ts  .md  .yml  .yaml  .html  .txt
    Files under .git\ are always excluded.

    Supports environment-scoped token configuration (dev, test, prod).

.PARAMETER Environment
    Target environment (dev, test, prod, or custom environment name from project.tokens.json).
    If not specified, shows interactive menu to choose environment.

.PARAMETER WhatIf
    Preview what would be applied without writing any files.

.PARAMETER Token
    Apply a single named token only (e.g. -Token iot-agents.crm.dynamics.com/).

.PARAMETER SkipMigration
    If detected old flat token format, skip migration offer and exit with error.

.EXAMPLE
    .\scripts\Apply-ProjectTokens.ps1 -Environment dev
    # Apply dev environment tokens

.EXAMPLE
    .\scripts\Apply-ProjectTokens.ps1
    # Show interactive menu to choose environment

.EXAMPLE
    .\scripts\Apply-ProjectTokens.ps1 -Environment prod -WhatIf
    # Preview what prod tokens would apply without writing files

.EXAMPLE
    .\scripts\Apply-ProjectTokens.ps1 -Environment dev -Token iot-agents.crm.dynamics.com/
    # Apply only iot-agents.crm.dynamics.com/ token for dev environment

.EXAMPLE
    .\scripts\Apply-ProjectTokens.ps1 -Environment dev -SkipRemoteSync
    # Apply tokens and skip the remote Copilot asset sync entirely

.EXAMPLE
    .\scripts\Apply-ProjectTokens.ps1 -Environment dev -RemoteSync
    # Apply tokens then sync all enabled remote Copilot asset sources without prompting

.EXAMPLE
    .\scripts\Apply-ProjectTokens.ps1 -Environment dev -RemoteSyncSourceKeys awesome-copilot
    # Apply tokens then sync only the 'awesome-copilot' source without prompting
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]   $Environment,
    [string]   $Token,
    [switch]   $SkipMigration,

    # --- Remote Copilot asset sync switches ---
    [switch]   $SkipRemoteSync,
    [switch]   $RemoteSync,
    [string[]] $RemoteSyncSourceKeys = @(),
    [switch]   $RemoteSyncNoPrompt
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve repo root (one level above this script's directory)
# ---------------------------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir

$tokensFile  = Join-Path $repoRoot 'project.tokens.json'
$appliedFile = Join-Path $repoRoot 'project.tokens.applied.json'

if (-not (Test-Path $tokensFile)) {
    Write-Error "project.tokens.json not found at: $tokensFile"
    exit 1
}

# ---------------------------------------------------------------------------
# Load token definitions
# ---------------------------------------------------------------------------
$tokenDef = Get-Content $tokensFile -Raw | ConvertFrom-Json

# Detect if using old flat format vs. new environment-scoped format
$isNewFormat = $null -ne $tokenDef.dev -or $null -ne $tokenDef.test -or $null -ne $tokenDef.prod

if (-not $isNewFormat) {
    # Old flat format detected
    if ($SkipMigration) {
        Write-Error @"
Old flat token format detected in project.tokens.json.
To use the new environment-scoped token system, run:
  .\scripts\Migrate-TokensToEnvironments.ps1

Or remove -SkipMigration flag to allow automatic migration.
"@
        exit 1
    }

    Write-Host "Old flat token format detected. Migrate to environment-scoped format?" -ForegroundColor Yellow
    Write-Host "This will create separate sections for dev, test, prod environments." -ForegroundColor Gray
    $response = Read-Host "Type 'migrate' to proceed, or 'skip' to exit"

    if ($response -eq 'migrate') {
        Write-Host "`nRunning migration helper..." -ForegroundColor Cyan
        & "$scriptDir\Migrate-TokensToEnvironments.ps1"
        Write-Host "After migration completes, please re-run this script with the -Environment parameter." -ForegroundColor Cyan
        exit 0
    }
    else {
        Write-Host "Skipped. You can migrate later by running: .\scripts\Migrate-TokensToEnvironments.ps1" -ForegroundColor Gray
        exit 0
    }
}

# Extract available environments (all properties except metadata and project scope)
$availableEnvs = @($tokenDef.PSObject.Properties.Name | Where-Object { $_ -notin '_comment','project','required','optional' })

if ($availableEnvs.Count -eq 0) {
    Write-Error "No environments found in project.tokens.json. Expected dev, test, prod or custom environments."
    exit 1
}

# Determine target environment(s)
$environmentsToProcess = @()

if ([string]::IsNullOrEmpty($Environment)) {
    # Interactive menu
    $supportsAll = (@('dev','test','prod') | Where-Object { $_ -in $availableEnvs }).Count -eq 3

    while ($true) {
        Write-Host "`nSelect environment to apply tokens for:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $availableEnvs.Count; $i++) {
            Write-Host "  [$($i+1)] $($availableEnvs[$i])"
        }
        if ($supportsAll) {
            Write-Host "  [$($availableEnvs.Count + 1)] all (dev, test, prod)"
        }

        $choice = Read-Host 'Enter choice'

        if ($choice -match '^\d+$') {
            $choiceNumber = [int]$choice
            if ($choiceNumber -ge 1 -and $choiceNumber -le $availableEnvs.Count) {
                $environmentsToProcess = @($availableEnvs[$choiceNumber - 1])
                break
            }
            if ($supportsAll -and $choiceNumber -eq ($availableEnvs.Count + 1)) {
                $environmentsToProcess = @('dev','test','prod')
                break
            }
        }

        if ($choice -in $availableEnvs) {
            $environmentsToProcess = @($choice)
            break
        }
        if ($supportsAll -and $choice -ieq 'all') {
            $environmentsToProcess = @('dev','test','prod')
            break
        }

        Write-Host "Invalid selection. Enter a valid number or environment name." -ForegroundColor Yellow
    }
}
else {
    $environmentsToProcess = @($Environment)
}

foreach ($envName in $environmentsToProcess) {
    if ($envName -notin $availableEnvs) {
        Write-Error "Environment '$envName' not found in project.tokens.json. Available: $($availableEnvs -join ', ')"
        exit 1
    }

    $Environment = $envName
    Write-Host "Applying tokens for environment: $Environment" -ForegroundColor Cyan

# Get token definitions for target environment
$targetEnv = $tokenDef.$Environment
$requiredTokenNames = @($tokenDef.required)
$optionalTokenNames = @($tokenDef.optional)

$projectRequiredTokenNames = @()
if ($null -ne $tokenDef.project -and $null -ne $tokenDef.project.required) {
    $projectRequiredTokenNames = @($tokenDef.project.required.PSObject.Properties.Name)
}

# Load previously-applied state
$appliedMap = @{}
$projectAppliedMap = @{}
if (Test-Path $appliedFile) {
    $raw = Get-Content $appliedFile -Raw
    if ($raw.Trim() -ne '' -and $raw.Trim() -ne '{}') {
        $parsed = $raw | ConvertFrom-Json
        if ($null -ne $parsed.$Environment -and $null -ne $parsed.$Environment.values) {
            foreach ($prop in $parsed.$Environment.values.PSObject.Properties) {
                $appliedMap[$prop.Name] = $prop.Value
            }
        }
        if ($null -ne $parsed.project -and $null -ne $parsed.project.values) {
            foreach ($prop in $parsed.project.values.PSObject.Properties) {
                $projectAppliedMap[$prop.Name] = $prop.Value
            }
        }
    }
}

# Prune stale applied values that no longer belong to this scope
$validEnvTokenNames = @($requiredTokenNames + $optionalTokenNames)
foreach ($k in @($appliedMap.Keys)) {
    if ($k -notin $validEnvTokenNames) {
        [void]$appliedMap.Remove($k)
    }
}
foreach ($k in @($projectAppliedMap.Keys)) {
    if ($k -notin $projectRequiredTokenNames) {
        [void]$projectAppliedMap.Remove($k)
    }
}

# Build list of [key, value, isOptional, scope] tokens
$allTokens = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($tokenKey in $projectRequiredTokenNames) {
    $value = $tokenDef.project.required.$tokenKey
    $allTokens.Add([PSCustomObject]@{ Key = $tokenKey; Value = $value; Optional = $false; Scope = 'project' })
}

foreach ($tokenKey in $requiredTokenNames) {
    $value = $targetEnv.required.$tokenKey
    $allTokens.Add([PSCustomObject]@{ Key = $tokenKey; Value = $value; Optional = $false; Scope = $Environment })
}

foreach ($tokenKey in $optionalTokenNames) {
    $value = $targetEnv.optional.$tokenKey
    $allTokens.Add([PSCustomObject]@{ Key = $tokenKey; Value = $value; Optional = $true; Scope = $Environment })
}

# If -Token was specified, narrow to that single token
if ($Token) {
    $allTokens = $allTokens | Where-Object { $_.Key -eq $Token }
    if ($allTokens.Count -eq 0) {
        Write-Error "Token '$Token' not found in project.tokens.json."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# File set to search
# ---------------------------------------------------------------------------
# *.md covers CLAUDE.md, all subdirectory CLAUDE.md files, and .claude/commands/*.md
$fileExtensions = '*.ps1','*.json','*.ts','*.md','*.yml','*.yaml','*.html','*.txt'

$files = Get-ChildItem -Path $repoRoot -Recurse -File -Include $fileExtensions |
    Where-Object { $_.FullName -notmatch [regex]::Escape("$([System.IO.Path]::DirectorySeparatorChar).git$([System.IO.Path]::DirectorySeparatorChar)") -and
                   $_.Name -ne 'project.tokens.applied.json' }

# ---------------------------------------------------------------------------
# Process each token
# ---------------------------------------------------------------------------
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($t in $allTokens) {
    $key   = $t.Key
    $value = $t.Value
    $scope = $t.Scope

    # --- Skip: optional and not configured ---
    if ($null -eq $value) {
        $results.Add([PSCustomObject]@{ Token = $key; Status = 'Skipped-Optional'; Detail = 'null — set a value to apply' })
        continue
    }

    # --- Skip: still at placeholder ---
    if ($value -eq $key) {
        $results.Add([PSCustomObject]@{ Token = $key; Status = 'Pending'; Detail = 'Value not yet set in project.tokens.json' })
        continue
    }

    if ($scope -eq 'project') {
        $wasApplied   = $projectAppliedMap.ContainsKey($key)
        $appliedValue = if ($wasApplied) { $projectAppliedMap[$key] } else { $null }
    }
    else {
        $wasApplied   = $appliedMap.ContainsKey($key)
        $appliedValue = if ($wasApplied) { $appliedMap[$key] } else { $null }
    }

    if ($wasApplied -and $appliedValue -eq $value) {
        # --- Skip: already up-to-date ---
        $results.Add([PSCustomObject]@{ Token = $key; Status = 'Unchanged'; Detail = "Already applied: $value" })
        continue
    }

    # Determine what to search for in files
    if ($wasApplied) {
        # Value changed — replace the old applied value with the new value
        $searchFor  = $appliedValue
        $statusVerb = 'Updated'
        $detail     = "$appliedValue  ->  $value"
    }
    else {
        # First-time apply — replace the placeholder token
        $searchFor  = $key
        $statusVerb = 'Applied'
        $detail     = $value
    }

    $modifiedCount = 0

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8

        if ($content -match [regex]::Escape($searchFor)) {
            $newContent = $content -replace [regex]::Escape($searchFor), $value

            if ($PSCmdlet.ShouldProcess($file.FullName, "Replace '$searchFor' with '$value'")) {
                Set-Content -Path $file.FullName -Value $newContent -NoNewline -Encoding UTF8
                $modifiedCount++
            }
            else {
                # -WhatIf: count the match without writing
                $modifiedCount++
            }
        }
    }

    $results.Add([PSCustomObject]@{
        Token  = $key
        Status = $statusVerb
        Detail = "$detail  ($modifiedCount file$(if ($modifiedCount -ne 1){ 's' }))"
    })

    # Update in-memory applied map (only when not in WhatIf)
    if (-not $WhatIfPreference) {
        if ($scope -eq 'project') {
            $projectAppliedMap[$key] = $value
        }
        else {
            $appliedMap[$key] = $value
        }
    }
}

# ---------------------------------------------------------------------------
# Persist updated applied state (per environment)
# ---------------------------------------------------------------------------
if (-not $WhatIfPreference) {
    # Load current applied state
    $appliedState = @{}
    if (Test-Path $appliedFile) {
        $raw = Get-Content $appliedFile -Raw
        if ($raw.Trim() -ne '' -and $raw.Trim() -ne '{}') {
            $appliedState = $raw | ConvertFrom-Json -AsHashtable
        }
    }

    # Initialize environment section if not present
    if ($null -eq $appliedState[$Environment]) {
        $appliedState[$Environment] = @{
            appliedAt = $null
            values    = @{}
        }
    }

    # Update values for this environment
    $valueMap = @{}
    foreach ($k in ($appliedMap.Keys | Sort-Object)) {
        $valueMap[$k] = $appliedMap[$k]
    }
    $appliedState[$Environment].values = $valueMap
    $appliedState[$Environment].appliedAt = Get-Date -Format 'o'

    # Initialize project section if not present
    if ($null -eq $appliedState['project']) {
        $appliedState['project'] = @{
            appliedAt = $null
            values    = @{}
        }
    }

    # Update project-scoped values
    $projectValueMap = @{}
    foreach ($k in ($projectAppliedMap.Keys | Sort-Object)) {
        $projectValueMap[$k] = $projectAppliedMap[$k]
    }
    $appliedState['project'].values = $projectValueMap
    $appliedState['project'].appliedAt = Get-Date -Format 'o'

    # Write back, preserving other environments' states
    $appliedState | ConvertTo-Json -Depth 5 | Set-Content -Path $appliedFile -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Summary output
# ---------------------------------------------------------------------------
$prefix = if ($WhatIfPreference) { ' [WHAT-IF]' } else { '' }
Write-Host "`n=====$prefix Apply-ProjectTokens Summary [$Environment]=====" -ForegroundColor Cyan

$groups = $results | Group-Object Status

foreach ($group in $groups | Sort-Object Name) {
    $color = switch ($group.Name) {
        'Applied'          { 'Green'  }
        'Updated'          { 'Cyan'   }
        'Pending'          { 'Yellow' }
        'Unchanged'        { 'Gray'   }
        'Skipped-Optional' { 'DarkGray' }
        default            { 'White'  }
    }
    Write-Host "`n  $($group.Name) ($($group.Count)):" -ForegroundColor $color
    foreach ($r in $group.Group) {
        Write-Host "    $($r.Token.PadRight(24))  $($r.Detail)" -ForegroundColor $color
    }
}

$pending = ($results | Where-Object { $_.Status -eq 'Pending' }).Count
$applied = ($results | Where-Object { $_.Status -in 'Applied','Updated' }).Count

Write-Host ''
if ($WhatIfPreference) {
    Write-Host '  (No files were modified — WhatIf mode)' -ForegroundColor DarkGray
}
elseif ($applied -gt 0) {
    Write-Host "  $applied token$(if ($applied -ne 1){ 's' }) stamped." -ForegroundColor Green
}

if ($pending -gt 0) {
    Write-Host "  $pending token$(if ($pending -ne 1){ 's' }) still pending. Fill them in project.tokens.json and re-run." -ForegroundColor Yellow
}
elseif ($applied -eq 0 -and -not $WhatIfPreference) {
    Write-Host '  Nothing to do — all tokens are up-to-date.' -ForegroundColor Green
}

Write-Host ''

# ---------------------------------------------------------------------------
# Remote Copilot asset sync
# ---------------------------------------------------------------------------
$syncScript = Join-Path $scriptDir 'Sync-RemoteCopilotAssets.ps1'

if ($SkipRemoteSync) {
    # User explicitly opted out — do nothing
}
elseif (-not (Test-Path $syncScript)) {
    Write-Warning "Sync-RemoteCopilotAssets.ps1 not found at '$syncScript' — skipping remote sync."
}
elseif ($WhatIfPreference) {
    Write-Host '  (Remote sync skipped — WhatIf mode)' -ForegroundColor DarkGray
}
else {
    # Determine sync parameters
    if ($RemoteSync -or $RemoteSyncSourceKeys.Count -gt 0) {
        # Non-interactive: caller supplied explicit intent
        $syncParams = @{
            RepoRoot  = $repoRoot
            NoPrompt  = $true
            AllSources = $RemoteSync -and $RemoteSyncSourceKeys.Count -eq 0
        }
        if ($RemoteSyncSourceKeys.Count -gt 0) {
            $syncParams.SourceKeys = $RemoteSyncSourceKeys
        }
        Write-Host '===== Remote Copilot Asset Sync =====' -ForegroundColor Cyan
        & $syncScript @syncParams
    }
    else {
        # Interactive: prompt the user
        Write-Host 'Sync remote Copilot assets (instructions/agents/skills) now? (Y/N)' -ForegroundColor Cyan -NoNewline
        Write-Host ' [from remote-content.sources.json]' -ForegroundColor DarkGray
        $syncChoice = if ($RemoteSyncNoPrompt) { 'N' } else { Read-Host 'Enter choice [Y/N]' }

        if ($syncChoice -match '^[Yy]') {
            Write-Host '===== Remote Copilot Asset Sync =====' -ForegroundColor Cyan
            & $syncScript -RepoRoot $repoRoot
        }
        else {
            Write-Host '  Remote sync skipped. Run .\scripts\Sync-RemoteCopilotAssets.ps1 at any time.' -ForegroundColor DarkGray
        }
    }
}

Write-Host ''
}
