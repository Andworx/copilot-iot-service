<#
.SYNOPSIS
    Validate deployment prerequisites for this Power Platform project.
.DESCRIPTION
    Checks config files, .env secrets, script syntax, and optionally tests
    Dataverse connectivity. Run this before your first deployment on a new
    machine or after changes to config-{env}.json or .env.
.PARAMETER TestConnection
    If set, also authenticates and tests Dataverse API connectivity.
.PARAMETER Environment
    Target environment to validate. Default: dev.
#>
param(
    [switch]$TestConnection,
    [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$passed = 0
$failed = 0
$warnings = 0

function Write-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor DarkGray }
        $script:failed++
    }
}

function Write-Warn {
    param([string]$Name, [string]$Detail = '')
    Write-Host "  [WARN] $Name" -ForegroundColor Yellow
    if ($Detail) { Write-Host "         $Detail" -ForegroundColor DarkGray }
    $script:warnings++
}

Write-Host "`n===== Power Platform Deployment Validation =====" -ForegroundColor Cyan

# --- 0. Project token stamping ---
Write-Host "`n--- Project Tokens ---" -ForegroundColor Yellow

$tokensFile = Join-Path (Split-Path -Parent $scriptDir) 'project.tokens.json'

if (-not (Test-Path $tokensFile)) {
    Write-Warn "project.tokens.json not found" "Create it at the repo root and run Apply-ProjectTokens.ps1."
}
else {
    try {
        $tokenDef = Get-Content $tokensFile -Raw | ConvertFrom-Json

        $pendingTokens  = [System.Collections.Generic.List[string]]::new()

        foreach ($prop in $tokenDef.required.PSObject.Properties) {
            if ($prop.Value -eq $prop.Name) {
                $pendingTokens.Add($prop.Name)
            }
        }

        if ($pendingTokens.Count -gt 0) {
            Write-Check "All required tokens are stamped" $false "Pending: $($pendingTokens -join ', ')"
            Write-Warn  "Run Apply-ProjectTokens.ps1 after filling in the missing values" ".\scripts\Apply-ProjectTokens.ps1"
        }
        else {
            Write-Check "All required tokens are stamped" $true
        }

        # Check if CLIENT_ID is set (needed for automations)
        $clientIdSet = $false
        if ($tokenDef.optional) {
            $clientId = $tokenDef.optional.YOUR_CLIENT_ID
            if ($clientId -and $clientId -ne 'YOUR_CLIENT_ID') {
                $clientIdSet = $true
            }
        }

        if (-not $clientIdSet -and $pendingTokens.Count -eq 0) {
            Write-Warn "YOUR_CLIENT_ID not set" "Power Automate automations will not work. Add it to project.tokens.json and run Apply-ProjectTokens.ps1."
        }

        # Verify no YOUR_* placeholders remain in scanned file types
        $fileExtensions   = '*.ps1','*.json','*.ts','*.md','*.yml','*.yaml','*.html','*.txt'
        $repoRoot         = Split-Path -Parent $scriptDir
        $filesWithTokens  = Get-ChildItem -Path $repoRoot -Recurse -File -Include $fileExtensions |
            Where-Object {
                $_.FullName -notmatch [regex]::Escape("$([System.IO.Path]::DirectorySeparatorChar).git$([System.IO.Path]::DirectorySeparatorChar)") -and
                $_.Name -notin @('project.tokens.json', 'project.tokens.applied.json')
            } |
            Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match 'YOUR_[A-Z_]+' }

        if ($filesWithTokens) {
            Write-Check "No YOUR_* placeholders remain in repo files" $false "$($filesWithTokens.Count) file(s) still contain placeholder tokens."
            foreach ($f in $filesWithTokens | Select-Object -First 5) {
                Write-Host "         $($f.FullName -replace [regex]::Escape($repoRoot), '.')" -ForegroundColor DarkGray
            }
            if ($filesWithTokens.Count -gt 5) {
                Write-Host "         ... and $($filesWithTokens.Count - 5) more." -ForegroundColor DarkGray
            }
        }
        else {
            Write-Check "No YOUR_* placeholders remain in repo files" $true
        }
    }
    catch {
        Write-Check "project.tokens.json is valid JSON" $false $_.Exception.Message
    }
}

# --- 2. Config files ---
Write-Host "`n--- Configuration Files ---" -ForegroundColor Yellow

$configPath = Join-Path $scriptDir "config-$Environment.json"
$configExists = Test-Path $configPath
Write-Check "config-$Environment.json exists" $configExists

if ($configExists) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-Check "config-$Environment.json is valid JSON" $true
        Write-Check "environmentUrl is set" ([bool]$config.environmentUrl)
        Write-Check "tenantId is set" ([bool]$config.tenantId)
        Write-Check "clientId is set" ([bool]$config.clientId)
        Write-Check "solutionUniqueName is set" ([bool]$config.solutionUniqueName)

        $validCloudValues = @('commercial', 'gcc', 'gcch', 'dod')
        $cloudValue = [string]$config.cloudEnvironment
        $cloudSet = -not [string]::IsNullOrWhiteSpace($cloudValue)
        Write-Check "cloudEnvironment is set" $cloudSet
        if ($cloudSet) {
            $isValidCloud = $cloudValue.Trim().ToLowerInvariant() -in $validCloudValues
            Write-Check "cloudEnvironment is valid" $isValidCloud "Valid values: $($validCloudValues -join ', ')"
        }
        elseif ([bool]$config.authEndpoint) {
            Write-Warn "Using legacy authEndpoint in config" "Set cloudEnvironment to commercial, gcc, gcch, or dod."
        }

        # Warn if tokens are still in place
        $configRaw = Get-Content $configPath -Raw
        if ($configRaw -match 'YOUR_') {
            Write-Check "No placeholder tokens remain in config" $false "Replace all YOUR_* values in config-$Environment.json (see PROJECT.md)."
        }
        else {
            Write-Check "No placeholder tokens remain in config" $true
        }
    }
    catch {
        Write-Check "config-$Environment.json is valid JSON" $false $_.Exception.Message
    }
}

# Check for other environment configs
foreach ($env in @('dev', 'prod', 'staging')) {
    $p = Join-Path $scriptDir "config-$env.json"
    if ($env -ne $Environment -and -not (Test-Path $p)) {
        Write-Warn "config-$env.json not found" "Optional — add when ready for $env environment."
    }
}

# --- 3. .env file ---
Write-Host "`n--- Environment Secrets ---" -ForegroundColor Yellow

$envPath = Join-Path (Split-Path -Parent $scriptDir) '.env'
$envExists = Test-Path $envPath
Write-Check ".env file exists" $envExists

if ($envExists) {
    $envContent = Get-Content $envPath -Raw
    $envUpper = $Environment.ToUpper()
    $hasEnvSecret = $envContent -match "DATAVERSE_CLIENT_SECRET_$envUpper\s*="
    $hasGenericSecret = $envContent -match 'DATAVERSE_CLIENT_SECRET\s*='
    Write-Check "DATAVERSE_CLIENT_SECRET_$envUpper is set" $hasEnvSecret
    if (-not $hasEnvSecret) {
        Write-Warn "Fallback: DATAVERSE_CLIENT_SECRET" $(if ($hasGenericSecret) { 'Found — will be used as fallback.' } else { 'Not found either. Auth will fail.' })
    }

    if ($envContent -match 'your-.*-secret-here') {
        Write-Check "Secret values are not placeholders" $false "Replace placeholder values in .env with actual secrets."
    }
    else {
        Write-Check "Secret values are not placeholders" $true
    }
}

# --- 4. Script files ---
Write-Host "`n--- PowerShell Scripts ---" -ForegroundColor Yellow

$requiredScripts = @(
    'Connect-Dataverse.ps1',
    'Invoke-DataverseApi.ps1',
    'Deploy-Project.ps1',
    'Validate-TableDefinitions.ps1',
    'Export-Tables.ps1',
    'Export-Relationships.ps1',
    'Export-Flows.ps1',
    'Export-EnvironmentVariables.ps1'
)

foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path $scriptDir $script
    $exists = Test-Path $scriptPath
    Write-Check "$script exists" $exists

    if ($exists) {
        try {
            $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
            Write-Check "$script parses without errors" $true
        }
        catch {
            Write-Check "$script parses without errors" $false $_.Exception.Message
        }
    }
}

# --- 5. Documentation ---
Write-Host "`n--- Documentation ---" -ForegroundColor Yellow

foreach ($doc in @('DEPLOYMENT_GUIDE.md', 'QUICK_REFERENCE.md')) {
    $docPath = Join-Path $scriptDir $doc
    if (Test-Path $docPath) {
        Write-Check "$doc exists" $true
    }
    else {
        Write-Warn "$doc not found" "Optional but recommended."
    }
}

# --- 6. Connectivity test ---
if ($TestConnection) {
    Write-Host "`n--- Connectivity Test ---" -ForegroundColor Yellow

    try {
        if ($envExists) {
            Get-Content $envPath | ForEach-Object {
                $line = $_.Trim()
                if ($line -and -not $line.StartsWith('#')) {
                    $eqIdx = $line.IndexOf('=')
                    if ($eqIdx -gt 0) {
                        $k = $line.Substring(0, $eqIdx).Trim()
                        $v = $line.Substring($eqIdx + 1).Trim()
                        [System.Environment]::SetEnvironmentVariable($k, $v, 'Process')
                    }
                }
            }
        }

        . "$scriptDir\Connect-Dataverse.ps1"
        . "$scriptDir\Invoke-DataverseApi.ps1"

        $conn = Connect-Dataverse -ConfigPath $configPath
        Write-Check "Authentication successful" $true

        $solCheck = Invoke-DataverseApi -Connection $conn -Endpoint "solutions?`$filter=uniquename eq '$($conn.SolutionName)'&`$select=solutionid,friendlyname"
        $solOk = $solCheck.value -and $solCheck.value.Count -gt 0
        Write-Check "Solution '$($conn.SolutionName)' exists" $solOk
    }
    catch {
        Write-Check "Connectivity test" $false $_.Exception.Message
    }
}

# --- Summary ---
Write-Host "`n===== Validation Summary =====" -ForegroundColor Cyan
Write-Host "  Passed:   $passed" -ForegroundColor Green
Write-Host "  Failed:   $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Warnings: $warnings" -ForegroundColor $(if ($warnings -gt 0) { 'Yellow' } else { 'Green' })

if ($failed -gt 0) {
    Write-Host "`n  Fix the failed checks above before running Deploy-Project.ps1" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "`n  All checks passed! Ready to deploy." -ForegroundColor Green
    exit 0
}
