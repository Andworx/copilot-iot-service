<#
.SYNOPSIS
    Authenticates to Dataverse using OAuth2 client_credentials (commercial cloud).
.DESCRIPTION
    Reads a config JSON file, resolves the environment-specific client secret from
    process environment variables, and obtains a Bearer token from Azure AD.
.PARAMETER ConfigPath
    Path to the environment config JSON file (e.g., config-dev.json).
.OUTPUTS
    Hashtable with keys: Headers, ApiBase, SolutionName, Config
#>

function Connect-Dataverse {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    # --- Load config ---
    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    # --- Detect environment name from config filename ---
    $configFileName = [System.IO.Path]::GetFileNameWithoutExtension($ConfigPath)
    $envName = if ($configFileName -match '^config-(.+)$') { ($Matches[1] -replace '\.example$', '').ToUpper() } else { 'DEV' }
    Write-Host "[Auth] Environment: $envName" -ForegroundColor Cyan

    # --- Resolve client secret ---
    $envSpecificVar = "DATAVERSE_CLIENT_SECRET_$envName"
    $secret = [System.Environment]::GetEnvironmentVariable($envSpecificVar, 'Process')
    if (-not $secret) {
        $secret = [System.Environment]::GetEnvironmentVariable('DATAVERSE_CLIENT_SECRET', 'Process')
    }
    if (-not $secret) {
        throw "No client secret found. Set `$envSpecificVar` or DATAVERSE_CLIENT_SECRET in your .env file."
    }

    # --- Resolve cloud authority endpoint ---
    $validCloudValues = @('commercial', 'gcc', 'gcch', 'dod')
    $cloudEnvironment = [string]$config.cloudEnvironment
    $authEndpoint = $null

    if (-not [string]::IsNullOrWhiteSpace($cloudEnvironment)) {
        $cloudKey = $cloudEnvironment.Trim().ToLowerInvariant()
        $authEndpoint = switch ($cloudKey) {
            'commercial' { 'https://login.microsoftonline.com' }
            'gcc'        { 'https://login.microsoftonline.com' }
            'gcch'       { 'https://login.microsoftonline.us' }
            'dod'        { 'https://login.microsoftonline.us' }
            default      { $null }
        }

        if (-not $authEndpoint) {
            throw "Invalid cloudEnvironment '$cloudEnvironment' in $ConfigPath. Valid values: $($validCloudValues -join ', ')."
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$config.authEndpoint)) {
        # Backward compatibility for existing config files that still define authEndpoint.
        $authEndpoint = [string]$config.authEndpoint
        Write-Host "[Auth] cloudEnvironment not set. Using legacy authEndpoint from config." -ForegroundColor Yellow
    }
    else {
        throw "Missing cloudEnvironment in $ConfigPath. Set cloudEnvironment to one of: $($validCloudValues -join ', ')."
    }

    # --- Request token ---
    $tokenUrl = "$authEndpoint/$($config.tenantId)/oauth2/v2.0/token"
    $body = [ordered]@{
        grant_type    = 'client_credentials'
        client_id     = $config.clientId
        client_secret = $secret
        scope         = "$($config.environmentUrl)/.default"
    }
    $formBody = [string]::Join('&', ($body.GetEnumerator() | ForEach-Object {
        "{0}={1}" -f $_.Key, [System.Net.WebUtility]::UrlEncode([string]$_.Value)
    }))

    $authCloudLabel = if ([string]::IsNullOrWhiteSpace($cloudEnvironment)) { 'legacy-config' } else { $cloudEnvironment }
    Write-Host "[Auth] Cloud: $authCloudLabel" -ForegroundColor Cyan
    Write-Host "[Auth] Requesting token from $authEndpoint..." -ForegroundColor Cyan
    try {
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -ContentType 'application/x-www-form-urlencoded' -Body $formBody -ErrorAction Stop
    }
    catch {
        $statusCode = $null
        $responseDetails = $null
        $response = $_.Exception.Response

        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $responseDetails = $_.ErrorDetails.Message.Trim()
        }

        if ($response -is [System.Net.Http.HttpResponseMessage]) {
            $statusCode = [int]$response.StatusCode
            if (-not $responseDetails -and $response.Content) {
                try {
                    $responseDetails = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                }
                catch { }
            }
        }
        elseif ($null -ne $response) {
            try {
                $statusCode = [int]$response.StatusCode
            }
            catch { }

            if (-not $responseDetails) {
                try {
                    $stream = $response.GetResponseStream()
                    if ($stream) {
                        $reader = [System.IO.StreamReader]::new($stream)
                        $responseDetails = $reader.ReadToEnd()
                        $reader.Dispose()
                    }
                }
                catch { }
            }
        }

        $errorMessage = 'Authentication failed'
        if ($statusCode) {
            $errorMessage += " (HTTP $statusCode)"
        }
        $errorMessage += ": $($_.Exception.Message)"
        if (-not [string]::IsNullOrWhiteSpace($responseDetails)) {
            $errorMessage += " Response body: $responseDetails"
        }

        throw $errorMessage
    }

    if (-not $tokenResponse.access_token) {
        throw "No access_token in response from $tokenUrl"
    }
    Write-Host "[Auth] Token acquired successfully." -ForegroundColor Green

    # --- Build connection object ---
    $apiBase = "$($config.environmentUrl)/api/data/$($config.apiVersion)"
    $headers = @{
        'Authorization'    = "Bearer $($tokenResponse.access_token)"
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
        'Accept'           = 'application/json'
        'Content-Type'     = 'application/json; charset=utf-8'
    }

    return @{
        Headers      = $headers
        ApiBase      = $apiBase
        SolutionName = $config.solutionUniqueName
        Config       = $config
    }
}
