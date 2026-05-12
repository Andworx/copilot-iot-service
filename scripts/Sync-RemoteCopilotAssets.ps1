<#
.SYNOPSIS
    Download remote Copilot instructions, agents, skills, and Claude commands into the local repo.
.DESCRIPTION
    Reads scripts/remote-content.sources.json to discover upstream sources and their
    file lists, then downloads each file via the GitHub raw content URL into the
    correct upstream folder:

      .github/instructions/upstream/<sourceKey>/<remotePath>   (GitHub Copilot instructions)
      .github/agents/upstream/<sourceKey>/<remotePath>         (GitHub Copilot agents)
      .github/skills/upstream/<sourceKey>/<remotePath>         (GitHub Copilot skills)
      .claude/commands/upstream/<sourceKey>/<remotePath>       (Claude Code slash commands)

    A sync-state file is written after each source run:
      .github/upstream/<sourceKey>/SYNC_STATE.json

    If $env:GITHUB_TOKEN or $env:GH_TOKEN is set it is used as a Bearer token so
    unauthenticated rate-limit hits are less likely. The script still works without
    authentication.

    Failures on individual files are non-fatal (warn and continue) so token
    application is never blocked by a sync failure.

.PARAMETER RepoRoot
    Absolute path to the repository root. Defaults to one level above the script dir.

.PARAMETER ManifestPath
    Path to the manifest JSON. Defaults to scripts/remote-content.sources.json.

.PARAMETER SourceKeys
    Only sync the sources whose key appears in this list. Syncs all enabled sources
    when omitted.

.PARAMETER NoPrompt
    Suppress all interactive prompts. Use together with SourceKeys or AllSources.

.PARAMETER AllSources
    Sync all enabled sources without prompting for selection.

.EXAMPLE
    .\scripts\Sync-RemoteCopilotAssets.ps1
    # Interactive: asks which sources to sync

.EXAMPLE
    .\scripts\Sync-RemoteCopilotAssets.ps1 -SourceKeys awesome-copilot
    # Non-interactive: sync only awesome-copilot

.EXAMPLE
    .\scripts\Sync-RemoteCopilotAssets.ps1 -AllSources -NoPrompt
    # Non-interactive: sync everything
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]   $RepoRoot     = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
    [string]   $ManifestPath = '',
    [string[]] $SourceKeys   = @(),
    [switch]   $NoPrompt,
    [switch]   $AllSources
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve manifest
# ---------------------------------------------------------------------------
if ([string]::IsNullOrEmpty($ManifestPath)) {
    $ManifestPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'remote-content.sources.json'
}

if (-not (Test-Path $ManifestPath)) {
    Write-Warning "Remote content manifest not found at: $ManifestPath  — skipping remote sync."
    return
}

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

$enabledSources = @($manifest.sources | Where-Object { $_.enabled -eq $true })

if ($enabledSources.Count -eq 0) {
    Write-Host '  No enabled sources found in remote-content.sources.json — nothing to sync.' -ForegroundColor DarkGray
    return
}

# ---------------------------------------------------------------------------
# Determine which sources to sync
# ---------------------------------------------------------------------------
$selectedSources = @()

if ($SourceKeys.Count -gt 0) {
    # Caller supplied explicit keys — validate and use
    foreach ($key in $SourceKeys) {
        $src = $enabledSources | Where-Object { $_.key -eq $key }
        if ($null -eq $src) {
            Write-Warning "Source key '$key' not found in manifest or is disabled — skipping."
        }
        else {
            $selectedSources += $src
        }
    }
}
elseif ($AllSources) {
    $selectedSources = $enabledSources
}
else {
    # Interactive selection
    if ($NoPrompt) {
        # NoPrompt without keys or AllSources means nothing to do
        Write-Host '  -NoPrompt set but no sources specified. Use -SourceKeys or -AllSources.' -ForegroundColor DarkGray
        return
    }

    Write-Host "`nAvailable remote Copilot asset sources:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $enabledSources.Count; $i++) {
        $s = $enabledSources[$i]
        $itemCount = ($s.items.instructions.Count + $s.items.agents.Count + $s.items.skills.Count + $s.items.claudeCommands.Count)
        Write-Host "  [$($i+1)] $($s.key)  —  $($s.repo)@$($s.ref)  ($itemCount file$(if($itemCount -ne 1){'s'}))" -ForegroundColor White
        if ($s.description) {
            Write-Host "       $($s.description)" -ForegroundColor DarkGray
        }
    }
    Write-Host "  [A] All of the above" -ForegroundColor White
    Write-Host "  [0] Cancel / skip" -ForegroundColor DarkGray

    $choice = Read-Host "`nEnter number(s) separated by commas, A for all, or 0 to skip"
    $choice = $choice.Trim()

    if ($choice -eq '0' -or [string]::IsNullOrEmpty($choice)) {
        Write-Host '  Skipping remote sync.' -ForegroundColor DarkGray
        return
    }
    elseif ($choice -ieq 'A') {
        $selectedSources = $enabledSources
    }
    else {
        foreach ($part in ($choice -split ',')) {
            $n = $part.Trim()
            if ($n -match '^\d+$') {
                $idx = [int]$n - 1
                if ($idx -ge 0 -and $idx -lt $enabledSources.Count) {
                    $selectedSources += $enabledSources[$idx]
                }
                else {
                    Write-Warning "Selection '$n' out of range — ignored."
                }
            }
            else {
                Write-Warning "Invalid selection '$n' — ignored."
            }
        }
    }
}

if ($selectedSources.Count -eq 0) {
    Write-Host '  No sources selected — skipping remote sync.' -ForegroundColor DarkGray
    return
}

# ---------------------------------------------------------------------------
# Confirm before writing (unless NoPrompt)
# ---------------------------------------------------------------------------
if (-not $NoPrompt -and -not $WhatIfPreference) {
    $keyList = ($selectedSources | ForEach-Object { $_.key }) -join ', '
    Write-Host "`nReady to download assets from: $keyList" -ForegroundColor Cyan
    Write-Host "Files will be written to .github/**/upstream/ and .claude/commands/upstream/ inside this repo." -ForegroundColor DarkGray
    $confirm = Read-Host "Proceed? (Y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host '  Cancelled.' -ForegroundColor DarkGray
        return
    }
}

# ---------------------------------------------------------------------------
# Build auth header (optional)
# ---------------------------------------------------------------------------
$authHeader = @{}
$token = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { $null }
if ($token) {
    $authHeader = @{ Authorization = "Bearer $token" }
    Write-Host '  Using GitHub token for authenticated requests.' -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Kind → destination root mapping
# ---------------------------------------------------------------------------
$kindDestMap = @{
    instructions  = '.github/instructions/upstream'
    agents        = '.github/agents/upstream'
    skills        = '.github/skills/upstream'
    claudeCommands = '.claude/commands/upstream'
}

# ---------------------------------------------------------------------------
# Process each selected source
# ---------------------------------------------------------------------------
$grandAdded   = 0
$grandUpdated = 0
$grandFailed  = 0

foreach ($source in $selectedSources) {
    Write-Host "`n  Syncing source: $($source.key)  [$($source.repo)@$($source.ref)]" -ForegroundColor Cyan

    $syncResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $added   = 0
    $updated = 0
    $failed  = 0

    foreach ($kind in @('instructions','agents','skills','claudeCommands')) {
        $paths = $source.items.$kind
        if ($null -eq $paths -or $paths.Count -eq 0) { continue }

        $destRoot = Join-Path $RepoRoot ($kindDestMap[$kind]) | Join-Path -ChildPath $source.key

        foreach ($remotePath in $paths) {
            $url = "https://raw.githubusercontent.com/$($source.repo)/$($source.ref)/$remotePath"

            $destFile = Join-Path $destRoot $remotePath

            Write-Host "    Downloading $remotePath ..." -ForegroundColor Gray -NoNewline

            # Ensure destination directory exists
            $destDir = Split-Path -Parent $destFile
            if (-not (Test-Path $destDir)) {
                if ($PSCmdlet.ShouldProcess($destDir, 'Create directory')) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
            }

            $status   = 'ok'
            $isNew    = -not (Test-Path $destFile)
            $errorMsg = $null

            try {
                $params = @{
                    Uri         = $url
                    OutFile     = $destFile
                    UseBasicParsing = $true
                }
                if ($authHeader.Count -gt 0) {
                    $params.Headers = $authHeader
                }

                if ($PSCmdlet.ShouldProcess($destFile, "Download $url")) {
                    Invoke-WebRequest @params -ErrorAction Stop
                    if ($isNew) { $added++; Write-Host ' added' -ForegroundColor Green }
                    else        { $updated++; Write-Host ' updated' -ForegroundColor Cyan }
                }
                else {
                    Write-Host ' (WhatIf)' -ForegroundColor DarkGray
                }
            }
            catch {
                $status   = 'failed'
                $errorMsg = $_.Exception.Message
                $failed++
                Write-Host " FAILED: $errorMsg" -ForegroundColor Red
            }

            $syncResults.Add([PSCustomObject]@{
                kind       = $kind
                remotePath = $remotePath
                url        = $url
                destFile   = $destFile
                status     = $status
                error      = $errorMsg
            })
        }
    }

    # -------------------------------------------------------------------------
    # Write SYNC_STATE.json
    # -------------------------------------------------------------------------
    $stateDir  = Join-Path $RepoRoot ".github/upstream/$($source.key)"
    $stateFile = Join-Path $stateDir 'SYNC_STATE.json'

    if (-not (Test-Path $stateDir)) {
        if ($PSCmdlet.ShouldProcess($stateDir, 'Create directory')) {
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        }
    }

    $state = [ordered]@{
        sourceKey  = $source.key
        repo       = $source.repo
        ref        = $source.ref
        syncedAt   = (Get-Date -Format 'o')
        files      = @($syncResults | ForEach-Object {
            [ordered]@{
                kind       = $_.kind
                remotePath = $_.remotePath
                url        = $_.url
                destFile   = $_.destFile
                status     = $_.status
                error      = $_.error
            }
        })
    }

    if ($PSCmdlet.ShouldProcess($stateFile, 'Write sync state')) {
        $state | ConvertTo-Json -Depth 6 | Set-Content -Path $stateFile -Encoding UTF8
    }

    Write-Host "    Source '$($source.key)': added=$added  updated=$updated  failed=$failed" -ForegroundColor $(if ($failed -gt 0) { 'Yellow' } else { 'Green' })

    $grandAdded   += $added
    $grandUpdated += $updated
    $grandFailed  += $failed
}

# ---------------------------------------------------------------------------
# Grand summary
# ---------------------------------------------------------------------------
Write-Host "`n  Remote Copilot asset sync complete." -ForegroundColor Cyan
Write-Host "  Added: $grandAdded   Updated: $grandUpdated   Failed: $grandFailed" -ForegroundColor $(if ($grandFailed -gt 0) { 'Yellow' } else { 'Green' })

if ($grandFailed -gt 0) {
    Write-Host "  Some files failed to download. Check the output above and SYNC_STATE.json files for details." -ForegroundColor Yellow
    Write-Host "  Token application was not affected." -ForegroundColor DarkGray
}
