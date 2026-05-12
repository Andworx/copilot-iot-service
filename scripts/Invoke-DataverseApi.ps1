<#
.SYNOPSIS
    Reusable HTTP wrapper for Dataverse Web API calls with retry logic.
.DESCRIPTION
    Provides Invoke-DataverseApi (GET/POST/PATCH/DELETE with 429 retry),
    Test-DataverseExists (existence check by URL), and
    Get-AllDataverseRecords (auto-paging GET helper).
#>

function Invoke-DataverseApi {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body = $null,

        [switch]$IncludeSolutionHeader,

        [int]$MaxRetries = 3,

        [switch]$RawResponse
    )

    $url = if ($Endpoint -match '^https?://') { $Endpoint } else { "$($Connection.ApiBase)/$Endpoint" }

    $headers = @{}
    foreach ($key in $Connection.Headers.Keys) {
        $headers[$key] = $Connection.Headers[$key]
    }
    if ($IncludeSolutionHeader -and $Connection.SolutionName) {
        $headers['MSCRM.SolutionUniqueName'] = $Connection.SolutionName
    }

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            $params = @{
                Method      = $Method
                Uri         = $url
                Headers     = $headers
                ErrorAction = 'Stop'
            }
            if ($Body -and $Method -in @('POST', 'PATCH', 'PUT')) {
                $jsonBody = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 100 }
                $params['Body'] = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
            }

            $response = Invoke-RestMethod @params
            return $response
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            # Retry on 429 (throttled)
            if ($statusCode -eq 429 -and $attempt -lt $MaxRetries) {
                $retryAfter = 5
                if ($_.Exception.Response.Headers -and $_.Exception.Response.Headers['Retry-After']) {
                    $retryAfter = [int]$_.Exception.Response.Headers['Retry-After']
                }
                Write-Warning "[API] Throttled (429). Retry $attempt/$MaxRetries in ${retryAfter}s..."
                Start-Sleep -Seconds $retryAfter
                continue
            }

            # Extract OData error message
            $errorDetail = $_.Exception.Message
            try {
                if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                    $odataError = $_.ErrorDetails.Message | ConvertFrom-Json
                    if ($odataError.error.message) {
                        $errorDetail = $odataError.error.message
                    }
                }
            }
            catch { }

            throw "[API] $Method $url failed (HTTP $statusCode): $errorDetail"
        }
    }
}

function Test-DataverseExists {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$Endpoint
    )

    try {
        $null = Invoke-DataverseApi -Connection $Connection -Endpoint $Endpoint -Method GET
        return $true
    }
    catch {
        if ($_ -match '404') { return $false }
        throw
    }
}

function Get-AllDataverseRecords {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$Endpoint
    )

    $allRecords = @()
    $url = $Endpoint

    while ($url) {
        $response = Invoke-DataverseApi -Connection $Connection -Endpoint $url -Method GET
        if ($response.value) {
            $allRecords += $response.value
        }
        $url = $response.'@odata.nextLink'
    }

    return $allRecords
}
