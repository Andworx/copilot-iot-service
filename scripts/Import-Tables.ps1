<#
.SYNOPSIS
    Import table (entity) definitions and columns into Dataverse from local JSON definitions.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER SourcePath
    Path to the tables directory. Defaults to tables/.
.PARAMETER DryRun
    Preview mode — logs what would happen without making API calls.
#>

function Import-Tables {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$SourcePath,
        [switch]$DryRun
    )

    Write-Host "`n=== Import Tables ===" -ForegroundColor Cyan

    if (-not $SourcePath) {
        $SourcePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tables'
    }
    if (-not (Test-Path $SourcePath)) {
        throw "Tables source path not found: $SourcePath"
    }

    # Deployment order per project conventions
    $deployOrder = @(
        'andy_category',
        'andy_department',
        'andy_mapoverlay',
        'andy_servicetype',
        'andy_servicerequest',
        'andy_servicerequestnote',
        'andy_servicerequestattachment'
    )

    # Discover definition files
    $defFiles = @{}
    Get-ChildItem -Path $SourcePath -Directory | Where-Object { $_.Name -ne 'choices' -and $_.Name -ne 'relationships' } | ForEach-Object {
        $defPath = Join-Path $_.FullName 'definition.json'
        if (Test-Path $defPath) {
            $defFiles[$_.Name] = $defPath
        }
    }

    if ($defFiles.Count -eq 0) {
        Write-Host "[Tables] No definition.json files found in $SourcePath" -ForegroundColor Yellow
        return @{ imported = 0; tables = @() }
    }

    # Sort by deployment order; any not in the list go last
    $sortedNames = @()
    foreach ($name in $deployOrder) {
        if ($defFiles.ContainsKey($name)) { $sortedNames += $name }
    }
    foreach ($name in ($defFiles.Keys | Sort-Object)) {
        if ($name -notin $sortedNames) { $sortedNames += $name }
    }

    Write-Host "[Tables] Found $($sortedNames.Count) table definition(s). Processing in deployment order." -ForegroundColor Gray
    $results = @()

    foreach ($tableName in $sortedNames) {
        $def = Get-Content $defFiles[$tableName] -Raw | ConvertFrom-Json
        Write-Host "`n  [Table] $($def.schemaName) — $($def.displayName)" -ForegroundColor White

        $exists = Test-DataverseExists -Connection $Connection -Endpoint "EntityDefinitions(LogicalName='$($def.schemaName)')"

        if ($exists) {
            Write-Host "    [EXISTS] Table already deployed, checking columns..." -ForegroundColor DarkGray
            $results += @{ name = $def.schemaName; action = 'Exists' }
        }
        else {
            Write-Host "    [NEW] Creating entity..." -ForegroundColor DarkGray

            # Build primary name attribute
            $primaryAttr = $def.columns | Where-Object { $_.schemaName -eq $def.primaryNameColumn } | Select-Object -First 1
            $primaryMaxLen = if ($primaryAttr -and $primaryAttr.maxLength) { $primaryAttr.maxLength } else { 200 }

            $entityBody = @{
                '@odata.type'         = 'Microsoft.Dynamics.CRM.EntityMetadata'
                SchemaName            = $def.schemaName
                DisplayName           = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $def.displayName; LanguageCode = 1033 }) }
                DisplayCollectionName = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $def.displayCollectionName; LanguageCode = 1033 }) }
                Description           = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $def.description; LanguageCode = 1033 }) }
                OwnershipType         = if ($def.ownership -eq 'User') { 'UserOwned' } else { 'OrganizationOwned' }
                IsActivity            = if ($def.isActivity) { $true } else { $false }
                ChangeTrackingEnabled = if ($null -ne $def.changeTrackingEnabled) { $def.changeTrackingEnabled } else { $true }
                HasNotes              = $false
                HasActivities         = $false
                PrimaryNameAttribute  = $def.primaryNameColumn
                Attributes            = @(
                    @{
                        '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
                        IsPrimaryName = $true
                        SchemaName    = $def.primaryNameColumn
                        DisplayName   = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = if ($primaryAttr) { $primaryAttr.displayName } else { 'Name' }; LanguageCode = 1033 }) }
                        Description   = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = if ($primaryAttr) { $primaryAttr.description } else { '' }; LanguageCode = 1033 }) }
                        RequiredLevel = @{ Value = 'ApplicationRequired' }
                        MaxLength     = $primaryMaxLen
                        FormatName    = @{ Value = 'Text' }
                    }
                )
            }

            if ($DryRun) {
                Write-Host "    [DRY-RUN] Would POST EntityDefinitions ($($def.schemaName))" -ForegroundColor Yellow
            }
            else {
                Invoke-DataverseApi -Connection $Connection `
                    -Endpoint 'EntityDefinitions' `
                    -Method POST -Body $entityBody -IncludeSolutionHeader
                # Brief delay for entity propagation before adding columns
                Start-Sleep -Seconds 5
            }
            $results += @{ name = $def.schemaName; action = 'Created' }
        }

        # --- Process additional columns (skip primary name & lookups) ---
        $additionalColumns = @($def.columns | Where-Object {
            $_.schemaName -ne $def.primaryNameColumn -and $_.dataType -ne 'Lookup'
        })

        foreach ($col in $additionalColumns) {
          try {
            $colExists = Test-DataverseExists -Connection $Connection `
                -Endpoint "EntityDefinitions(LogicalName='$($def.schemaName)')/Attributes(LogicalName='$($col.schemaName)')"

            $attrBody = ConvertTo-AttributeMetadata -Column $col -Connection $Connection
            if (-not $attrBody) {
                Write-Warning "    [SKIP] $($col.schemaName) — unsupported dataType '$($col.dataType)'"
                continue
            }

            if ($colExists) {
                Write-Host "    [COL-EXISTS] $($col.schemaName) ($($col.dataType))" -ForegroundColor DarkGray
            }
            else {
                Write-Host "    [COL-NEW] $($col.schemaName) ($($col.dataType))" -ForegroundColor DarkGray
                if ($DryRun) {
                    Write-Host "    [DRY-RUN] Would POST column $($col.schemaName)" -ForegroundColor Yellow
                }
                else {
                    Invoke-DataverseApi -Connection $Connection `
                        -Endpoint "EntityDefinitions(LogicalName='$($def.schemaName)')/Attributes" `
                        -Method POST -Body $attrBody -IncludeSolutionHeader
                }
            }
          }
          catch {
              Write-Warning "    [COL-FAIL] $($col.schemaName): $_"
          }
        }

        # --- AutoNumber format ---
        $autoNumCol = $def.columns | Where-Object { $_.autoNumber } | Select-Object -First 1
        if ($autoNumCol -and -not $DryRun) {
            Write-Host "    [AUTO-NUM] Setting format on $($autoNumCol.schemaName): $($autoNumCol.autoNumber.format)" -ForegroundColor DarkGray
            $autoBody = @{ AutoNumberFormat = $autoNumCol.autoNumber.format }
            try {
                Invoke-DataverseApi -Connection $Connection `
                    -Endpoint "EntityDefinitions(LogicalName='$($def.schemaName)')/Attributes(LogicalName='$($autoNumCol.schemaName)')" `
                    -Method PATCH -Body $autoBody -IncludeSolutionHeader
            }
            catch {
                Write-Warning "    [WARN] AutoNumber format update failed: $_"
            }
        }
        elseif ($autoNumCol -and $DryRun) {
            Write-Host "    [DRY-RUN] Would set AutoNumberFormat on $($autoNumCol.schemaName)" -ForegroundColor Yellow
        }

        # --- Table icon (SVG web resource) ---
        if ($def.iconSvgFile) {
            if (-not $def.iconWebResourceName) {
                Write-Warning "    [ICON-SKIP] iconSvgFile set but iconWebResourceName missing on $($def.schemaName)"
            }
            else {
                $iconPath = Join-Path (Split-Path $defFiles[$tableName]) $def.iconSvgFile
                if (-not (Test-Path $iconPath)) {
                    Write-Warning "    [ICON-SKIP] SVG file not found: $iconPath"
                }
                else {
                    $svgContent = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($iconPath))
                    $wrExisting = $null
                    if (-not $DryRun) {
                        $wrResult = Invoke-DataverseApi -Connection $Connection `
                            -Endpoint "webresourceset?`$filter=name eq '$($def.iconWebResourceName)'&`$select=webresourceid" `
                            -Method GET
                        $wrExisting = if ($wrResult.value.Count -gt 0) { $wrResult.value[0] } else { $null }
                    }

                    if ($DryRun) {
                        Write-Host "    [DRY-RUN] Would upsert web resource $($def.iconWebResourceName) (type 11 SVG)" -ForegroundColor Yellow
                        Write-Host "    [DRY-RUN] Would publish web resource $($def.iconWebResourceName)" -ForegroundColor Yellow
                        Write-Host "    [DRY-RUN] Would GET MetadataId for $($def.schemaName)" -ForegroundColor Yellow
                        Write-Host "    [DRY-RUN] Would PUT EntityDefinitions IconVectorName = $($def.iconWebResourceName)" -ForegroundColor Yellow
                        Write-Host "    [DRY-RUN] Would PublishXml entity $($def.schemaName)" -ForegroundColor Yellow
                    }
                    else {
                        try {
                            if ($wrExisting) {
                                Write-Host "    [ICON-UPDATED] $($def.iconWebResourceName)" -ForegroundColor DarkGray
                                Invoke-DataverseApi -Connection $Connection `
                                    -Endpoint "webresourceset($($wrExisting.webresourceid))" `
                                    -Method PATCH `
                                    -Body @{ content = $svgContent } `
                                    -IncludeSolutionHeader
                            }
                            else {
                                Write-Host "    [ICON-CREATED] $($def.iconWebResourceName)" -ForegroundColor DarkGray
                                Invoke-DataverseApi -Connection $Connection `
                                    -Endpoint 'webresourceset' `
                                    -Method POST `
                                    -Body @{
                                        name            = $def.iconWebResourceName
                                        displayname     = "$($def.displayName) Icon"
                                        webresourcetype = 11
                                        content         = $svgContent
                                    } `
                                    -IncludeSolutionHeader
                            }

                            $wrPublishXml = "<ImportExportXml><webresources><webresource>$($def.iconWebResourceName)</webresource></webresources></ImportExportXml>"
                            Write-Host "    [ICON-PUBLISHED] $($def.iconWebResourceName)" -ForegroundColor DarkGray
                            Invoke-DataverseApi -Connection $Connection `
                                -Endpoint 'PublishXml' `
                                -Method POST `
                                -Body @{ ParameterXml = $wrPublishXml }

                            $entityMeta = Invoke-DataverseApi -Connection $Connection `
                                -Endpoint "EntityDefinitions(LogicalName='$($def.schemaName)')?`$select=MetadataId" `
                                -Method GET
                            $metadataId = $entityMeta.MetadataId

                            Write-Host "    [ICON-LINKED] IconVectorName → $($def.iconWebResourceName) on $($def.schemaName)" -ForegroundColor DarkGray
                            Invoke-DataverseApi -Connection $Connection `
                                -Endpoint "EntityDefinitions($metadataId)" `
                                -Method PUT `
                                -Body @{
                                    '@odata.type'  = 'Microsoft.Dynamics.CRM.EntityMetadata'
                                    MetadataId     = $metadataId
                                    IconVectorName = $def.iconWebResourceName
                                } `
                                -IncludeSolutionHeader

                            $entityPublishXml = "<importexportxml><entities><entity>$($def.schemaName)</entity></entities></importexportxml>"
                            Write-Host "    [ICON-ENTITY-PUBLISHED] $($def.schemaName)" -ForegroundColor DarkGray
                            Invoke-DataverseApi -Connection $Connection `
                                -Endpoint 'PublishXml' `
                                -Method POST `
                                -Body @{ ParameterXml = $entityPublishXml }
                        }
                        catch {
                            Write-Warning "    [ICON-FAIL] $($def.iconWebResourceName): $_"
                        }
                    }
                }
            }
        }

        Write-Host "    [PASS] $($def.schemaName)" -ForegroundColor Green
    }

    Write-Host "`n[Tables] Processed $($results.Count) table(s)." -ForegroundColor Green
    return @{ imported = $results.Count; tables = $results }
}

function ConvertTo-AttributeMetadata {
    param(
        [Parameter(Mandatory = $true)]
        $Column,
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection
    )

    $requiredMap = @{
        'Required'    = 'ApplicationRequired'
        'Recommended' = 'Recommended'
        'Optional'    = 'None'
    }
    $reqLevel = if ($requiredMap.ContainsKey($Column.required)) { $requiredMap[$Column.required] } else { 'None' }

    $base = @{
        SchemaName    = $Column.schemaName
        DisplayName   = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $Column.displayName; LanguageCode = 1033 }) }
        Description   = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = if ($Column.description) { $Column.description } else { '' }; LanguageCode = 1033 }) }
        RequiredLevel = @{ Value = $reqLevel }
    }

    switch ($Column.dataType) {
        'String' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
            $base['MaxLength'] = if ($Column.maxLength) { $Column.maxLength } else { 200 }
            if ($Column.format -eq 'Email') {
                $base['FormatName'] = @{ Value = 'Email' }
            }
            elseif ($Column.format -eq 'Phone') {
                $base['FormatName'] = @{ Value = 'Phone' }
            }
            elseif ($Column.format -eq 'Url') {
                $base['FormatName'] = @{ Value = 'Url' }
            }
            else {
                $base['FormatName'] = @{ Value = 'Text' }
            }
            return $base
        }
        'Memo' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.MemoAttributeMetadata'
            $base['MaxLength'] = if ($Column.maxLength) { $Column.maxLength } else { 2000 }
            $base['Format'] = 'TextArea'
            return $base
        }
        'Integer' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.IntegerAttributeMetadata'
            $base['MinValue'] = if ($null -ne $Column.minValue) { $Column.minValue } else { -2147483648 }
            $base['MaxValue'] = if ($null -ne $Column.maxValue) { $Column.maxValue } else { 2147483647 }
            $base['Format'] = 'None'
            return $base
        }
        'Float' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.DoubleAttributeMetadata'
            $base['MinValue'] = if ($null -ne $Column.minValue) { $Column.minValue } else { 0 }
            $base['MaxValue'] = if ($null -ne $Column.maxValue) { $Column.maxValue } else { 1000000000 }
            $prec = if ($null -ne $Column.precision) { [Math]::Min($Column.precision, 5) } else { 2 }
            $base['Precision'] = $prec
            return $base
        }
        'Decimal' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.DecimalAttributeMetadata'
            $base['MinValue'] = if ($null -ne $Column.minValue) { $Column.minValue } else { 0 }
            $base['MaxValue'] = if ($null -ne $Column.maxValue) { $Column.maxValue } else { 1000000000 }
            $base['Precision'] = if ($null -ne $Column.precision) { $Column.precision } else { 2 }
            return $base
        }
        'Boolean' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
            $base['DefaultValue'] = if ($null -ne $Column.defaultValue) { $Column.defaultValue } else { $false }
            $base['OptionSet'] = @{
                TrueOption  = @{ Value = 1; Label = @{ LocalizedLabels = @(@{ Label = 'Yes'; LanguageCode = 1033 }) } }
                FalseOption = @{ Value = 0; Label = @{ LocalizedLabels = @(@{ Label = 'No'; LanguageCode = 1033 }) } }
            }
            return $base
        }
        'DateTime' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata'
            $base['Format'] = if ($Column.format) { $Column.format } else { 'DateAndTime' }
            $base['DateTimeBehavior'] = @{ Value = 'UserLocal' }
            return $base
        }
        'Choice' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
            if ($Column.choiceName) {
                # Look up the global option set GUID (bind requires GUID, not Name)
                $optSet = Invoke-DataverseApi -Connection $Connection `
                    -Endpoint "GlobalOptionSetDefinitions(Name='$($Column.choiceName)')?`$select=MetadataId"
                $base['GlobalOptionSet@odata.bind'] = "/GlobalOptionSetDefinitions($($optSet.MetadataId))"
            }
            if ($null -ne $Column.defaultValue) {
                $base['DefaultFormValue'] = $Column.defaultValue
            }
            return $base
        }
        'File' {
            $base['@odata.type'] = 'Microsoft.Dynamics.CRM.FileAttributeMetadata'
            $base['MaxSizeInKB'] = if ($Column.maxSizeKB) { $Column.maxSizeKB } else { 32768 }
            return $base
        }
        default {
            return $null
        }
    }
}
