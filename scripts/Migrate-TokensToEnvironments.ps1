<# 
.SYNOPSIS
Migrates project.tokens.json from flat structure to environment-scoped structure.

.DESCRIPTION
Converts old format (flat required/optional objects) to new format (nested by environment).
Automatically discovers environments from existing config-*.json files.
Preserves existing token values and creates environment sections for dev, test, prod.

.PARAMETER SourceFile
Path to existing project.tokens.json (default: script directory)

.PARAMETER TargetFile
Path where migrated file will be written (default: overwrites source after backup)

.PARAMETER Environments
Comma-separated list of environments to create. Default: dev, test, prod

.PARAMETER NoBackup
If specified, does not create a backup of the original file.

.EXAMPLE
.\Migrate-TokensToEnvironments.ps1
# Automatically detects environments from config-*.json, migrates in-place, creates backup

.EXAMPLE
.\Migrate-TokensToEnvironments.ps1 -Environments "dev,staging,prod" -NoBackup
# Migrates with custom environment list, no backup created
#>

param(
    [string]$SourceFile = "$PSScriptRoot\project.tokens.json",
    [string]$TargetFile = $null,
    [string]$Environments = "dev,test,prod",
    [switch]$NoBackup
)

# Detect environments from config files
$configFiles = @(Get-ChildItem -Path $PSScriptRoot -Filter "config-*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    $name = $_.BaseName -replace "^config-(.+)$", '$1'
    $name
})

$discoveredEnvs = @($configFiles | Sort-Object -Unique)

if ($discoveredEnvs.Count -gt 0) {
    Write-Host "Discovered environments from config files: $($discoveredEnvs -join ', ')" -ForegroundColor Cyan
    $Environments = $discoveredEnvs -join ','
}

$environmentList = @($Environments -split ',' | ForEach-Object { $_.Trim() })

if (-not (Test-Path $SourceFile)) {
    Write-Error "Source file not found: $SourceFile"
    exit 1
}

# Load existing tokens
$existingTokens = Get-Content $SourceFile | ConvertFrom-Json

# Validate it's old format (required/optional are objects, not arrays)
if ($existingTokens.required -is [object] -and $existingTokens.required -isnot [array]) {
    Write-Host "Detected old flat token format. Converting..." -ForegroundColor Green
} else {
    Write-Host "File appears to already be in new environment-scoped format or is invalid." -ForegroundColor Yellow
    exit 0
}

# Extract token names from old format
$requiredTokens = @($existingTokens.required.PSObject.Properties.Name)
$optionalTokens = @($existingTokens.optional.PSObject.Properties.Name)

Write-Host "Found $($requiredTokens.Count) required tokens and $($optionalTokens.Count) optional tokens" -ForegroundColor Cyan

# Build new structure
$newTokens = @{
    "_comment" = "Environment-scoped tokens. Fill in known values for each environment and run scripts/Apply-ProjectTokens.ps1 -Environment {env}. Leave as placeholder string if not yet known. Set optional tokens to null to skip them."
    "required" = @($requiredTokens)
    "optional" = @($optionalTokens)
}

# Create environment sections
foreach ($env in $environmentList) {
    $envSection = @{
        "required" = @{}
        "optional" = @{}
    }
    
    # Populate with existing values
    foreach ($token in $requiredTokens) {
        $envSection.required[$token] = $existingTokens.required[$token]
    }
    
    foreach ($token in $optionalTokens) {
        $value = if ($null -eq $existingTokens.optional[$token]) { $null } else { $existingTokens.optional[$token] }
        $envSection.optional[$token] = $value
    }
    
    $newTokens[$env] = $envSection
}

# Write output
if ([string]::IsNullOrEmpty($TargetFile)) {
    $TargetFile = $SourceFile
}

# Create backup if needed
if (-not $NoBackup -and $TargetFile -eq $SourceFile) {
    $backupFile = "$SourceFile.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Path $SourceFile -Destination $backupFile
    Write-Host "Backup created: $backupFile" -ForegroundColor Cyan
}

# Write migrated file with formatting
$newTokens | ConvertTo-Json -Depth 5 | Set-Content -Path $TargetFile -Encoding UTF8

Write-Host "Migration complete!" -ForegroundColor Green
Write-Host "New structure written to: $TargetFile" -ForegroundColor Cyan
Write-Host "Environments created: $($environmentList -join ', ')" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Edit $TargetFile with environment-specific token values"
Write-Host "2. Run: .\Apply-ProjectTokens.ps1 -Environment dev" -ForegroundColor White
Write-Host "3. Run: .\Apply-ProjectTokens.ps1 -Environment test"
Write-Host "4. Run: .\Apply-ProjectTokens.ps1 -Environment prod"
