<#
.SYNOPSIS
    Master orchestrator for AgenticIoT Power Platform deployment jobs.
.DESCRIPTION
    Central job runner with multi-environment support, production safety controls,
    dry-run preview, interactive menus, and HTML run report.

    To add project-specific jobs:
    1. Add the job name to the [ValidateSet()] below.
    2. Dot-source the corresponding script under "Source all scripts".
    3. Add an entry to the $jobMap hashtable.
    4. Add the job to the appropriate interactive menu in Select-JobInteractive.
.PARAMETER Job
    Which job to run. If omitted, shows interactive menu.
.PARAMETER Environment
    Target environment: dev, prod, staging. Default: dev.
.PARAMETER ConfigPath
    Explicit config file path (overrides -Environment).
.PARAMETER DryRun
    Preview mode — shows what would happen without making changes.
.PARAMETER ReplaceExistingFlows
    For Import-Flows only: explicitly deletes existing cloud flows and recreates
    them from local JSON. Leave this off for the normal in-place update path.
.PARAMETER SkipConfirmation
    Bypass production confirmation prompt (for CI/CD).
.PARAMETER ReportPath
    Custom path for the HTML report. Auto-generated if omitted.
.EXAMPLE
    .\Deploy-Project.ps1
    # Interactive mode — shows environment and job menus
.EXAMPLE
    .\Deploy-Project.ps1 -Job Export-Tables -Environment dev
.EXAMPLE
    .\Deploy-Project.ps1 -Job Import-Flows -Environment dev
.EXAMPLE
    .\Deploy-Project.ps1 -Job Import-Flows -Environment dev -ReplaceExistingFlows
    # Destructive recovery path: delete and recreate matching flows
#>
param(
    [ValidateSet(
        # --- Export jobs ---
        'Export-All',
        'Export-Tables',
        'Export-Flows',
        'Export-Relationships',
        'Export-Forms',
        'Export-Views',
        'Export-WebResources',
        'Export-SecurityRoles',
        'Export-CanvasApps',
        'Export-EnvironmentVariables',
        # --- Import jobs ---
        'Import-All',
        'Import-Choices',
        'Import-Tables',
        'Import-Relationships',
        'Import-EmailTemplates',
        'Import-Flows'
        # --- Add project-specific jobs here ---
        # e.g., 'Initialize-Queues', 'Seed-Data'
    )]
    [string]$Job,

    [ValidateSet('dev', 'prod', 'staging')]
    [string]$Environment,

    [string]$ConfigPath,

    [switch]$DryRun,

    [switch]$ReplaceExistingFlows,

    [switch]$SkipConfirmation,

    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ============================================================
# Helper Functions
# ============================================================

function Load-EnvFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $eqIndex = $line.IndexOf('=')
            if ($eqIndex -gt 0) {
                $key = $line.Substring(0, $eqIndex).Trim()
                $val = $line.Substring($eqIndex + 1).Trim()
                [System.Environment]::SetEnvironmentVariable($key, $val, 'Process')
            }
        }
    }
}

function Select-EnvironmentInteractive {
    $configs = Get-ChildItem -Path $scriptDir -Filter 'config-*.json' | Sort-Object Name
    if ($configs.Count -eq 0) {
        throw "No config-*.json files found in $scriptDir. Copy config-dev.example.json to config-dev.json and fill in values."
    }

    Write-Host "`n===== Select Environment =====" -ForegroundColor Cyan
    for ($i = 0; $i -lt $configs.Count; $i++) {
        $envName = $configs[$i].BaseName -replace '^config-', ''
        $marker = if ($envName -eq 'prod') { ' [PRODUCTION]' } else { '' }
        Write-Host "  [$($i + 1)] $envName$marker" -ForegroundColor $(if ($envName -eq 'prod') { 'Red' } else { 'White' })
    }
    Write-Host ""

    $selection = Read-Host "Select environment (1-$($configs.Count)) [default: 1]"
    if (-not $selection) { $selection = '1' }
    $idx = [int]$selection - 1
    if ($idx -lt 0 -or $idx -ge $configs.Count) {
        throw "Invalid selection: $selection"
    }

    return $configs[$idx].FullName
}

function Select-JobInteractive {
    Write-Host "`n===== Select Mode =====" -ForegroundColor Cyan
    Write-Host "  [1] Export" -ForegroundColor White -NoNewline
    Write-Host " — Pull components from Dataverse" -ForegroundColor DarkGray
    Write-Host "  [2] Import" -ForegroundColor White -NoNewline
    Write-Host " — Push definitions to Dataverse" -ForegroundColor DarkGray
    Write-Host ""

    $modeSelection = Read-Host "Select mode (1-2)"
    if ($modeSelection -notin @('1', '2')) {
        throw "Invalid selection: $modeSelection"
    }

    if ($modeSelection -eq '1') {
        $jobs = @(
            @{ Name = 'Export-All';                  Desc = 'Export all components' }
            @{ Name = 'Export-Tables';               Desc = 'Tables, columns, and keys' }
            @{ Name = 'Export-Flows';                Desc = 'Power Automate cloud flows' }
            @{ Name = 'Export-Relationships';        Desc = 'Entity relationships (1:N, N:1, N:N)' }
            @{ Name = 'Export-Forms';                Desc = 'Model-driven app forms' }
            @{ Name = 'Export-Views';                Desc = 'Saved queries / views' }
            @{ Name = 'Export-WebResources';         Desc = 'JS, CSS, HTML, images' }
            @{ Name = 'Export-SecurityRoles';        Desc = 'Security roles and privileges' }
            @{ Name = 'Export-CanvasApps';           Desc = 'Canvas app metadata' }
            @{ Name = 'Export-EnvironmentVariables'; Desc = 'Environment variable definitions & values' }
            # Add project-specific export jobs here
        )
    }
    else {
        $jobs = @(
            @{ Name = 'Import-All';            Desc = 'Deploy choices, tables, relationships, templates, and flows' }
            @{ Name = 'Import-Choices';        Desc = 'Global option sets from tables/choices/' }
            @{ Name = 'Import-Tables';         Desc = 'Entities and columns from tables/*/' }
            @{ Name = 'Import-EmailTemplates'; Desc = 'Create/update managed email templates' }
            @{ Name = 'Import-Relationships';  Desc = '1:N relationships and lookup columns' }
            @{ Name = 'Import-Flows';          Desc = 'Env vars, connection refs, and flow definitions' }
            # Add project-specific import jobs here
        )
    }

    Write-Host "`n===== Select Job =====" -ForegroundColor Cyan
    for ($i = 0; $i -lt $jobs.Count; $i++) {
        Write-Host "  [$($i + 1)] $($jobs[$i].Name)" -ForegroundColor White -NoNewline
        Write-Host " — $($jobs[$i].Desc)" -ForegroundColor DarkGray
    }
    Write-Host ""

    $selection = Read-Host "Select job (1-$($jobs.Count))"
    $idx = [int]$selection - 1
    if ($idx -lt 0 -or $idx -ge $jobs.Count) {
        throw "Invalid selection: $selection"
    }

    return $jobs[$idx].Name
}

function Select-FlowInteractive {
    $flowsDir = Join-Path (Split-Path -Parent $scriptDir) 'flows'
    $prefix = $null
    try {
        $cfg = Get-Content (Join-Path $scriptDir "config-dev.json") -Raw | ConvertFrom-Json
        $prefix = $cfg.publisherPrefix
    }
    catch { }

    $pattern = if ($prefix) { "${prefix}_*.json" } else { '*.json' }
    $flowFiles = Get-ChildItem -Path $flowsDir -Filter $pattern -File -ErrorAction SilentlyContinue | Sort-Object Name

    if (-not $flowFiles -or $flowFiles.Count -eq 0) {
        Write-Host "  [Flows] No flow definitions found in $flowsDir" -ForegroundColor Yellow
        return $null
    }

    Write-Host "`n===== Select Flow =====" -ForegroundColor Cyan
    Write-Host "  [1] All Flows" -ForegroundColor White -NoNewline
    Write-Host " — Deploy all $($flowFiles.Count) flow(s)" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $flowFiles.Count; $i++) {
        Write-Host "  [$($i + 2)] $($flowFiles[$i].BaseName)" -ForegroundColor White
    }
    Write-Host ""

    $selection = Read-Host "Select flow (1-$($flowFiles.Count + 1)) [default: 1]"
    if (-not $selection) { $selection = '1' }
    $idx = [int]$selection

    if ($idx -eq 1) { return $null }
    elseif ($idx -ge 2 -and $idx -le ($flowFiles.Count + 1)) { return $flowFiles[$idx - 2].BaseName }
    else { throw "Invalid selection: $selection" }
}

function Get-ConnectionWithSolution {
    param([string]$ConfigPath)

    . "$scriptDir\Connect-Dataverse.ps1"
    $conn = Connect-Dataverse -ConfigPath $ConfigPath

    . "$scriptDir\Invoke-DataverseApi.ps1"
    $solCheck = Invoke-DataverseApi -Connection $conn -Endpoint "solutions?`$filter=uniquename eq '$($conn.SolutionName)'&`$select=solutionid,friendlyname,version"
    if (-not $solCheck.value -or $solCheck.value.Count -eq 0) {
        throw "Solution '$($conn.SolutionName)' not found in environment. Check config solutionUniqueName."
    }
    $sol = $solCheck.value[0]
    Write-Host "[Solution] $($sol.friendlyname) v$($sol.version) ($($conn.SolutionName))" -ForegroundColor Green

    return $conn
}

function Invoke-TrackedStep {
    param(
        [string]$StepName,
        [scriptblock]$Action,
        [string]$RecommendedFix = ''
    )

    $step = [ordered]@{
        name           = $StepName
        status         = 'Running'
        startTime      = Get-Date
        endTime        = $null
        duration       = $null
        error          = $null
        recommendedFix = $RecommendedFix
        result         = $null
    }

    Write-Host "`n--- Step: $StepName ---" -ForegroundColor Yellow
    try {
        $step.result = & $Action
        $step.status = 'Success'
    }
    catch {
        $step.status = 'Failed'
        $step.error = $_.Exception.Message
        Write-Host "[FAILED] $StepName : $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        $step.endTime = Get-Date
        $step.duration = ($step.endTime - $step.startTime).TotalSeconds
        Write-Host "  Duration: $([math]::Round($step.duration, 1))s | Status: $($step.status)" -ForegroundColor $(if ($step.status -eq 'Success') { 'Green' } else { 'Red' })
    }

    return $step
}

function Write-RunReport {
    param(
        [array]$Steps,
        [string]$Environment,
        [string]$Job,
        [string]$ReportPath
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if (-not $ReportPath) {
        $reportsDir = Join-Path $scriptDir "exports\$($connection.SolutionName)"
        if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
        $ReportPath = Join-Path $reportsDir "run-report-$timestamp.html"
    }

    $totalSteps = $Steps.Count
    $successCount = ($Steps | Where-Object { $_.status -eq 'Success' }).Count
    $failedCount = ($Steps | Where-Object { $_.status -eq 'Failed' }).Count
    $totalDuration = ($Steps | Measure-Object -Property duration -Sum).Sum

    $stepRows = $Steps | ForEach-Object {
        $statusColor = if ($_.status -eq 'Success') { '#28a745' } elseif ($_.status -eq 'Failed') { '#dc3545' } else { '#6c757d' }
        $errorRow = if ($_.error) { "<br><small style='color:#dc3545'>$([System.Web.HttpUtility]::HtmlEncode($_.error))</small>" } else { '' }
        $fixRow = if ($_.error -and $_.recommendedFix) { "<br><small style='color:#17a2b8'>Fix: $([System.Web.HttpUtility]::HtmlEncode($_.recommendedFix))</small>" } else { '' }
        "<tr><td>$([System.Web.HttpUtility]::HtmlEncode($_.name))</td><td style='color:$statusColor;font-weight:bold'>$($_.status)</td><td>$([math]::Round($_.duration, 1))s</td><td>$errorRow$fixRow</td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>AgenticIoT — Run Report $timestamp</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 2rem; background: #f8f9fa; }
h1 { color: #343a40; } h2 { color: #495057; margin-top: 2rem; }
.summary { display: flex; gap: 1rem; margin: 1rem 0; }
.card { padding: 1rem 1.5rem; border-radius: 8px; background: white; box-shadow: 0 1px 3px rgba(0,0,0,0.12); }
.card .value { font-size: 2rem; font-weight: bold; }
.card .label { color: #6c757d; font-size: 0.9rem; }
.success .value { color: #28a745; } .failed .value { color: #dc3545; }
table { width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.12); }
th { background: #343a40; color: white; padding: 0.75rem 1rem; text-align: left; }
td { padding: 0.75rem 1rem; border-bottom: 1px solid #dee2e6; }
tr:last-child td { border-bottom: none; }
</style></head><body>
<h1>AgenticIoT — Power Platform Run Report</h1>
<p><strong>Environment:</strong> $Environment | <strong>Job:</strong> $Job | <strong>Time:</strong> $timestamp</p>
<div class="summary">
    <div class="card"><div class="value">$totalSteps</div><div class="label">Total Steps</div></div>
    <div class="card success"><div class="value">$successCount</div><div class="label">Succeeded</div></div>
    <div class="card failed"><div class="value">$failedCount</div><div class="label">Failed</div></div>
    <div class="card"><div class="value">$([math]::Round($totalDuration, 1))s</div><div class="label">Total Duration</div></div>
</div>
<h2>Step Details</h2>
<table><thead><tr><th>Step</th><th>Status</th><th>Duration</th><th>Details</th></tr></thead>
<tbody>$($stepRows -join "`n")</tbody></table>
</body></html>
"@

    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    $html | Set-Content -Path $ReportPath -Encoding UTF8
    Write-Host "`n[Report] $ReportPath" -ForegroundColor Cyan
    try { Start-Process $ReportPath } catch { }

    return $ReportPath
}

# ============================================================
# Main Execution
# ============================================================

Write-Host @"

  ╔══════════════════════════════════════════════════╗
  ║   AgenticIoT — Power Platform Deploy      ║
  ╚══════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# --- Load .env ---
Load-EnvFile -Path (Join-Path (Split-Path -Parent $scriptDir) '.env')

# --- Resolve config path ---
if (-not $ConfigPath) {
    if ($Environment) {
        $ConfigPath = Join-Path $scriptDir "config-$Environment.json"
        if (-not (Test-Path $ConfigPath)) {
            throw "Config file not found for environment '$Environment': $ConfigPath"
        }
    }
    else {
        $ConfigPath = Select-EnvironmentInteractive
    }
}

# --- Extract environment name ---
$configFileName = [System.IO.Path]::GetFileNameWithoutExtension($ConfigPath)
$envName = if ($configFileName -match '^config-(.+)$') { $Matches[1] -replace '\.example$', '' } else { 'unknown' }

# --- Dry-run selection (interactive only) ---
if (-not $PSBoundParameters.ContainsKey('DryRun') -and -not $Environment -and -not $Job) {
    Write-Host "`n===== Dry Run? =====" -ForegroundColor Cyan
    Write-Host "  [1] No  — execute for real" -ForegroundColor White
    Write-Host "  [2] Yes — preview only (no changes)" -ForegroundColor White
    Write-Host ""
    $dryRunSelection = Read-Host "Select mode (1-2) [default: 1]"
    if ($dryRunSelection -eq '2') { $DryRun = [switch]::new($true) }
}

# --- Production safety ---
if ($envName -eq 'prod' -and -not $SkipConfirmation) {
    Write-Host "`n  !! WARNING: You are targeting PRODUCTION !!" -ForegroundColor Red
    Write-Host "  Environment: $envName" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "  Type YES (all caps) to continue"
    if ($confirm -ne 'YES') {
        Write-Host "  Aborted by user." -ForegroundColor Yellow
        exit 0
    }
}

# --- Select job ---
if (-not $Job) {
    $Job = Select-JobInteractive
}

# --- Flow selection (interactive only) ---
$selectedFlowName = $null
if ($Job -eq 'Import-Flows' -and -not $PSBoundParameters.ContainsKey('Job')) {
    $selectedFlowName = Select-FlowInteractive
}

Write-Host "`n[Config] Environment: $envName | Job: $Job | DryRun: $DryRun" -ForegroundColor Cyan

# --- Connect ---
$connection = Get-ConnectionWithSolution -ConfigPath $ConfigPath

# --- Source all scripts ---
. "$scriptDir\Invoke-DataverseApi.ps1"
. "$scriptDir\Export-Tables.ps1"
. "$scriptDir\Export-Relationships.ps1"
. "$scriptDir\Export-Flows.ps1"
. "$scriptDir\Export-Forms.ps1"
. "$scriptDir\Export-Views.ps1"
. "$scriptDir\Export-WebResources.ps1"
. "$scriptDir\Export-SecurityRoles.ps1"
. "$scriptDir\Export-CanvasApps.ps1"
. "$scriptDir\Export-EnvironmentVariables.ps1"
. "$scriptDir\Import-Choices.ps1"
. "$scriptDir\Import-Tables.ps1"
. "$scriptDir\Import-Relationships.ps1"
. "$scriptDir\Import-EmailTemplates.ps1"
. "$scriptDir\Import-Flows.ps1"
# Add project-specific script dot-sources here:
# . "$scriptDir\Initialize-MyQueues.ps1"
# . "$scriptDir\Seed-Data.ps1"

$outputBase = Join-Path $scriptDir "exports\$($connection.SolutionName)"
$tablesBase = Join-Path (Split-Path -Parent $scriptDir) 'tables'

# --- Job map ---
$jobMap = @{
    'Export-Tables'               = @{ Step = 'Export Tables';               Fn = { Export-Tables -Connection $connection -OutputPath (Join-Path $outputBase 'tables') };               Fix = 'Verify solution contains entity components (componenttype 1).' }
    'Export-Flows'                = @{ Step = 'Export Flows';                Fn = { Export-Flows -Connection $connection -OutputPath (Join-Path $outputBase 'flows') };                Fix = 'Verify solution contains workflow components (componenttype 29).' }
    'Export-Relationships'        = @{ Step = 'Export Relationships';        Fn = { Export-Relationships -Connection $connection -OutputPath (Join-Path $outputBase 'relationships') }; Fix = 'Verify solution contains entities with relationships.' }
    'Export-Forms'                = @{ Step = 'Export Forms';                Fn = { Export-Forms -Connection $connection -OutputPath (Join-Path $outputBase 'forms') };                Fix = 'Verify solution contains form components (componenttype 60).' }
    'Export-Views'                = @{ Step = 'Export Views';                Fn = { Export-Views -Connection $connection -OutputPath (Join-Path $outputBase 'views') };                Fix = 'Verify solution contains view components (componenttype 26).' }
    'Export-WebResources'         = @{ Step = 'Export Web Resources';        Fn = { Export-WebResources -Connection $connection -OutputPath (Join-Path $outputBase 'webresources') };   Fix = 'Verify solution contains web resource components (componenttype 61).' }
    'Export-SecurityRoles'        = @{ Step = 'Export Security Roles';       Fn = { Export-SecurityRoles -Connection $connection -OutputPath (Join-Path $outputBase 'securityroles') }; Fix = 'Verify solution contains security role components (componenttype 20).' }
    'Export-CanvasApps'           = @{ Step = 'Export Canvas Apps';          Fn = { Export-CanvasApps -Connection $connection -OutputPath (Join-Path $outputBase 'canvasapps') };       Fix = 'Verify solution contains canvas app components (componenttype 300).' }
    'Export-EnvironmentVariables' = @{ Step = 'Export Environment Variables'; Fn = { Export-EnvironmentVariables -Connection $connection -OutputPath (Join-Path $outputBase 'environmentvariables') }; Fix = 'Verify solution contains environment variable definitions (componenttype 380).' }
    'Import-Choices'              = @{ Step = 'Import Choices';              Fn = { Import-Choices -Connection $connection -SourcePath (Join-Path $tablesBase 'choices') -DryRun:$DryRun };              Fix = 'Verify tables/choices/ contains valid JSON choice definitions.' }
    'Import-Tables'               = @{ Step = 'Import Tables';               Fn = { Import-Tables -Connection $connection -SourcePath $tablesBase -DryRun:$DryRun };               Fix = 'Verify tables/*/definition.json files exist and are valid.' }
    'Import-EmailTemplates'       = @{ Step = 'Import Email Templates';      Fn = { Import-EmailTemplates -Connection $connection -SourcePath (Join-Path (Split-Path -Parent $scriptDir) 'automations\emails') -DryRun:$DryRun }; Fix = 'Verify automations/emails/templates.json and referenced HTML files exist.' }
    'Import-Relationships'        = @{ Step = 'Import Relationships';        Fn = { Import-Relationships -Connection $connection -SourcePath (Join-Path $tablesBase 'relationships') -DryRun:$DryRun }; Fix = 'Verify tables/relationships/definitions.json exists and is valid.' }
    'Import-Flows'                = @{ Step = 'Import Flows';                Fn = { Import-Flows -Connection $connection -SourcePath (Join-Path (Split-Path -Parent $scriptDir) 'flows') -FlowName $selectedFlowName -ReplaceExistingFlows:$ReplaceExistingFlows -DryRun:$DryRun }; Fix = 'Verify flows/ directory exists with valid JSON definitions.' }
    # Add project-specific jobs here:
    # 'Initialize-Queues' = @{ Step = 'Initialize Queues'; Fn = { Initialize-MyQueues -Connection $connection -DryRun:$DryRun }; Fix = 'Verify active departments exist.' }
}

# --- Execute ---
$runSteps = @()

if ($Job -eq 'Export-All') {
    foreach ($key in @('Export-Tables', 'Export-Relationships', 'Export-Flows', 'Export-Forms', 'Export-Views', 'Export-WebResources', 'Export-SecurityRoles', 'Export-CanvasApps', 'Export-EnvironmentVariables')) {
        $step = Invoke-TrackedStep -StepName $jobMap[$key].Step -Action $jobMap[$key].Fn -RecommendedFix $jobMap[$key].Fix
        $runSteps += $step
    }
}
elseif ($Job -eq 'Import-All') {
    foreach ($key in @('Import-Choices', 'Import-Tables', 'Import-EmailTemplates', 'Import-Relationships', 'Import-Flows')) {
        $step = Invoke-TrackedStep -StepName $jobMap[$key].Step -Action $jobMap[$key].Fn -RecommendedFix $jobMap[$key].Fix
        $runSteps += $step
    }
    # Add project-specific Import-All steps here

    # Publish customizations
    if (-not $DryRun) {
        $pubStep = Invoke-TrackedStep -StepName 'Publish Customizations' -Action {
            Write-Host "[Publish] Publishing all customizations..." -ForegroundColor Cyan
            Invoke-DataverseApi -Connection $connection -Endpoint 'PublishAllXml' -Method POST -Body @{}
            Write-Host "[Publish] Done." -ForegroundColor Green
        } -RecommendedFix 'Manually publish customizations in the Power Platform admin center.'
        $runSteps += $pubStep
    }
    else {
        Write-Host "`n[DRY-RUN] Would publish all customizations." -ForegroundColor Yellow
    }
}
else {
    $entry = $jobMap[$Job]
    if (-not $entry) { throw "Unknown job: $Job — add it to the jobMap in Deploy-Project.ps1" }
    $step = Invoke-TrackedStep -StepName $entry.Step -Action $entry.Fn -RecommendedFix $entry.Fix
    $runSteps += $step
}

# --- Report ---
$reportFile = Write-RunReport -Steps $runSteps -Environment $envName -Job $Job -ReportPath $ReportPath

# --- Summary ---
$successCount = ($runSteps | Where-Object { $_.status -eq 'Success' }).Count
$failedCount = ($runSteps | Where-Object { $_.status -eq 'Failed' }).Count

Write-Host "`n===== Run Complete =====" -ForegroundColor Cyan
Write-Host "  Steps: $($runSteps.Count) | Success: $successCount | Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Report: $reportFile" -ForegroundColor Gray

if ($failedCount -gt 0) { exit 1 } else { exit 0 }
