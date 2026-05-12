<#
.SYNOPSIS
    Import Power Automate flow definitions into Dataverse from local JSON files.
.DESCRIPTION
    Reads flow definition JSON files from flows/, registers environment variable
    definitions, connection references, and workflow records in the target environment.
    Existing modern flows are updated in place by default. Use -ReplaceExistingFlows
    only when you explicitly want to delete and recreate existing flows. Automatic
    delete/recreate fallback is disabled in update mode so flow history and
    connector authorization are preserved unless replacement is intentional.
    Update mode reads live workflow clientdata when available and swaps in only
    the new definition so existing bound connection IDs are preserved.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER SourcePath
    Path to the flows directory. Defaults to flows/.
.PARAMETER FlowName
    Optional single flow JSON base name to import from flows/.
.PARAMETER ReplaceExistingFlows
    Destructive recovery mode for existing flows. Deletes matching workflow
    records before recreating them from local JSON definitions.
    Do not use this for normal deployments.
.PARAMETER DryRun
    Preview mode — logs what would happen without making API calls.
#>

function Import-Flows {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$SourcePath,
        [string]$FlowName,
        [switch]$ReplaceExistingFlows,
        [switch]$DryRun
    )

    Write-Host "`n=== Import Flows ===" -ForegroundColor Cyan
    if ($ReplaceExistingFlows) {
        Write-Host "  [REPLACE MODE] Existing cloud flows will be deleted and recreated from local JSON definitions." -ForegroundColor Yellow
        Write-Host "  [REPLACE MODE] This is destructive: run history, last modified timestamps, and connector bindings may be reset." -ForegroundColor Yellow
    }
    else {
        Write-Host "  [UPDATE MODE] Existing cloud flows will be updated in place when possible." -ForegroundColor Green
        Write-Host "  [UPDATE MODE] Failed updates stop with repair guidance instead of delete/recreate." -ForegroundColor DarkGray
    }

    if (-not $SourcePath) {
        $SourcePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'flows'
    }
    if (-not (Test-Path $SourcePath)) {
        throw "Flows source path not found: $SourcePath"
    }

    $results = @{
        environmentVariables = @()
        connectionReferences = @()
        flows                = @()
    }

    # ── Step 1: Import Environment Variable Definitions ──
    $envVarsPath = Join-Path $SourcePath 'environment-variables.json'
    if (Test-Path $envVarsPath) {
        $envVarsList = @(Get-Content $envVarsPath -Raw | ConvertFrom-Json)
        Write-Host "`n  [EnvVars] Processing $($envVarsList.Count) environment variable(s)..." -ForegroundColor Gray

        foreach ($envVar in $envVarsList) {
            try {
                # Check if it already exists
                $existing = $null
                try {
                    $existing = Invoke-DataverseApi -Connection $Connection `
                        -Endpoint "environmentvariabledefinitions?`$filter=schemaname eq '$($envVar.schemaName)'&`$select=environmentvariabledefinitionid"
                } catch { }

                if ($existing -and $existing.value -and $existing.value.Count -gt 0) {
                    Write-Host "    [EXISTS] $($envVar.schemaName)" -ForegroundColor DarkGray
                    $results.environmentVariables += @{ name = $envVar.schemaName; action = 'Exists' }
                }
                else {
                    $typeMap = @{
                        'String'     = 100000000
                        'Number'     = 100000001
                        'Boolean'    = 100000002
                        'JSON'       = 100000003
                        'DataSource' = 100000004
                    }
                    $typeCode = if ($typeMap.ContainsKey($envVar.type)) { $typeMap[$envVar.type] } else { 100000000 }

                    $body = @{
                        schemaname    = $envVar.schemaName
                        displayname   = $envVar.displayName
                        description   = if ($envVar.description) { $envVar.description } else { '' }
                        type          = $typeCode
                        isrequired    = if ($envVar.required) { $true } else { $false }
                    }

                    if ($DryRun) {
                        Write-Host "    [DRY-RUN] Would create env var: $($envVar.schemaName)" -ForegroundColor Yellow
                    }
                    else {
                        Invoke-DataverseApi -Connection $Connection `
                            -Endpoint 'environmentvariabledefinitions' `
                            -Method POST -Body $body -IncludeSolutionHeader

                        # Set default value if provided
                        if ($envVar.defaultValue) {
                            $valBody = @{
                                schemaname = "$($envVar.schemaName)_default"
                                value      = "$($envVar.defaultValue)"
                            }
                            # Retrieve the definition ID for binding
                            $defLookup = Invoke-DataverseApi -Connection $Connection `
                                -Endpoint "environmentvariabledefinitions?`$filter=schemaname eq '$($envVar.schemaName)'&`$select=environmentvariabledefinitionid"
                            if ($defLookup.value -and $defLookup.value.Count -gt 0) {
                                $defId = $defLookup.value[0].environmentvariabledefinitionid
                                $valBody['EnvironmentVariableDefinitionId@odata.bind'] = "/environmentvariabledefinitions($defId)"
                                try {
                                    Invoke-DataverseApi -Connection $Connection `
                                        -Endpoint 'environmentvariablevalues' `
                                        -Method POST -Body $valBody -IncludeSolutionHeader
                                } catch {
                                    Write-Warning "    [WARN] Default value for $($envVar.schemaName): $_"
                                }
                            }
                        }

                        Write-Host "    [CREATED] $($envVar.schemaName)" -ForegroundColor Green
                    }
                    $results.environmentVariables += @{ name = $envVar.schemaName; action = 'Created' }
                }
            }
            catch {
                Write-Warning "    [FAIL] $($envVar.schemaName): $_"
                $results.environmentVariables += @{ name = $envVar.schemaName; action = 'Failed' }
            }
        }
    }
    else {
        Write-Host "  [EnvVars] No environment-variables.json found, skipping." -ForegroundColor DarkGray
    }

    # ── Step 2: Import Connection References ──
    $connRefsPath = Join-Path $SourcePath 'connection-references.json'
    if (Test-Path $connRefsPath) {
        $connRefsList = @(Get-Content $connRefsPath -Raw | ConvertFrom-Json)
        Write-Host "`n  [ConnRefs] Processing $($connRefsList.Count) connection reference(s)..." -ForegroundColor Gray

        foreach ($connRef in $connRefsList) {
            try {
                $existing = $null
                try {
                    $existing = Invoke-DataverseApi -Connection $Connection `
                        -Endpoint "connectionreferences?`$filter=connectionreferencelogicalname eq '$($connRef.schemaName)'&`$select=connectionreferenceid"
                } catch { }

                if ($existing -and $existing.value -and $existing.value.Count -gt 0) {
                    Write-Host "    [EXISTS] $($connRef.schemaName) ($($connRef.connectorId))" -ForegroundColor DarkGray
                    $results.connectionReferences += @{ name = $connRef.schemaName; action = 'Exists' }
                }
                else {
                    $body = @{
                        connectionreferencelogicalname = $connRef.schemaName
                        connectionreferencedisplayname = $connRef.displayName
                        connectorid                    = $connRef.connectorId
                    }

                    if ($DryRun) {
                        Write-Host "    [DRY-RUN] Would create connection reference: $($connRef.schemaName)" -ForegroundColor Yellow
                    }
                    else {
                        Invoke-DataverseApi -Connection $Connection `
                            -Endpoint 'connectionreferences' `
                            -Method POST -Body $body -IncludeSolutionHeader
                        Write-Host "    [CREATED] $($connRef.schemaName)" -ForegroundColor Green
                    }
                    $results.connectionReferences += @{ name = $connRef.schemaName; action = 'Created' }
                }
            }
            catch {
                Write-Warning "    [FAIL] $($connRef.schemaName): $_"
                $results.connectionReferences += @{ name = $connRef.schemaName; action = 'Failed' }
            }
        }
    }
    else {
        Write-Host "  [ConnRefs] No connection-references.json found, skipping." -ForegroundColor DarkGray
    }

    # ── Step 3: Create Flow Workflow Records ──
    # Load connection reference definitions for mapping
    $connRefMap = @{}
    if (Test-Path $connRefsPath) {
        $connRefsList | ForEach-Object {
            # Map the connector API name (e.g. "shared_commondataserviceforapps") to the solution connection reference logical name
            $connectorKey = ($_.connectorId -split '/')[-1]
            $connRefMap[$connectorKey] = @{
                logicalName = $_.schemaName
                connectorId = $_.connectorId
            }
        }
    }

    $flowFiles = Get-ChildItem -Path $SourcePath -Filter 'andy_*.json' -File
    if ($FlowName) {
        $flowFiles = $flowFiles | Where-Object { $_.BaseName -eq $FlowName }
        if ($flowFiles.Count -eq 0) {
            throw "Flow file not found: $FlowName.json in $SourcePath"
        }
    }
    Write-Host "`n  [Flows] Found $($flowFiles.Count) flow definition(s)." -ForegroundColor Gray

    foreach ($file in $flowFiles) {
        try {
            $flowDef = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $flowName = $flowDef.flowName

            Write-Host "`n    [Flow] $flowName ($($file.Name))" -ForegroundColor White
            Write-Host "      Description: $($flowDef.flowDescription)" -ForegroundColor DarkGray

            # Check if workflow already exists by name
            $existingFlow = $null
            try {
                $existingFlow = Invoke-DataverseApi -Connection $Connection `
                    -Endpoint "workflows?`$filter=name eq '$($flowName -replace "'", "''")' and category eq 5&`$select=workflowid,name,statecode,modifiedon&`$orderby=modifiedon desc"
            } catch { }

            if ($existingFlow -and $existingFlow.value -and $existingFlow.value.Count -gt 0) {
                Write-Host "      [EXISTS] Workflow already in Dataverse ($($existingFlow.value.Count) match(es))" -ForegroundColor DarkGray
                if ($existingFlow.value.Count -gt 1) {
                    Write-Host "      [WARN] Duplicate cloud flow records detected for '$flowName'." -ForegroundColor Yellow
                }
            }

            # Build connectionReferences map for clientdata
            $flowConnRefs = @{}
            if ($flowDef.connectionReferences) {
                foreach ($refName in $flowDef.connectionReferences) {
                    # refName is the solution connection ref logical name (e.g. "andy_shared_commondataserviceforapps")
                    # Extract the connector key from the logical name (strip publisher prefix)
                    $connectorKey = $refName -replace '^andy_', ''
                    if ($connRefMap.ContainsKey($connectorKey)) {
                        $ref = $connRefMap[$connectorKey]
                        $flowConnRefs[$connectorKey] = @{
                            runtimeSource = 'invoker'
                            connection    = @{
                                connectionReferenceLogicalName = $ref.logicalName
                            }
                            api           = @{ name = $connectorKey }
                        }
                    }
                }
            }

            # Build the clientdata JSON
            $clientDataObj = @{
                properties = @{
                    definition           = $flowDef.definition
                    connectionReferences = $flowConnRefs
                    environment          = @{
                        name = 'Default'
                        id   = ''
                    }
                }
                schemaVersion = '1.0.0.0'
            }

            # If a workflow already exists, either update it in place (default) or replace it intentionally.
            if ($existingFlow -and $existingFlow.value -and $existingFlow.value.Count -gt 0) {
                if (-not $ReplaceExistingFlows -and $existingFlow.value.Count -gt 1) {
                    throw "Multiple workflows found for '$flowName'. Update mode will not guess which record to patch. Manually clean up duplicates or rerun with -ReplaceExistingFlows only if you intentionally want destructive deduplication."
                }

                $existingWorkflowId = $existingFlow.value[0].workflowid
                $skipCurrentFlow = $false
                if (-not $ReplaceExistingFlows) {
                    $flowDescription = if ($flowDef.flowDescription) { $flowDef.flowDescription } else { '' }
                    $definitionJson = $flowDef.definition | ConvertTo-Json -Depth 100 -Compress

                    # Fetch the live flow record to reuse its existing clientdata connectionReferences.
                    # Dataverse rejects clientdata with connectionReferenceLogicalName entries for
                    # connection references that have no real connection bound yet. Reading the live
                    # clientdata and only swapping in the new definition preserves whatever connections
                    # are already signed-in and bound in the environment.
                    $liveRecord = $null
                    $mergedClientDataJson = $null
                    try {
                        $liveRecord = Invoke-DataverseApi -Connection $Connection `
                            -Endpoint "workflows($existingWorkflowId)?`$select=clientdata"
                    } catch { }

                    if ($liveRecord -and $liveRecord.clientdata) {
                        try {
                            $liveClientData = $liveRecord.clientdata | ConvertFrom-Json
                            if ($liveClientData.properties) {
                                $liveClientData.properties.definition = $flowDef.definition
                            }
                            $mergedClientDataJson = $liveClientData | ConvertTo-Json -Depth 100 -Compress
                            Write-Host "      [INFO] Using live clientdata connectionReferences for PATCH." -ForegroundColor DarkGray
                        } catch {
                            Write-Host "      [WARN] Could not parse live clientdata; falling back to freshly built clientdata." -ForegroundColor DarkGray
                        }
                    }

                    if (-not $mergedClientDataJson) {
                        $mergedClientDataJson = $clientDataObj | ConvertTo-Json -Depth 100 -Compress
                    }

                    $workflowPatchBody = @{
                        description = $flowDescription
                        definition  = $definitionJson
                        clientdata  = $mergedClientDataJson
                    }

                    if ($DryRun) {
                        Write-Host "      [DRY-RUN] Would update existing workflow: $flowName" -ForegroundColor Yellow
                        $results.flows += @{ name = $flowName; file = $file.Name; action = 'DryRunUpdate' }
                        continue
                    }

                    try {
                        Invoke-DataverseApi -Connection $Connection `
                            -Endpoint "workflows($existingWorkflowId)" `
                            -Method PATCH -Body $workflowPatchBody -IncludeSolutionHeader
                        Write-Host "      [UPDATED] $flowName — existing workflow definition refreshed" -ForegroundColor Green
                        $results.flows += @{ name = $flowName; file = $file.Name; action = 'Updated' }
                        continue
                    }
                    catch {
                        Write-Host "      [WARN] In-place update failed. Retrying with phased metadata patch for $flowName" -ForegroundColor Yellow
                        Write-Host "             $($_.Exception.Message)" -ForegroundColor DarkGray

                        $flowDescription = if ($flowDef.flowDescription) { $flowDef.flowDescription } else { '' }
                        $definitionJson = $flowDef.definition | ConvertTo-Json -Depth 100 -Compress
                        $clientDataJson = $clientDataObj | ConvertTo-Json -Depth 100 -Compress

                        $workflowPatchFallbackBody = @{
                            definition = $definitionJson
                        }

                        try {
                            Invoke-DataverseApi -Connection $Connection `
                                -Endpoint "workflows($existingWorkflowId)" `
                                -Method PATCH -Body $workflowPatchFallbackBody -IncludeSolutionHeader

                            # Follow with clientdata+description patch so designer reflects the new payload.
                            $workflowPatchMetadataBody = [ordered]@{
                                definition  = $definitionJson
                                clientdata  = $clientDataJson
                                description = $flowDescription
                            }

                            Invoke-DataverseApi -Connection $Connection `
                                -Endpoint "workflows($existingWorkflowId)" `
                                -Method PATCH -Body $workflowPatchMetadataBody -IncludeSolutionHeader

                            Write-Host "      [UPDATED] $flowName — workflow metadata refreshed using phased fallback" -ForegroundColor Green
                            $results.flows += @{ name = $flowName; file = $file.Name; action = 'UpdatedPhasedFallback' }
                            continue
                        }
                        catch {
                            $lastPatchError = $_.Exception.Message
                            Write-Host "      [FAIL] Both PATCH attempts failed for '$flowName'." -ForegroundColor Red
                            Write-Host "             $lastPatchError" -ForegroundColor DarkGray
                            Write-Host "" 
                            Write-Host "      Options:" -ForegroundColor Yellow
                            Write-Host "        [R] Replace — delete existing workflow and recreate from local JSON" -ForegroundColor Yellow
                            Write-Host "            WARNING: resets run history, last-modified timestamp, and requires" -ForegroundColor DarkGray
                            Write-Host "            connector re-auth. Only use when update is genuinely blocked." -ForegroundColor DarkGray
                            Write-Host "        [S] Skip    — leave the existing workflow unchanged and continue" -ForegroundColor Yellow
                            Write-Host "        [A] Abort   — stop the import immediately" -ForegroundColor Yellow
                            Write-Host ""

                            $doReplace = $false
                            if (-not $DryRun -and -not [Console]::IsInputRedirected) {
                                $choice = Read-Host "      Choice [R/S/A] (default: S)"
                                switch ($choice.Trim().ToUpper()) {
                                    'R' { $doReplace = $true }
                                    'A' { throw "Import aborted by user after update failure for '$flowName'. Last error: $lastPatchError" }
                                    default {
                                        Write-Host "      [SKIPPED] '$flowName' left unchanged." -ForegroundColor Yellow
                                        $results.flows += @{ name = $flowName; file = $file.Name; action = 'Skipped' }
                                        $skipCurrentFlow = $true
                                    }
                                }
                            }
                            else {
                                # Non-interactive (CI/CD or dry-run) — fail with guidance
                                throw "Unable to update existing workflow '$flowName' in place. Full PATCH and phased PATCH both failed. Run Repair-FlowDefinition.ps1 if the record is corrupted, or rerun with -ReplaceExistingFlows for a deliberate destructive reset. Last error: $lastPatchError"
                            }

                            if ($doReplace) {
                                Write-Host "      [REPLACE] Deleting existing workflow(s) for '$flowName'..." -ForegroundColor Yellow
                                foreach ($match in $existingFlow.value) {
                                    Invoke-DataverseApi -Connection $Connection `
                                        -Endpoint "workflows($($match.workflowid))" `
                                        -Method DELETE
                                }
                                Write-Host "      [DELETED] Existing workflow(s) removed." -ForegroundColor Yellow

                                $replaceBody = @{
                                    name          = $flowName
                                    description   = $flowDescription
                                    category      = 5
                                    type          = 1
                                    primaryentity = 'none'
                                    statecode     = 0
                                    definition    = $definitionJson
                                    clientdata    = $clientDataJson
                                }
                                Invoke-DataverseApi -Connection $Connection `
                                    -Endpoint 'workflows' `
                                    -Method POST -Body $replaceBody -IncludeSolutionHeader
                                Write-Host "      [CREATED] $flowName — recreated in Draft state" -ForegroundColor Green
                                $results.flows += @{ name = $flowName; file = $file.Name; action = 'Replaced' }
                                continue
                            }
                        }
                    }
                }

                if ($skipCurrentFlow) { continue }

                if ($DryRun) {
                    Write-Host "      [DRY-RUN] Would delete existing workflow(s) before recreate: $flowName (count: $($existingFlow.value.Count))" -ForegroundColor Yellow
                    $results.flows += @{ name = $flowName; file = $file.Name; action = 'DryRunReplace' }
                    continue
                }

                foreach ($match in $existingFlow.value) {
                    Invoke-DataverseApi -Connection $Connection `
                        -Endpoint "workflows($($match.workflowid))" `
                        -Method DELETE
                }

                Write-Host "      [DELETED] Existing workflow(s) removed: $flowName (count: $($existingFlow.value.Count))" -ForegroundColor Yellow
            }

            # Create the workflow record (category 5 = Modern Flow / Cloud Flow)
            $flowDescription = if ($flowDef.flowDescription) { $flowDef.flowDescription } else { '' }
            $definitionJson = $flowDef.definition | ConvertTo-Json -Depth 100 -Compress
            $clientDataJson = $clientDataObj | ConvertTo-Json -Depth 100 -Compress

            $workflowBody = @{
                name          = $flowName
                description   = $flowDescription
                category      = 5
                type          = 1
                primaryentity = 'none'
                statecode     = 0
                definition    = $definitionJson
                clientdata    = $clientDataJson
            }

            if ($DryRun) {
                Write-Host "      [DRY-RUN] Would create workflow: $flowName" -ForegroundColor Yellow
                $results.flows += @{ name = $flowName; file = $file.Name; action = 'DryRun' }
            }
            else {
                Invoke-DataverseApi -Connection $Connection `
                    -Endpoint 'workflows' `
                    -Method POST -Body $workflowBody -IncludeSolutionHeader
                Write-Host "      [CREATED] $flowName — workflow created in Draft state" -ForegroundColor Green
                $results.flows += @{ name = $flowName; file = $file.Name; action = 'Created' }
            }
        }
        catch {
            Write-Warning "    [FAIL] $($file.Name): $_"
            $results.flows += @{ name = $file.Name; action = 'Failed'; error = "$_" }
        }
    }

    # ── Summary ──
    Write-Host "`n[Flows] Import complete." -ForegroundColor Green
    Write-Host "  Environment Variables: $($results.environmentVariables.Count) processed" -ForegroundColor Gray
    Write-Host "  Connection References: $($results.connectionReferences.Count) processed" -ForegroundColor Gray
    Write-Host "  Flow Definitions:      $($results.flows.Count) processed" -ForegroundColor Gray

    $failedCount = @(
        ($results.environmentVariables | Where-Object { $_.action -eq 'Failed' }).Count
        ($results.connectionReferences | Where-Object { $_.action -eq 'Failed' }).Count
        ($results.flows | Where-Object { $_.action -eq 'Failed' }).Count
    ) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

    if ($failedCount -gt 0) {
        Write-Host "  Failures: $failedCount" -ForegroundColor Red
    }

    Write-Host @"

  NOTE: Flows are created in Draft state. To activate them:
  1. Open each flow in Power Automate (make.powerautomate.com)
  2. Configure connection references (sign in to each connector)
  3. Set environment variable values
  4. Turn on the flow

"@ -ForegroundColor DarkGray

    return $results
}
