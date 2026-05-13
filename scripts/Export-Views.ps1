<#
.SYNOPSIS
    Export saved queries (views) for all entities in the AgenticIoT solution.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/AgenticIoT/views.
#>

function Export-Views {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Views ===" -ForegroundColor Cyan

    # --- Resolve solution ID ---
    $solutionName = $Connection.SolutionName
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) { throw "Solution '$solutionName' not found." }
    $solutionId = $solutions.value[0].solutionid

    # --- Get entity components ---
    $entityComponents = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 1&`$select=objectid"

    # --- Also get view components directly (componenttype 26 = SavedQuery) ---
    $viewComponents = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 26&`$select=objectid"

    $entityNames = @()
    foreach ($comp in $entityComponents) {
        try {
            $entity = Invoke-DataverseApi -Connection $Connection -Endpoint "EntityDefinitions($($comp.objectid))?`$select=LogicalName"
            $entityNames += $entity.LogicalName
        } catch { }
    }

    $queryTypeNames = @{
        0 = 'PublicView'; 1 = 'AdvancedFind'; 2 = 'Associated'; 4 = 'QuickFind'; 16 = 'Lookup'; 64 = 'SubGrid'
    }

    $summary = @()
    $processedViewIds = @{}

    # --- Export views by direct solution component ---
    foreach ($comp in $viewComponents) {
        $viewId = $comp.objectid
        if ($processedViewIds.ContainsKey($viewId)) { continue }
        $processedViewIds[$viewId] = $true

        try {
            $view = Invoke-DataverseApi -Connection $Connection -Endpoint "savedqueries($viewId)?`$select=name,returnedtypecode,fetchxml,layoutxml,querytype,savedqueryid,description,isdefault"

            $entityName = $view.returnedtypecode
            $queryType = $view.querytype
            $typeName = if ($queryTypeNames.ContainsKey($queryType)) { $queryTypeNames[$queryType] } else { "Type$queryType" }
            $safeName = ($view.name -replace '[\\/:*?"<>|]', '_')

            Write-Host "  [View] $($view.name) ($entityName / $typeName)" -ForegroundColor White

            $entityDir = Join-Path $OutputPath $entityName
            if (-not (Test-Path $entityDir)) { New-Item -ItemType Directory -Path $entityDir -Force | Out-Null }

            $viewData = [ordered]@{
                exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
                savedQueryId  = $view.savedqueryid
                name          = $view.name
                entityName    = $entityName
                queryType     = $queryType
                typeName      = $typeName
                isDefault     = $view.isdefault
                description   = $view.description
                fetchXml      = $view.fetchxml
                layoutXml     = $view.layoutxml
            }
            $filePath = Join-Path $entityDir "$safeName.json"
            $viewData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
            Write-Host "    -> $filePath" -ForegroundColor DarkGray

            $summary += [ordered]@{
                savedQueryId = $view.savedqueryid
                name         = $view.name
                entityName   = $entityName
                typeName     = $typeName
                isDefault    = $view.isdefault
            }
        }
        catch {
            Write-Warning "[Views] Failed to export view $viewId : $_"
        }
    }

    # --- Export views by entity ---
    foreach ($entityName in $entityNames) {
        try {
            $views = Get-AllDataverseRecords -Connection $Connection -Endpoint "savedqueries?`$filter=returnedtypecode eq '$entityName'&`$select=name,returnedtypecode,fetchxml,layoutxml,querytype,savedqueryid,description,isdefault"

            foreach ($view in $views) {
                if ($processedViewIds.ContainsKey($view.savedqueryid)) { continue }
                $processedViewIds[$view.savedqueryid] = $true

                $queryType = $view.querytype
                $typeName = if ($queryTypeNames.ContainsKey($queryType)) { $queryTypeNames[$queryType] } else { "Type$queryType" }
                $safeName = ($view.name -replace '[\\/:*?"<>|]', '_')

                Write-Host "  [View] $($view.name) ($entityName / $typeName)" -ForegroundColor White

                $entityDir = Join-Path $OutputPath $entityName
                if (-not (Test-Path $entityDir)) { New-Item -ItemType Directory -Path $entityDir -Force | Out-Null }

                $viewData = [ordered]@{
                    exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
                    savedQueryId  = $view.savedqueryid
                    name          = $view.name
                    entityName    = $entityName
                    queryType     = $queryType
                    typeName      = $typeName
                    isDefault     = $view.isdefault
                    description   = $view.description
                    fetchXml      = $view.fetchxml
                    layoutXml     = $view.layoutxml
                }
                $filePath = Join-Path $entityDir "$safeName.json"
                $viewData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8

                $summary += [ordered]@{
                    savedQueryId = $view.savedqueryid
                    name         = $view.name
                    entityName   = $entityName
                    typeName     = $typeName
                    isDefault    = $view.isdefault
                }
            }
        }
        catch {
            Write-Warning "[Views] Failed to query views for $entityName : $_"
        }
    }

    $summaryData = [ordered]@{
        exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
        totalViews    = $summary.Count
        views         = $summary
    }
    $summaryPath = Join-Path $OutputPath '_summary.json'
    $summaryData | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "`n[Views] Exported $($summary.Count) views." -ForegroundColor Green

    return $summaryData
}
