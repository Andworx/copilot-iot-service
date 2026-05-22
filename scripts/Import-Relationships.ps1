<#
.SYNOPSIS
    Import entity relationships (1:N) into Dataverse from local JSON definitions.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER SourcePath
    Path to the relationships directory. Defaults to tables/relationships.
.PARAMETER DryRun
    Preview mode — logs what would happen without making API calls.
#>

function Import-Relationships {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$SourcePath,
        [switch]$DryRun
    )

    Write-Host "`n=== Import Relationships ===" -ForegroundColor Cyan

    if (-not $SourcePath) {
        $SourcePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tables\relationships'
    }

    $defFile = Join-Path $SourcePath 'definitions.json'
    if (-not (Test-Path $defFile)) {
        throw "Relationships definition file not found: $defFile"
    }

    $defData = Get-Content $defFile -Raw | ConvertFrom-Json
    $relationships = $defData.relationships
    if (-not $relationships -or $relationships.Count -eq 0) {
        Write-Host "[Relationships] No relationships defined." -ForegroundColor Yellow
        return @{ imported = 0; relationships = @() }
    }

    Write-Host "[Relationships] Found $($relationships.Count) relationship(s)." -ForegroundColor Gray

    # Map cascade behavior string to Dataverse enum value
    $cascadeMap = @{
        'Cascade'    = 'Cascade'
        'Restrict'   = 'Restrict'
        'RemoveLink' = 'RemoveLink'
        'NoCascade'  = 'NoCascade'
        'Active'     = 'Active'
        'UserOwned'  = 'UserOwned'
    }

    $results = @()

    foreach ($rel in $relationships) {
        Write-Host "`n  [Rel] $($rel.schemaName) ($($rel.referencedEntity) 1:N $($rel.referencingEntity))" -ForegroundColor White

        # Check if relationship already exists
        $exists = $false
        try {
            $existing = Get-AllDataverseRecords -Connection $Connection `
                -Endpoint "RelationshipDefinitions/Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata?`$filter=SchemaName eq '$($rel.schemaName)'&`$select=MetadataId,SchemaName"
            if ($existing -and $existing.Count -gt 0) { $exists = $true }
        }
        catch {
            if ($_ -notmatch '404') { throw }
        }

        $cascadeConfig = @{
            Delete   = if ($rel.cascadeDelete   -and $cascadeMap.ContainsKey($rel.cascadeDelete))   { $cascadeMap[$rel.cascadeDelete] }   else { 'NoCascade' }
            Assign   = if ($rel.cascadeAssign   -and $cascadeMap.ContainsKey($rel.cascadeAssign))   { $cascadeMap[$rel.cascadeAssign] }   else { 'NoCascade' }
            Reparent = if ($rel.cascadeReparent -and $cascadeMap.ContainsKey($rel.cascadeReparent)) { $cascadeMap[$rel.cascadeReparent] } else { 'NoCascade' }
            Share    = if ($rel.cascadeShare    -and $cascadeMap.ContainsKey($rel.cascadeShare))    { $cascadeMap[$rel.cascadeShare] }    else { 'NoCascade' }
            Unshare  = if ($rel.cascadeUnshare  -and $cascadeMap.ContainsKey($rel.cascadeUnshare))  { $cascadeMap[$rel.cascadeUnshare] }  else { 'NoCascade' }
            Merge    = 'NoCascade'
        }

        if ($exists) {
            Write-Host "    [EXISTS] Already deployed, skipping." -ForegroundColor DarkGray
            $results += @{ name = $rel.schemaName; action = 'Skipped' }
        }
        else {
            Write-Host "    [NEW] Creating 1:N relationship (creates lookup column $($rel.referencingAttribute) on $($rel.referencingEntity))..." -ForegroundColor DarkGray

            if ($DryRun) {
                Write-Host "    [DRY-RUN] Would POST RelationshipDefinitions ($($rel.schemaName))" -ForegroundColor Yellow
            }
            else {
                # Determine lookup display name from relationship context
                $lookupDisplayName = ($rel.referencingAttribute -replace '^andy_', '' -replace 'id$', '')
                $lookupDisplayName = (Get-Culture).TextInfo.ToTitleCase($lookupDisplayName)

                $postBody = @{
                    '@odata.type'           = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
                    SchemaName              = $rel.schemaName
                    ReferencedEntity        = $rel.referencedEntity
                    ReferencedAttribute     = $rel.referencedAttribute
                    ReferencingEntity       = $rel.referencingEntity
                    CascadeConfiguration    = $cascadeConfig
                    Lookup                  = @{
                        '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
                        SchemaName    = $rel.referencingAttribute
                        DisplayName   = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $lookupDisplayName; LanguageCode = 1033 }) }
                        RequiredLevel = @{ Value = 'None' }
                    }
                }
                Invoke-DataverseApi -Connection $Connection `
                    -Endpoint 'RelationshipDefinitions' `
                    -Method POST -Body $postBody -IncludeSolutionHeader
            }
            $results += @{ name = $rel.schemaName; action = 'Created' }
        }

        Write-Host "    [PASS] $($rel.schemaName)" -ForegroundColor Green
    }

    Write-Host "`n[Relationships] Processed $($results.Count) relationship(s)." -ForegroundColor Green
    return @{ imported = $results.Count; relationships = $results }
}
