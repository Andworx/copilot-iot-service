<#
.SYNOPSIS
    Import global option sets (choices) into Dataverse from local JSON definitions.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER SourcePath
    Path to the choices directory. Defaults to tables/choices.
.PARAMETER DryRun
    Preview mode — logs what would happen without making API calls.
#>

function Import-Choices {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$SourcePath,
        [switch]$DryRun
    )

    Write-Host "`n=== Import Choices ===" -ForegroundColor Cyan

    if (-not $SourcePath) {
        $SourcePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tables\choices'
    }
    if (-not (Test-Path $SourcePath)) {
        throw "Choices source path not found: $SourcePath"
    }

    $choiceFiles = Get-ChildItem -Path $SourcePath -Filter '*.json' | Where-Object { $_.Name -ne 'README.md' }
    if ($choiceFiles.Count -eq 0) {
        Write-Host "[Choices] No JSON files found in $SourcePath" -ForegroundColor Yellow
        return @{ imported = 0; choices = @() }
    }

    Write-Host "[Choices] Found $($choiceFiles.Count) choice definition(s)." -ForegroundColor Gray
    $results = @()

    foreach ($file in $choiceFiles) {
        $def = Get-Content $file.FullName -Raw | ConvertFrom-Json
        Write-Host "  [Choice] $($def.schemaName) — $($def.displayName)" -ForegroundColor White

        # Build OData options array
        $options = @($def.options | ForEach-Object {
            @{
                Value = $_.value
                Label = @{
                    LocalizedLabels = @(
                        @{
                            Label        = $_.label
                            LanguageCode = 1033
                        }
                    )
                }
                Description = @{
                    LocalizedLabels = @(
                        @{
                            Label        = $_.description
                            LanguageCode = 1033
                        }
                    )
                }
            }
        })

        # Check if the global option set already exists
        $exists = Test-DataverseExists -Connection $Connection -Endpoint "GlobalOptionSetDefinitions(Name='$($def.schemaName)')"

        if ($exists) {
            Write-Host "    [EXISTS] Already deployed, skipping." -ForegroundColor DarkGray
            $results += @{ name = $def.schemaName; action = 'Skipped' }
        }
        else {
            Write-Host "    [NEW] Creating global option set..." -ForegroundColor DarkGray

            if ($DryRun) {
                Write-Host "    [DRY-RUN] Would POST GlobalOptionSetDefinitions" -ForegroundColor Yellow
            }
            else {
                $body = @{
                    '@odata.type' = '#Microsoft.Dynamics.CRM.OptionSetMetadata'
                    Name          = $def.schemaName
                    DisplayName   = @{
                        LocalizedLabels = @(
                            @{ Label = $def.displayName; LanguageCode = 1033 }
                        )
                    }
                    Description   = @{
                        LocalizedLabels = @(
                            @{ Label = $def.description; LanguageCode = 1033 }
                        )
                    }
                    IsGlobal      = $true
                    Options       = $options
                }
                Invoke-DataverseApi -Connection $Connection `
                    -Endpoint 'GlobalOptionSetDefinitions' `
                    -Method POST -Body $body -IncludeSolutionHeader
            }
            $results += @{ name = $def.schemaName; action = 'Created' }
        }

        Write-Host "    [PASS] $($def.schemaName)" -ForegroundColor Green
    }

    Write-Host "`n[Choices] Processed $($results.Count) choice(s)." -ForegroundColor Green
    return @{ imported = $results.Count; choices = $results }
}
