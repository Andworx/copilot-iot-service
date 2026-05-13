<#
.SYNOPSIS
    Export web resources (JS, CSS, HTML, images) from the AgenticIoT solution.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/AgenticIoT/webresources.
#>

function Export-WebResources {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Web Resources ===" -ForegroundColor Cyan

    # Web resource type to extension mapping
    $typeExtensions = @{
        1 = '.html'; 2 = '.css'; 3 = '.js'; 4 = '.xml'; 5 = '.png'
        6 = '.jpg'; 7 = '.gif'; 8 = '.xap'; 9 = '.xsl'; 10 = '.ico'
        11 = '.svg'; 12 = '.resx'
    }
    $typeNames = @{
        1 = 'HTML'; 2 = 'CSS'; 3 = 'JavaScript'; 4 = 'XML'; 5 = 'PNG'
        6 = 'JPG'; 7 = 'GIF'; 8 = 'Silverlight'; 9 = 'XSL'; 10 = 'ICO'
        11 = 'SVG'; 12 = 'RESX'
    }

    # --- Resolve solution ID ---
    $solutionName = $Connection.SolutionName
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) { throw "Solution '$solutionName' not found." }
    $solutionId = $solutions.value[0].solutionid

    # --- Get web resource components (componenttype 61) ---
    Write-Host "[WebResources] Querying solution components..." -ForegroundColor Gray
    $components = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 61&`$select=objectid"

    if (-not $components -or $components.Count -eq 0) {
        Write-Host "[WebResources] No web resource components found." -ForegroundColor Yellow
        return @{ totalResources = 0; resources = @() }
    }
    Write-Host "[WebResources] Found $($components.Count) web resources." -ForegroundColor Gray

    $summary = @()

    foreach ($comp in $components) {
        $resourceId = $comp.objectid
        try {
            $wr = Invoke-DataverseApi -Connection $Connection -Endpoint "webresourceset($resourceId)?`$select=name,displayname,webresourcetype,content,description"

            $name = $wr.name
            $wrType = $wr.webresourcetype
            $typeName = if ($typeNames.ContainsKey($wrType)) { $typeNames[$wrType] } else { "Unknown($wrType)" }
            $ext = if ($typeExtensions.ContainsKey($wrType)) { $typeExtensions[$wrType] } else { '.bin' }

            Write-Host "  [WR] $name ($typeName)" -ForegroundColor White

            # Build file path preserving the web resource name structure
            $safeName = $name -replace '[\\/:*?"<>|]', '_'
            $filePath = Join-Path $OutputPath "$safeName$ext"

            # Decode base64 content and write to file
            if ($wr.content) {
                $bytes = [System.Convert]::FromBase64String($wr.content)
                # Text types: write as UTF8 string; binary types: write as bytes
                if ($wrType -in @(1, 2, 3, 4, 9, 12)) {
                    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
                    Set-Content -Path $filePath -Value $text -Encoding UTF8 -NoNewline
                }
                else {
                    [System.IO.File]::WriteAllBytes($filePath, $bytes)
                }
                Write-Host "    -> $filePath" -ForegroundColor DarkGray
            }

            # Save metadata
            $metaPath = Join-Path $OutputPath "$safeName.meta.json"
            $metaData = [ordered]@{
                exportedOnUtc  = (Get-Date).ToUniversalTime().ToString('o')
                webResourceId  = $resourceId
                name           = $name
                displayName    = $wr.displayname
                type           = $wrType
                typeName       = $typeName
                description    = $wr.description
            }
            $metaData | ConvertTo-Json -Depth 5 | Set-Content -Path $metaPath -Encoding UTF8

            $summary += [ordered]@{
                webResourceId = $resourceId
                name          = $name
                typeName      = $typeName
                displayName   = $wr.displayname
            }
        }
        catch {
            Write-Warning "[WebResources] Failed to export $resourceId : $_"
        }
    }

    $summaryData = [ordered]@{
        exportedOnUtc  = (Get-Date).ToUniversalTime().ToString('o')
        totalResources = $summary.Count
        resources      = $summary
    }
    $summaryPath = Join-Path $OutputPath '_summary.json'
    $summaryData | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "`n[WebResources] Exported $($summary.Count) web resources." -ForegroundColor Green

    return $summaryData
}
