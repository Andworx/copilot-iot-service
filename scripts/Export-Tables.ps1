<#
.SYNOPSIS
    Export tables (entities), columns, and keys from the YOUR_SOLUTION_NAME solution.
.PARAMETER ConfigPath
    Path to environment config JSON.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/YOUR_SOLUTION_NAME/tables.
#>

function Export-Tables {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Tables ===" -ForegroundColor Cyan

    # --- Resolve the solution ID ---
    $solutionName = $Connection.SolutionName
    Write-Host "[Tables] Looking up solution '$solutionName'..." -ForegroundColor Gray
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid,friendlyname,uniquename"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) {
        throw "Solution '$solutionName' not found."
    }
    $solutionId = $solutions.value[0].solutionid
    Write-Host "[Tables] Solution ID: $solutionId" -ForegroundColor Gray

    # --- Get entity components in the solution (componenttype 1 = Entity) ---
    Write-Host "[Tables] Querying solution entity components..." -ForegroundColor Gray
    $components = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 1&`$select=objectid"

    if (-not $components -or $components.Count -eq 0) {
        Write-Host "[Tables] No entity components found in solution." -ForegroundColor Yellow
        return @{ tablesExported = 0; tables = @() }
    }
    Write-Host "[Tables] Found $($components.Count) entities in solution." -ForegroundColor Gray

    $summary = @()

    foreach ($comp in $components) {
        $entityId = $comp.objectid
        try {
            $entity = Invoke-DataverseApi -Connection $Connection -Endpoint "EntityDefinitions($entityId)?`$select=LogicalName,SchemaName,DisplayName,PrimaryIdAttribute,PrimaryNameAttribute,LogicalCollectionName,EntitySetName,IsCustomEntity&`$expand=Attributes(`$select=LogicalName,SchemaName,DisplayName,AttributeType,IsCustomAttribute,RequiredLevel),Keys(`$select=LogicalName,SchemaName,DisplayName,KeyAttributes)"

            $logicalName = $entity.LogicalName
            $displayName = if ($entity.DisplayName.UserLocalizedLabel) { $entity.DisplayName.UserLocalizedLabel.Label } else { $logicalName }

            Write-Host "  [Table] $displayName ($logicalName)" -ForegroundColor White

            $tableData = [ordered]@{
                exportedOnUtc        = (Get-Date).ToUniversalTime().ToString('o')
                logicalName          = $logicalName
                schemaName           = $entity.SchemaName
                displayName          = $displayName
                entitySetName        = $entity.EntitySetName
                logicalCollectionName = $entity.LogicalCollectionName
                primaryIdAttribute   = $entity.PrimaryIdAttribute
                primaryNameAttribute = $entity.PrimaryNameAttribute
                isCustomEntity       = $entity.IsCustomEntity
                attributeCount       = ($entity.Attributes | Measure-Object).Count
                keyCount             = ($entity.Keys | Measure-Object).Count
                attributes           = @($entity.Attributes | ForEach-Object {
                    [ordered]@{
                        logicalName     = $_.LogicalName
                        schemaName      = $_.SchemaName
                        displayName     = if ($_.DisplayName.UserLocalizedLabel) { $_.DisplayName.UserLocalizedLabel.Label } else { $_.LogicalName }
                        attributeType   = $_.AttributeType
                        isCustom        = $_.IsCustomAttribute
                        requiredLevel   = if ($_.RequiredLevel) { $_.RequiredLevel.Value } else { $null }
                    }
                })
                keys                 = @($entity.Keys | ForEach-Object {
                    [ordered]@{
                        logicalName   = $_.LogicalName
                        schemaName    = $_.SchemaName
                        displayName   = if ($_.DisplayName.UserLocalizedLabel) { $_.DisplayName.UserLocalizedLabel.Label } else { $_.LogicalName }
                        keyAttributes = $_.KeyAttributes
                    }
                })
            }

            $filePath = Join-Path $OutputPath "$logicalName.json"
            $tableData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
            Write-Host "    -> $filePath" -ForegroundColor DarkGray

            $summary += [ordered]@{
                logicalName    = $logicalName
                displayName    = $displayName
                attributeCount = $tableData.attributeCount
                keyCount       = $tableData.keyCount
                isCustom       = $entity.IsCustomEntity
            }
        }
        catch {
            Write-Warning "[Tables] Failed to export entity $entityId : $_"
        }
    }

    # Write summary
    $summaryData = [ordered]@{
        exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
        totalTables   = $summary.Count
        tables        = $summary
    }
    $summaryPath = Join-Path $OutputPath '_summary.json'
    $summaryData | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "`n[Tables] Exported $($summary.Count) tables to $OutputPath" -ForegroundColor Green

    return $summaryData
}
