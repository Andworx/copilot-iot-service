<#
.SYNOPSIS
    Export entity relationships (1:N, N:1, N:N) for all tables in the YOUR_SOLUTION_NAME solution.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/YOUR_SOLUTION_NAME/relationships.
#>

function Export-Relationships {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Relationships ===" -ForegroundColor Cyan

    # --- Resolve solution ID ---
    $solutionName = $Connection.SolutionName
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) { throw "Solution '$solutionName' not found." }
    $solutionId = $solutions.value[0].solutionid

    # --- Get entities in solution ---
    $components = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 1&`$select=objectid"
    if (-not $components -or $components.Count -eq 0) {
        Write-Host "[Relationships] No entities in solution." -ForegroundColor Yellow
        return @{ totalEntities = 0 }
    }

    $summary = @()

    foreach ($comp in $components) {
        $entityId = $comp.objectid
        try {
            # Get entity logical name
            $entity = Invoke-DataverseApi -Connection $Connection -Endpoint "EntityDefinitions($entityId)?`$select=LogicalName,DisplayName"
            $logicalName = $entity.LogicalName
            $displayName = if ($entity.DisplayName.UserLocalizedLabel) { $entity.DisplayName.UserLocalizedLabel.Label } else { $logicalName }

            Write-Host "  [Rel] $displayName ($logicalName)" -ForegroundColor White

            # Fetch all three relationship types
            $oneToMany = @()
            try {
                $o2m = Get-AllDataverseRecords -Connection $Connection -Endpoint "EntityDefinitions(LogicalName='$logicalName')/OneToManyRelationships?`$select=SchemaName,ReferencedEntity,ReferencedAttribute,ReferencingEntity,ReferencingAttribute,CascadeConfiguration"
                $oneToMany = @($o2m | ForEach-Object {
                    [ordered]@{
                        schemaName            = $_.SchemaName
                        referencedEntity      = $_.ReferencedEntity
                        referencedAttribute   = $_.ReferencedAttribute
                        referencingEntity     = $_.ReferencingEntity
                        referencingAttribute  = $_.ReferencingAttribute
                    }
                })
            } catch { Write-Warning "    1:N query failed for $logicalName : $_" }

            $manyToOne = @()
            try {
                $m2o = Get-AllDataverseRecords -Connection $Connection -Endpoint "EntityDefinitions(LogicalName='$logicalName')/ManyToOneRelationships?`$select=SchemaName,ReferencedEntity,ReferencedAttribute,ReferencingEntity,ReferencingAttribute"
                $manyToOne = @($m2o | ForEach-Object {
                    [ordered]@{
                        schemaName            = $_.SchemaName
                        referencedEntity      = $_.ReferencedEntity
                        referencedAttribute   = $_.ReferencedAttribute
                        referencingEntity     = $_.ReferencingEntity
                        referencingAttribute  = $_.ReferencingAttribute
                    }
                })
            } catch { Write-Warning "    N:1 query failed for $logicalName : $_" }

            $manyToMany = @()
            try {
                $m2m = Get-AllDataverseRecords -Connection $Connection -Endpoint "EntityDefinitions(LogicalName='$logicalName')/ManyToManyRelationships?`$select=SchemaName,Entity1LogicalName,Entity1IntersectAttribute,Entity2LogicalName,Entity2IntersectAttribute,IntersectEntityName"
                $manyToMany = @($m2m | ForEach-Object {
                    [ordered]@{
                        schemaName                = $_.SchemaName
                        entity1LogicalName        = $_.Entity1LogicalName
                        entity1IntersectAttribute = $_.Entity1IntersectAttribute
                        entity2LogicalName        = $_.Entity2LogicalName
                        entity2IntersectAttribute = $_.Entity2IntersectAttribute
                        intersectEntityName       = $_.IntersectEntityName
                    }
                })
            } catch { Write-Warning "    N:N query failed for $logicalName : $_" }

            $relData = [ordered]@{
                exportedOnUtc    = (Get-Date).ToUniversalTime().ToString('o')
                logicalName      = $logicalName
                displayName      = $displayName
                oneToManyCount   = $oneToMany.Count
                manyToOneCount   = $manyToOne.Count
                manyToManyCount  = $manyToMany.Count
                oneToMany        = $oneToMany
                manyToOne        = $manyToOne
                manyToMany       = $manyToMany
            }

            $filePath = Join-Path $OutputPath "$logicalName.json"
            $relData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
            Write-Host "    -> $filePath" -ForegroundColor DarkGray

            $summary += [ordered]@{
                logicalName     = $logicalName
                displayName     = $displayName
                oneToManyCount  = $oneToMany.Count
                manyToOneCount  = $manyToOne.Count
                manyToManyCount = $manyToMany.Count
            }
        }
        catch {
            Write-Warning "[Relationships] Failed for entity $entityId : $_"
        }
    }

    $summaryData = [ordered]@{
        exportedOnUtc  = (Get-Date).ToUniversalTime().ToString('o')
        totalEntities  = $summary.Count
        entities       = $summary
    }
    $summaryPath = Join-Path $OutputPath '_summary.json'
    $summaryData | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "`n[Relationships] Exported relationships for $($summary.Count) entities." -ForegroundColor Green

    return $summaryData
}
