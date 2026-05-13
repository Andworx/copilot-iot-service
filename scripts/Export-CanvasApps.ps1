<#
.SYNOPSIS
    Export canvas app metadata from the AgenticIoT solution.
.DESCRIPTION
    Exports canvas app inventory and metadata. Full .msapp binary export
    requires the Power Apps Management API and is not included here.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/AgenticIoT/canvasapps.
#>

function Export-CanvasApps {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Canvas Apps ===" -ForegroundColor Cyan

    # --- Resolve solution ID ---
    $solutionName = $Connection.SolutionName
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) { throw "Solution '$solutionName' not found." }
    $solutionId = $solutions.value[0].solutionid

    # --- Get canvas app components (componenttype 300 = CanvasApp) ---
    Write-Host "[CanvasApps] Querying solution components..." -ForegroundColor Gray
    $components = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 300&`$select=objectid"

    if (-not $components -or $components.Count -eq 0) {
        Write-Host "[CanvasApps] No canvas app components found." -ForegroundColor Yellow
        return @{ totalApps = 0; apps = @() }
    }
    Write-Host "[CanvasApps] Found $($components.Count) canvas apps." -ForegroundColor Gray

    $summary = @()

    foreach ($comp in $components) {
        $appId = $comp.objectid
        try {
            $app = Invoke-DataverseApi -Connection $Connection -Endpoint "canvasapps($appId)?`$select=name,displayname,status,commitmessage,createdon,modifiedon,appversion,description,tags,backgroundcolor,appcomponentdependencies"

            $displayName = if ($app.displayname) { $app.displayname } else { $app.name }
            $safeName = ($displayName -replace '[\\/:*?"<>|]', '_')
            Write-Host "  [App] $displayName" -ForegroundColor White

            $appData = [ordered]@{
                exportedOnUtc   = (Get-Date).ToUniversalTime().ToString('o')
                canvasAppId     = $appId
                name            = $app.name
                displayName     = $displayName
                description     = $app.description
                status          = $app.status
                appVersion      = $app.appversion
                commitMessage   = $app.commitmessage
                backgroundColor = $app.backgroundcolor
                tags            = $app.tags
                createdOn       = $app.createdon
                modifiedOn      = $app.modifiedon
            }

            # Parse dependencies if available
            if ($app.appcomponentdependencies) {
                try {
                    $appData['dependencies'] = $app.appcomponentdependencies | ConvertFrom-Json
                } catch {
                    $appData['dependenciesRaw'] = $app.appcomponentdependencies
                }
            }

            $filePath = Join-Path $OutputPath "$safeName.json"
            $appData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
            Write-Host "    -> $filePath" -ForegroundColor DarkGray

            $summary += [ordered]@{
                canvasAppId = $appId
                name        = $app.name
                displayName = $displayName
                status      = $app.status
                modifiedOn  = $app.modifiedon
            }
        }
        catch {
            Write-Warning "[CanvasApps] Failed to export app $appId : $_"
        }
    }

    $summaryData = [ordered]@{
        exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
        totalApps     = $summary.Count
        apps          = $summary
    }
    $summaryPath = Join-Path $OutputPath '_summary.json'
    $summaryData | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "`n[CanvasApps] Exported $($summary.Count) canvas app metadata records." -ForegroundColor Green

    return $summaryData
}
