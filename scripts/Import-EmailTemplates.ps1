<#
.SYNOPSIS
    Imports and updates managed AgenticIoT email templates in Dataverse.
.DESCRIPTION
    Reads template metadata from automations/emails/templates.json and upserts
    records into the standard Dataverse template table using the template title as the key.
    Supports dry run mode and enforces the agenticiot naming prefix for managed assets.
.PARAMETER Connection
    Dataverse connection object from Connect-Dataverse.
.PARAMETER SourcePath
    Path to template source files. Defaults to automations/emails.
.PARAMETER ManifestPath
    Optional explicit path to templates manifest JSON.
.PARAMETER DryRun
    Preview mode - logs planned create/update actions without API writes.
.EXAMPLE
    Import-EmailTemplates -Connection $conn
    # Imports or updates all templates from automations/emails/templates.json
.EXAMPLE
    Import-EmailTemplates -Connection $conn -DryRun
    # Prints planned template changes without saving to Dataverse
#>

function Import-EmailTemplates {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,

        [string]$SourcePath,

        [string]$ManifestPath,

        [switch]$DryRun
    )

    Write-Host "`n=== Import Email Templates ===" -ForegroundColor Cyan

    if (-not $SourcePath) {
        $SourcePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'automations\emails'
    }
    if (-not (Test-Path $SourcePath)) {
        throw "Email template source path not found: $SourcePath"
    }

    if (-not $ManifestPath) {
        $ManifestPath = Join-Path $SourcePath 'templates.json'
    }
    if (-not (Test-Path $ManifestPath)) {
        throw "Email template manifest not found: $ManifestPath"
    }

    $entityMeta = Invoke-DataverseApi -Connection $Connection -Endpoint "EntityDefinitions(LogicalName='template')?`$select=EntitySetName,PrimaryIdAttribute"
    $entitySetName = $entityMeta.EntitySetName
    $primaryIdAttribute = $entityMeta.PrimaryIdAttribute

    if (-not $entitySetName) {
        throw "Unable to resolve EntitySetName for standard Dataverse template table (logical name: template)."
    }

    $manifestRaw = Get-Content -Path $ManifestPath -Raw
    $templates = @($manifestRaw | ConvertFrom-Json)

    if ($templates.Count -eq 0) {
        Write-Host "[Templates] No templates found in manifest." -ForegroundColor Yellow
        return @{ processed = 0; created = 0; updated = 0; unchanged = 0; failed = 0 }
    }

    Write-Host "[Templates] Processing $($templates.Count) managed template(s) from $ManifestPath" -ForegroundColor Gray

    $created = 0
    $updated = 0
    $unchanged = 0
    $failed = 0

    foreach ($template in $templates) {
        try {
            if (-not $template.name) {
                throw "Template entry is missing 'name'."
            }
            if ($template.name -notlike 'agenticiot*') {
                throw "Template '$($template.name)' is invalid. Managed template names must start with agenticiot."
            }
            if (-not $template.subject) {
                throw "Template '$($template.name)' is missing 'subject'."
            }
            if (-not $template.bodyFile) {
                throw "Template '$($template.name)' is missing 'bodyFile'."
            }

            $bodyPath = Join-Path $SourcePath $template.bodyFile
            if (-not (Test-Path $bodyPath)) {
                throw "Template body file not found: $bodyPath"
            }
            $bodyHtml = Get-Content -Path $bodyPath -Raw

            $placeholderList = ''
            if ($template.placeholders) {
                $placeholderList = (($template.placeholders | ForEach-Object { [string]$_.Trim() } | Where-Object { $_ }) -join ', ')
            }

            $descriptionText = if ($template.description) { [string]$template.description } else { '' }
            if ($placeholderList) {
                $descriptionText = ($descriptionText + " Placeholder tokens: " + $placeholderList).Trim()
            }
            if ($template.version) {
                $descriptionText = ($descriptionText + " Version: " + [string]$template.version).Trim()
            }

            # templatetypecode is Edm.String and must be an email-enabled entity logical name.
            # Custom entities are not email-enabled, so flow-driven templates always use 'contact'.
            $payload = @{
                title            = [string]$template.name
                subject          = [string]$template.subject
                safehtml         = [string]$bodyHtml
                description      = $descriptionText
                templatetypecode = 'contact'
                ispersonal       = $false
                languagecode     = 1033
            }

            $escapedName = ([string]$template.name) -replace "'", "''"
            $filter = "title eq '$escapedName'"
            $select = "title,subject,safehtml,description,templatetypecode,ispersonal,languagecode,$primaryIdAttribute"
            $existing = Invoke-DataverseApi -Connection $Connection -Endpoint "$entitySetName`?`$filter=$filter&`$select=$select&`$top=1"

            if ($existing.value -and $existing.value.Count -gt 0) {
                $current = $existing.value[0]
                $recordId = $current.$primaryIdAttribute

                $changes = @{}
                foreach ($key in $payload.Keys) {
                    $currentValue = $current.$key
                    $newValue = $payload[$key]

                    if ($null -eq $currentValue -and $null -eq $newValue) { continue }

                    $currentText = if ($null -eq $currentValue) { '' } else { [string]$currentValue }
                    $newText = if ($null -eq $newValue) { '' } else { [string]$newValue }

                    if ($currentText -ne $newText) {
                        $changes[$key] = $newValue
                    }
                }

                if ($changes.Count -eq 0) {
                    Write-Host "  [UNCHANGED] $($template.name)" -ForegroundColor DarkGray
                    $unchanged++
                    continue
                }

                if ($DryRun) {
                    Write-Host "  [DRY-RUN] Would update $($template.name) ($($changes.Keys.Count) changed field(s))" -ForegroundColor Yellow
                }
                else {
                    Invoke-DataverseApi -Connection $Connection -Endpoint "$entitySetName($recordId)" -Method PATCH -Body $changes -IncludeSolutionHeader
                    Write-Host "  [UPDATED] $($template.name)" -ForegroundColor Green
                }
                $updated++
            }
            else {
                if ($DryRun) {
                    Write-Host "  [DRY-RUN] Would create $($template.name)" -ForegroundColor Yellow
                }
                else {
                    Invoke-DataverseApi -Connection $Connection -Endpoint $entitySetName -Method POST -Body $payload -IncludeSolutionHeader
                    Write-Host "  [CREATED] $($template.name)" -ForegroundColor Green
                }
                $created++
            }
        }
        catch {
            $failed++
            Write-Host "  [FAIL] $($template.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "[Templates] Import complete. Created: $created | Updated: $updated | Unchanged: $unchanged | Failed: $failed" -ForegroundColor Cyan

    if ($failed -gt 0) {
        throw "Import-EmailTemplates encountered $failed failure(s)."
    }

    return @{
        processed = $templates.Count
        created   = $created
        updated   = $updated
        unchanged = $unchanged
        failed    = $failed
    }
}
