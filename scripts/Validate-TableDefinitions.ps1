<#
.SYNOPSIS
    Validate Dataverse table definition files for CI-safe preflight checks.
.DESCRIPTION
    Scans tables/**/definition.json files (excluding choices and relationships)
    and validates required fields, canonical dataType values, naming rules, and
    column constraints without any Dataverse API calls.
.EXAMPLE
    .\Validate-TableDefinitions.ps1
    # Validates all table definition files and returns a non-zero exit code on failure.
#>

$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$tablesRoot = Join-Path $repoRoot 'tables'

$canonicalDataTypes = @(
    'String',
    'Memo',
    'Integer',
    'Float',
    'Decimal',
    'Money',
    'Boolean',
    'DateTime',
    'Choice',
    'File',
    'Lookup'
)

$legacyTypeReplacements = [ordered]@{
    'SingleLine.Text' = 'String'
    'MultiLine.Text' = 'Memo'
    'Picklist' = 'Choice'
    'TwoOptions' = 'Boolean'
    'WholeNumber' = 'Integer'
    'DateAndTime' = 'DateTime'
}

$requiredValues = @('Required', 'Recommended', 'Optional')
$requiredTableFields = @(
    'schemaName',
    'displayName',
    'displayCollectionName',
    'description',
    'primaryNameColumn',
    'ownership',
    'changeTrackingEnabled',
    'columns'
)

$requiredColumnFields = @('schemaName', 'displayName', 'dataType')

$passedFiles = 0
$failedFiles = 0
$totalFiles = 0

function Get-LegacyReplacement {
    param(
        [string]$DataType
    )

    foreach ($key in $legacyTypeReplacements.Keys) {
        if ($key -ieq $DataType) {
            return [ordered]@{ Legacy = $key; Replacement = $legacyTypeReplacements[$key] }
        }
    }

    return $null
}

function Is-NullOrWhiteSpaceValue {
    param(
        [object]$Value
    )

    if ($null -eq $Value) {
        return $true
    }

    if ($Value -is [string]) {
        return [string]::IsNullOrWhiteSpace($Value)
    }

    return $false
}

Write-Host "`n===== Dataverse Table Definition Validation =====" -ForegroundColor Cyan

if (-not (Test-Path $tablesRoot)) {
    Write-Host "  [FAIL] tables folder not found" -ForegroundColor Red
    Write-Host "         Expected path: $tablesRoot" -ForegroundColor DarkGray
    Write-Host "`n===== Validation Summary =====" -ForegroundColor Cyan
    Write-Host "  Files:  0" -ForegroundColor Yellow
    Write-Host "  Passed: 0" -ForegroundColor Green
    Write-Host "  Failed: 1" -ForegroundColor Red
    exit 1
}

$definitionFiles = Get-ChildItem -Path $tablesRoot -Recurse -File -Filter 'definition.json' |
    Where-Object {
        $_.FullName -notmatch [regex]::Escape("$([System.IO.Path]::DirectorySeparatorChar)choices$([System.IO.Path]::DirectorySeparatorChar)") -and
        $_.FullName -notmatch [regex]::Escape("$([System.IO.Path]::DirectorySeparatorChar)relationships$([System.IO.Path]::DirectorySeparatorChar)")
    }

if (-not $definitionFiles) {
    Write-Host "  [PASS] No table definition files found to validate." -ForegroundColor Green
    Write-Host "`n===== Validation Summary =====" -ForegroundColor Cyan
    Write-Host "  Files:  0" -ForegroundColor Yellow
    Write-Host "  Passed: 0" -ForegroundColor Green
    Write-Host "  Failed: 0" -ForegroundColor Green
    exit 0
}

foreach ($file in $definitionFiles) {
    $totalFiles++
    $relativePath = $file.FullName -replace [regex]::Escape($repoRoot), '.'
    $fileErrors = [System.Collections.Generic.List[string]]::new()

    try {
        $raw = Get-Content $file.FullName -Raw
        $definition = $raw | ConvertFrom-Json
    }
    catch {
        $fileErrors.Add("Invalid JSON: $($_.Exception.Message)")
        Write-Host "  [FAIL] $relativePath" -ForegroundColor Red
        foreach ($err in $fileErrors) {
            Write-Host "         $err" -ForegroundColor DarkGray
        }
        $failedFiles++
        continue
    }

    foreach ($field in $requiredTableFields) {
        $hasProperty = $definition.PSObject.Properties.Name -contains $field
        if (-not $hasProperty) {
            $fileErrors.Add("Missing required table field '$field'.")
            continue
        }

        $value = $definition.$field
        if ($field -eq 'changeTrackingEnabled') {
            if ($null -eq $value) {
                $fileErrors.Add("Required table field '$field' is null.")
            }
            continue
        }

        if ($field -eq 'columns') {
            if ($null -eq $value) {
                $fileErrors.Add("Required table field '$field' is null.")
            }
            continue
        }

        if (Is-NullOrWhiteSpaceValue -Value $value) {
            $fileErrors.Add("Required table field '$field' is empty.")
        }
    }

    $tableSchemaName = [string]$definition.schemaName
    if (-not [string]::IsNullOrWhiteSpace($tableSchemaName)) {
        if ($tableSchemaName -cnotmatch '^andy_[a-z0-9_]+$') {
            $fileErrors.Add("Table schemaName '$tableSchemaName' must start with 'andy_' and be lowercase.")
        }
    }

    $columns = $definition.columns
    if ($null -ne $columns) {
        if ($columns -isnot [System.Collections.IEnumerable] -or $columns -is [string]) {
            $fileErrors.Add("Table field 'columns' must be an array.")
        }
        else {
            $columnIndex = 0
            foreach ($column in $columns) {
                $columnIndex++
                $columnLabel = "Column #$columnIndex"

                foreach ($field in $requiredColumnFields) {
                    $hasProperty = $column.PSObject.Properties.Name -contains $field
                    if (-not $hasProperty) {
                        $fileErrors.Add("$columnLabel is missing required field '$field'.")
                        continue
                    }

                    if (Is-NullOrWhiteSpaceValue -Value $column.$field) {
                        $fileErrors.Add("$columnLabel field '$field' is empty.")
                    }
                }

                $columnSchemaName = [string]$column.schemaName
                if (-not [string]::IsNullOrWhiteSpace($columnSchemaName)) {
                    if ($columnSchemaName -cnotmatch '^andy_[a-z0-9_]+$') {
                        $fileErrors.Add("$columnLabel schemaName '$columnSchemaName' must start with 'andy_' and be lowercase.")
                    }
                }

                $dataType = [string]$column.dataType
                if (-not [string]::IsNullOrWhiteSpace($dataType)) {
                    $legacy = Get-LegacyReplacement -DataType $dataType
                    if ($null -ne $legacy) {
                        $fileErrors.Add("$columnLabel dataType '$($legacy.Legacy)' is legacy. Use '$($legacy.Replacement)' instead.")
                    }
                    elseif (-not ($canonicalDataTypes -ccontains $dataType)) {
                        $fileErrors.Add("$columnLabel dataType '$dataType' is invalid. Allowed values: $($canonicalDataTypes -join ', ').")
                    }
                }

                if ($column.PSObject.Properties.Name -contains 'required') {
                    $requiredValue = [string]$column.required
                    if (-not [string]::IsNullOrWhiteSpace($requiredValue) -and -not ($requiredValues -ccontains $requiredValue)) {
                        $fileErrors.Add("$columnLabel required value '$requiredValue' is invalid. Allowed values: $($requiredValues -join ', ').")
                    }
                }

                if ($dataType -ceq 'Choice') {
                    $hasChoiceName = $column.PSObject.Properties.Name -contains 'choiceName'
                    if (-not $hasChoiceName -or (Is-NullOrWhiteSpaceValue -Value $column.choiceName)) {
                        $fileErrors.Add("$columnLabel with dataType 'Choice' must include non-empty choiceName.")
                    }
                }

                if ($dataType -ceq 'Lookup') {
                    $hasTarget = $column.PSObject.Properties.Name -contains 'target'
                    if (-not $hasTarget -or (Is-NullOrWhiteSpaceValue -Value $column.target)) {
                        $fileErrors.Add("$columnLabel with dataType 'Lookup' must include non-empty target.")
                    }
                }
            }
        }
    }

    if ($fileErrors.Count -gt 0) {
        Write-Host "  [FAIL] $relativePath" -ForegroundColor Red
        foreach ($err in $fileErrors) {
            Write-Host "         $err" -ForegroundColor DarkGray
        }
        $failedFiles++
    }
    else {
        Write-Host "  [PASS] $relativePath" -ForegroundColor Green
        $passedFiles++
    }
}

Write-Host "`n===== Validation Summary =====" -ForegroundColor Cyan
Write-Host "  Files:  $totalFiles" -ForegroundColor Yellow
Write-Host "  Passed: $passedFiles" -ForegroundColor Green
Write-Host "  Failed: $failedFiles" -ForegroundColor $(if ($failedFiles -gt 0) { 'Red' } else { 'Green' })

if ($failedFiles -gt 0) {
    exit 1
}

exit 0