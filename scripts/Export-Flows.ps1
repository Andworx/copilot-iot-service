<#
.SYNOPSIS
    Export Power Automate cloud flows from the AgenticIoT solution.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/AgenticIoT/flows.
#>

function Export-Flows {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Flows ===" -ForegroundColor Cyan

    # --- Resolve solution ID ---
    $solutionName = $Connection.SolutionName
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) { throw "Solution '$solutionName' not found." }
    $solutionId = $solutions.value[0].solutionid

    # --- Get workflow components (componenttype 29 = Process/Workflow) ---
    Write-Host "[Flows] Querying solution workflow components..." -ForegroundColor Gray
    $components = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 29&`$select=objectid"

    if (-not $components -or $components.Count -eq 0) {
        Write-Host "[Flows] No workflow components found in solution." -ForegroundColor Yellow
        return @{ totalFlows = 0; flows = @() }
    }
    Write-Host "[Flows] Found $($components.Count) workflow components." -ForegroundColor Gray

    $summary = @()

    foreach ($comp in $components) {
        $workflowId = $comp.objectid
        try {
            $flow = Invoke-DataverseApi -Connection $Connection -Endpoint "workflows($workflowId)?`$select=name,category,statecode,statuscode,clientdata,createdon,modifiedon,description,primaryentity"

            $name = $flow.name
            $category = $flow.category
            # category: 0=Workflow, 2=BusinessRule, 3=Action, 5=ModernFlow, 6=DesktopFlow
            $categoryName = switch ($category) {
                0 { 'ClassicWorkflow' }
                2 { 'BusinessRule' }
                3 { 'Action' }
                5 { 'CloudFlow' }
                6 { 'DesktopFlow' }
                default { "Unknown($category)" }
            }

            $safeName = $name -replace '[\\/:*?"<>|]', '_'
            Write-Host "  [Flow] $name ($categoryName)" -ForegroundColor White

            $flowData = [ordered]@{
                exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
                workflowId    = $workflowId
                name          = $name
                category      = $category
                categoryName  = $categoryName
                description   = $flow.description
                primaryEntity = $flow.primaryentity
                stateCode     = $flow.statecode
                statusCode    = $flow.statuscode
                createdOn     = $flow.createdon
                modifiedOn    = $flow.modifiedon
            }

            # clientdata contains the full flow definition for modern flows
            if ($flow.clientdata) {
                try {
                    $flowData['definition'] = $flow.clientdata | ConvertFrom-Json
                }
                catch {
                    $flowData['clientdataRaw'] = $flow.clientdata
                }
            }

            $filePath = Join-Path $OutputPath "$safeName.json"
            $flowData | ConvertTo-Json -Depth 50 | Set-Content -Path $filePath -Encoding UTF8
            Write-Host "    -> $filePath" -ForegroundColor DarkGray

            $summary += [ordered]@{
                workflowId   = $workflowId
                name         = $name
                categoryName = $categoryName
                stateCode    = $flow.statecode
                modifiedOn   = $flow.modifiedon
            }
        }
        catch {
            Write-Warning "[Flows] Failed to export workflow $workflowId : $_"
        }
    }

    $summaryData = [ordered]@{
        exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
        totalFlows    = $summary.Count
        flows         = $summary
    }
    $summaryPath = Join-Path $OutputPath '_summary.json'
    $summaryData | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "`n[Flows] Exported $($summary.Count) flows." -ForegroundColor Green

    return $summaryData
}
