<#
.SYNOPSIS
    Export security roles and their privileges from the YOUR_SOLUTION_NAME solution.
.PARAMETER Connection
    Hashtable from Connect-Dataverse.
.PARAMETER OutputPath
    Root output folder. Defaults to scripts/exports/YOUR_SOLUTION_NAME/securityroles.
#>

function Export-SecurityRoles {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    Write-Host "`n=== Export Security Roles ===" -ForegroundColor Cyan

    # --- Resolve solution ID ---
    $solutionName = $Connection.SolutionName
    $solutions = Invoke-DataverseApi -Connection $Connection -Endpoint "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid"
    if (-not $solutions.value -or $solutions.value.Count -eq 0) { throw "Solution '$solutionName' not found." }
    $solutionId = $solutions.value[0].solutionid

    # --- Get role components (componenttype 20 = SecurityRole) ---
    Write-Host "[SecurityRoles] Querying solution components..." -ForegroundColor Gray
    $components = Get-AllDataverseRecords -Connection $Connection -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solutionId and componenttype eq 20&`$select=objectid"

    if (-not $components -or $components.Count -eq 0) {
        Write-Host "[SecurityRoles] No security role components found." -ForegroundColor Yellow
        return @{ totalRoles = 0; roles = @() }
    }
    Write-Host "[SecurityRoles] Found $($components.Count) security roles." -ForegroundColor Gray

    $summary = @()

    foreach ($comp in $components) {
        $roleId = $comp.objectid
        try {
            $role = Invoke-DataverseApi -Connection $Connection -Endpoint "roles($roleId)?`$select=name,roleid,ismanaged,iscustomizable"

            $name = $role.name
            $safeName = $name -replace '[\\/:*?"<>|]', '_'
            Write-Host "  [Role] $name" -ForegroundColor White

            # Get role privileges
            $privileges = @()
            try {
                $privs = Get-AllDataverseRecords -Connection $Connection -Endpoint "roles($roleId)/roleprivileges_association?`$select=name,privilegeid"
                $privileges = @($privs | ForEach-Object {
                    [ordered]@{
                        privilegeId = $_.privilegeid
                        name        = $_.name
                    }
                })
            }
            catch {
                Write-Warning "    Failed to get privileges for role $name : $_"
            }

            $roleData = [ordered]@{
                exportedOnUtc  = (Get-Date).ToUniversalTime().ToString('o')
                roleId         = $roleId
                name           = $name
                isManaged      = $role.ismanaged
                isCustomizable = $role.iscustomizable
                privilegeCount = $privileges.Count
                privileges     = $privileges
            }

            $filePath = Join-Path $OutputPath "$safeName.json"
            $roleData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
            Write-Host "    -> $filePath ($($privileges.Count) privileges)" -ForegroundColor DarkGray

            $summary += [ordered]@{
                roleId         = $roleId
                name           = $name
                privilegeCount = $privileges.Count
                isManaged      = $role.ismanaged
            }
        }
        catch {
            Write-Warning "[SecurityRoles] Failed to export role $roleId : $_"
        }
    }

    $summaryData = [ordered]@{
        exportedOnUtc = (Get-Date).ToUniversalTime().ToString('o')
        totalRoles    = $summary.Count
        roles         = $summary
    }
    $summaryPath = Join-Path $OutputPath '_summary.json'
    $summaryData | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "`n[SecurityRoles] Exported $($summary.Count) security roles." -ForegroundColor Green

    return $summaryData
}
