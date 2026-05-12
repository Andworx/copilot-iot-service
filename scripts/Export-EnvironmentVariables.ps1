<#
.SYNOPSIS
    Export environment variable definitions and values from the YOUR_SOLUTION_NAME solution.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/YOUR_SOLUTION_NAME/environmentvariables.
#>

function Export-EnvironmentVariables {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Environment Variables ===" -ForegroundColor Cyan

    # --- Resolve solution ID ---
    $solutionName = $Connection.SolutionName
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) { throw "Solution '$solutionName' not found." }
    $solutionId = $solutions.value[0].solutionid

    # --- Get environment variable definition components (componenttype 380) ---
    Write-Host "[EnvVars] Querying solution components..." -ForegroundColor Gray
    $components = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 380&`$select=objectid"

    if (-not $components -or $components.Count -eq 0) {
        # Fallback: try querying all env var definitions with publisher prefix filter
        Write-Host "[EnvVars] No components via solution, trying direct query..." -ForegroundColor Gray
        $prefix = $Connection.Config.publisherPrefix
        $allDefs = Get-AllDataverseRecords -Connection $Connection -Endpoint "environmentvariabledefinitions?`$filter=startswith(schemaname,'$prefix')&`$select=schemaname,displayname,type,defaultvalue,description,environmentvariabledefinitionid&`$expand=environmentvariabledefinition_environmentvariablevalue(`$select=value,schemaname)"

        if (-not $allDefs -or $allDefs.Count -eq 0) {
            Write-Host "[EnvVars] No environment variables found." -ForegroundColor Yellow
            return @{ totalVariables = 0; variables = @() }
        }

        $variables = @($allDefs | ForEach-Object { Format-EnvVarRecord $_ })
        return Write-EnvVarOutput -Variables $variables -OutputPath $OutputPath
    }

    Write-Host "[EnvVars] Found $($components.Count) environment variable definitions." -ForegroundColor Gray

    $variables = @()

    foreach ($comp in $components) {
        $defId = $comp.objectid
        try {
            $def = Invoke-DataverseApi -Connection $Connection -Endpoint "environmentvariabledefinitions($defId)?`$select=schemaname,displayname,type,defaultvalue,description,environmentvariabledefinitionid&`$expand=environmentvariabledefinition_environmentvariablevalue(`$select=value,schemaname)"
            $variables += Format-EnvVarRecord $def
        }
        catch {
            Write-Warning "[EnvVars] Failed to export definition $defId : $_"
        }
    }

    return Write-EnvVarOutput -Variables $variables -OutputPath $OutputPath
}

function Format-EnvVarRecord {
    param($def)

    $typeNames = @{
        100000000 = 'String'; 100000001 = 'Number'; 100000002 = 'Boolean'
        100000003 = 'JSON'; 100000004 = 'DataSource'; 100000005 = 'Secret'
    }

    $displayName = if ($def.displayname) { $def.displayname } else { $def.schemaname }
    $typeName = if ($typeNames.ContainsKey($def.type)) { $typeNames[$def.type] } else { "Unknown($($def.type))" }

    Write-Host "  [EnvVar] $displayName ($typeName)" -ForegroundColor White

    $values = @()
    if ($def.environmentvariabledefinition_environmentvariablevalue) {
        $values = @($def.environmentvariabledefinition_environmentvariablevalue | ForEach-Object {
            [ordered]@{
                schemaName = $_.schemaname
                value      = $_.value
            }
        })
    }

    return [ordered]@{
        definitionId = $def.environmentvariabledefinitionid
        schemaName   = $def.schemaname
        displayName  = $displayName
        type         = $def.type
        typeName     = $typeName
        defaultValue = $def.defaultvalue
        description  = $def.description
        values       = $values
    }
}

function Write-EnvVarOutput {
    param(
        [array]$Variables,
        [string]$OutputPath
    )

    $outputData = [ordered]@{
        exportedOnUtc  = (Get-Date).ToUniversalTime().ToString('o')
        totalVariables = $Variables.Count
        variables      = $Variables
    }

    $filePath = Join-Path $OutputPath '_all.json'
    $outputData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
    Write-Host "`n[EnvVars] Exported $($Variables.Count) environment variables." -ForegroundColor Green

    return $outputData
}
