<#
.SYNOPSIS
    Export model-driven app forms (Main, QuickCreate, QuickView, Card) for solution entities.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/YOUR_SOLUTION_NAME/forms.
#>

function Export-Forms {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Forms ===" -ForegroundColor Cyan

    # --- Resolve solution ID ---
    $solutionName = $Connection.SolutionName
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) { throw "Solution '$solutionName' not found." }
    $solutionId = $solutions.value[0].solutionid

    # --- Get entity components ---
    $entityComponents = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 1&`$select=objectid"

    # Also get form components directly (componenttype 60 = SystemForm)
    $formComponents = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 60&`$select=objectid"

    # Collect entity logical names
    $entityNames = @()
    foreach ($comp in $entityComponents) {
        try {
            $entity = Invoke-DataverseApi -Connection $Connection -Endpoint "EntityDefinitions($($comp.objectid))?`$select=LogicalName"
            $entityNames += $entity.LogicalName
        } catch { }
    }

    $formTypeNames = @{
        0 = 'Dashboard'; 2 = 'Main'; 5 = 'MobileExpress'; 6 = 'QuickView'; 7 = 'QuickCreate'; 11 = 'Card'
    }

    $summary = @()
    $processedFormIds = @{}

    # --- Export forms by direct solution component ---
    foreach ($comp in $formComponents) {
        $formId = $comp.objectid
        if ($processedFormIds.ContainsKey($formId)) { continue }
        $processedFormIds[$formId] = $true

        try {
            $form = Invoke-DataverseApi -Connection $Connection -Endpoint "systemforms($formId)?`$select=name,objecttypecode,type,description,formxml,formid,isdefault"

            $entityName = $form.objecttypecode
            $formType = $form.type
            $typeName = if ($formTypeNames.ContainsKey($formType)) { $formTypeNames[$formType] } else { "Type$formType" }
            $safeName = ($form.name -replace '[\\/:*?"<>|]', '_')

            Write-Host "  [Form] $($form.name) ($entityName / $typeName)" -ForegroundColor White

            $entityDir = Join-Path $OutputPath $entityName
            if (-not (Test-Path $entityDir)) { New-Item -ItemType Directory -Path $entityDir -Force | Out-Null }

            # Save FormXML
            $xmlPath = Join-Path $entityDir "$safeName.xml"
            if ($form.formxml) {
                $form.formxml | Set-Content -Path $xmlPath -Encoding UTF8
            }

            # Save metadata JSON
            $metaData = [ordered]@{
                exportedOnUtc  = (Get-Date).ToUniversalTime().ToString('o')
                formId         = $form.formid
                name           = $form.name
                entityName     = $entityName
                type           = $formType
                typeName       = $typeName
                isDefault      = $form.isdefault
                description    = $form.description
            }
            $jsonPath = Join-Path $entityDir "$safeName.json"
            $metaData | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
            Write-Host "    -> $xmlPath" -ForegroundColor DarkGray

            $summary += [ordered]@{
                formId     = $form.formid
                name       = $form.name
                entityName = $entityName
                typeName   = $typeName
                isDefault  = $form.isdefault
            }
        }
        catch {
            Write-Warning "[Forms] Failed to export form $formId : $_"
        }
    }

    # --- Export forms by entity (for entities in solution, query their forms) ---
    foreach ($entityName in $entityNames) {
        try {
            $forms = Get-AllDataverseRecords -Connection $Connection -Endpoint "systemforms?`$filter=objecttypecode eq '$entityName'&`$select=name,objecttypecode,type,description,formxml,formid,isdefault"

            foreach ($form in $forms) {
                if ($processedFormIds.ContainsKey($form.formid)) { continue }
                $processedFormIds[$form.formid] = $true

                $formType = $form.type
                $typeName = if ($formTypeNames.ContainsKey($formType)) { $formTypeNames[$formType] } else { "Type$formType" }
                $safeName = ($form.name -replace '[\\/:*?"<>|]', '_')

                Write-Host "  [Form] $($form.name) ($entityName / $typeName)" -ForegroundColor White

                $entityDir = Join-Path $OutputPath $entityName
                if (-not (Test-Path $entityDir)) { New-Item -ItemType Directory -Path $entityDir -Force | Out-Null }

                if ($form.formxml) {
                    $xmlPath = Join-Path $entityDir "$safeName.xml"
                    $form.formxml | Set-Content -Path $xmlPath -Encoding UTF8
                }

                $metaData = [ordered]@{
                    exportedOnUtc  = (Get-Date).ToUniversalTime().ToString('o')
                    formId         = $form.formid
                    name           = $form.name
                    entityName     = $entityName
                    type           = $formType
                    typeName       = $typeName
                    isDefault      = $form.isdefault
                    description    = $form.description
                }
                $jsonPath = Join-Path $entityDir "$safeName.json"
                $metaData | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8

                $summary += [ordered]@{
                    formId     = $form.formid
                    name       = $form.name
                    entityName = $entityName
                    typeName   = $typeName
                    isDefault  = $form.isdefault
                }
            }
        }
        catch {
            Write-Warning "[Forms] Failed to query forms for $entityName : $_"
        }
    }

    $summaryData = [ordered]@{
        exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
        totalForms    = $summary.Count
        forms         = $summary
    }
    $summaryPath = Join-Path $OutputPath '_summary.json'
    $summaryData | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "`n[Forms] Exported $($summary.Count) forms." -ForegroundColor Green

    return $summaryData
}
